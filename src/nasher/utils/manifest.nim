import json, os, times, std/sha1

import cli

type
  FileDetail = tuple[fileName, fileSum, savedSum: string, savedTime: Time]

  Manifest = object
    file: string
    data: JsonNode

proc newManifest*(file: string): Manifest =
  Manifest(file: file, data: %* {})

proc read*(manifest: var Manifest) =
  let
    path = getCurrentDir() / ".nasher" / manifest.file & ".json"

  try:
    manifest.data = path.parseFile()
  except IOError:
    manifest.data = %* {}

proc write*(manifest: Manifest) =
  let
    path = getCurrentDir() / ".nasher" / manifest.file & ".json"

  try:
    createDir(getCurrentDir() / ".nasher")
    path.writeFile(manifest.data.pretty)
  except:
    fatal("Could not write to manifest file " & path)

proc parseManifest*(file: string): Manifest =
  result = newManifest(file)
  result.read

proc parseTime(time: string): Time =
  if time == "":
    fromUnix(0)
  else:
    try:
      time.parseTime("yyyy-MM-dd\'T\'HH:mm:sszzz", now().timezone)
    except:
      error("Could not parse timestamp " & time)
      fromUnix(0)

proc getFilesChanged*(manifest: Manifest, srcFile, outFile: string): bool =
  ## Returns whether either srcFile or outFile have changed in the manifest
  let fileName = outFile.extractFilename

  if not existsFile(outFile) or not manifest.data.hasKey(fileName):
    return true

  return (manifest.data{fileName, "srcSum"}.getStr != $srcFile.secureHashFile or
          manifest.data{fileName, "outSum"}.getStr != $outFile.secureHashFile)

proc getChangedFiles*(manifest: Manifest, dir = getCurrentDir()): seq[FileDetail] =
  info("Checking", "changed files")
  for file in walkFiles(dir / "*"):
    if file.splitFile.ext == ".ncs":
      continue

    let
      fileName = file.extractFilename
      fileSum = $file.secureHashFile
      savedSum = manifest.data{fileName, "sha1"}.getStr
      savedTime = manifest.data{fileName, "modified"}.getStr.parseTime

    if fileSum == savedSum:
      info("Skipping", "unchanged file " & fileName)
      continue

    result.add((fileName, fileSum, savedSum, savedTime))

proc update*(manifest: var Manifest, fileName, fileSum: string, fileTime: Time) =
  manifest.data[fileName] = %* {"sha1": fileSum, "modified": $fileTime}

proc add*(manifest: var Manifest, file: string, fileTime: Time) =
  manifest.update(file.extractFilename, $file.secureHashFile, fileTime)

proc add*(manifest: var Manifest, srcFile, outFile: string) =
  let
    fileName = outFile.extractFilename
    srcSum = $srcFile.secureHashFile
    outSum = $outFile.secureHashFile
  manifest.data[fileName] = %* {"srcSum": srcSum, "outSum": outSum}

proc delete*(manifest: var Manifest, file: string) =
  if manifest.data.hasKey(file):
    manifest.data.delete(file)

iterator keys*(manifest: Manifest): string =
  for key in manifest.data.keys:
    yield key
