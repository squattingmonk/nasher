import streams, strtabs, strutils
import parsetoml

export strtabs
export parsetoml.TomlError

type
  PackageError* = object of CatchableError

  Target* = object
    name*, description*, file*, branch*, modName*, modMinGameVersion*: string
    includes*, excludes*, filters*, flags*: seq[string]
    rules*: seq[Rule]
    aliases*: StringTableRef

  Rule* = tuple[pattern, dest: string]

proc raisePackageError(msg: string) =
  ## Raises a ``PackageError`` containing message ``msg``.
  raise newException(PackageError, msg)

proc expectKind(value: TomlValueRef, kind: TomlValueKind, field: string) =
  ## Raises a `PackageError` if ``value`` is not of ``kind``. ``field`` is used
  ## for pretty error messages.
  if value.kind != kind:
    raisePackageError("expected $1 to be $2 but got $3" % [field, $kind, $value.kind])

proc expectTable(value: TomlValueRef, field: string) =
  ## Raises a `PackageError` if ``value`` is not a table. ``field`` is used for
  ## pretty error messages.
  expectKind(value, TomlValueKind.Table, field)

proc expectString(value: TomlValueRef, field: string) =
  ## Raises a `PackageError` if ``value`` is not a string. ``field`` is used for
  ## pretty error messages.
  expectKind(value, TomlValueKind.String, field)

proc expectArray(value: TomlValueRef, field: string) =
  ## Raises a `PackageError` if ``value`` is not an array. ``field`` is used for
  ## pretty error messages.
  expectKind(value, TomlValueKind.Array, field)

proc expectStringArray(value: TomlValueRef, field: string) =
  ## Raises a `PackageError` if ``value`` is not an array of strings. ``field``
  ## is used for pretty error messages.
  expectArray(value, field)
  for item in value.getElems:
    expectString(item, "all items in " & field)

proc validateTarget(target: TomlValueRef, scope = "target") =
  ## Checks the fields in ``target`` to ensure they are of the right type. A
  ## `PackageError` will be raised if an unknown field or a field with the wrong
  ## type of value is found. ``scope`` is just used for pretty error messages.

  # Top level should always be a table
  expectTable(target, scope)

  # Loop through the given fields
  for key, value in target.getTable.pairs:
    case key
    of "name", "file", "description", "branch", "modName", "modMinGameVersion":
      expectString(value, scope & "." & key)
    of "flags":
      expectStringArray(value, scope & ".flags")
    of "sources":
      expectTable(value, scope & ".sources")
      for sourceKey, sourceVal in value.getTable.pairs:
        if sourceKey notin ["includes", "excludes", "filters"]:
          raisePackageError("unknown key $1.sources.$2" % [scope, sourceKey])
        expectStringArray(sourceVal, join([scope, "sources", sourceKey], "."))
    of "aliases":
      expectTable(value, scope & ".aliases")
      for alias, path in value.getTable.pairs:
        expectString(path, scope & ".aliases." & alias)
    of "rules":
      expectTable(value, scope & ".rules")
      for pattern, dest in value.getTable.pairs:
        expectString(dest, scope & ".rules." & pattern.escape)
    else:
      raisePackageError("unknown key $1.$2" % [scope, key])

proc getTarget(target, package: TomlValueRef): Target =
  ## Deserializes ``target`` into a ``Target`` object, filling in any missing
  ## values from ``package``.

  for key, value in result.fieldPairs:
    when value is string:
      case key
      of "name", "description":
        # Not inherited by the target
        value = target{key}.getStr
      else:
        value = target{key}.getStr(package{key}.getStr)
    elif value is seq[string]:
      case key
      of "includes", "excludes", "filters":
        for source in target{"sources", key}.getElems(package{"sources", key}.getElems):
          value.add(source.getStr)
      else:
        for val in target{key}.getElems(package{key}.getElems):
          value.add(val.getStr)
    elif value is seq[Rule]:
      for pattern, dest in target{"rules"}.getTable(package{"rules"}.getTable).pairs:
        value.add((pattern, dest.getStr))
    elif value is StringTableRef:
      # Targets inherit unset values from the package
      value = newStringTable()
      for alias, path in package{"aliases"}.getTable.pairs:
        value[alias] = path.getStr
      for alias, path in target{"aliases"}.getTable.pairs:
        value[alias] = path.getStr

  # Ensure required fields are set
  if result.name.len == 0:
    raisePackageError("target missing required field \"name\"")
  if result.file.len == 0:
    raisePackageError("target missing required field \"file\"")
  if result.includes.len == 0:
    raisePackageError("target missing required field \"sources.includes\"")

proc getTargets(pkg: TomlValueRef): seq[Target] =
  ## Deserializes each ``target`` entry into a ``Target`` object, filling in
  ## any missing values from the ``package`` entry.
  if pkg.hasKey("package"):
    validateTarget(pkg["package"], "package")

  if pkg.hasKey("target"):
    case pkg["target"].kind
    of TomlValueKind.Array:
      for target in pkg{"target"}.getElems:
        validateTarget(target)
        result.add(target.getTarget(pkg{"package"}))
    of TomlValueKind.Table:
      validateTarget(pkg["target"])
      result = @[pkg["target"].getTarget(pkg{"package"})]
    else:
      raisePackageError("[target] must be TOML table or array of tables")

template raiseWithFilename(filename: string, body: untyped): untyped =
  ## Adds the name of the file being processed to a `PackageError`.
  try:
    body
  except PackageError as e:
    e.msg = "Error validating $1: $2" % [filename, e.msg]
    raise
  except TomlError as e:
    e.msg = "Error parsing " & e.msg
    raise

proc parsePackageStream*(s: Stream, filename: string = "[stream]"): seq[Target] =
  ## Parses the stream ``s`` and returns a sequence of ``Target``s. ``filename``
  ## is used for pretty error messages.
  raiseWithFilename filename:
    parsetoml.parseStream(s, filename).getTargets

proc parsePackageString*(s: string, filename: string = "[stream]"): seq[Target] =
  ## Parses the string ``s`` and returns a sequence of ``Target``s. ``filename``
  ## is used for pretty error messages.
  raiseWithFilename filename:
    parsetoml.parseString(s, filename).getTargets

proc parsePackageFile*(filename: string): seq[Target] =
  ## Parses the file ``filename`` and returns a sequence of ``Target``s.
  raiseWithFilename filename:
    parsetoml.parseFile(filename).getTargets
