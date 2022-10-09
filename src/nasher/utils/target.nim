import os, parsecfg, streams, strtabs, strutils
from sequtils import anyIt, filterIt, deduplicate

type
  PackageError* = object of CatchableError
    ## Raised when the package parser encounters an error

  Target* = ref object
    name*, description*, file*, branch*, parent*: string
    modName*, modMinGameVersion*, modDescription*: string
    includes*, excludes*, filters*, flags*, groups*: seq[string]
    variables*: seq[KeyValuePair]
    rules*: seq[Rule]

  KeyValuePair* = tuple[key, value: string]

  Rule* = tuple[pattern, dest: string]

const validTargetChars = {'\32'..'\64', '\91'..'\126'} - invalidFileNameChars

proc `==`*(a, b: Target): bool =
  result = true
  for _, valA, valB in fieldPairs(a[], b[]):
    if valA != valB:
      return false

proc filter*(targets: seq[Target], wanted: string): seq[Target] =
  for find in wanted.split(';'):
    if find == "":
      result.add(targets[0])
    elif find == "all":
      return targets
    else:
      let found = targets.filterIt(find == it.name or find in it.groups)
      if found.len == 0:
        raise newException(KeyError, "Unknown target " & find)
      result.add(found)
  result.deduplicate

proc raisePackageError(msg: string) =
  ## Raises a `PackageError` with the given message.
  raise newException(PackageError, msg)

proc raisePackageError(p: CfgParser, msg: string) =
  ## Raises a `PackageError` with the given message. Includes file, column, and
  ## line information for the user.
  raise newException(PackageError, "Error parsing $1($2:$3): $4" %
    [p.getFilename, $p.getLine, $p.getColumn, msg])

proc contains(kv: seq[KeyValuePair], key: string): bool =
  for k in kv:
    if k.key == key:
      return true

proc setDefaults(target, defaults: Target, idx: int) =
  ## Fills in missing fields other than `name` and `description` from `target`
  ## using those in `defaults`. Missing key/value pairs in `target.variables`
  ## are copied from `default.variables`. A `PackageError` is raised if the
  ## target does not have a name. `idx` and `filename` are used for error
  ## messages.
  for key, targetVal, defaultVal in fieldPairs(target[], defaults[]):
    if targetVal.len == 0:
      case key:
      of "name":
        raisePackageError("Error: target $1 does not have a name" % $(idx + 1))
      of "description", "parent", "variables":
        discard
      else:
        targetVal = defaultVal

  for (key, value) in defaults.variables:
    if key notin target.variables:
      target.variables.add((key, value))

proc resolve(s: var string, variables: StringTableRef) =
  s = `%`(s, variables, {useEnvironment})

proc resolve(items: var seq[string], variables: StringTableRef) =
  for item in items.mitems:
    resolve(item, variables)

proc resolve(rules: var seq[Rule], variables: StringTableRef) =
  for rule in rules.mitems:
    rule.pattern.resolve(variables)
    rule.dest.resolve(variables)

proc resolve(target: Target) =
  ## Resolves all variables in `target`'s fields using the values in
  ## `target.variables`. Missing variables will be filled in by env vars if
  ## available. Otherwise, throws an error.
  let vars = newStringTable()
  for (key, value) in target.variables:
    vars[key] = value

  # These variables should remain constant
  vars["target"] = target.name
  vars["ext"] = "$ext" # This supports $ext in unpack rule destinations

  # Resolve variables (including env vars)
  try:
    for key, val in fieldPairs(target[]):
      when key != "name" and key != "variables":
        resolve(val, vars)
  except ValueError as e:
    e.msg.removePrefix("format string: key not found: ")
    raisePackageError("Unknown variable $$$# in target $#" % [e.msg, target.name])

proc add(targets: var seq[Target], target, package: Target, isDefault: bool) =
  ## Resolves variables in `target` using the parent target from `targets` (if
  ## given, `package` if not) to supply default values. Then inserts `target` at
  ## the beginning or end of `targets` depending on `isDefault`.
  let parent =
    if target.parent.len > 0:
      targets.filterIt(it.name == target.parent)[0]
    else: package
  target.setDefaults(parent, targets.len)
  target.resolve
  if isDefault:
    targets.insert(target, 0)
  else:
    targets.add(target)

proc parseCfgPackage(s: Stream, filename = "nasher.cfg"): seq[Target] =
  ## Parses the content of `s` into a sequence of `Target`s. The cfg package
  ## format is assumed. `filename` is used for error messages only. Raises
  ## `PackageError` if an error is encountered during parsing.
  var
    p: CfgParser
    context, section, defaultTarget: string
    defaults = new Target
    target = new Target
    isDefault: bool

  p.open(s, filename)
  while true:
    var e = p.next
    case e.kind
    of cfgEof:
      if context == "target":
          result.add(target, defaults, isDefault)
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
          result.add(target, defaults, isDefault)
        else: assert(false)
        target = new Target
        context = "target"
        isDefault = false
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
        of "default":
          case section
          of "package":
            defaultTarget = e.value
          of "target":
            isDefault = true
        of "name":
          if section == "target":
            if e.value in ["", "all"]:
              p.raisePackageError("invalid target name \"$1\"" % e.value)
            for c in e.value:
              if c notin validTargetChars:
                p.raisePackageError("invalid character $1 in target name $2" %
                                    [escape($c), e.value.escape])
            if result.anyIt(it.name == e.value):
              p.raisePackageError("duplicate target name $1" % e.value.escape)
            else:
              target.name = e.value
              isDefault = isDefault or target.name == defaultTarget
        of "description": target.description = e.value
        of "file": target.file = e.value
        of "branch": target.branch = e.value
        of "parent":
          if not result.anyIt(it.name == e.value):
            p.raisePackageError("unknown parent target $1" % e.value.escape)
          target.parent = e.value
        of "modName": target.modName = e.value
        of "modMinGameVersion": target.modMinGameVersion = e.value
        of "modDescription": target.modDescription = e.value
        of "group": target.groups.add(e.value)
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
        target.variables.add((e.key, e.value))
      else:
        discard
    of cfgError:
      p.raisePackageError(e.msg)
  close(p)

proc parsePackageString*(s: string, filename = "nasher.cfg"): seq[Target] =
  ## Parses `s` into a series of targets. The parser chosen is based on
  ## `filename`'s extension'.
  let stream = newStringStream(s)
  case filename.splitFile.ext
  of ".cfg":
    result = parseCfgPackage(stream, filename)
  else:
    raisePackageError("Unable to determine package parser for $1" % filename)

proc parsePackageFile*(filename: string): seq[Target] =
  ## Parses the file `filename` into a sequence of targets. The parser chosen is
  ## based on the file's extension.
  let fileStream = newFileStream(filename)
  if fileStream.isNil:
    raise newException(IOError, "Could not read package file $1" % filename)

  case filename.splitFile.ext
  of ".cfg": result = parseCfgPackage(fileStream, filename)
  else: raisePackageError("Unable to determine package parser for $1" % filename)
