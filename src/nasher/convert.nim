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
$#
""" % ConvertOpts

proc convert*(opts: Options, target: Target, updatedNss: var seq[string]): bool =
  setCurrentDir(getPackageRoot())

  let
    cmd = opts["command"]
    cacheDir = ".nasher" / "cache" / target.name

  if opts.get("noConvert", false):
    return cmd != "convert"

  let
    category = if cmd.endsWith('e'): cmd[0..^2] & "ing" else:  cmd & "ing"
    gffUtil = opts.findBin("gffUtil", "nwn_gff", "gff utility")
    gffFlags = opts.get("gffFlags", "-p")
    gffFormat = opts.get("gffFormat", "json")
    tlkUtil = opts.findBin("tlkUtil", "nwn_tlk", "tlk utility")
    tlkFlags = opts.get("tlkFlags")
    tlkFormat = opts.get("tlkFormat", "json")
    multiSrcAction = opts.get("onMultipleSources", MultiSrcAction.None)

  display(category.capitalizeAscii, "target " & target.name)
  var outFiles: Table[string, seq[string]]
  for file in target.walkSourceFiles:
    let
      srcFile = file.normalizeFilename
      outFile = srcFile.outFile

    if file != srcFile:
      info("Renaming", fmt"{file} to {srcFile}")
      file.moveFile(srcFile)

    if outFiles.hasKeyOrPut(outFile, @[srcFile]):
      outFiles[outFile].add(srcFile)

  if outFiles.len == 0:
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
          chooseFile(cacheFile, inFiles, multiSrcAction)
        else:
          inFiles[0]

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
