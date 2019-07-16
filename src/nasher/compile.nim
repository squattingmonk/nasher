from sequtils import toSeq
import os, tables, strtabs, strutils

import cli, config, shared, utils

const
  helpCompile* = """
  Usage:
    nasher compile [options] [<target>]

  Description:
    Compiles all nss sources for <target>. If <target> is not supplied, the first
    target supplied by the config files will be compiled. The input and output
    files are placed in .nasher/cache/<target>.

    Compilation of scripts is handled automatically by 'nasher pack', so you only
    need to use this if you want to compile the scripts without converting gff
    sources and packing the target file.

  Options:
    --clean        clears the cache directory before compiling

  Global Options:
    -h, --help     Display help for nasher or one of its commands
    -v, --version  Display version information
    --config FILE  Use FILE rather than the package config file

  Logging:
    --debug        Enable debug logging
    --verbose      Enable additional messages about normal operation
    --quiet        Disable all logging except errors
    --no-color     Disable color output (automatic if not a tty)
  """

proc getCacheMap(sources: seq[string]): StringTableRef =
  ## Generates a table mapping source files to their proper names in the cache
  for file in walkSourceFiles(sources):
    let
      (_, name, ext) = splitFile(file)
      fileName = if ext == ".json": name else: name & ext
    result[fileName] = file

proc updateCacheDir(target: Target, dir: string) =
  ## Syncs dir to the source tree for target. Copies new or changed source
  ## files and removes those that were deleted.
  display("Updating", "cache for target " & target.name)
  let
    cacheMap = getCacheMap(target.sources)

  # Remove deleted files
  for file in walkFiles(dir / "*"):
    if file notin cacheMap:
      removeFile(file)

  # Copy newer files
  for cacheFile, srcFile in cacheMap.pairs:
    let srcTime = srcFile.getLastModificationTime
    if fileOlder(cacheFile, srcTime):
      if srcFile.splitFile.ext == ".json":
        gffConvert(srcFile, dir)
      else:
        copyFile(srcFile, cacheFile)

      cacheFile.setLastModificationTime(srcTime)

proc compile*(opts: Options, cfg: var Config) =
  let
    cmd = opts.get("command")

  if opts.getBool("help"):
    # Make sure the correct command handles showing the help text
    if cmd == "compile": help(helpCompile)
    else: return

  if not isNasherProject():
    fatal("This is not a nasher project. Please run nasher init.")

  let config = opts.get("config", getPkgCfgFile())
  cfg = initConfig(getGlobalCfgFile(), config)

  let
    name = opts.get("target")
    target = getTarget(name, cfg)
    cacheDir = getCacheDir(target.name)

  # Set these so they can be gotten easily by the pack and install commands
  opts["file"] = target.file
  opts["directory"] = cacheDir

  if opts.get("clean", false):
    removeDir(cacheDir)

  createDir(cacheDir)
  updateCacheDir(target, cacheDir)

  withDir(cacheDir):
    let
      scripts = toSeq(walkFiles("*.nss")).join(" ")
      compiler = cfg.compiler.binary
      flags = cfg.compiler.flags.join(" ")

    if scripts.len > 0:
      let errcode = runCompiler(compiler, [flags, scripts])
      if errcode != 0:
        warning("Finished with error code " & $errcode)
    else:
      info("Skipping", "compilation: nothing to compile")

  # Prevent falling through to the next function if we were called directly
  if cmd == "compile":
    quit(QuitSuccess)
