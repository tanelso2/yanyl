import
  macros,
  sequtils,
  strformat,
  sugar,
  fusion/matching

{.experimental: "caseStmtMacros".}

type
  Field* = object of RootObj
    name*: string
    t*: NimNode
  ObjType* = enum
    otObj, 
    otVariant, 
    otEnum, 
    otEmpty, 
    otTypeAlias, 
    otDistinct, 
    otTuple
  NimVariant* = object of RootObj
    name*: string
    fields*: seq[Field]
  EnumVal* = object of RootObj
    name*: string
    val*: NimNode
  ObjFields* = object of RootObj
    case kind*: ObjType
    of otEmpty:
      discard
    of otObj:
      ## e.g. Type = object of RootObj
      ## Object types have a list of fields,
      ## including fields from their parents.
      fields*: seq[Field]
    of otVariant:
      ## Variant types have a list of fields in common,
      ## but also have variants that can hold additional fields.
      common*: seq[Field]
      ## Discriminator decides between the variants, 
      ## and is not included in the common fields      
      discriminator*: Field
      variants*: seq[NimVariant]
    of otEnum:
      ## e.g. Type = enum
      ## Enums have a list of names and their values
      vals*: seq[EnumVal]
    of otTypeAlias:
      ## e.g. Type = seq[Foo]
      ## A type alias can hold anything
      t*: NimNode
    of otDistinct:
      ## e.g. Type = distinct int
      ## A distinct type can be made from anything
      base*: NimNode
    of otTuple:
      ## e.g. Type = tuple
      tupleFields*: seq[Field]

proc newTupleFields(fields: seq[Field]): ObjFields =
  ObjFields(kind: otTuple, tupleFields: fields)

proc newDistinct(base: NimNode): ObjFields =
  ObjFields(kind: otDistinct, base: base)

proc newTypeAlias(t: NimNode): ObjFields =
  ObjFields(kind: otTypeAlias, t: t)

proc discrim*(o: ObjFields): Field = o.discriminator

proc newEnumFields(vals: seq[EnumVal]): ObjFields =
  ObjFields(kind: otEnum, vals: vals)

proc newVariantFields(common: seq[Field], discrim: Field, variants: seq[NimVariant]): ObjFields =
  ObjFields(kind: otVariant,
            common: common,
            discriminator: discrim,
            variants: variants)

proc newObjFields(fields: seq[Field]): ObjFields =
  ObjFields(kind: otObj, fields: fields)

proc empty(): ObjFields =
  ObjFields(kind: otEmpty)

proc getName*(f: Field): string =
  f.name

proc getT*(f: Field): NimNode =
  f.t

proc getTypeDefName*(n: NimNode): string =
  expectKind(n, nnkTypeDef)
  n[0].strVal

proc combine(a,b: ObjFields): ObjFields =
  case (a.kind, b.kind)
  of (otEmpty, _):
    result = b
  of (_, otEmpty):
    result = a
  of (otObj, otObj):
    result = newObjFields(concat(a.fields, b.fields))
  of (otObj, otVariant):
    result = newVariantFields(
      common=concat(a.fields, b.common),
      discrim=b.discrim,
      variants=b.variants)
  of (otVariant, otObj):
    result = newVariantFields(
      common=concat(a.common, b.fields),
      discrim=a.discrim,
      variants=a.variants
    )
  of (otVariant, otVariant):
    if a.discriminator != b.discriminator:
      raise newException(ValueError, "Cannot combine variants of different discriminators")
    result = newVariantFields(
      common=concat(a.common, b.common),
      discrim=a.discrim,
      variants=concat(a.variants, b.variants)
    )
  of (otEnum, otEnum):
    result = newEnumFields(concat(a.vals, b.vals))
  else:
    raise newException(ValueError, fmt"No implementation for comparing {a.kind} and {b.kind}")

proc combineAll(x: seq[ObjFields]): ObjFields =
  foldl(x, combine(a,b))

proc collectEnumVals(x: NimNode): seq[EnumVal] =
  case x.kind
  of nnkSym:
    result = @[EnumVal(name: x.strVal, val: newStrLitNode(x.strVal))]
  of nnkEmpty:
    result = @[]
  of nnkEnumFieldDef:
    result = @[EnumVal(name: x[0].strVal, val: x[1])]
  else:
    error("Cannot collect enum vals from node ", x)

proc collectEnumFields(x: NimNode): ObjFields =
  expectKind(x, nnkEnumTy)
  let vs = collect:
    for c in x.children:
      collectEnumVals c
  let vals = concat(vs)
  return ObjFields(kind: otEnum, vals: vals)

proc getUnadornedName(x: NimNode): string =
  ## Removes stars and accent quoting
  case x.kind
  of nnkIdent, nnkSym:
    return x.strVal
  of nnkAccQuoted:
    return $x
  of nnkPostfix:
    let op = x[0].strVal
    if op == "*":
      return getUnadornedName(x[1])
    else:
      raise newException(ValueError, fmt"do not know how to handle postfix op {op}")
  else:
    raise newException(ValueError, fmt"do not know how to get name of {x.kind}")

# Forward declaration
proc collectObjFieldsForType*(t: NimNode): ObjFields

proc fieldOfIdentDef(x: NimNode): Field =
  expectKind(x, nnkIdentDefs)
  # echo x[0]
  Field(name: getUnadornedName(x[0]),
        t: x[1])

# Forward declaration for mutual recursion
proc collectObjFields(x: NimNode): ObjFields


proc collectVariantFields(x: NimNode): ObjFields =
  expectKind(x, nnkRecCase)
  result = ObjFields(kind: otVariant, common: @[], variants: @[])
  for c in x.children:
    case c.kind
    of nnkIdentDefs:
      let discrim = fieldOfIdentDef(c)
      result.discriminator = discrim
    of nnkOfBranch:
      let name = c[0].strVal
      let branchFields = collectObjFields(c[1])
      case branchFields.kind
      of otObj:
        let newVariant = NimVariant(name: name, fields: branchFields.fields)
        result.variants.add(newVariant)
      of otEmpty:
        let newVariant = NimVariant(name: name, fields: @[])
        result.variants.add(newVariant)
      else:
        error("branch of variant parsed as an enum type or variant type", x)
    of nnkEmpty:
      discard
    else:
      error("Don't know how to collect variant fields from ", x)

proc collectObjFields(x: NimNode): ObjFields =
  case x.kind
  of nnkIdent, nnkEmpty, nnkNilLit, nnkSym:
    return empty()
  of nnkRefTy:
    return collectObjFields(x[0])
  of nnkIdentDefs:
    return ObjFields(
      kind: otObj,
      fields: @[fieldOfIdentDef(x)]
    )
  of nnkRecList:
    let r = collect:
      for c in x.children:
        collectObjFields(c)
    return combineAll(r)
  of nnkRecCase:
    return collectVariantFields(x)
  else:
    error(fmt"Cannot collect object fields from a NimNode of this kind {x.kind}", x)

proc getParentFieldsFromInherit(t: NimNode): ObjFields =
  case t.kind
  of nnkEmpty:
    return empty()
  of nnkOfInherit:
    let parentClassSym = t[0]
    if parentClassSym.strVal == "RootObj":
      return empty()
    else:
      return collectObjFieldsForType(parentClassSym.getImpl())
  else:
    error("cannot get parent fields from this NimNode", t)



proc collectFieldsFromDefinition(t: NimNode): ObjFields =
  case t.kind
  of nnkRefTy:
    return collectFieldsFromDefinition(t[0])
  of nnkEnumTy:
    return collectEnumFields(t) 
  of nnkObjectTy:
    let parent = getParentFieldsFromInherit(t[1])
    let base = collectObjFields(t[2])
    return combine(parent, base)
  of nnkDistinctTy:
    return newDistinct(t[0])
  of nnkTupleTy:
    let objFields = t
      .children
      .toSeq()
      .map(collectObjFields)
      .combineAll()
    assert objFields.kind == otObj
    return newTupleFields(objFields.fields)
  else:
    return newTypeAlias(t)


proc collectObjFieldsForType*(t: NimNode): ObjFields =
  ## Takes a Nim type and returns an `ObjFields` object
  ## representing the fields of that object
  expectKind(t, nnkTypeDef)
  let definition = t[2]
  collectFieldsFromDefinition(definition)

macro dumpFields*(x: typed) =
  ## Dumps the result of running `collectObjFieldsForType`
  ## for the given type
  ## 
  ## Used to debug that proc
  ## 
  ## NOTE: Runs at compile time
  echo newLit($collectObjFieldsForType(x.getImpl()))

macro dumpImpl*(x: typed) =
  ## Used to dump the AST definition of x
  ## 
  ## Useful for debugging
  ## 
  ## NOTE: Runs at compile time
  echo newLit(fmt"Impl for {x}" & "\n")
  echo newLit(x.getImpl.treeRepr)
  echo newLit("\n~~~~~~~~~~~~~~\n")

macro dumpTypeImpl*(x: typed) =
  ## Macro to dump the AST tree of the
  ## type of x
  ## 
  ## Useful for debugging/writing reflection code
  ## 
  ## NOTE: Runs at compile time
  echo newLit(x.getTypeImpl.treeRepr)
