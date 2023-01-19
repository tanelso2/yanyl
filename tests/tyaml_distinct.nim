import
  yanyl,
  macros,
  unittest,
  test_utils/yaml_testing

type
  Name = distinct string

deriveYamls:
  Name

let roger: Name = ofYamlStr("roger", Name)
check roger.string == "roger"
check roger.toYamlStr == "roger"
checkRoundTrip roger

type
  Id = distinct int
  Employee = object
    name: Name
    id: Id

deriveYamls:
  Id
  Employee

var sample = """
name: Isaac
id: 45
"""
let emp: Employee = ofYamlStr(sample, Employee)
check emp.name.string == "Isaac"
check emp.id.int == 45