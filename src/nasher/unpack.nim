import tables, os, strformat, strutils, times
from glob import walkGlob

import utils/[cli, compiler, nwn, options, shared]

const
  helpUnpack = """
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

proc getSrcFiles(sources: seq[string]): seq[string] =
  ## Walks all source patterns in sources and returns the matching files
  for source in sources:
    debug("Walking", "pattern " & source)
    for path in glob.walkGlob(source):
      debug("Found", path)
      result.add(path)

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

template confirmOverwriteNewer(
  path: string, newerFiles: seq[string], time: Time, statements: untyped) =
  if path in newerFiles:
    let fileName = path.extractFilename
    if not askIf(fmt"Overwrite changed file {fileName} with older version?"):
      continue
  statements
  path.setLastModificationTime(time)

proc unpack*(opts: Options, pkg: PackageRef) =
  let
    file = opts.getOrDefault("file").absolutePath
    dir = opts.getOrDefault("directory", getCurrentDir())

  if opts.getBoolOrDefault("help") or file == "":
    help(helpUnpack)

  if not existsFile(file):
    fatal(fmt"Cannot unpack {file}: file does not exist")

  if not existsDir(dir):
    fatal("Cannot unpack to {dir}: directory does not exist.")

  if not loadPackageFile(pkg, getPackageFile(dir)):
    fatal("This is not a nasher project. Please run nasher init.")

  let
    tmpDir = ".nasher" / "tmp"
    fileName = file.extractFilename

  display("Extracting", fmt"{fileName} to {dir}")
  setCurrentDir(dir)
  removeDir(tmpDir)
  createDir(tmpDir)
  extractErf(file, tmpDir)

  let
    sourceFiles = getSrcFiles(pkg.sources)
    srcMap = genSrcMap(sourceFiles)
    packTime = file.getLastModificationTime
    newerFiles = getNewerFiles(sourceFiles, packTime)

  if newerFiles.len > 0:
    let shortFile = file.extractFilename
    if not askIf(fmt"{$newerFiles.len} files have changed since {shortFile} " &
                 "was packed. These changes may be overwritten. Continue?"):
      quit(QuitSuccess)

  var warnings = 0
  for file in walkFiles(tmpDir / "*"):
    let ext = file.splitFile.ext.strip(chars = {'.'})
    if ext == "ncs":
      continue

    let
      fileName = file.extractFilename
      relPath = file.relativePath(tmpDir)
      dir = mapSrc(fileName, ext, srcMap, pkg.rules)

    if dir == "unknown":
      warning("cannot decide where to extract " & fileName)
      warnings.inc
    createDir(dir)

    if ext in GffExtensions:
      confirmOverwriteNewer(dir / fileName & ".json", newerFiles, packTime):
        gffConvert(file, dir)
    else:
      confirmOverwriteNewer(dir / fileName, newerFiles, packTime):
        display("Copying", relPath & " -> " & dir / fileName,
                priority = LowPriority)
        copyFile(file, dir / fileName)

  if warnings > 0:
    let words =
      if warnings == 1: ["1", "file", "has", "this", "location"]
      else: [$warnings, "files", "have", "these", "locations"]

    warning(("$1 $2 could not be automatically extracted and $3 been placed " &
             "into \"unknown\". You will need to manually copy $4 $2 to the " &
             "correct $5.") % words)
