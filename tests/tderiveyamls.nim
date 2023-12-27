import
    yanyl,
    std/macros

type
    Owner = ref object of RootObj
        name: string
    Pet = ref object of RootObj
        name: string
        kind: string
        owner: Owner

deriveYamls:
    Owner
    Pet

let sample = """
name: Garfield
kind: cat
owner:
    name: J. Arbuckle
"""
let garf = ofYamlStr(sample, Pet)
doAssert garf.name == "Garfield"
doAssert garf.kind == "cat"
doAssert garf.owner.name == "J. Arbuckle"
