import
  yanyl,
  test_utils/yaml_testing,
  std/options,
  strutils,
  unittest

type
  Job* = object of RootObj
    name*: string
    weaponOfChoice*: Option[string]
  Hero* = object of RootObj
    name*: string
    primaryJob*: Job
    secondaryJob*: Option[Job]

deriveYamls:
  Job
  Hero

var sample = """
- name: Guy
  primaryJob: 
    name: Samurai
    weaponOfChoice: katana
  secondaryJob:
    name: Monk
    weaponOfChoice: fists
- name: Hekate
  primaryJob:
    name: Witch
"""

let heroes = ofYamlStr(sample, seq[Hero])
let guy = heroes[0]
let hekate = heroes[1]

check guy.name == "Guy"
check guy.primaryJob.name == "Samurai"
check guy.primaryJob.weaponOfChoice.get() == "katana"
check guy.secondaryJob.isSome() == true
check guy.secondaryJob.get().name == "Monk"

check hekate.name == "Hekate"
check hekate.primaryJob.name == "Witch"
check hekate.primaryJob.weaponOfChoice.isNone()
check hekate.secondaryJob.isNone()

let hs = hekate.toYamlStr()
# toString shouldn't put nones in the maps
check hs.contains("secondaryJob") == false
