import os, osproc, strformat, strutils, logging, tables

import nasher/options
import nasher/erf
import nasher/gff

proc showHelp(kind: CommandKind) =
  echo help

proc unpack(opts: Options) =
  let
    dir = opts.cmd.dir
    file = opts.cmd.file
    cacheDir = file.getCacheDir(dir)

  if not existsFile(file):
    fatal(fmt"Cannot unpack file {file}: file does not exist")
    quit(QuitFailure)

  try:
    createDir(cacheDir)
  except OSError:
    let msg = osErrorMsg(osLastError())
    fatal(fmt"Could not create directory {cacheDir}: {msg}")
    quit(QuitFailure)

  try:
    extractErf(file, cacheDir)
  except IOError:
    fatal(fmt"Could not extract {file}")
    quit(QuitFailure)

  for ext in GffExtensions:
    createDir(dir / ext)
    for file in walkFiles(cacheDir / "*".addFileExt(ext)):
      gffConvert(file, dir / ext)

  createDir(dir / "nss")
  for file in walkFiles(cacheDir / "*".addFileExt("nss")):
    copyFileWithPermissions(file, dir / "nss" / file.extractFilename())

proc init(opts: var Options) =
  let
    dir = opts.cmd.dir
    userCfgFile = getUserCfgFile()
    pkgCfgFile = dir / "nasher.cfg"

  if not existsFile(userCfgFile):
    # TODO: allow user to input desired values before writing
    writeCfgFile(userCfgFile, userCfgText)

  if existsFile(pkgCfgFile):
    fatal(fmt"{dir} is already a nasher project")
    quit(QuitFailure)

  notice(fmt"Initializing into {dir}...")
  # TODO: allow user to input desired values before writing
  writeCfgFile(pkgCfgFile, pkgCfgText)
  notice("Successfully initialized project")

  if opts.cmd.file.len() > 0:
    opts.cmd.dir = getSrcDir(dir)
    opts.configs[1] = pkgCfgFile
    opts.cfg = loadConfig(opts.configs)
    unpack(opts)

proc list(opts: Options) =
  for target in opts.cfg.targets.values:
    echo target.name
    if opts.verbosity <= lvlInfo:
      echo "  Description: ", target.description
      echo "  File: ", target.file
      for source in target.sources:
        echo "  Source: ", source

proc compile(opts: Options) =
  echo fmt"Compiling target {opts.cmd.target}..."

proc pack(opts: Options) =
  echo fmt"Packing {opts.cmd.target}..."

proc install(opts: Options) =
  echo fmt"Installing {opts.cmd.file} into {opts.cmd.dir}..."





when isMainModule:
  var opts = parseCmdLine()

  setLogFilter(opts.verbosity)
  addHandler(newConsoleLogger(fmtStr = "[$levelname]: "))
  debug(opts)

  if opts.cmd.kind notin {ckNil, ckInit}:
    if not isNasherProject():
      fatal("This is not a nasher project. Please run nasher init.")
      quit(QuitFailure)
    else:
      opts.cfg = loadConfig(opts.configs)

  if opts.showHelp:
    showHelp(opts.cmd.kind)
  else:
    case opts.cmd.kind
    of ckList: list(opts)
    of ckInit: init(opts)
    of ckCompile: compile(opts)
    of ckPack: pack(opts)
    of ckUnpack: unpack(opts)
    of ckInstall: install(opts)
    of ckNil: echo nasherVersion
