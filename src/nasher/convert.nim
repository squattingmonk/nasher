import os, strtabs, strutils, strformat, sequtils
import utils/[cli, manifest, nwn, options, shared]

const
  helpConvert* = """
  Usage:
    nasher convert [options] [<target>...]

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

proc outFile(srcFile: string): string =
  ## Returns the filename of the converted source file
  let (_, name, ext) = srcFile.splitFile
  if ext == ".json": name else: name & ext

proc convert*(opts: Options, pkg: PackageRef): bool =
  setCurrentDir(getPackageRoot())

  let
    cmd = opts["command"]
    target = pkg.getTarget(opts["target"])
    cacheDir = ".nasher" / "cache" / target.name

  # Set these so they can be gotten easily by the pack and install commands
  opts["file"] = target.file
  opts["directory"] = cacheDir

  if opts.get("noConvert", false):
    return cmd != "convert"

  let
    category = (if cmd == "compile": "compiling" else: cmd & "ing")
    gffUtil = opts.get("gffUtil")
    gffFlags = opts.get("gffFlags")
    gffFormat = opts.get("gffFormat", "json")
    tlkUtil = opts.get("tlkUtil")
    tlkFlags = opts.get("tlkFlags")
    tlkFormat = opts.get("tlkFormat", "json")
    srcFiles = getSourceFiles(target.includes, target.excludes)
    outFiles = srcFiles.map(outFile)

  display(category.capitalizeAscii, "target " & target.name)
  if srcFiles.len == 0:
    error("No source files found for target " & target.name)
    return false

  display("Updating", "cache for target " & target.name)
  if opts.get("clean", false):
    removeDir(cacheDir)
    removeFile(cacheDir & ".json")

  createDir(cacheDir)

  # We use a separate manifest from the one used for packing and unpacking
  # because the user may convert or compile without packing or unpacking. This
  # manifest will contain the sha1 of the source file and the out file.
  var manifest = parseManifest("cache" / target.name)

  # Remove deleted files from the cache
  for file in walkFiles(cacheDir / "*"):
    let
      (_, name, ext) = file.splitFile
      fileName =
        case ext
        of ".ncs", ".ndb":
          name & ".nss"
        else:
          name & ext

    if fileName.extractFilename notin outFiles:
      info("Removing", name & ext)
      file.removeFile

  # Copy newer files
  for file in srcFiles:
    # Ensure filenames are lowercase before converting to avoid collisions
    let
      srcFile = file.normalizeFilename
      outFile = cacheDir / srcFile.outFile

    if file != srcFile:
      info("Renaming", fmt"{file.extractFilename} to {srcFile.extractFilename}")
      file.moveFile(srcFile)

    if manifest.getFilesChanged(srcFile, outFile):
      let
        srcExt = srcFile.getFileExt
        fileName = outFile.extractFilename

      if srcExt in [gffFormat, tlkFormat]:
        if cmd == "compile":
          continue

        if fileName.getFileExt == "tlk":
          gffConvert(srcFile, outFile, tlkUtil, tlkFlags)
        else:
          gffConvert(srcFile, outFile, gffUtil, gffFlags)
      else:
        info("Copying", srcFile & " -> " & fileName)
        copyFile(srcFile, outFile)

        # Let compile() know this is a new or updated script
        if cmd != "convert" and srcExt == "nss":
          removeFile(outfile.changeFileExt("ncs"))
          pkg.updated.add(fileName)

      manifest.add(srcFile, outFile)

  manifest.write
  
  # Update the module's .ifo file
  if cmd != "compile":
    updateIfo(cacheDir, gffUtil, gffFlags, opts, target)

  # Prevent falling through to the next function if we were called directly
  return cmd != "convert"
