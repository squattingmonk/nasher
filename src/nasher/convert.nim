import os, strtabs
import utils/[cli, nwn, options, shared]

const
  helpConvert* = """
  Usage:
    nasher convert [options] [<target>]

  Description:
    Converts all JSON sources for <target> into their GFF counterparts. If not
    supplied, <target> will default to the first target found in the package file.
    The input and output files are placed in .nasher/cache/<target>.

    This command is called automatically by 'nasher pack', so you only need to use
    this if you want to convert the sources without compiling scripts and packing
    the target file.

  Options:
    --clean        Clears the cache directory before converting

  Global Options:
    -h, --help     Display help for nasher or one of its commands
    -v, --version  Display version information

  Logging:
    --debug        Enable debug logging
    --verbose      Enable additional messages about normal operation
    --quiet        Disable all logging except errors
    --no-color     Disable color output (automatic if not a tty)
  """

proc getCacheMap(includes, excludes: seq[string]): StringTableRef =
  ## Generates a table mapping source files to their proper names in the cache
  result = newStringTable()
  for file in walkSourceFiles(includes, excludes):
    let
      (_, name, ext) = splitFile(file)
      fileName = if ext == ".json": name else: name & ext
    result[fileName] = file

proc convert*(opts: Options, pkg: PackageRef) =
  let
    cmd = opts["command"]

  if opts.getBoolOrDefault("help"):
    # Make sure the correct command handles showing the help text.
    if cmd == "convert": help(helpConvert)
    else: return

  if not loadPackageFile(pkg, getPackageFile()):
    fatal("This is not a nasher project. Please run nasher init.")

  setCurrentDir(getPackageRoot())
  
  let
    target = pkg.getTarget(opts.getOrDefault("target"))
    cacheDir = ".nasher" / "cache" / target.name
    cacheMap = getCacheMap(target.includes, target.excludes)

  # Set these so they can be gotten easily by the pack and install commands
  pkg.cache = cacheMap
  opts["file"] = target.file
  opts["target"] = target.name
  opts["directory"] = cacheDir

  display("Updating", "cache for target " & target.name)
  if opts.getBoolOrDefault("clean"):
    removeDir(cacheDir)

  createDir(cacheDir)

  # Remove deleted files
  for file in walkFiles(cacheDir / "*"):
    let fileName = file.extractFileName
    if fileName notin cacheMap and fileName.splitFile.ext != ".ncs":
      display("Removing", fileName, priority = LowPriority)
      removeFile(file)

  # Copy newer files
  for fileName, srcFile in cacheMap.pairs:
    let
      cacheFile = cacheDir / fileName
      srcTime = srcFile.getLastModificationTime
    if fileOlder(cacheFile, srcTime):
      if srcFile.splitFile.ext == ".json":
        gffConvert(srcFile, cacheDir)
      else:
        display("Copying", srcFile & " -> " & fileName, priority = LowPriority)
        copyFile(srcFile, cacheFile)

      setLastModificationTime(cacheFile, srcTime)

  # Prevent falling through to the next function if we were called directly
  if cmd == "convert":
    quit(QuitSuccess)
