import
  macros,
  unittest,
  yanyl,
  test_utils/yaml_testing

type
  Owner = object of RootObj
    name: string
    `addr`: string
  Pet = ref object of RootObj
    name*: string
    `type`*: string
    owner: Owner

deriveYamls:
  Owner
  Pet

let sample = """
name: Garfield
type: cat
owner:
    name: J. Arbuckle
    addr: 711 Maple Street
"""

let garf = ofYamlStr(sample, Pet)
check garf.name == "Garfield"
check garf.`type` == "cat"
check garf.owner.name == "J. Arbuckle"
check garf.owner.`addr` == "711 Maple Street"

checkRoundTrip garf
