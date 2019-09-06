import os, strtabs, strutils
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

proc convert*(opts: Options, pkg: PackageRef): bool =
  let root = getPackageRoot()
  setCurrentDir(root)

  let
    cmd = opts["command"]
    category = (if cmd == "compile": "compiling" else: cmd & "ing")
    target = pkg.getTarget(opts.get("target"))
    cacheMap = getCacheMap(target.includes, target.excludes)

  display(category.capitalizeAscii, "target " & target.name)

  if cacheMap.len == 0:
    error("No source files found for target " & target.name)
    return false

  let
    cacheDir = ".nasher" / "cache" / target.name
    gffUtil = opts.get("gffUtil", findExe("nwn_gff", root))
    gffFlags = opts.get("gffFlags")
    gffFormat = opts.get("gffFormat", "json")

  # Set these so they can be gotten easily by the pack and install commands
  opts["file"] = target.file
  opts["directory"] = cacheDir

  display("Updating", "cache for target " & target.name)
  if opts.get("clean", false):
    removeDir(cacheDir)

  createDir(cacheDir)

  # Remove deleted files
  for file in walkFiles(cacheDir / "*"):
    let
      (_, name, ext) = file.splitFile
      fileName = if ext == ".ncs": name & ".nss" else: name & ext

    if fileName notin cacheMap:
      display("Removing", name & ext, priority = LowPriority)
      removeFile(file)

  # Copy newer files
  for fileName, srcFile in cacheMap.pairs:
    let
      cacheFile = cacheDir / fileName
      srcTime = srcFile.getLastModificationTime
      ext = srcFile.splitFile.ext.strip(chars = {'.'})

    if fileOlder(cacheFile, srcTime):
      if ext == gffFormat:
        if cmd != "compile":
          gffConvert(srcFile, cacheFile, gffUtil, gffFlags)
          setLastModificationTime(cacheFile, srcTime)
      elif cmd != "convert":
        display("Copying", srcFile & " -> " & fileName, priority = LowPriority)
        copyFile(srcFile, cacheFile)
        setLastModificationTime(cacheFile, srcTime)

        # Let compile() know this is a new or updated script
        if ext == "nss":
          pkg.updated.add(fileName)

  # Trim unused areas from the module.ifo
  if opts.get("removeUnusedAreas", true):
    removeUnusedAreas(cacheDir, gffUtil, gffFlags)

  # Prevent falling through to the next function if we were called directly
  return cmd != "convert"
