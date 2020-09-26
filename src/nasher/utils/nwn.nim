import json, os, osproc, strformat, strutils, math
from sequtils import mapIt, toSeq

import cli

const
  Options = {poUsePath, poStdErrToStdOut}

  GffExtensions* = @[
    "utc", "utd", "ute", "uti", "utm", "utp", "uts", "utt", "utw",
    "git", "are", "gic", "mod", "ifo", "fac", "dlg", "itp", "bic",
    "jrl", "gff", "gui"
  ]

proc truncateFloats(j: var JsonNode, precision: range[1..32] = 4, bearing: bool = false) =
  case j.kind
  of JObject:
    for k, v in j.mpairs:
      if(k == "Bearing"):
        v.truncateFloats(precision, true)
      else:
        v.truncateFloats(precision, bearing)
  of JArray:
    for e in j.mitems:
      e.truncateFloats(precision, bearing)
  of JFloat:
    var f = j.getFloat.formatFloat(ffDecimal, precision)
    f.trimZeros
    if {'.', 'e'} notin f:
      f.add(".0")
    j = newJFloat(
      if bearing and f == formatFloat(-PI, ffDecimal, precision):
        f.parseFloat.abs
      else: f.parseFloat)
  else:
    discard

proc gffToJson(file, bin, args: string, precision: range[1..32] = 4): JsonNode =
  ## Converts ``file`` to json, stripping the module ID if ``file`` is
  ## module.ifo.
  let
    cmd = join([bin, args, "-i", file.escape, "-k json -p"], " ")
    (output, errCode) = execCmdEx(cmd, Options)

  if errCode != 0:
    fatal(fmt"Could not parse {file}: {output}")

  result = output.parseJson

  result.truncateFloats(precision)

  if file.extractFilename == "module.ifo" and result.hasKey("Mod_ID"):
    result.delete("Mod_ID")
  elif file.splitFile.ext == ".are" and result.hasKey("Version"):
    result.delete("Version")

proc convertFile(inFile, outFile, bin, args: string) =
  ## Converts a ``inFile`` to ``outFile``.
  let
    cmd = join([bin, args, "-i", inFile.escape, "-o", outFile.escape], " ")
    (output, errCode) = execCmdEx(cmd, Options)

  if errCode != 0:
    fatal(fmt"Could not convert {inFile}: {output}")

proc gffConvert*(inFile, outFile, bin, args: string, precision: range[1..32] = 4) =
  ## Converts ``inFile`` to ``outFile``
  let
    (dir, name, ext) = outFile.splitFile
    fileType = ext.strip(chars = {'.'})
    outFormat = if fileType in GffExtensions: "gff" else: fileType
    category = if outFormat in ["json", "gff", "tlk"]: "Converting" else: "Copying"

  info(category, "$1 -> $2" % [inFile.extractFilename, name & ext])

  try:
    createDir(dir)
  except OSError:
    let msg = osErrorMsg(osLastError())
    fatal(fmt"Could not create {dir}: {msg}")
  except:
    fatal(getCurrentExceptionMsg())

  ## TODO: Add gron and yaml support
  try:
    case outFormat
    of "json":
      if inFile.splitFile.ext == ".tlk":
        convertFile(inFile, outFile, bin, args & " -p")
      else:
        let text = gffToJson(inFile, bin, args, precision).pretty & "\c\L"
        writeFile(outFile, text)
    of "gff", "tlk":
      convertFile(inFile, outFile, bin, args)
    else:
      copyFile(inFile, outFile)
  except:
    fatal(fmt"Could not create {outFile}:\n" & getCurrentExceptionMsg())

proc removeUnusedAreas*(dir, bin, args: string) =
  ## Removes any areas not in ``dir`` from the module.ifo file in ``dir``.
  let
    fileGff = dir / "module.ifo"
    fileJson = fileGff & ".json"
    areas = toSeq(walkFiles(dir / "*.are")).mapIt(it.splitFile.name)

  if not existsFile(fileGff):
    return

  var
    ifoJson = gffToJson(fileGff, bin, args)
    ifoAreas: seq[JsonNode]

  let
    entryArea = ifoJson["Mod_Entry_Area"]["value"].getStr

  if entryArea notin areas:
    fatal("This module does not have a valid starting area!")

  for key, value in ifoJson["Mod_Area_list"]["value"].getElems.pairs:
    let area = value["Area_Name"]["value"].getStr
    if area in areas:
      ifoAreas.add(value)
    else:
      info("Removing", fmt"unused area {area.escape} from module.ifo")

  ifoJson["Mod_Area_list"]["value"] = %ifoAreas
  writeFile(fileJson, $ifoJson)
  convertFile(fileJson, fileGff, bin, args)
  removeFile(fileJson)

proc extractErf*(file, bin, args: string) =
  ## Extracts the erf ``file`` into the current directory.
  let
    cmd = join([bin, args, "-x -f", file.escape], " ")
    (output, errCode) = execCmdEx(cmd, Options)

  if errCode != 0:
    fatal(fmt"Could not extract {file}: {output}")

proc createErf*(dir, outFile, bin, args: string) =
  ## Creates an erf file at ``outFile`` from all files in ``dir``, passing
  ## ``args`` to the ``nwn_erf`` utiltity.
  let
    cmd = join([bin, args, "-c -f", outFile.escape, dir], " ")
    (output, errCode) = execCmdEx(cmd, Options)

  if errCode != 0:
    fatal(fmt"Could not pack {outFile}: {output}")
