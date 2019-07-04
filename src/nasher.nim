import os, osproc, rdstdin, sequtils, strformat, strutils, logging, tables

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
    file = opts.cmd.file.expandFilename
    cacheDir = file.getCacheDir(dir)

  if not existsFile(file):
    fatal(fmt"Cannot unpack file {file}: file does not exist")
    quit(QuitFailure)

  tryOrQuit(fmt"Could not create directory {cacheDir}"):
    createDir(cacheDir)

  withDir(cacheDir):
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
    globalCfgFile = getGlobalCfgFile()
    pkgCfgFile = dir / "nasher.cfg"

  if not existsFile(globalCfgFile):
    # TODO: allow user to input desired values before writing
    writeCfgFile(globalCfgFile, globalCfgText)

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
  withDir(dir):
    for source in target.sources:
      for file in glob.walkGlob(source):
        debug(fmt"Got file: {file}")
        copyFile(file, file.extractFilename)

proc compile(dir, compiler, flags: string) =
  withDir(dir):
    var isScripts = false
    for file in walkFiles("*.nss"):
      isScripts = true
      break

    if isScripts:
      let cmd = fmt"{compiler} {flags} *.nss"
      info(cmd)
      discard execCmd(cmd)
    else:
      info("Nothing to compile")

proc convert(dir: string) =
  withDir(dir):
    for file in walkFiles("*.*.json"):
      info("Converting ", file)
      file.gffConvert
      file.removeFile

proc install (file, dir: string, force: Answer) =
  if not existsFile(file):
    quit(fmt"Cannot install {file}: file does not exist")

  let
    fileName = file.extractFilename
    installDir = expandTilde(
      case fileName.splitFile.ext.strip(chars = {'.'})
      of "erf": dir / "erf"
      of "hak": dir / "hak"
      of "mod": dir / "modules"
      else: dir
    )

  if not existsDir(installDir):
    quit(fmt"Cannot install to {installDir}: directory does not exist")

  if existsFile(installDir / fileName):
    let prompt = fmt"{fileName} already exists. Overwrite? (y/N): "
    var overwrite = false
    case force
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
      quit(QuitSuccess)

  copyFile(file, installDir / fileName)

proc pack(opts: Options) =
  let
    target = getTarget(opts)
    buildDir = getBuildDir(target.name)

  removeDir(buildDir)
  createDir(buildDir)
  copySourceFiles(target, buildDir)

  if opts.cmd.kind in {ckInstall, ckPack, ckCompile}:
    info(fmt"Compiling scripts for target: {target.name}")
    compile(buildDir, opts.cfg.compiler.binary, opts.cfg.compiler.flags.join(" "))

  if opts.cmd.kind in {ckInstall, ckPack}:
    info(fmt"Converting sources for target: {target.name}")
    convert(buildDir)

    info(fmt"Packing files for target: {target.name}")
    let
      # sourceFiles = toSeq(walkFiles(buildDir / "*"))
      sourceFiles = @[buildDir / "*"]
      error = createErf(getPkgRoot() / target.file, sourceFiles)

    if error == 0:
      info(fmt"Successfully packed file: {target.file}")
    else:
      quit("Something went wrong!")

  if opts.cmd.kind == ckInstall:
    info(fmt"Installing {target.file} to {opts.cfg.install}")
    install(target.file, opts.cfg.install, opts.forceAnswer)

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
    of ckCompile, ckPack, ckInstall: pack(opts)
    of ckNil: echo nasherVersion
