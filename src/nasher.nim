import os, osproc, sequtils, streams, strformat, strutils, tables

import glob

import nasher/options
import nasher/erf
import nasher/gff
import nasher/nwnsc

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

  display("Initializing", "into " & dir)
  # TODO: allow user to input desired values before writing
  writeCfgFile(pkgCfgFile, pkgCfgText)
  success("project initialized")

  if opts.cmd.file.len() > 0:
    opts.cmd.dir = getSrcDir(dir)
    opts.configs.add(getPkgCfgFile(dir))
    opts.cfg = loadConfig(opts.configs)
    unpack(opts)

proc list(opts: Options) =
  tryOrQuit("No targets found. Please check your nasher.cfg."):
    if isLogging(Low):
      var hasRun = false
      for target in opts.cfg.targets.values:
        if hasRun:
          stdout.write("\n")
        display("Target:", target.name)
        display("Description:", target.description)
        display("File:", target.file)
        display("Sources:", target.sources.join("\n"))
        hasRun = true
    else:
      echo toSeq(opts.cfg.targets.keys).join("\n")

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
    fatal("No targets found. Please check your nasher.cfg file.")
  except KeyError:
    fatal("Unknown target: " & opts.cmd.target)

proc copySourceFiles(target: Target, dir: string) =
  ## Copies all source files for target to dir
  withDir(getPkgRoot()):
    for source in target.sources:
      debug("Copying", "source files from " & source)
      for file in glob.walkGlob(source):
        debug("Copying", file)
        copyFile(file, dir / file.extractFilename)

proc compile(dir, compiler, flags: string) =
  withDir(dir):
    var isScripts = false
    for file in walkFiles("*.nss"):
      isScripts = true
      break

    if isScripts:
      let errcode = runCompiler(compiler, [flags, "*.nss"])
      if errcode != 0:
        warning("Finished with error code " & $errcode)
    else:
      info("Skipping", "compilation: nothing to compile")

proc convert(dir: string) =
  withDir(dir):
    for file in walkFiles("*.*.json"):
      file.gffConvert
      file.removeFile

proc install (file, dir: string, force: Answer) =
  display("Installing", file & " into " & dir)
  if not existsFile(file):
    fatal(fmt"Cannot install {file}: file does not exist")

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
    fatal(fmt"Cannot install to {installDir}: directory does not exist")

  if existsFile(installDir / fileName):
    if not prompt(fileName & " already exists. Overwrite?"):
      quit(QuitSuccess)

  copyFile(file, installDir / fileName)
  success("file installed")

proc pack(opts: Options) =
  let
    target = getTarget(opts)
    buildDir = getBuildDir(target.name)

  removeDir(buildDir)
  createDir(buildDir)
  copySourceFiles(target, buildDir)

  if opts.cmd.kind in {ckInstall, ckPack, ckCompile}:
    compile(buildDir, opts.cfg.compiler.binary, opts.cfg.compiler.flags.join(" "))

  if opts.cmd.kind in {ckInstall, ckPack}:
    convert(buildDir)

    display("Packing", "files for " & target.name)
    let
      # sourceFiles = toSeq(walkFiles(buildDir / "*"))
      sourceFiles = @[buildDir / "*"]
      error = createErf(getPkgRoot() / target.file, sourceFiles)

    if error == 0:
      success("Packed " & target.file)
    else:
      fatal("Something went wrong!")

  if opts.cmd.kind == ckInstall:
    install(target.file, opts.cfg.install, opts.forceAnswer)

when isMainModule:
  var opts = parseCmdLine()

  if opts.cmd.kind notin {ckNil, ckInit}:
    if not isNasherProject():
      fatal("This is not a nasher project. Please run nasher init.")
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
