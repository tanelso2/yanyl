discard """
# This is expected to fail
exitcode: 1
"""


import
    yaml

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

var sample: string
sample = """
kind: eStr
c: c1
s: s1
"""

var v: V
load(sample, v)
assert v.kind == eStr
assert v.c == "c1"
assert v.s == "s1"