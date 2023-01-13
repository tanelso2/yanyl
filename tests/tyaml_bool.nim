import
  yanyl

assert ofYaml(newYString("true"), bool) == true
assert ofYaml(newYString("false"), bool) == false