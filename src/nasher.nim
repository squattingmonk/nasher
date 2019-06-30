import os, osproc, rdstdin, strformat, strutils, logging, tables

import glob

import nasher/options
import nasher/erf
import nasher/gff

proc showHelp(kind: CommandKind) =
  let help =
    case kind
    of ckInit: helpInit
    of ckList: helpList
    of ckCompile: helpCompile
    of ckPack: helpPack
    of ckUnpack: helpUnpack
    of ckInstall: helpInstall
    else: helpAll

  echo help
  echo helpOptions

proc unpack(opts: Options) =
  let
    dir = opts.cmd.dir
    file = opts.cmd.file
    cacheDir = file.getCacheDir(dir)

  if not existsFile(file):
    fatal(fmt"Cannot unpack file {file}: file does not exist")
    quit(QuitFailure)

  tryOrQuit(fmt"Could not create directory {cacheDir}"):
    createDir(cacheDir)

  tryOrQuit(fmt"Could not extract {file}"):
    extractErf(file, cacheDir)

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
    opts.configs.add(getPkgCfgFile(dir))
    opts.cfg = loadConfig(opts.configs)
    unpack(opts)

proc list(opts: Options) =
  tryOrQuit("No targets found. Please check your nasher.cfg."):
    for target in opts.cfg.targets.values:
      echo target.name
      if opts.verbosity <= lvlInfo:
        echo "  Description: ", target.description
        echo "  File: ", target.file
        for source in target.sources:
          echo "  Source: ", source

proc getTarget(opts: Options): Target =
  ## Returns the target specified by the user, or the first target found in the
  ## parsed config files if the user did not specify a target.
  try:
    if opts.cmd.target.len > 0:
      result = opts.cfg.targets[opts.cmd.target]
    else:
      for target in opts.cfg.targets.values:
        return target
  except IndexError:
    quit("No targets found. Please check your nasher.cfg file.")
  except KeyError:
    quit(fmt"Unknown target: {opts.cmd.target}")

proc copySourceFiles(target: Target, dir: string) =
  ## Copies all source files for target to dir
  for source in target.sources:
    for file in glob.walkGlob(source):
      debug(fmt"Got file: {file}")
      copyFile(file, dir / file.extractFilename)

proc compile(dir, compiler, flags: string) =
  setCurrentDir(dir)
  var fileList: seq[string]

  for file in walkFiles("*.nss"):
    fileList.add(file)

  if fileList.len > 0:
    let
      files = fileList.join(" ")
      cmd = fmt"{compiler} {flags} {files}"
    info(cmd)
    discard execCmd(cmd)
  else:
    info("Nothing to compile")

proc convert(dir: string) =
  setCurrentDir(dir)
  for file in walkFiles("*.*.json"):
    info("Converting ", file)
    file.gffConvert
    file.removeFile

proc pack(opts: Options) =
  let
    target = getTarget(opts)
    buildDir = getBuildDir(target.name)

  removeDir(buildDir)
  createDir(buildDir)
  copySourceFiles(target, buildDir)

  if opts.cmd.kind in {ckPack, ckCompile}:
    notice(fmt"Compiling scripts for target: {target.name}")
    compile(buildDir, opts.cfg.compiler.binary, opts.cfg.compiler.flags.join(" "))

  if opts.cmd.kind == ckPack:
    notice(fmt"Converting sources for target: {target.name}")
    convert(buildDir)

    notice(fmt"Packing files for target: {target.name}")
    let outfile = getPkgRoot(getCurrentDir()) / target.file
    var files: seq[string]

    for file in walkFiles(buildDir / "*"):
      files.add(file)

    createErf(outfile, files)
    if existsFile(outfile):
      notice(fmt"Successfully packed file: {outfile}")
    else:
      fatal("Something went wrong!")

proc install(opts: Options) =
  if not opts.cmd.file.existsFile:
    quit(fmt"Cannot install {opts.cmd.file}: file does not exist.")

  let
    file = opts.cmd.file.extractFilename
    ext = file.splitFile.ext.strip(chars = {'.'})
    dir =
      case ext
      of "erf", "hak":
        opts.cmd.dir / ext
      of "mod":
        opts.cmd.dir / "modules"
      else:
        opts.cmd.dir

  if not existsDir(dir):
    quit(fmt"Cannot install {opts.cmd.file}: {dir} does not exist.")

  echo fmt"Installing {opts.cmd.file} into {dir}..."

  if existsFile(dir / file):
    let prompt = fmt"{file} already exists. Overwrite? (y/N): "
    var overwrite = false
    case opts.forceAnswer
    of No, Default:
      echo(prompt, "-> forced no")
    of Yes:
      echo(prompt, "-> forced yes")
      overwrite = true
    else:
      try:
        overwrite = readLineFromStdin(prompt).parseBool
      except ValueError:
        discard

    if not overwrite:
      quit("Aborting...")

  copyFile(opts.cmd.file, dir / file)






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
    of ckUnpack: unpack(opts)
    of ckInstall: install(opts)
    of ckCompile, ckPack: pack(opts)
    of ckNil: echo nasherVersion
