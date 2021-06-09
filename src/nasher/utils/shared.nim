import os, times, strtabs, tables, json
from sequtils import toSeq, deduplicate
from strutils import unindent, strip
from unicode import toLower
from sequtils import mapIt

when defined(Windows):
  import registry

from glob import walkGlob

import cli

proc help*(helpMessage: string, errorCode = QuitSuccess) =
  ## Quits with a formatted help message, sending errorCode
  quit(helpMessage.unindent(2), errorCode)

proc matchesAny*(s: string, patterns: seq[string]): bool =
  ## Returns whether ``s`` matches any glob pattern in ``patterns``.
  for pattern in patterns:
    if glob.matches(s, pattern):
      return true

iterator walkSourceFiles*(includes, excludes: seq[string]): string =
  ## Yields all files in the source tree matching include patterns while not
  ## matching exclude patterns.
  for pattern in includes:
    for file in glob.walkGlob(pattern):
      if not file.matchesAny(excludes):
        yield file

proc getSourceFiles*(includes, excludes: seq[string]): seq[string] =
  ## Returns all files in the source tree matching include patterns while not
  ## matching exclude patterns.
  toSeq(walkSourceFiles(includes, excludes)).deduplicate

proc getTimeDiff*(a, b: Time): int =
  ## Compares two times and returns the difference in seconds. If 0, the files
  ## are the same age. If positive, a is newer than b. If negative, b is newer
  ## than a.
  (a - b).inSeconds.int

proc getTimeDiffHint*(file: string, diff: int): string =
  ## Returns a message stating whether file a is newer than, older than, or the
  ## same age as file b, based on the value of diff.
  if diff > 0: file & " is newer than the existing file"
  elif diff < 0: file & " is older than the existing file"
  else: file & " is the same age as the existing file"

proc fileOlder*(file: string, time: Time): bool =
  ## Checks whether file is older than a time. Only checks seconds since copying
  ## modification times results in unequal nanoseconds.
  if fileExists(file):
    getTimeDiff(time, file.getLastModificationTime) > 0
  else: true

proc fileNewer*(file: string, time: Time): bool =
  if fileExists(file):
    getTimeDiff(time, file.getLastModificationTime) < 0
  else: false

proc getNwnHomeDir*: string =
  if existsEnv("NWN_HOME"):
    getEnv("NWN_HOME")
  else:
    when defined(Linux):
      getHomeDir() / ".local" / "share" / "Neverwinter Nights"
    else:
      getHomeDir() / "Documents" / "Neverwinter Nights"

proc getNwnRootDir*: string =
  if existsEnv("NWN_ROOT"):
    result = getEnv("NWN_ROOT")
    if dirExists(result / "data"):
      info("Located", "$NWN_ROOT at " & result)
      return result

  # Steam Install
  var path: string
  const steamPath = "Steam" / "steamapps" / "common" / "Neverwinter Nights"
  when defined(Linux):
    path = getHomeDir() / ".local" / "share" / steamPath
  elif defined(MacOSX):
    path = getHomeDir() / "Library" / "Application Support" / steamPath
  elif defined(Windows):
    path = getEnv("PROGRAMFILES(X86)") / steamPath
    if not dirExists(path / "data"):
      path = getUnicodeValue(r"SOFTWARE\WOW6432Node\Valve\Steam", "InstallPath", HKEY_LOCAL_MACHINE)
      path = path / "steamapps" / "common" / "Neverwinter Nights"
  else:
    raise newException(ValueError, "Could not locate NWN root: unsupported OS")
  if dirExists(path / "data"):
    info("Located", "Steam installation at " & path)
    return path

  # Beamdog Install
  # 00785: Stable
  # 00829: Development
  const
    settings = "Beamdog Client" / "settings.json"
    releases = ["00829", "00785"]

  when defined(Linux):
    let settingsFile = getConfigDir() / settings
  elif defined(MacOSX):
    let settingsFile = getHomeDir() / "Library" / "Application Support" / settings
  elif defined(Windows):
    let settingsFile = getHomeDir() / "AppData" / "Roaming" / settings
  else:
    raise newException(ValueError, "Could not locate NWN root: unsupported OS")
  if fileExists(settingsFile):
    let data = json.parseFile(settingsFile)
    doAssert(data.hasKey("folders"))
    doAssert(data["folders"].kind == JArray)

  for release in releases:
    for folder in data["folders"].getElems.mapIt(it.getStr / release):
      if dirExists(folder / "data"):
        info("Located", "Beamdog installation at " & folder)
        return folder

  # GOG Install
  when defined(Linux) or defined(MacOSX):
    path = getHomeDir() / "GOG Games" / "Neverwinter Nights Enhanced Edition"
  elif defined(Windows):
    path = getEnv("PROGRAMFILES(X86)") / "GOG Galaxy" / "Games" / "Neverwinter Nights Enhanced Edition"
    if not dirExists(path / "data"):
      path = getUnicodeValue(r"SOFTWARE\WOW6432Node\GOG.com\Games\1097893768", "path", HKEY_LOCAL_MACHINE)
  else:
    raise newException(ValueError, "Could not locate NWN root: unsupported OS")
  if dirExists(path / "data"):
    info("Located", "GOG installation at " & path)
    return path

  raise newException(ValueError,
    "Could not locate NWN root. Try setting the NWN_ROOT environment " &
    "variable to the path of your NWN installation.")


template withDir*(dir: string, body: untyped): untyped =
  let curDir = getCurrentDir()
  try:
    setCurrentDir(dir)
    body
  finally:
    setCurrentDir(curDir)

template withEnv*(envs: openarray[(string, string)], body: untyped): untyped =
  ## Executes ``body`` with all environment variables in ``envs``, then returns
  ## the environment variables to their previous values.
  var
    prevValues: seq[(string, string)]
    noValues: seq[string]
  for (name, value) in envs:
    if existsEnv(name):
      prevValues.add((name, getEnv(name)))
    else:
      noValues.add(name)
    putEnv(name, value)

  body

  for (name, value) in prevValues:
    putEnv(name, value)
  for name in noValues:
    delEnv(name)



proc findExe*(exe, baseDir: string): string =
  ## As findExe, but uses baseDir as the current directory.
  withDir(baseDir):
    findExe(exe)

proc getFileExt*(file: string): string =
  ## Returns the file extension without the leading "."
  file.splitFile.ext.strip(chars = {ExtSep})

proc normalizeFilename*(file: string): string =
  ## Converts ``file``'s filename to lowercase
  let (dir, fileName) = file.splitPath
  dir / fileName.toLower

proc expandPath*(path: string, keepUnknownKeys = false): string =
  ## Expands the tilde and any environment variables in ``path``. If
  ## ``keepUnknownKeys`` is ``true``, will leave unknown variables in place
  ## rather than replacing them with an empty string.
  let flags = {useEnvironment, if keepUnknownKeys: useKey else: useEmpty}
  result = `%`(path.expandTilde, newStringTable(modeCaseSensitive), flags)

proc outFile(srcFile: string): string =
  ## Returns the filename of the converted source file
  let (_, name, ext) = srcFile.splitFile
  if ext == ".json" or ext == ".nwnt": name
  else: name & ext


type
  FileMap* = Table[string, seq[string]]

proc outFiles*(srcFiles: seq[string]): FileMap =
  ## Returns a table mapping an output file with source files. Used to determine
  ## if there is more than one file in the target's source tree that can be used
  ## to generate the output file.
  for srcFile in srcFiles:
    let outFile = srcFile.outFile.normalizeFilename
    if result.hasKeyOrPut(outFile, @[srcFile]):
      result[outFile].add(srcFile)

