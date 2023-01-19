import
  macros,
  sequtils,
  strformat,
  sugar,
  ./core,
  ./reflection

proc mkYNodeGetCall(n: NimNode, k: string): NimNode =
  newCall(newDotExpr(n, ident("get")),
          newStrLitNode(k))

proc mkYNodeGetCall(n: NimNode, k: string, t: NimNode): NimNode =
  newCall(newDotExpr(n, ident("get")),
          newLit(k),
          t)

proc mkTypedesc(t: NimNode): NimNode =
  nnkBracketExpr.newTree(
    ident("typedesc"), t
  )

proc getValueForField(f: Field, obj: NimNode): NimNode =
    mkYNodeGetCall(
      obj, 
      f.getName(), 
      mkTypedesc(f.getT()))

proc pubIdent(s: string): NimNode =
  nnkPostfix.newTree(
    ident("*"),
    ident(s)
  )

proc mkObjTypeConsFieldParam(f: Field, obj: NimNode): NimNode =
  newColonExpr(
    ident(f.name),
    getValueForField(f, obj)
  )



proc mkOfYamlForObjType(t: NimNode, fields: seq[Field]): NimNode =
    let retType = t
    let nodeParam = newIdentDefs(ident("n"), ident("YNode"))
    let typeParam = newIdentDefs(ident("t"), 
                                 nnkBracketExpr.newTree(
                                    ident "typedesc",
                                    retType
                                 ))
    let n = ident("n")
    newProc(
        name=pubIdent("ofYaml"),
        params=[retType, nodeParam, typeParam],
        body=nnkStmtList.newTree(
            nnkCommand.newTree(
                ident("expectYMap"),
                n,
                newStmtList(
                    nnkAsgn.newTree(
                        ident("result"),
                        nnkObjConstr.newTree(
                            concat(
                              @[retType],
                              fields.mapIt(mkObjTypeConsFieldParam(it, n))
                            )
                        )
                    )

                )
            )
        )
    )

proc mkObjTypeTableField(f: Field, obj: NimNode): NimNode =
    nnkExprColonExpr.newTree(
        newStrLitNode(f.name),
        newCall(
            ident("toYaml"),
            newDotExpr(
                obj,
                ident(f.name)
            )
        )
    )

proc mkToYamlForObjType(t: NimNode, fields: seq[Field]): NimNode =
    let retType = ident("YNode")
    let obj = ident("x")
    newProc(
        name=pubIdent("toYaml"),
        params=[retType, newIdentDefs(obj, t)],
        body=nnkStmtList.newTree(
            newCall(
                ident("newYMapRemoveNils"),
                nnkTableConstr.newTree(
                    fields.mapIt(mkObjTypeTableField(it, obj))
                )
            )
        )
    )

proc mkToYamlForEnumType(t: NimNode, vals: seq[EnumVal]): NimNode =
  let retType = ident("YNode")
  let obj = ident("x")
  newProc(
      name=pubIdent("toYaml"),
      params=[retType, newIdentDefs(obj, t)],
      body=nnkStmtList.newTree(
        newCall(
          ident("newYString"),
          nnkPrefix.newTree(
            ident("$"),
            obj
          )
        )
      )
  )

proc mkEnumOfBranch(val: EnumVal): NimNode =
  nnkOfBranch.newTree(
    nnkPrefix.newTree(
      ident("$"),
      ident(val.name)
    ),
    newStmtList(
      ident(val.name)
    )
  )

proc mkOfYamlForEnumType(t: NimNode, vals: seq[EnumVal]): NimNode =
  let retType = t
  let n = ident("n")
  let nodeParam = newIdentDefs(n, ident("YNode"))
  let typeParam = newIdentDefs(ident("t"), 
                                nnkBracketExpr.newTree(
                                  ident "typedesc",
                                  retType
                                ))
  let elseBranch = 
    nnkElse.newTree(
      newStmtList(
        nnkRaiseStmt.newTree(
          newCall(
            ident("newException"),
            ident("ValueError"),
            nnkInfix.newTree(
              ident("&"),
              #TODO: Add type name here
              newStrLitNode("unknown kind: "),
              nnkDotExpr.newTree(
                n, ident("strVal")))))))
  newProc(
      name=pubIdent("ofYaml"),
      params=[retType, nodeParam, typeParam],
      body=nnkStmtList.newTree(
        nnkCommand.newTree(
          ident("expectYString"),
          n,
          newStmtList(
            nnkCaseStmt.newTree(
              concat(@[
                  nnkDotExpr.newTree(
                    n, ident("strVal")
                  )
                ],
                vals.mapIt(mkEnumOfBranch(it)),
                @[elseBranch])
            )))))

proc mkOfYamlForVariantType(t: NimNode, 
                            common: seq[Field], 
                            discrim: Field, 
                            variants: seq[NimVariant]): NimNode =
  let retType = t
  let n = ident("n")
  let kind = ident(discrim.name)

  proc mkVariantOfBranch(v: NimVariant): NimNode =
    let neededFields = common & v.fields
    nnkOfBranch.newTree(
      ident(v.name),
      newStmtList(
        nnkAsgn.newTree(
          ident("result"),
          nnkObjConstr.newTree(
            concat(
              @[t,
                newColonExpr(kind, kind)],
              neededFields.mapIt(mkObjTypeConsFieldParam(it, n)))))))

  let nodeParam = newIdentDefs(n, ident("YNode"))
  let typedescType = nnkBracketExpr.newTree(
    ident "typedesc", retType
  )
  let typeParam = newIdentDefs(ident("t"), typedescType)
  let ofBranches = collect:
    for v in variants:
      mkVariantOfBranch(v)
  newProc(
    name=pubIdent("ofYaml"),
    params=[retType, nodeParam, typeParam],
    body=newStmtList(
      nnkCommand.newTree(
        ident("expectYMap"),
        n,
        newStmtList(
          newLetStmt(kind,
                     getValueForField(discrim, n)),
          nnkCaseStmt.newTree(
            concat(@[kind], ofBranches))))))

proc mkToYamlForVariantType(t: NimNode,
                            common: seq[Field], 
                            discrim: Field, 
                            variants: seq[NimVariant]): NimNode =
  let retType = ident("YNode")
  let obj = ident("x")
  proc mkVariantOfBranch(v: NimVariant): NimNode =
    let neededFields = @[discrim] & common & v.fields
    nnkOfBranch.newTree(
      ident(v.name),
      nnkAsgn.newTree(
        ident("result"),
        newCall(
          ident("newYMapRemoveNils"),
          nnkTableConstr.newTree(
            neededFields.mapIt(mkObjTypeTableField(it, obj))
          )
        )
      )
    )
  let ofBranches = variants.map(mkVariantOfBranch)
  newProc(
    name=pubIdent("toYaml"),
    params=[retType, newIdentDefs(obj, t)],
    body=newStmtList(
      nnkCaseStmt.newTree(
        concat(
          @[newDotExpr(obj, ident(discrim.name))],
          ofBranches
        )
      )
    )
  )

proc mkToYamlForTypeAlias(t, alias: NimNode): NimNode =
  newCommentStmtNode(fmt"Not generating toYaml() for {$t.repr}, compiler will use implementation for {$alias.repr}")

proc mkOfYamlForTypeAlias(t, alias: NimNode): NimNode =
  newCommentStmtNode(fmt"Not generating ofYaml() for {$t.repr}, compiler will use implementation for {$alias.repr}")

proc mkToYamlForDistinctType(t, base: NimNode): NimNode =
  let retType = ident("YNode")
  let obj = ident("x")
  newProc(
    name=pubIdent("toYaml"),
    params=[retType, newIdentDefs(obj, t)],
    body=newStmtList(
      newCall(
        ident("toYaml"),
        nnkCommand.newTree(
          newPar(base),
          obj
        )
      )
    ),
  )

proc mkOfYamlForDistinctType(t, base: NimNode): NimNode =
  let retType = t
  let n = ident("n")
  let nodeParam = newIdentDefs(n, ident("YNode"))
  let typeParam = newIdentDefs(ident("t"), mkTypedesc(retType))
  newProc(
    name = pubIdent("ofYaml"),
    params = [retType, nodeParam, typeParam],
    body = nnkStmtList.newTree(
      newCall(
        ident(t.strVal),
        newCall(
          ident("ofYaml"),
          n,
          mkTypeDesc(base)
        )
      )
    )
  )



proc mkToYamlForType(t: NimNode): NimNode =
  let fields = collectObjFieldsForType(t.getImpl())
  case fields.kind
  of otObj:
    return mkToYamlForObjType(t, fields.fields)
  of otVariant:
    return mkToYamlForVariantType(t, fields.common, fields.discrim, fields.variants)
  of otEnum:
    return mkToYamlForEnumType(t, fields.vals)
  of otTypeAlias:
    return mkToYamlForTypeAlias(t, fields.t)
  of otDistinct:
    return mkToYamlForDistinctType(t, fields.base)
  of otEmpty:
    error("NOIMPL for empty types", t)

proc mkOfYamlForType(t: NimNode): NimNode =
  let fields = collectObjFieldsForType(t.getImpl())
  case fields.kind
  of otObj:
    return mkOfYamlForObjType(t, fields.fields)
  of otVariant:
    return mkOfYamlForVariantType(t, fields.common, fields.discrim, fields.variants)
  of otEnum:
    return mkOfYamlForEnumType(t, fields.vals)
  of otTypeAlias:
    return mkOfYamlForTypeAlias(t, fields.t)
  of otDistinct:
    return mkOfYamlForDistinctType(t, fields.base)
  of otEmpty:
    error("NOIMPL for empty types", t)

macro deriveYaml*(v: typed) =
  ## Generate `ofYaml` and `toYaml` procs for a type
  runnableExamples:
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
    doAssert o.i == 99
    doAssert o.s == "hello world"

  if v.kind == nnkSym and v.symKind == nskType:
      let ofYamlDef = mkOfYamlForType v
      let toYamlDef = mkToYamlForType v
      result = newStmtList(
          ofYamlDef,
          toYamlDef
      )
  else:
      error("deriveYaml only works on types", v)

macro deriveYamls*(body: untyped) =
  ## Derive yamls for multiple types
  runnableExamples:
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

  expectKind(body, nnkStmtList)
  result = newStmtList()
  for x in body.children:
    result.add(nnkCommand.newTree(
      ident("deriveYaml"),
      x
    ))
