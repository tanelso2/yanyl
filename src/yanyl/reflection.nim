import
  macros,
  sequtils,
  strformat,
  sugar

type
  Field* = object of RootObj
    name*: string
    t*: NimNode
  ObjType* = enum
    otObj, otVariant, otEnum, otEmpty
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
      fields*: seq[Field]
    of otVariant:
      common*: seq[Field]
      discriminator*: Field
      variants*: seq[NimVariant]
    of otEnum:
      vals*: seq[EnumVal]

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

proc combine(a,b: ObjFields): ObjFields =
  proc noimpl() =
    raise newException(ValueError, fmt"No implementation for comparing {a.kind} and {b.kind}")

  case a.kind
  of otObj:
    case b.kind
    of otObj:
      result = newObjFields(concat(a.fields, b.fields))
    of otVariant:
      result = newVariantFields(common=concat(a.fields, b.common),
                                discrim=b.discrim,
                                variants=b.variants
                                )
    of otEnum:
      noimpl()
    of otEmpty:
      result = a
  of otVariant:
    case b.kind
    of otObj:
      result = newVariantFields(common=concat(a.common, b.fields),
                                discrim=a.discrim,
                                variants=a.variants
      )
    of otVariant:
      if a.discriminator != b.discriminator:
        raise newException(ValueError, "Cannot combine variants of different discriminators")
      result = newVariantFields(
        common=concat(a.common, b.common),
        discrim=a.discrim,
        variants=concat(a.variants, b.variants)
      )
    of otEnum:
      noimpl()
    of otEmpty:
      result = a
  of otEnum:
    case b.kind
    of otObj:
      noimpl()
    of otVariant:
      noimpl()
    of otEnum:
      result = newEnumFields(concat(a.vals, b.vals))
    of otEmpty:
      result = a
  of otEmpty:
    result = b

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

proc getNameWithoutStar(x: NimNode): string =
  case x.kind
  of nnkIdent:
    return x.strVal
  of nnkPostfix:
    let op = x[0].strVal
    if op == "*":
      return x[1].strVal
    else:
      raise newException(ValueError, fmt"do no know how to handle postfix op {op}")
  else:
    raise newException(ValueError, fmt"do not know how to get name of {x.kind}")

proc fieldOfIdentDef(x: NimNode): Field =
  expectKind(x, nnkIdentDefs)
  # echo x[0]
  Field(name: getNameWithoutStar(x[0]),
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
  proc foldChildren(x: NimNode): ObjFields =
    let r = collect:
      for c in x.children:
        collectObjFields(c)
    return combineAll(r)

  case x.kind
  of nnkIdent:
    return empty()
  of nnkEmpty:
    return empty()
  of nnkNilLit:
    return empty()
  of nnkSym:
    return empty()
  of nnkIdentDefs:
    return ObjFields(
      kind: otObj,
      fields: @[fieldOfIdentDef(x)]
    )
  of nnkOfInherit:
    let parentClassSym = x[0]
    if parentClassSym.strVal == "RootObj":
      return empty()
    else:
      # echo "GOT INHERITANCE"
      return collectObjFields(parentClassSym.getImpl())
  of nnkRecList:
    return foldChildren(x)
  of nnkObjectTy:
    return foldChildren(x)
  of nnkTypeDef:
    return foldChildren(x)
  of nnkRefTy:
    return foldChildren(x)
  of nnkEnumTy:
    return collectEnumFields(x)
  of nnkRecCase:
    return collectVariantFields(x)
  else:
    # echo x.kind
    error(fmt"Cannot collect object fields from a NimNode of this kind {x.kind}", x)

proc collectObjFieldsForType*(t: NimNode): ObjFields =
  expectKind(t, nnkTypeDef)
  collectObjFields(t)