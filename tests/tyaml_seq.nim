import
  yanyl,
  test_utils/yaml_testing,
  std/options,
  strutils,
  unittest

type
  Person* = object of RootObj
    id: int
    names*: seq[string]
  Team* = object of RootObj
    id: int
    members*: seq[Person]

deriveYamls:
  Person
  Team

var sample = """
id: 1
names:
- Bobby
"""
let bobby = ofYamlStr(sample, Person)
check bobby.id == 1
check bobby.names.len == 1
check bobby.names[0] == "Bobby"

var noNameYaml = """
id: 0
"""
let noName = ofYamlStr(noNameYaml, Person)
check noName.id == 0
check noName.names.len == 0


