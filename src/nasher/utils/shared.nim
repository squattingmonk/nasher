import os, times, strtabs
from sequtils import toSeq
from strutils import unindent, strip
from unicode import toLower

from glob import walkGlob

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
  toSeq(walkSourceFiles(includes, excludes))

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
  if existsFile(file):
    getTimeDiff(time, file.getLastModificationTime) > 0
  else: true

proc fileNewer*(file: string, time: Time): bool =
  if existsFile(file):
    getTimeDiff(time, file.getLastModificationTime) < 0
  else: false

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
