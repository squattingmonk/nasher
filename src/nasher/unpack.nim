import tables, os, strformat, strutils, times
from glob import walkGlob

import utils/[cli, git, manifest, nwn, options, shared]

const
  helpUnpack* = """
  Usage:
    nasher unpack [options] [<target> [<file>]]

  Description:
    Unpacks a file into the project source tree for the given target.

    If a target is not specified, the first target found in nasher.cfg is used. If
    a file is not specified, will search for the target's file in the NWN install
    directory.

    Each extracted file is checked against the target's source tree (as defined in
    the [Target] section of the package config). If the file only exists in one
    location, it is copied there, overwriting the existing file. If the file
    exists in multiple folders, you will be prompted to select where it should be
    copied.

    If the extracted file does not exist in the source tree already, it is checked
    against each pattern listed in the [Rules] section of the package config. If
    a match is found, the file is copied to that location.

    If, after checking the source tree and rules, a suitable location has not been
    found, the file is copied into a folder in the project root called "unknown"
    so you can manually move it later.

    If an unpacked source would overwrite an existing source, its sha1 checksum is
    against that from the last pack/unpack operation. If the sum is different, the
    file has changed. If the source file has not been updated since the last pack
    or unpack, the source file will be overwritten by the unpacked file. Otherwise
    you will be prompted to overwrite the source file. The default answer is to
    keep the existing source file.

  Options:
    --file:<file>  A file to unpack into the target's source tree. Only needed if
                   not specifying the target and not using the default target's
                   output file.
    --yes, --no    Automatically answer yes/no to the overwrite prompt
    --default      Automatically accept the default answer to the overwrite prompt
    --branch       Place files into specified vcs branch

  Global Options:
    -h, --help     Display help for nasher or one of its commands
    -v, --version  Display version information

  Logging:
    --debug        Enable debug logging
    --verbose      Enable additional messages about normal operation
    --quiet        Disable all logging except errors
    --no-color     Disable color output (automatic if not a tty)
  """

proc genSrcMap(files: seq[string]): FileMap =
  ## Generates a table mapping unconverted source files to the proper directory.
  ## Each file has a sequence of locations (in case it exists in more than one
  ## directory).
  for file in files:
    let
      (dir, name, ext) = splitFile(file)
      fileName = if ext in [".json", ".nwnt"]: name else: name.addFileExt(ext)
    if result.hasKeyOrPut(fileName, @[dir]):
      result[fileName].add(dir)

proc mapSrc(file, ext, target: string, srcMap: FileMap, rules: seq[Rule]): string =
  ## Maps a file to the proper directory, first searching existing source files
  ## and then matching it to each pattern in rules. Returns the directory.
  var choices = srcMap.getOrDefault(file)
  case choices.len
  of 1:
    result = choices[0]
  of 0:
    result = "unknown"
    for pattern, dir in rules.items:
      if glob.matches(file, pattern):
        result = dir % ["ext", ext, "target", target]
        debug("Matched", file & " to pattern " & pattern.escape)
        break
  else:
    choices.add("unknown")
    result =
      choose(fmt"Cannot decide where to extract {file}. Please choose:",
             choices)

proc unpack*(opts: Options, target: Target) =
  let
    dir = opts.get("directory", getPackageRoot())
    precision = opts.get("truncateFloats", 4)

  if precision notin 1..32:
    fatal("Invalid value: --truncateFloats must be between 1 and 32")

  if not dirExists(dir):
    fatal("Cannot unpack to {dir}: directory does not exist.")

  # If the user has specified a file to unpack, use that. Otherwise, look for
  # the installed target file.
  let
    installDir = opts.get("installDir", getEnv("NWN_HOME")).expandPath
    file =
      if opts.hasKey("file"): opts.get("file").expandPath.absolutePath
      else:
        let fileName = target.file.extractFilename
        case target.file.getFileExt
        of "mod": installDir / "modules" / fileName
        of "erf": installDir / "erf" / fileName
        of "hak": installDir / "hak" / fileName
        of "tlk": installDir / "tlk" / fileName
        else: dir / target.file
    branch = opts.get("branch", target.branch)

  if file == "":
    help(helpUnpack)

  if not dirExists(file) and not fileExists(file):
    fatal(fmt"Cannot unpack {file}: file does not exist")

  # If requested, set a specific vcs branch
  if branch.len > 0:
    display("VCS Branch", gitSetBranch(dir, branch))

  let
    fileType = file.getFileExt
    (_, name, ext) = file.splitFile
    shortFile = file.extractFilename
    erfUtil = opts.get("erfUtil")
    erfFlags = opts.get("erfFlags")
    useFolder =
      ext == ".mod" and
      opts.get("useModuleFolder", not opts.hasKey("file"))

  var
    tmpDir = ".nasher" / "tmp"

  display("Extracting", fmt"{shortFile} to {dir} using target {target.name}")
  setCurrentDir(dir)

  if useFolder:
    tmpDir = installDir / "modules" / name

    info("Using", "module folder at " & tmpDir)
    if not dirExists(tmpDir):
      createDir(tmpDir)
      withDir(tmpDir):
        extractErf(file, erfUtil, erfFlags)
  elif dirExists(file):
    tmpDir = file
  else:
    removeDir(tmpDir)
    createDir(tmpDir)
    withDir(tmpDir):
      if fileType == "tlk":
        copyFile(file, shortFile)
      else:
        extractErf(file, erfUtil, erfFlags)

  # Ensure all files are converted to lowercase to avoid collisions
  for file in walkFiles(tmpDir / "*"):
    let fileLower = file.normalizeFilename

    if file != fileLower:
      info("Renaming", fmt"{file.extractFilename} to {fileLower.extractFilename}")
      file.moveFile(fileLower)

  var
    manifest = parseManifest(target.name)
    deleted: seq[string] = @[]

  let
    sourceFiles = getSourceFiles(target.includes, target.excludes)
    srcMap = genSrcMap(sourceFiles)
    packTime = file.getLastModificationTime
    removeDeleted = opts.get("removeDeleted", false)
    askRemove = not opts.hasKey("removeDeleted")

  let
    gffUtil = opts.get("gffUtil")
    gffFlags = opts.get("gffFlags")
    gffFormat = opts.get("gffFormat", "json")
    tlkUtil = opts.get("tlkUtil")
    tlkFlags = opts.get("tlkFlags")
    tlkFormat = opts.get("tlkFormat", "json")

  # Scan manifest and compare to sourceFiles. If a file was removed from the
  # source tree, ask-remove from package before scanning.
  for fileName in manifest.keys:
    let
      ext = fileName.getFileExt
      dir = mapSrc(fileName, ext, target.name, srcMap, target.rules)

    var sourceName = dir / filename
    if ext in GffExtensions:
      sourceName.add("." & gffFormat)
    elif ext == "tlk":
      sourceName.add("." & tlkFormat)

    if sourceName notin sourceFiles and fileExists(tmpDir / fileName):
      if not askIf(fmt"{fileName} not found in source directory. Should it be re-added?"):
        if not useFolder:
          removeFile(tmpDir / fileName)

      # Delete from manifest whether yes or no, because if no we want it found
      # and re-added via changedFiles
      deleted.add(fileName)

  for fileName in deleted:
    manifest.delete(fileName)

  # Scan sourceFiles and remove if not in fresh mod unpack (i.e., deleted
  # deleted in toolset)
  info("Checking", "for deleted files")
  for file in sourceFiles:
    let
      (_, name, ext) = splitFile(file)
      fileName = if ext in [".json", ".nwnt"]: name else: name.addFileExt(ext)

    if not fileExists(tmpDir / fileName) and
      (removeDeleted or
        (askRemove and
         askIf(fmt"{fileName} was not found in {shortFile}. " &
               fmt"Remove source file {file}?"))):
           info("Removing", "deleted file " & file)
           manifest.delete(fileName)
           file.removeFile

  var warnings = 0

  let
    changedFiles = manifest.getChangedFiles(tmpDir)

  display("Converting", fmt"{changedFiles.len} new or updated files")
  for file in changedFiles:
    debug("Checking", file.fileName)

    let
      ext = file.fileName.getFileExt
      filePath = tmpDir / file.fileName
      dir = mapSrc(file.fileName, ext, target.name, srcMap, target.rules)

    if dir == "unknown":
      warning("cannot decide where to extract " & file.fileName)
      warnings.inc
    elif dir == "/dev/null":
      info("Removing", file.fileName)
      filePath.removeFile
      continue

    var outFile = dir / file.fileName
    if ext.toLower in GffExtensions:
      outFile.add("." & gffFormat)
    elif ext.toLower == "tlk":
      outFile.add("." & tlkFormat)

    let outName = outFile.extractFilename

    if file.savedSum != "":
      if (outFile.getLastModificationTime - file.savedTime).inSeconds > 0 and not
          askIf(fmt"{outName} source file updated since last unpack. Overwrite?"):
            manifest.update(file.fileName, file.savedSum, packTime)
            continue

    if fileType == "tlk":
      info("Converting", fmt"{filePath} -> outFile")
      convertFile(filePath, outFile, tlkUtil, tlkFlags)
    elif file.fileName.getFileExt in GffExtensions:
      info("Converting", fmt"{filePath} -> outFile")
      case gffFormat
      of "json": gffToJson(filePath, outFile, gffUtil, gffFlags, precision)
      of "nwnt": gffToNwnt(filePath, outFile, precision)
      else: fatal(fmt"Unsupported output format: {gffFormat}")
    else:
      createDir(outFile.splitFile.dir)
      info("Copying", fmt"{filePath} -> outFile")
      copyFile(filePath, outFile)

    outFile.setLastModificationTime(packTime)
    manifest.update(file.fileName, file.fileSum, packTime)

  if warnings > 0:
    let words =
      if warnings == 1: ["1", "file", "has", "this", "location"]
      else: [$warnings, "files", "have", "these", "locations"]

    warning(("$1 $2 could not be automatically extracted and $3 been placed " &
             "into \"unknown\". You will need to manually copy $4 $2 to the " &
             "correct $5.") % words)

  manifest.write
