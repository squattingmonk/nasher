import tables, os, strformat, strutils, times
from glob import walkGlob

import utils/[cli, nwn, options, shared]

const
  helpUnpack* = """
  Usage:
    nasher unpack [options] <file>

  Description:
    Unpacks <file> into the project source tree.

    Each extracted file is checked against the source tree (as defined in the
    [Package] section of the package config). If the file exists in one location,
    it is copied there, overwriting the existing file. If the file exists in
    multiple folders, you will be prompted to select where it should be copied.

    If the extracted file does not exist in the source tree already, it is checked
    against each pattern listed in the [Rules] section of the package config. If
    a match is found, the file is copied to that location.

    If, after checking the source tree and rules, a suitable location has not been
    found, the file is copied into a folder in the project root called "unknown"
    so you can manually move it later.

    If an unpacked source would overwrite an existing source, you will be prompted
    to overwrite the file. The newly unpacked file will have a modification time
    less than or equal to the modification time of the file being unpacked. If the
    source file is newer than the existing file, the default is to overwrite the
    existing file.

  Options:
    --yes, --no    Automatically answer yes/no to the overwrite prompt
    --default      Automatically accept the default answer to the overwrite prompt

  Global Options:
    -h, --help     Display help for nasher or one of its commands
    -v, --version  Display version information

  Logging:
    --debug        Enable debug logging
    --verbose      Enable additional messages about normal operation
    --quiet        Disable all logging except errors
    --no-color     Disable color output (automatic if not a tty)
  """

type
  SourceMap = Table[string, seq[string]]

proc fileNewer(file: string, time: Time): bool =
  ## Checks whether file is newer than time. Only checks seconds, since copying
  ## modification times results in unequal nanoseconds.
  (file.getLastModificationTime - time).inSeconds > 0

proc getNewerFiles(files: seq[string], time: Time): seq[string] =
  ## Compares time to the timestamp for each files in files. Displays a warning
  ## for each file that is newer than time, and returns thennewer files.
  for file in files:
    if file.fileNewer(time):
      warning(file & " has changed and may be overwritten.")
      result.add(file)

proc genSrcMap(files: seq[string]): SourceMap =
  ## Generates a table mapping unconverted source files to the proper directory.
  ## Each file has a sequence of locations (in case it exists in more than one
  ## directory).
  for file in files:
    let
      (dir, name, ext) = splitFile(file)
      fileName = if ext == ".json": name else: name.addFileExt(ext)
    if result.hasKeyOrPut(fileName, @[dir]):
      result[fileName].add(dir)

proc mapSrc(file, ext: string, srcMap: SourceMap, rules: seq[Rule]): string =
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
        result = dir % ["ext", ext]
        debug("Matched", file & " to pattern " & pattern.escape)
        break
  else:
    choices.add("unknown")
    result =
      choose(fmt"Cannot decide where to extract {file}. Please choose:",
             choices)

proc unpack*(opts: Options, pkg: PackageRef) =
  let
    file = opts.get("file").absolutePath
    dir = opts.get("directory", getCurrentDir())

  if file == "":
    help(helpUnpack)

  if not existsFile(file):
    fatal(fmt"Cannot unpack {file}: file does not exist")

  if not existsDir(dir):
    fatal("Cannot unpack to {dir}: directory does not exist.")

  if not loadPackageFile(pkg, getPackageFile(dir)):
    fatal(dir & " is not a nasher project. Please run nasher init.")

  let
    tmpDir = ".nasher" / "tmp"
    fileName = file.extractFilename
    erfUtil = opts.get("erfUtil")
    erfFlags = opts.get("erfFlags")

  display("Extracting", fmt"{fileName} to {dir}")
  setCurrentDir(dir)
  removeDir(tmpDir)
  createDir(tmpDir)

  withDir(tmpDir):
    extractErf(file, erfUtil, erfFlags)

  let
    sourceFiles = getSourceFiles(pkg.includes, pkg.excludes)
    srcMap = genSrcMap(sourceFiles)
    packTime = file.getLastModificationTime
    newerFiles = getNewerFiles(sourceFiles, packTime)
    shortFile = file.extractFilename
    removeDeleted = opts.get("removeDeleted", false)
    askRemove = not opts.hasKey("removeDeleted")

  if newerFiles.len > 0 and not
    askIf(fmt"{$newerFiles.len} files have changed since {shortFile} " &
          "was packed. These changes may be overwritten. Continue?"):
      quit(QuitSuccess)

  for file in sourceFiles:
    let
      (_, name, ext) = splitFile(file)
      fileName = if ext == ".json": name else: name.addFileExt(ext)

    if not existsFile(tmpDir / fileName) and
      (removeDeleted or
        (askRemove and
         askIf(fmt"{fileName} was not found in {shortFile}. " &
               fmt"Remove source file {file}?"))):
        info("Removing", "deleted file " & file)
        file.removeFile

  let
    gffUtil = opts.get("gffUtil")
    gffFlags = opts.get("gffFlags")
    gffFormat = opts.get("gffFormat", "json")

  var warnings = 0
  for file in walkFiles(tmpDir / "*"):
    let ext = file.splitFile.ext.strip(chars = {'.'})
    if ext == "ncs":
      continue

    let
      fileName = file.extractFilename
      dir = mapSrc(fileName, ext, srcMap, pkg.rules)

    if dir == "unknown":
      warning("cannot decide where to extract " & fileName)
      warnings.inc

    var outFile = dir / fileName
    if ext in GffExtensions:
      outFile.add("." & gffFormat)

    let outName = outFile.extractFilename
    if outFile in newerFiles and not
      askIf(fmt"Overwrite changed file {outName} with older version?"):
        continue

    gffConvert(file, outFile, gffUtil, gffFlags)
    outFile.setLastModificationTime(packTime)

  if warnings > 0:
    let words =
      if warnings == 1: ["1", "file", "has", "this", "location"]
      else: [$warnings, "files", "have", "these", "locations"]

    warning(("$1 $2 could not be automatically extracted and $3 been placed " &
             "into \"unknown\". You will need to manually copy $4 $2 to the " &
             "correct $5.") % words)
