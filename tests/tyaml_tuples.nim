import
  macros,
  unittest,
  yanyl,
  test_utils/yaml_testing

type
  Named = tuple
    name: string 
    id: int
  BracketSyntax = tuple[id: int, name: string]

expandMacros:
  deriveYaml Named
  deriveYaml BracketSyntax

var sample = """
name: Jim
id: 98
"""
let jim1 = ofYamlStr(sample, Named)
check jim1.name == "Jim"
check jim1.id == 98
check jim1[0] == "Jim"
checkRoundTrip jim1

let jim2 = ofYamlStr(sample, BracketSyntax)
check jim2.name == "Jim"
check jim2.id == 98
check jim2[0] == 98
checkRoundTrip jim2