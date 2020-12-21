import os, strtabs, strutils, strformat, tables
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
    --clean            Clears the cache directory before converting
    --branch:<branch>  Selects git branch before operation.

  Global Options:
    -h, --help     Display help for nasher or one of its commands
    -v, --version  Display version information

  Logging:
    --debug        Enable debug logging
    --verbose      Enable additional messages about normal operation
    --quiet        Disable all logging except errors
    --no-color     Disable color output (automatic if not a tty)
  """

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
    outFiles = srcFiles.outFiles

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

    if not outFiles.hasKey(fileName.extractFilename):
      info("Removing", name & ext)
      file.removeFile

  # Copy newer files
  for cacheFile, inFiles in outFiles.pairs:
    assert inFiles.len > 0

    let
      outFile = cacheDir / cacheFile
      srcFile =
        if inFiles.len > 1:
          choose(fmt"Multiple sources found for {outFile}. " &
                 "Which one do you wish to use?", inFiles)
        else:
          inFiles[0]

    if manifest.getFilesChanged(srcFile, outFile):
      let
        srcExt = srcFile.getFileExt
        fileName = outFile.extractFilename

      if srcExt in ["json", "nwnt", tlkFormat]:
        if cmd == "compile":
          continue

        if fileName.getFileExt == "tlk":
          info("Converting", fmt"{srcFile} -> {fileName}")
          convertFile(srcFile, outFile, tlkUtil, tlkFlags)
        else:
          info("Converting", fmt"{srcFile} -> {fileName}")
          srcFile.toGFF(outFile)
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
    updateIfo(cacheDir, opts, target)

  # Prevent falling through to the next function if we were called directly
  return cmd != "convert"
