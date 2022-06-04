## This module implements configuration options. It also handles parsing of user
## input as options. It supports either command-line parameters or configuration
## files.
##
## # Options
## `Options` is implemented as a case- and style-insensitive `StringTableRef`.
## 
## Values are retrieved from the table using `get`, which provides a default
## value if the key is not set. While values are always stored as strings, they
## can be converted to an `int` or `bool` type by passing a default value of
## that type to `get`.
##
## # Parsing user input
## When processing user options, nasher first parses a global `user.cfg` file,
## then parses a package-local `user.cfg` file, then parses command-line input.
## At each step, option values may be overridden, allowing a heirarchy. Default
## options can be supplied at access time when the user has not supplied them.
import os, parsecfg, streams, strtabs, strutils
from sequtils import toSeq
from algorithm import sorted

import blarg
import cli

export strtabs

type
  Options* = StringTableRef

  SyntaxError* = object of CatchableError
    ## Raised when a syntax error is found in a config file

const
  nasherCommands* = ## Valid nasher commands.
    ["init", "list", "config", "convert", "compile", "pack", "install", "play",
     "test", "serve", "unpack"]

  internalKeys* = ## Keys that cannot be set via config file or command-line
    ["command", "configop", "configscope", "configkey", "configvalue"]

  cliKeys* = ## Keys that cannot be set via config file
    ["directory", "file", "files", "target", "targets", "help", "version"]

proc newOptions*(): Options =
  ## Returns a new options table.
  newStringTable(modeStyleInsensitive)

proc `[]=`*[T: bool|int](opts: Options, key: string, value: T) =
  ## Overloaded `[]=` operator that converts `value` to a string before setting
  ## `opts[key]`.
  opts[key] = $value

converter toBool(s: string): bool =
  ## Converts `s` to a `bool` value. An empty string is treated as `true` in
  ## order to support flags passed without an explicit value. Throws a
  ## `ValueError` if `s` cannot be converted to `bool`.
  s == "" or s.parseBool

converter toInt(s: string): int =
  ## Converts `s` to an `int` value. Throws a `ValueError` if `s` cannot be
  ## converted to `int`.
  s.parseInt

proc get*[T: bool|int|string](opts: Options, keys: openarray[string], default: T = ""): T =
  ## Checks `opts` for each key in `keys` and returns the value of the first one
  ## of type `T`. If none of the keys are set or none of the keys can be
  ## converted to `T`, returns `default`. 
  result = default
  for key in keys:
    if key in opts:
      try:
        when T is string:
          result = opts[key]
        elif T is bool:
          result = opts[key].toBool
        elif T is int:
          result = opts[key].toInt
      except ValueError:
        discard

proc get*[T: bool|int|string](opts: Options, key: string, default: T = ""): T =
  ## Returns value of type `T` stored at `key` in `opts`. If `key` is not
  ## present in `opts` or cannot be converted to `T`, returns `default` instead.
  opts.get([key], default)

proc hasKeyOrPut*[T: bool|int|string](opts: Options, keys: openarray[string], value: T): bool =
  ## Returns true if each key in `keys` is in `opts`. Otherwise, sets the first
  ## key that is not present to `value` and returns false.
  result = true
  for key in keys:
    if key notin opts:
      opts[key] = value
      return false

proc hasKeyOrPut*[T: bool|int|string](opts: Options, key: string, value: T): bool =
  ## Returns true if `key` is in `opts`. Otherwise, sets `opts[key]` to
  ## `value` and returns false. If `value` is not a string, it will be
  ## converted to one.
  opts.hasKeyOrPut([key], value)

proc getOrPut*[T: bool|int|string](opts: Options, key: string, value: T): T =
  ## Returns the value of type `T` located at `opts[key]`. If the key does not
  ## exist or cannot be converted to `T`, it is set to `value`, which is
  ## returned.
  result = value
  if opts.hasKeyOrPut([key], value):
    let tmpValue = opts[key]
    try:
      when T is bool:
        result = tmpValue.toBool
      elif T is int:
        result = tmpValue.toInt
      else:
        result = tmpValue
    except ValueError:
      opts[key] = value

# --- Config file parsing

proc handleColorKey(key, val: string) =
  ## Handling for the --[no-]color key. The special "auto" value is supported to
  ## allow the user to override a config-file setting with the default.
  ##   showColor == true: --color, --color=true, --no-color=false
  ##   showColor == false: --no-color, --no-color=true, --color=false
  ##   showColor == stdout.isatty: --color=auto, --no-color=auto
  if val == "auto":
    setShowColor(stdout.isatty)
  else:
    try:
      setShowColor(if key == "color": val.toBool else: not val.toBool)
    except ValueError:
      raise newException(SyntaxError,
        "Expected bool value for option --$1 but got $2" % [key, val])

proc parseCfg(opts: Options, s: Stream, filename = "user.cfg") =
  ## Parses all key/value pairs in `s` and loads them into `opts`. The
  ## `user.cfg` file format is assumed. Raises a `SyntaxError` if invalid syntax
  ## was found. `filename` is used only for pretty error messages.
  var
    p: CfgParser
    e: CfgEvent

  p.open(s, filename)
  while true:
    e = p.next
    case e.kind
    of cfgKeyValuePair, cfgOption:
      let normalKey = e.key.normalize
      if normalKey in internalKeys or normalKey in cliKeys:
        # TODO: warn with ignoreMsg()?
        discard
      else:
        # We store the keys in their non-normalized version so the config file
        # retains the style the user prefers.
        opts[e.key] = e.value
        if normalKey in ["color", "no-color", "nocolor", "noColor"]:
          handleColorKey(normalKey, e.value)
    of cfgEof:
      break
    of cfgError:
      raise newException(SyntaxError, e.msg)
    else:
      # TODO: subsections?
      discard
  p.close

proc parseString*(opts: Options, s: string, filename = "user.cfg") =
  ## Loads all key/value pairs from `s` into `opts`. Will throw a `SyntaxError`
  ## if invalid syntax was found. `filename` is used only for pretty error
  ## messages.
  let stream = newStringStream(s)
  case filename.splitFile.ext
  of ".cfg":
    opts.parseCfg(stream, filename)
  else:
    raise newException(ValueError, "Unable to determine config parser for $1" % filename)

proc parseFile*(opts: Options, file: string) =
  ## Parses all key/value pairs in `file` into `opts`. Raises `ValueError` if
  ## the correct parser for the file cannot be dtermined, an `IOError` if `file`
  ## cannot be opened, a `SyntaxError` if an error was encountered in parsing.
  let stream = openFileStream(file)
  defer: stream.close
  case file.splitFile.ext
  of ".cfg":
    opts.parseCfg(stream, file)
  else:
    raise newException(ValueError, "Unable to determine config parser for $1" % file)

iterator sortedPairs*(opts: Options): tuple[key, value: string] =
  ## Iterates over every key-value pair in `opts` sorted by key.
  for key in toSeq(opts.keys).sorted(cmpIgnoreStyle):
    yield (key, opts[key])

proc writeFile*(opts: Options, file: string) =
  ## Converts `opts` into a config file named `file` which can be read with
  ## `parseConfigFile`. Raises an `IOError` if `file` cannot be written to.
  var s = openFileStream(file, fmWrite)
  defer: s.close
  for (key, value) in opts.sortedPairs:
    s.writeLine("$1 = $2" % [key, value.escape])

# --- Command-line parsing

proc putKeyOrHelp*[T: bool|int|string](opts: Options, keys: openarray[string], value: T) =
  ## Checks `opts` for each key in `keys`, setting the first missing key to
  ## `value`. If all `keys` are set, sets the `help` key to `true`.
  for key in keys:
    if key notin opts:
      opts[key] = value
      return
  opts["help"] = true

proc parseCommandLine*[T: string|seq[string]](opts: Options, params: T = commandLineParams()) =
  ## Parses the command line and stores the user input into `opts`.
  var
    p = initOptParser(
      cmdline = params,
      shortNoVal = {'y', 'n', 'h', 'v', 'g', 's', 'u', 'l'},
      longNoVal = @["help", "version", "color", "noColor", "no-color", "debug",
        "verbose", "quiet", "yes", "no", "default", "get", "set", "unset",
        "list", "global", "local", "clean", "noConvert", "noCompile", "noPack",
        "noInstall", "removeDeleted", "removeUnusedAreas", "useModuleFolder",
        "abortOnCompileError"],
      normalizeOption = normalize)

  for kind, key, val in p.getopt():
    case kind
    of cmdArgument:
      case opts.get("command")
      of "init":
        opts.putKeyOrHelp(["directory", "file"], key)
      of "config":
        opts.putKeyOrHelp(["configKey", "configValue"], key)
      of "list", "compile", "convert", "pack", "install", "play", "test", "serve":
        if opts.hasKeyOrPut("targets", key):
          opts["targets"] = opts["targets"] & ";" & key
      of "unpack":
        opts.putKeyOrHelp(["target", "file"], key)
      else:
        if key in nasherCommands:
          opts["command"] = key
        else:
          opts["help"] = true
          break
    of cmdLongOption, cmdShortOption:
      let normalKey = p.normalizeOption(key)
      if normalKey in internalKeys:
        raise newException(SyntaxError,
          "Cannot manually set option --$1: internal use only" % key)
      case normalKey
      of "h", "help":
        opts["help"] = true
      of "v", "version":
        opts["version"] = true
      of "quiet":
        setLogLevel(HighPriority)
      of "verbose":
        setLogLevel(LowPriority)
      of "debug":
        setLogLevel(DebugPriority)
      of "y", "yes":
        setForceAnswer(Yes)
      of "n", "no":
        setForceAnswer(No)
      of "d", "default":
        setForceAnswer(Default)
      of "color", "no-color", "nocolor":
        handleColorKey(key, val)
      else:
        case opts.get("command")
        of "config":
          case key
          of "g", "get": opts.putKeyOrHelp(["configOp"], "get")
          of "s", "set": opts.putKeyOrHelp(["configOp"], "set")
          of "u", "unset": opts.putKeyOrHelp(["configOp"], "unset")
          of "l", "list": opts.putKeyOrHelp(["configOp"], "list")
          of "global", "local": opts.putKeyOrHelp(["configScope"], key)
          of "directory": opts.putKeyOrHelp(["directory"], val)
          else:
            opts.putKeyOrHelp(["configKey"], key)
            opts.putKeyOrHelp(["configValue"], val)
        of "compile":
          case key
          of "f", "file":
            if opts.hasKeyOrPut("files", val):
              opts["files"] = opts["files"] & ";" & val
          else:
            opts[key] = val
        else:
          opts[key] = val
    else:
      assert false

  # Some options imply others
  if opts.get("clean", false):
    opts["noInstall"] = false
    opts["noPack"] = false

  if opts.get("noInstall", false):
    opts["noPack"] = true

  if opts.get("noPack", false):
    opts["noCompile"] = true
    opts["noConvert"] = true
