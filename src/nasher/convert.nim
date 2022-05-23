import os, strtabs, strutils, strformat, tables
import utils/[manifest, nwn, shared]

const helpConvert* = """
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
  --branch:<branch>  Selects git branch before operation
"""

proc convert*(opts: Options, target: Target, updatedNss: var seq[string]): bool =
  setCurrentDir(getPackageRoot())

  let
    cmd = opts["command"]
    cacheDir = ".nasher" / "cache" / target.name

  if opts.get("noConvert", false):
    return cmd != "convert"

  let
    multiSrcChoices = ["choose", "default", "error"]
    multiSrcAction = opts.get("onMultipleSources", multiSrcChoices[0])
  if multiSrcAction notin multiSrcChoices:
    fatal("--onMultipleSources must be one of [$#]" % join(multiSrcChoices, ", "))

  let
    category = if cmd.endsWith('e'): cmd[0..^2] & "ing" else:  cmd & "ing"
    gffUtil = opts.findBin("gffUtil", "nwn_gff", "gff utility")
    gffFlags = opts.get("gffFlags", "-p")
    gffFormat = opts.get("gffFormat", "json")
    tlkUtil = opts.findBin("tlkUtil", "nwn_tlk", "tlk utility")
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

    var srcFile = inFiles[0]
    if inFiles.len > 1:
      case multiSrcAction
      of "error":
        fatal("Multiple sources found for $1:\n$2" % [cacheFile, join(inFiles, "\n")])
      of "choose":
        srcFile = choose(fmt"Multiple sources found for {cacheFile}. " &
                    "Which one do you wish to use?", inFiles)
      of "default": discard
      else: assert false

    let outFile = cacheDir / cacheFile
    if manifest.getFilesChanged(srcFile, outFile):
      let
        srcExt = srcFile.getFileExt
        fileName = outFile.extractFilename

      if srcExt in ["json", "nwnt", tlkFormat]:
        if cmd == "compile":
          continue

        info("Converting", fmt"{srcFile} -> {fileName}")
        if srcExt == "nwnt":
          nwntToGff(srcFile, outFile)
        elif fileName.getFileExt == "tlk":
          convertFile(srcFile, outFile, tlkUtil, tlkFlags)
        else:
          jsonToGff(srcFile, outFile, gffUtil, gffFlags)
      else:
        info("Copying", srcFile & " -> " & fileName)
        copyFile(srcFile, outFile)

        # Let compile() know this is a new or updated script
        if cmd != "convert" and srcExt == "nss":
          removeFile(outfile.changeFileExt("ncs"))
          updatedNss.add(fileName)

      manifest.add(srcFile, outFile)

  manifest.write

  # Update the module's .ifo file
  if cmd != "compile":
    updateIfo(cacheDir, opts, target)

  # Prevent falling through to the next function if we were called directly
  return cmd != "convert"
