import logging, parseopt, strutils

import common

type
  Options* = object
    cmd*: Command
    verbosity*: Level
    showVersion*: bool
    showHelp*: bool

  CommandKind* = enum
    cmdNil, cmdInit, cmdCompile, cmdList, cmdBuild,
    cmdUnpack, cmdInstall, cmdClean, cmdClobber

  Command* = object
    case kind*: CommandKind
    of cmdNil, cmdList, cmdClean, cmdClobber:
      nil
    of cmdCompile, cmdBuild:
      build*: string
    of cmdInit, cmdUnpack, cmdInstall:
      file*: string
      dir*: string

proc initOptions(): Options =
  result.cmd = Command(kind: cmdNil)
  result.verbosity = lvlNotice

proc initCommand(options: var Options) =
  case options.cmd.kind
  of cmdInit:
    options.cmd.dir = getCurrentDir()
    options.cmd.file = ""
  of cmdUnpack:
    options.cmd.dir = srcDir
    options.cmd.file = ""
  of cmdInstall:
    options.cmd.dir = nwnInstallDir
    options.cmd.file = ""
  of cmdCompile, cmdBuild:
    options.cmd.build = ""
  else:
    discard

proc parseCommandKind(cmd: string): CommandKind =
  case cmd.normalize()
  of "init": cmdInit
  of "list": cmdList
  of "compile": cmdCompile
  of "build": cmdBuild
  of "unpack": cmdUnpack
  of "install": cmdInstall
  of "clean": cmdClean
  of "clobber": cmdClobber
  else: cmdNil

proc parseCommand(key: string, result: var Options) =
    result.cmd = Command(kind: parseCommandKind(key))
    initCommand(result)

proc parseArgument(key: string, result: var Options) =
  case result.cmd.kind
  of cmdNil:
    assert(false)
  of cmdInit:
    result.cmd.dir = key
  of cmdCompile, cmdBuild:
    result.cmd.build = key
  of cmdUnpack, cmdInstall:
    if result.cmd.file != "":
      result.cmd.dir = key
    else:
      result.cmd.file = key
  else:
    discard

proc parseFlag(flag, value: string, result: var Options) =
  case flag
  of "h", "help":
    result.showHelp = true
  of "v", "version":
    result.showVersion = true
  of "verbose":
    result.verbosity = lvlDebug
  of "quiet":
    result.verbosity = lvlError
  else:
    raise newException(NasherError, "Unknown option --" & flag)

proc parseCmdLine*(): Options =
  result = initOptions()

  for kind, key, value in getopt():
    case kind
    of cmdArgument:
      if result.cmd.kind == cmdNil:
        parseCommand(key, result)
      else:
        parseArgument(key, result)
    of cmdLongOption, cmdShortOption:
      parseFlag(key, value, result)
    of cmdEnd: # Cannot happen
      assert(false)

  # If no commands were entered, show the help message
  if result.cmd.kind == cmdNil and not result.showVersion:
    result.showHelp = true

  # The build and install commands must specify a file to operate on
  if result.cmd.kind in {cmdUnpack, cmdInstall} and result.cmd.file.len == 0:
    result.showHelp = true
