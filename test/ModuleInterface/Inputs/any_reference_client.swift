import AnyRef

class C: RefP {}

func client(_ c: C) {
  _ = takesAR(c)
  takesExistentialAR(c)
  _ = G(c)
  takesAOAndAR(c)
  _ = inlinableUse(c)
}
