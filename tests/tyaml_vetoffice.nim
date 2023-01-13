import
  yanyl,
  unittest

type
  CatBreed = enum
    cbMaineCoon = "MaineCoon" 
    cbPersian = "Persian"
    cbBengal = "Bengal"
  DogBreed = enum
    dbCorgi = "Corgi"
    dbMastiff = "Mastiff"
  PetType = enum
    ptCat = "cat"
    ptDog = "dog"
  Nameable = object of RootObj
    name: string
  Pet = ref object of Nameable
    vet: Nameable
    case kind: PetType
    of ptCat:
      catBreed: CatBreed
    of ptDog:
      dogBreed: DogBreed
  Owner = object of Nameable
    paid: bool
    pets: seq[Pet]

deriveYamls:
  CatBreed
  DogBreed
  PetType
  Nameable
  Pet
  Owner

var s: string = """
name: Duncan Indigo
paid: false
pets:
- name: Ginger
  vet:
    name: Maria Belmont
  kind: cat
  catBreed: MaineCoon
- name: Buttersnap
  vet:
    name: Maria Belmont
  kind: dog
  dogBreed: Corgi
"""

let duncan = ofYamlStr(s, Owner)

check duncan.name == "Duncan Indigo"
check duncan.paid == false
check duncan.pets.len() == 2

let ginger = duncan.pets[0]
check ginger.name == "Ginger"
check ginger.kind == ptCat
check ginger.catBreed == cbMaineCoon
check ginger.vet.name == "Maria Belmont"

let buttersnap = duncan.pets[1]
check buttersnap.name == "Buttersnap"
check buttersnap.kind == ptDog
check buttersnap.dogBreed == dbCorgi
check buttersnap.vet.name == "Maria Belmont"