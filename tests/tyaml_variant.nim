import
  yanyl,
  test_utils/yaml_testing,
  unittest

type
  E = enum
    eStr, eInt
  V = object
    c: string
    case kind: E
    of eStr:
      s: string
    of eInt:
      i: int

deriveYamls:
  E
  V

var sample: string
sample = """
kind: eStr
c: c1
s: s1
"""

var v: V = sample.ofYamlStr(V)

check v.kind == eStr
check v.c == "c1"
check v.s == "s1"
checkRoundTrip v

sample = """
kind: eInt
c: c2
i: 10
"""

v = sample.ofYamlStr(V)
check v.kind == eInt
check v.c == "c2"
check v.i == 10
checkRoundTrip v