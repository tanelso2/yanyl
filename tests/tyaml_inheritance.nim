import
  yanyl,
  test_utils/yaml_testing,
  unittest

type
  Base = object of RootObj
    s1: string
  Deriv = object of Base
    s2: string
  RDeriv = ref object of Base
    i1: int

deriveYamls:
  Base
  Deriv
  RDeriv

var sample: string = """
s1: abcdef
"""

var base: Base = ofYamlStr(sample, Base)
check base.s1 == "abcdef"

sample = """
s1: xyz
s2: thomas was here
"""
var deriv: Deriv = ofYamlStr(sample, Deriv)
check deriv.s1 == "xyz"
check deriv.s2 == "thomas was here"
checkRoundTrip deriv

sample = """
s1: yep
i1: 73
"""
var rderiv: RDeriv = ofYamlStr(sample, RDeriv)
check rderiv.s1 == "yep"
check rderiv.i1 == 73
checkRoundTrip rderiv