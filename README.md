# YANYL (Yet Another Nim Yaml Library)

A library for working with YAML in Nim. Can generate conversion functions for most types declared in Nim.

[NimDocs can be found here](https://tanelso2.github.io/yanyl/index.html)

# Example

```nim
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
assert o.i == 99
assert o.s == "hello world"
```

# Install

Add the following to your `.nimble` file:
```
requires "https://github.com/tanelso2/yanyl >= 0.0.3"
```

# Usage

## `deriveYaml`

Macro that takes the name of a type and will generate `ofYaml` and `toYaml` procs for that type.

```nim
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
assert o.i == 99
assert o.s == "hello world"
```

## `loadNode`
Proc that takes a string or Stream and returns a `YNode`, the internal representation of a YAML document.

```nim
import
  yanyl

let s = """
a: 1
b: 3
c:
  - a
  - b
  - c
"""

let y: YNode = s.loadNode()
assert y.kind == ynMap
assert y.get("a").kind == ynString
assert y.get("c").kind == ynList
```

## `toString`
Proc that returns the YAML string of a `YNode`
<!-- TODO example -->

## `toYaml`
Proc that takes an object of type `T` and returns a `YNode`. 

Generic proc, should be redefined for every type. Can be autogenerated by `deriveYaml`
<!-- TODO example -->

## `ofYaml`
Proc that takes a `YNode` and returns an object of type `T`.

Generic proc, should be redefined for every type. Can be autogenerated by `deriveYaml`
<!-- TODO example -->

## `ofYamlStr`
Shortcut proc. 

`ofYamlStr(s,t)` is equivalent to `s.loadNode().ofYaml(t)`

## `toYamlStr`
Shortcut proc. 

`toYamlStr(x)` is equivalent to `x.toYaml().toString()`

# Code Generation

Code generation is opt-in per type. You can also write custom `ofYaml`/`toYaml` if the autogenerated ones do not work for your use-case. 

Code generation supports most types you can define in Nim: `object`s, `ref object`s, `enum`s, and variant objects are all supported.

Here's an example with multiple types that get generated and parse the YAML as expected:

```nim
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
```
