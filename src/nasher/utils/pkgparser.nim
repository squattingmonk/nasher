import os, parsecfg, streams, strutils
from sequtils import anyIt

import target
export target

type
  PackageError* = object of CatchableError
    ## Raised when the package parser encounters an error

const validTargetChars = Letters + Digits + {'_', '-'}

proc raisePackageError(msg: string) =
  ## Raises a `PackageError` with the given message.
  raise newException(PackageError, msg)

proc raisePackageError(p: CfgParser, msg: string) =
  ## Raises a `PackageError` with the given message. Includes file, column, and
  ## line information for the user.
  raise newException(PackageError, "Error parsing $1($2:$3): $4" %
    [p.getFilename, $p.getLine, $p.getColumn, msg])

proc addTarget(targets: var seq[Target], target: Target, defaults: Target, filename = "") =
  ## Adds `target` to `targets`. Missing fields other than `name`
  ## and`description` are copied from `defaults`. A `PackageError` is raised if
  ## the target does not have a name. `filename` is used for error messages.
  for key, targetVal, defaultVal in fieldPairs(target[], defaults[]):
    if targetVal.len == 0:
      case key:
      of "name":
        raisePackageError("Error parsing $1: target $2 does not have a name" %
          [filename, $(targets.len + 1)])
      of "description":
        discard
      else:
        targetVal = defaultVal
  targets.add(target)

proc parseCfgPackage(s: Stream, filename = "nasher.cfg"): seq[Target] =
  ## Parses the content of `s` into a sequence of `Target`s. The cfg package
  ## format is assumed. `filename` is used for error messages only. Raises
  ## `PackageError` if an error is encountered during parsing.
  var
    p: CfgParser
    context, section: string
    defaults = new Target
    target = new Target

  p.open(s, filename)
  while true:
    var e = p.next
    case e.kind
    of cfgEof:
      if context == "target":
        result.addTarget(target, defaults)
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
          result.addTarget(target, defaults)
        else: assert(false)
        target = new Target
        context = "target"
      of "sources", "rules":
        discard
      of "package.sources", "package.rules":
        if context in ["target"]:
          p.raisePackageError("[$1] must be declared within [package]" % e.section)
      of "target.sources", "target.rules":
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
            if e.value == "all" or not e.value.allCharsInSet(validTargetChars):
              p.raisePackageError("invalid target name $1" % e.value.escape)
            elif result.anyIt(it.name == e.value):
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
