import tables, os, strformat, strutils, db_sqlite, times
from glob import walkGlob

import utils/[cli, sql, nwn, options, shared]

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
    db = fileName.getDB()
    fullDB = db.sqlRetrieveAllNames()
    sourceFiles = getSourceFiles(pkg.includes, pkg.excludes)
    srcMap = genSrcMap(sourceFiles)
    packTime = file.getLastModificationTime
    shortFile = file.extractFilename
    removeDeleted = opts.get("removeDeleted", false)
    askRemove = not opts.hasKey("removeDeleted")

  let
    gffUtil = opts.get("gffUtil")
    gffFlags = opts.get("gffFlags")
    gffFormat = opts.get("gffFormat", "json")

  ## Scans database and compares to sourceFiles. If file removed from
  ## Source, ask-remove from package before scanning.
  for fileName in fullDB:
    let
      ext = fileName.splitFile.ext.strip(chars = {'.'})
      dir = mapSrc(fileName, ext, srcMap, pkg.rules)

    var sourceName = dir / filename
    if ext in GffExtensions:
      sourceName.add("." & gffFormat)

    if sourceName notin sourceFiles and existsFile(tmpDir/fileName):
      if not askIf(fmt"{fileName} not found in source Directory. Should it be re-added?"):
        removeFile(tmpDir/fileName)
      ## Delete from sql whether yes or no, because if no we want it
      ## found and re-added via changedFiles
      db.sqlDelete(fileName)

  let changedFiles = db.getChangedFiles(tmpDir)

  if changedFiles.len > 0 and not
    askIf(fmt"{$changedFiles.len} new or updated files since {shortFile} " &
          "was packed. Continue?"):
      quit(QuitSuccess)

  ## Scans sourceFiles and removes if not in fresh mod unpack (I.E
  ## deleted in toolset)
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
        db.sqlDelete(fileName)
        file.removeFile

  var warnings = 0

  display("Converting", fmt"new or updated files")
  db.sqlBegin()
  for file in changedFiles:
    let
      ext = file.fileName.splitFile.ext.strip(chars = {'.'})
      filePath = tmpDir / file.filename
      dir = mapSrc(file.fileName, ext, srcMap, pkg.rules)

    if dir == "unknown":
      warning("cannot decide where to extract " & file.fileName)
      warnings.inc

    var outFile = dir / file.fileName
    if ext in GffExtensions:
      outFile.add("." & gffFormat)

    let outName = outFile.extractFilename

    if file.sqlSha1 != "":
      if (outFile.getLastModificationTime - file.sqlTime).inSeconds > 0 and not
          askIf(fmt"{outName} source file updated since last unpack. Overwrite?"):
        db.sqlUpdate(file.fileName, file.fileSha1, packTime)
        continue

    gffConvert(filePath, outFile, gffUtil, gffFlags)
    outFile.setLastModificationTime(packTime)
    db.sqlUpsert(file.fileName, file.fileSha1, packTime, file.sqlSha1)

  db.sqlCommit()

  if warnings > 0:
    let words =
      if warnings == 1: ["1", "file", "has", "this", "location"]
      else: [$warnings, "files", "have", "these", "locations"]

    warning(("$1 $2 could not be automatically extracted and $3 been placed " &
             "into \"unknown\". You will need to manually copy $4 $2 to the " &
             "correct $5.") % words)

  db.close()
