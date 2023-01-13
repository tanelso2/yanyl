import
  test_utils/yaml_testing,
  macros,
  unittest

import
  yanyl

type
  Obj = object
    i: int
    s: string

deriveYaml Obj

var sample: string = """
i: 99
s: hello world
"""
var o: Obj = ofYamlStr(sample, Obj)
check o.i == 99
check o.s == "hello world"

type
  MyType = object of RootObj
    pulse: bool
    breathing: bool

deriveYaml MyType

sample = """
pulse: true
breathing: true
"""

var mt: MyType = ofYamlStr(sample, MyType)
check mt.pulse == true
check mt.breathing == true

sample = """
pulse: true
breathing: false
"""
mt = ofYamlStr(sample, MyType)
check mt.pulse == true
check mt.breathing == false

type
  Nested = ref object of RootObj
    n: string
    t: MyType

deriveYaml Nested

sample = """
n: Pinhead Larry 
t:
  pulse: true
  breathing: true
"""

var nested: Nested = ofYamlStr(sample, Nested)
check nested.n == "Pinhead Larry"
check nested.t.pulse == true
check nested.t.breathing == true

type
  Status = ref object of MyType
    bpm: int
  Vitals = ref object of RootObj
    status: Status
    name: string

deriveYamls:
  Status
  Vitals

sample = """
status:
  bpm: 90
  pulse: true
  breathing: true
name: Leonard Snart
"""

var v: Vitals = ofYamlStr(sample, Vitals)
check v.status.bpm == 90
check v.status.pulse == true
check v.status.breathing == true
check v.name == "Leonard Snart"