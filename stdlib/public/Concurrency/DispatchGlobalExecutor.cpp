///===--- DispatchGlobalExecutor.inc ------------------------*- C++ -*--===///
///
/// This source file is part of the Swift.org open source project
///
/// Copyright (c) 2014 - 2020 Apple Inc. and the Swift project authors
/// Licensed under Apache License v2.0 with Runtime Library Exception
///
/// See https:///swift.org/LICENSE.txt for license information
/// See https:///swift.org/CONTRIBUTORS.txt for the list of Swift project authors
///
///===------------------------------------------------------------------===///
///
/// The implementation of the global executor when using Dispatch.
///
/// This file is included into GlobalExecutor.cpp only when Dispatch
/// integration is enabled.  It is expected to define the following
/// functions:
///   swift_task_asyncMainDrainQueueImpl
///   swift_task_checkIsolatedImpl
///   swift_task_donateThreadToGlobalExecutorUntilImpl
///   swift_task_enqueueGlobalImpl
///   swift_task_enqueueGlobalWithDeadlineImpl
///   swift_task_enqueueGlobalWithDelayImpl
///   swift_task_enqueueMainExecutorImpl
///   swift_task_getMainExecutorImpl
///   swift_task_isMainExecutorImpl
/// as well as any Dispatch-specific functions for the runtime.
///
///===------------------------------------------------------------------===///

#include <cstddef>

#include "swift/Basic/Casting.h"
#include "swift/Runtime/Concurrency.h"
#include "swift/Runtime/EnvironmentVariables.h"

#if SWIFT_CONCURRENCY_ENABLE_DISPATCH
#include "swift/Runtime/HeapObject.h"
#include <dispatch/dispatch.h>
#if defined(_WIN32)
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <Windows.h>
#else
#include <dlfcn.h>
#endif
#endif

#if __has_include(<dispatch/private.h>)
#include <dispatch/private.h>
#define SWIFT_CONCURRENCY_HAS_DISPATCH_PRIVATE 1
#endif

#include "Error.h"
#include "ExecutorImpl.h"
#include "TaskPrivate.h"

#ifndef NSEC_PER_SEC
#define NSEC_PER_SEC 1000000000ull
#endif

using namespace swift;

/// The function passed to dispatch_async_f to execute a job.
static void __swift_run_job(void *_job) {
  SwiftJob *job = (SwiftJob*) _job;
  auto metadata =
      reinterpret_cast<const DispatchClassMetadata *>(job->metadata);
  metadata->VTableInvoke(job, nullptr, 0);
}

/// The type of a function pointer for enqueueing a Job object onto a dispatch
/// queue.
typedef void (*dispatchEnqueueFuncType)(dispatch_queue_t queue, void *obj,
                                        dispatch_qos_class_t qos);

/// Initialize dispatchEnqueueFunc and then call through to the proper
/// implementation.
static void initializeDispatchEnqueueFunc(dispatch_queue_t queue, void *obj,
                                          dispatch_qos_class_t qos);

/// A function pointer to the function used to enqueue a Job onto a dispatch
/// queue. Initially set to initializeDispatchEnqueueFunc, so that the first
/// call will initialize it. initializeDispatchEnqueueFunc sets it to point
/// either to dispatch_async_swift_job when it's available, otherwise to
/// dispatchEnqueueDispatchAsync.
static std::atomic<dispatchEnqueueFuncType> dispatchEnqueueFunc{
    initializeDispatchEnqueueFunc};

/// A small adapter that dispatches a Job onto a queue using dispatch_async_f.
static void dispatchEnqueueDispatchAsync(dispatch_queue_t queue, void *obj,
                                         dispatch_qos_class_t qos) {
  dispatch_async_f(queue, obj, __swift_run_job);
}

static void initializeDispatchEnqueueFunc(dispatch_queue_t queue, void *obj,
                                          dispatch_qos_class_t qos) {
  dispatchEnqueueFuncType func = nullptr;

  // Always fall back to plain dispatch_async_f for back-deployed concurrency.
#if !defined(SWIFT_CONCURRENCY_BACK_DEPLOYMENT)
#if SWIFT_CONCURRENCY_HAS_DISPATCH_PRIVATE
  if (SWIFT_RUNTIME_WEAK_CHECK(dispatch_async_swift_job))
    func = SWIFT_RUNTIME_WEAK_USE(dispatch_async_swift_job);
#elif defined(_WIN32)
#if SwiftConcurrency_HAS_DISPATCH_ASYNC_SWIFT_JOB
#if defined(dispatch_STATIC)
  func = dispatch_async_swift_job;
#else
  func = function_cast<dispatchEnqueueFuncType>(
      GetProcAddress(LoadLibraryW(L"dispatch.dll"),
      "dispatch_async_swift_job"));
#endif
#endif
#else
  func = function_cast<dispatchEnqueueFuncType>(
      dlsym(RTLD_NEXT, "dispatch_async_swift_job"));
#endif
#endif

  if (!func)
    func = dispatchEnqueueDispatchAsync;

  dispatchEnqueueFunc.store(func, std::memory_order_relaxed);

  func(queue, obj, qos);
}

/// Enqueue a Job onto a dispatch queue using dispatchEnqueueFunc.
static void dispatchEnqueue(dispatch_queue_t queue, SwiftJob *job,
                            dispatch_qos_class_t qos, void *executorQueue) {
  job->schedulerPrivate[Job::DispatchQueueIndex] = executorQueue;
  dispatchEnqueueFunc.load(std::memory_order_relaxed)(queue, job, qos);
}

static constexpr size_t globalQueueCacheCount =
    static_cast<size_t>(JobPriority::UserInteractive) + 1;
static std::atomic<dispatch_queue_t> globalQueueCache[globalQueueCacheCount];

#if defined(__APPLE__) && !defined(SWIFT_CONCURRENCY_BACK_DEPLOYMENT)
static constexpr size_t dispatchQueueCooperativeFlag = 4;
#else
extern "C" void dispatch_queue_set_width(dispatch_queue_t dq, long width);
#endif

static dispatch_queue_t getGlobalQueue(SwiftJobPriority priority) {
  size_t numericPriority = static_cast<size_t>(priority);
  if (numericPriority >= globalQueueCacheCount)
    swift_Concurrency_fatalError(0, "invalid job priority %#zx", numericPriority);

#ifdef SWIFT_CONCURRENCY_BACK_DEPLOYMENT
  std::memory_order loadOrder = std::memory_order_acquire;
#else
  std::memory_order loadOrder = std::memory_order_relaxed;
#endif

  auto *ptr = &globalQueueCache[numericPriority];
  auto queue = ptr->load(loadOrder);
  if (SWIFT_LIKELY(queue))
    return queue;

#if defined(SWIFT_CONCURRENCY_BACK_DEPLOYMENT) || !defined(__APPLE__)
  const int DISPATCH_QUEUE_WIDTH_MAX_LOGICAL_CPUS = -3;

  // Create a new cooperative concurrent queue and swap it in.
  dispatch_queue_attr_t newQueueAttr = dispatch_queue_attr_make_with_qos_class(
      DISPATCH_QUEUE_CONCURRENT, (dispatch_qos_class_t)priority, 0);
  dispatch_queue_t newQueue = dispatch_queue_create(
      "Swift global concurrent queue", newQueueAttr);
  dispatch_queue_set_width(newQueue, DISPATCH_QUEUE_WIDTH_MAX_LOGICAL_CPUS);

  if (!ptr->compare_exchange_strong(queue, newQueue,
                                    /*success*/ std::memory_order_release,
                                    /*failure*/ std::memory_order_acquire)) {
    dispatch_release(newQueue);
    return queue;
  }

  return newQueue;
#else
  // If we don't have a queue cached for this priority, cache it now. This may
  // race with other threads doing this at the same time for this priority, but
  // that's OK, they'll all end up writing the same value.
  if (runtime::environment::concurrencyEnableCooperativeQueues())
    queue = dispatch_get_global_queue((dispatch_qos_class_t)priority,
                                      dispatchQueueCooperativeFlag);
  // If dispatch doesn't support dispatchQueueCooperativeFlag, it will return
  // NULL. Fall back to a standard global queue.
  if (!queue)
    queue = dispatch_get_global_queue((dispatch_qos_class_t)priority,
                                      /*flags*/ 0);

  // Unconditionally store it back in the cache. If we raced with another
  // thread, we'll just overwrite the entry with the same value.
  ptr->store(queue, std::memory_order_relaxed);
#endif

  return queue;
}

// Get a queue suitable for dispatch_after. Use the cooperative queues on OS
// versions where they work with dispatch_after, and use a standard global
// queue where cooperative queues don't work.
static dispatch_queue_t getTimerQueue(SwiftJobPriority priority) {
  // On newer OSes, we can use the cooperative queues.
  if (__builtin_available(macOS 12.3, iOS 15.4, tvOS 15.4, watchOS 8.5, *))
    return getGlobalQueue(priority);

  // On older OSes, use a standard global queue.
  return dispatch_get_global_queue((dispatch_qos_class_t)priority, /*flags*/ 0);
}

extern "C" SWIFT_CC(swift)
void swift_dispatchEnqueueGlobal(SwiftJob *job) {
  assert(job && "no job provided");
  // We really want four things from the global execution service:
  //  - Enqueuing work should have minimal runtime and memory overhead.
  //  - Adding work should never result in an "explosion" where many
  //    more threads are created than the available cores.
  //  - Jobs should run on threads with an appropriate priority.
  //  - Thread priorities should temporarily elevatable to avoid
  //    priority inversions.
  //
  // Of these, the first two are the most important.  Many programs
  // do not rely on high-usage priority scheduling, and many priority
  // inversions can be avoided at a higher level (albeit with some
  // performance cost, e.g. by creating higher-priority tasks to run
  // critical sections that contend with high-priority work).  In
  // contrast, if the async feature adds too much overhead, or if
  // heavy use of it leads to thread explosions and memory exhaustion,
  // programmers will have no choice but to stop using it.  So if
  // goals are in conflict, it's best to focus on core properties over
  // priority-inversion avoidance.

  // We currently use Dispatch for our thread pool on all platforms.
  // Dispatch currently backs its serial queues with a global
  // concurrent queue that is prone to thread explosions when a flood
  // of jobs are added to it.  That problem does not apply equally
  // to the global concurrent queues returned by dispatch_get_global_queue,
  // which are not strictly CPU-limited but are at least much more
  // cautious about adding new threads.  We cannot safely elevate
  // the priorities of work added to this queue using Dispatch's public
  // API, but as discussed above, that is less important than avoiding
  // performance problems.
  SwiftJobPriority priority = swift_job_getPriority(job);

  auto queue = getGlobalQueue(priority);

  dispatchEnqueue(queue, job, (dispatch_qos_class_t)priority,
                  DISPATCH_QUEUE_GLOBAL_EXECUTOR);
}

#define DISPATCH_UP_OR_MONOTONIC_TIME_MASK  (1ULL << 63)
#define DISPATCH_WALLTIME_MASK  (1ULL << 62)
#define DISPATCH_TIME_MAX_VALUE (DISPATCH_WALLTIME_MASK - 1)

struct __swift_job_source {
  dispatch_source_t source;
  SwiftJob *job;
};

static void _swift_run_job_leeway(struct __swift_job_source *jobSource) {
  dispatch_source_t source = jobSource->source;
  dispatch_release(source);
  SwiftJob *job = jobSource->job;
  swift_job_dealloc(job, jobSource);
  __swift_run_job(job);
}

#if defined(__i386__) || defined(__x86_64__) || !defined(__APPLE__)
#define TIME_UNIT_USES_NANOSECONDS 1
#else
#define TIME_UNIT_USES_NANOSECONDS 0
#endif

#if TIME_UNIT_USES_NANOSECONDS
// x86 currently implements mach time in nanoseconds
// this is NOT likely to change
static inline uint64_t
platform_time(uint64_t nsec) {
  return nsec;
}
#else
#define DISPATCH_USE_HOST_TIME 1
#if defined(__APPLE__)
#if defined(__arm__) || defined(__arm64__)
// Apple arm platforms currently use a fixed mach timebase of 125/3 (24 MHz)
static inline uint64_t
platform_time(uint64_t nsec) {
  if (!nsec) {
    return nsec;
  }
  if (nsec >= (uint64_t)INT64_MAX) {
    return INT64_MAX;
  }
  if (nsec >= UINT64_MAX / 3ull) {
    return (nsec / 125ull) * 3ull;
  } else {
    return (nsec * 3ull) / 125ull;
  }
}
#endif
#endif
#endif

static inline dispatch_time_t
clock_and_value_to_time(int clock, long long sec, long long nsec) {
  uint64_t deadline;
  if (sec < 0 || (sec == 0 && nsec < 0))
    deadline = 0;
  else if (__builtin_mul_overflow(sec, NSEC_PER_SEC, &deadline)
      || __builtin_add_overflow(nsec, deadline, &deadline)) {
    deadline = UINT64_MAX;
  }
  uint64_t value = platform_time((uint64_t)deadline);
  if (value >= DISPATCH_TIME_MAX_VALUE) {
    return DISPATCH_TIME_FOREVER;
  }
  switch (clock) {
  case swift_clock_id_suspending:
    return value;
  case swift_clock_id_continuous:
    return value | DISPATCH_UP_OR_MONOTONIC_TIME_MASK;
  case swift_clock_id_wall: {
    struct timespec ts = {
      .tv_sec = static_cast<decltype(ts.tv_sec)>(sec),
      .tv_nsec = static_cast<decltype(ts.tv_nsec)>(nsec)
    };
    return dispatch_walltime(&ts, 0);
  }
  }
  __builtin_unreachable();
}

extern "C" SWIFT_CC(swift)
void swift_dispatchEnqueueWithDeadline(bool global,
                                       long long sec,
                                       long long nsec,
                                       long long tsec,
                                       long long tnsec,
                                       int clock, SwiftJob *job) {
  assert(job && "no job provided");

  SwiftJobPriority priority = swift_job_getPriority(job);

  dispatch_queue_t queue;

  if (global) {
    queue = getTimerQueue(priority);

    job->schedulerPrivate[SwiftJobDispatchQueueIndex] =
      DISPATCH_QUEUE_GLOBAL_EXECUTOR;
  } else {
    queue = dispatch_get_main_queue();

    job->schedulerPrivate[SwiftJobDispatchQueueIndex] = queue;
  }

  dispatch_time_t when = clock_and_value_to_time(clock, sec, nsec);

  if (tnsec != -1) {
    uint64_t leeway;
    if (tsec < 0 || (tsec == 0 && tnsec < 0))
      leeway = 0;
    else if (__builtin_mul_overflow(tsec, NSEC_PER_SEC, &leeway)
             || __builtin_add_overflow(tnsec, leeway, &leeway)) {
      leeway = UINT64_MAX;
    }

    dispatch_source_t source =
      dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    dispatch_source_set_timer(source, when, DISPATCH_TIME_FOREVER, leeway);

    size_t sz = sizeof(struct __swift_job_source);

    struct __swift_job_source *jobSource =
      (struct __swift_job_source *)swift_job_alloc(job, sz);

    jobSource->job = job;
    jobSource->source = source;

    dispatch_set_context(source, jobSource);
    dispatch_source_set_event_handler_f(source,
      (dispatch_function_t)&_swift_run_job_leeway);

    dispatch_activate(source);
  } else {
    dispatch_after_f(when, queue, (void *)job,
      (dispatch_function_t)&__swift_run_job);
  }
}

extern "C" SWIFT_CC(swift)
void swift_dispatchEnqueueMain(SwiftJob *job) {
  assert(job && "no job provided");

  SwiftJobPriority priority = swift_job_getPriority(job);

  // This is an inline function that compiles down to a pointer to a global.
  auto mainQueue = dispatch_get_main_queue();

  dispatchEnqueue(mainQueue, job, (dispatch_qos_class_t)priority, mainQueue);
}

void swift::swift_task_enqueueOnDispatchQueue(Job *job,
                                              HeapObject *_queue) {
  JobPriority priority = job->getPriority();
  auto queue = reinterpret_cast<dispatch_queue_t>(_queue);
  dispatchEnqueue(queue, (SwiftJob *)job, (dispatch_qos_class_t)priority, queue);
}
