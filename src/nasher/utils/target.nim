import macros, os, parsecfg, streams, strtabs, strutils, tables
from sequtils import anyIt
export tables, strtabs

type
  PackageError* = object of CatchableError
    ## Raised when the package parser encounters an error

  Target* = ref object
    name*, description*, file*, branch*, modName*, modMinGameVersion*: string
    includes*, excludes*, filters*, flags*: seq[string]
    variables*: StringTableRef
    rules*: seq[Rule]

  Rule* = tuple[pattern, dest: string]

const validTargetChars = {'\32'..'\64', '\91'..'\126'} - invalidFileNameChars

proc `==`*(a, b: Target): bool =
  result = true
  for _, valA, valB in fieldPairs(a[], b[]):
    when valA is StringTableRef:
      if valA.isNil != valB.isNil:
        return false
      if not valA.isNil:
        if valA.len != valB.len:
          return false
        for key, val in valA.pairs:
          if key notin valB or valB[key] != val:
            return false
    else:
      if valA != valB:
        return false

proc `[]`*(t: OrderedTableRef[string, Target]; index: Natural): Target =
  ## Returns the `Target` at `index` in `t`. Raises an `IndexDefect` if there
  ## are not `index + 1` items in `t`.
  if t.len <= index:
    raise newException(IndexDefect, "index $1 not in 0..$2" % [$index, $(t.len - 1)])
  var idx: Natural
  for value in t.values:
    if idx == index:
      return value
    idx.inc

iterator filter*(t: OrderedTableRef[string, Target], names = ""): Target =
  ## Iterates over each target in `t` named in the semicolon-delimited list
  ## `names`. If `names` is "", yields the first target in `t`. If any name in
  ## `names` is "all", yields all targets in `t`. Raises a `KeyError` if any
  ## target is not in `t`.
  if names == "":
    yield t[0]
  else:
    let wanted = names.split(';')
    if wanted.anyIt(it == "all"):
      for target in t.values:
        yield target
    else:
      for name in wanted:
        if name in t:
          yield t[name]
        else:
          raise newException(KeyError, "Unknown target " & name)

proc raisePackageError(msg: string) =
  ## Raises a `PackageError` with the given message.
  raise newException(PackageError, msg)

proc raisePackageError(p: CfgParser, msg: string) =
  ## Raises a `PackageError` with the given message. Includes file, column, and
  ## line information for the user.
  raise newException(PackageError, "Error parsing $1($2:$3): $4" %
    [p.getFilename, $p.getLine, $p.getColumn, msg])

proc setDefaults(target, defaults: Target, idx: int, filename = "") =
  ## Fills in missing fields other than `name` and `description` from `target`
  ## using those in `defaults`. Missing key/value pairs in `target.variables`
  ## are copied from `default.variables`. A `PackageError` is raised if the
  ## target does not have a name. `idx` and `filename` are used for error
  ## messages.
  for key, targetVal, defaultVal in fieldPairs(target[], defaults[]):
    if targetVal.len == 0:
      case key:
      of "name":
        raisePackageError("Error parsing $1: target $2 does not have a name" %
          [filename, $idx])
      of "description":
        discard
      else:
        when targetVal is StringTableRef:
          targetVal[] = defaultVal[]
        else:
          targetVal = defaultVal
    else:
      when targetVal is StringTableRef:
        for name, val in defaultVal.pairs:
          if name notin targetVal:
            targetVal[name] = val

  # This variable should remain constant
  target.variables["target"] = target.name

proc resolve(s: var string, variables: StringTableRef, flags = {useEnvironment}) =
  s = `%`(s, variables, flags)

proc resolve(paths: var seq[string], variables: StringTableRef) =
  for path in paths.mitems:
    path.resolve(variables)

proc resolve(rules: var seq[Rule], variables: StringTableRef) =
  for rule in rules.mitems:
    rule.pattern.resolve(variables)
    rule.dest.resolve(variables, {useEnvironment, useKey}) # Leave unknown keys to support $ext

macro resolve(target: Target, field: string): untyped =
  let field = ident($field)
  quote do:
    resolve(`target`.`field`, `target`.variables)

proc resolve(target: Target) =
  # Resolve variables (including env vars)
  try:
    for key, val in fieldPairs(target[]):
      when key != "name" and val isnot StringTableRef:
        target.resolve(key)
  except ValueError as e:
    e.msg.removePrefix("format string: key not found: ")
    raisePackageError("Unknown variable $$$# in target $#" % [e.msg, target.name])

proc newTarget(): Target =
  result = new Target
  result.variables = newStringTable(modeStyleInsensitive)

proc parseCfgPackage(s: Stream, filename = "nasher.cfg"): OrderedTableRef[string, Target] =
  ## Parses the content of `s` into a table of `Target`s where the key is the
  ## name of the target. The cfg package format is assumed. `filename` is used
  ## for error messages only. Raises `PackageError` if an error is encountered
  ## during parsing.
  result = newOrderedTable[string, Target]()
  var
    p: CfgParser
    context, section: string
    defaults = newTarget()
    target = newTarget()

  p.open(s, filename)
  while true:
    var e = p.next
    case e.kind
    of cfgEof:
      if context == "target":
        target.setDefaults(defaults, result.len + 1, filename)
        target.resolve()
        result[target.name] = target
      break
    of cfgSectionStart:
      # echo "Section: [$1]" % e.section
      case e.section.toLower
      of "package":
        if section == "package":
          p.raisePackageError("duplicate [package] section")
        elif section.len > 0:
          p.raisePackageError("[package] section must be declared before other sections")
        context = "package"
      of "target":
        case context
        of "package", "":
          defaults = target
        of "target":
          target.setDefaults(defaults, result.len + 1, filename)
          target.resolve()
          result[target.name] = target
        else: assert(false)
        target = newTarget()
        context = "target"
      of "sources", "rules", "variables":
        discard
      of "package.sources", "package.rules", "package.variables":
        if context in ["target"]:
          p.raisePackageError("[$1] must be declared within [package]" % e.section)
      of "target.sources", "target.rules", "target.variables":
        if context in ["package", ""]:
          p.raisePackageError("[$1] must be declared within [target]" % e.section)
      else:
        p.raisePackageError("invalid section [$1]" % e.section)

      # Trim context from subsection
      section = e.section.toLower.rsplit('.', maxsplit = 1)[^1]
    of cfgKeyValuePair, cfgOption:
      # echo "Option: $1 = $2 [$1]" % [e.key, e.value.escape]
      case section
      of "package", "target":
        case e.key
        of "name":
          if section == "target":
            if e.value == "all":
              p.raisePackageError("invalid target name \"all\"")
            for c in e.value:
              if c notin validTargetChars:
                p.raisePackageError("invalid character $1 in target name $2" %
                                    [escape($c), e.value.escape])
            if e.value in result:
              p.raisePackageError("duplicate target name $1" % e.value.escape)
            else:
              target.name = e.value
        of "description": target.description = e.value
        of "file": target.file = e.value
        of "branch": target.branch = e.value
        of "modName": target.modName = e.value
        of "modMinGameVersion": target.modMinGameVersion = e.value
        of "flags": target.flags.add(e.value)
        # Keep for backwards compatibility, but prefer [{package,target}.sources]
        of "source", "include": target.includes.add(e.value)
        of "exclude": target.excludes.add(e.value)
        of "filter": target.filters.add(e.value)
        # Unused, but kept for backwards compatibility
        of "version", "url", "author": discard
        else:
          # For backwards compatibility, treat any unknown keys as unpack rules.
          # Unfortunately, this prevents us from detecting incorrect keys, so
          # nasher may work unexpectedly. In the future, we will issue a
          # deprecation warning here.
          target.rules.add((e.key, e.value))
      of "sources":
        case e.key
        of "include": target.includes.add(e.value)
        of "exclude": target.excludes.add(e.value)
        of "filter": target.filters.add(e.value)
        else:
          p.raisePackageError("invalid key $1 for section [$2$3]" %
            [e.key.escape, if context.len > 0: context & "." else: "", section])
      of "rules":
        target.rules.add((e.key, e.value))
      of "variables":
        target.variables[e.key] = e.value
      else:
        discard
    of cfgError:
      p.raisePackageError(e.msg)
  close(p)

proc parsePackageString*(s: string, filename = "nasher.cfg"): OrderedTableRef[string, Target] =
  ## Parses `s` into a series of targets. The parser chosen is based on
  ## `filename`'s extension'.
  let stream = newStringStream(s)
  case filename.splitFile.ext
  of ".cfg":
    result = parseCfgPackage(stream, filename)
  else:
    raisePackageError("Unable to determine package parser for $1" % filename)

proc parsePackageFile*(filename: string): OrderedTableRef[string, Target] =
  ## Parses the file `filename` into a sequence of targets. The parser chosen is
  ## based on the file's extension.
  let fileStream = newFileStream(filename)
  if fileStream.isNil:
    raise newException(IOError, "Could not read package file $1" % filename)

  case filename.splitFile.ext
  of ".cfg": result = parseCfgPackage(fileStream, filename)
  else: raisePackageError("Unable to determine package parser for $1" % filename)
