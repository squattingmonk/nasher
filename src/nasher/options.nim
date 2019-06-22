import logging, os, parseopt, strutils

import common, config
export common, config

type
  Options* = object
    cmd*: Command
    cfg*: Config
    configs*: seq[string]
    verbosity*: Level
    showVersion*: bool
    showHelp*: bool

  CommandKind* = enum
    ckNil, ckInit, ckCompile, ckList, ckPack, ckUnpack, ckInstall 

  Command* = object
    case kind*: CommandKind
    of ckNil, ckList:
      nil
    of ckCompile, ckPack:
      target*: string
    of ckInit, ckUnpack, ckInstall:
      file*: string
      dir*: string

proc initOptions(): Options =
  result.cmd = Command(kind: ckNil)
  result.configs = @[getUserCfgFile(), getPkgCfgFile()]
  result.verbosity = lvlNotice

proc initCommand(options: var Options) =
  case options.cmd.kind
  of ckInit:
    options.cmd.dir = getCurrentDir()
    options.cmd.file = ""
  of ckUnpack:
    options.cmd.dir = getSrcDir()
    options.cmd.file = ""
  of ckInstall:
    options.cmd.dir = nwnInstallDir
    options.cmd.file = ""
  of ckCompile, ckPack:
    options.cmd.target = ""
  else:
    discard

proc parseCommandKind(cmd: string): CommandKind =
  case cmd.normalize()
  of "init": ckInit
  of "list": ckList
  of "compile": ckCompile
  of "pack": ckPack
  of "unpack": ckUnpack
  of "install": ckInstall
  else: ckNil

proc parseCommand(key: string, result: var Options) =
    result.cmd = Command(kind: parseCommandKind(key))
    initCommand(result)

proc parseArgument(key: string, result: var Options) =
  case result.cmd.kind
  of ckNil:
    assert(false)
  of ckInit:
    if result.cmd.dir != getCurrentDir() or key == getCurrentDir():
      result.cmd.file = key
    else:
      result.cmd.dir = key
  of ckCompile, ckPack:
    result.cmd.target = key
  of ckUnpack, ckInstall:
    if result.cmd.file != "":
      result.cmd.dir = key
    else:
      result.cmd.file = key
  else:
    discard

proc parseFlag(flag, value: string, result: var Options) =
  case flag
  of "c", "config":
    result.configs.add(value)
  of "h", "help":
    result.showHelp = true
  of "v", "version":
    result.showVersion = true
  of "debug":
    result.verbosity = lvlDebug
  of "verbose":
    result.verbosity = lvlInfo
  of "quiet":
    result.verbosity = lvlError
  else:
    raise newException(NasherError, "Unknown option --" & flag)

const
  longOpts = @["help", "version", "verbose", "debug", "quiet"]
  shortOpts = {'h', 'v'}

proc parseCmdLine*(): Options =
  result = initOptions()

  for kind, key, value in getopt(shortNoVal = shortOpts, longNoVal = longOpts):
    case kind
    of cmdArgument:
      if result.cmd.kind == ckNil:
        parseCommand(key, result)
      else:
        parseArgument(key, result)
    of cmdLongOption, cmdShortOption:
      parseFlag(key, value, result)
    of cmdEnd: # Cannot happen
      assert(false)

  # If no commands were entered, show the help message
  if result.cmd.kind == ckNil and not result.showVersion:
    result.showHelp = true

  # The unpack and install commands must specify a file to operate on
  if result.cmd.kind in {ckUnpack, ckInstall} and result.cmd.file.len == 0:
    result.showHelp = true
