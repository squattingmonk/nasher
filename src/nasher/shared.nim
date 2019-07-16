import os, strtabs, strutils, times

from glob import walkGlob

type
  Options* = StringTableRef
  CommandResult* = tuple[output: TaintedString, exitCode: int]

proc get*[T](opts: Options, name: string, default: T = ""): T =
  ## Returns a value or type T from opts using name as the key. If not present,
  ## returns default.
  if opts.contains(name):
    let value = opts[name]
    when T is bool: (value == "" or value.parseBool)
    elif T is int: value.parseInt
    elif T is string: value
    else: doAssert(false)
  else: default

proc getBool*(opts: Options, name: string, default = false): bool =
  opts.get(name, default)

proc help*(helpMessage: string, errorcode = QuitSuccess) =
  ## Quits, with a formatted help message
  quit(helpMessage.unindent(2), errorcode)

iterator walkSourceFiles*(sources: seq[string]): string =
  for source in sources:
    for file in glob.walkGlob(source):
      yield file

proc getTimeDiff*(a, b: Time): int =
  ## Compares two times and returns the difference in seconds. If 0, the files
  ## are the same age. If positive, a is newer than b. If negative, b is newer
  ## than a.
  (a - b).inSeconds.int

proc getTimeDiffHint*(a, b: string, diff: int): string =
  ## Returns a message stating whether file a is newer than, older than, or the
  ## same age as file b, based on the value of diff.
  if diff > 0: a & " is newer than " & b
  elif diff < 0: a & " is older than " & b
  else: a & " is the same age as " & b

proc fileOlder*(file: string, time: Time): bool =
  ## Checks whether file is older than a time. Only checks seconds since copying
  ## modification times results in unequal nanoseconds.
  if existsFile(file):
    getTimeDiff(time, file.getLastModificationTime) > 0
  else: true

proc fileNewer*(file: string, time: Time): bool =
  if existsFile(file):
    getTimeDiff(time, file.getLastModificationTime) < 0
  else: false

proc getPkgRoot*(baseDir = getCurrentDir()): string =
  ## Returns the first parent of baseDir that contains a nasher config
  result = baseDir.absolutePath()

  for dir in parentDirs(result):
    if existsFile(dir / "nasher.cfg"):
      return dir

proc getGlobalCfgFile*: string =
  getConfigDir() / "nasher" / "nasher.cfg"

proc getPkgCfgFile*(baseDir = getCurrentDir()): string =
  getPkgRoot(baseDir) / "nasher.cfg"

proc getCacheDir*(file: string, baseDir = getCurrentDir()): string =
  getPkgRoot(baseDir) / ".nasher" / "cache" / file.extractFilename()

proc getBuildDir*(build: string, baseDir = getCurrentDir()): string =
  getPkgRoot(baseDir) / ".nasher" / "build" / build

proc isNasherProject*(dir = getCurrentDir()): bool =
  existsFile(getPkgCfgFile(dir))

proc getNwnInstallDir*: string =
  when defined(Linux):
    getHomeDir() / ".local" / "share" / "Neverwinter Nights"
  else:
    getHomeDir() / "Documents" / "Neverwinter Nights"

template withDir*(dir: string, body: untyped): untyped =
  let curDir = getCurrentDir()
  try:
    setCurrentDir(dir)
    body
  finally:
    setCurrentDir(curDir)

