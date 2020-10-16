import json, os, osproc, strformat, strutils, math
from sequtils import mapIt, toSeq

import cli, options

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

proc isValid(version: string): bool =
  # Returns true if the version number is plausible.
  let decomp = version.split('.')

  if decomp.len < 2 or decomp.len > 4:
    return false
  
  for section in decomp:
    try:
      discard section.parseUInt
      result = true
    except ValueError:
      return false

proc updateIfo*(dir, bin, args: string, opts: options.Options, target: options.Target) =
  ## Updates the areas listing in module.ifo, checks for matching .gic/.git files,          
  ## and sets module name and min version, if specified
  let
    fileGff = dir / "module.ifo"
    fileJson = fileGff & ".json"
    areas = toSeq(walkFiles(dir / "*.are")).mapIt(it.splitFile.name)
    gics = toSeq(walkFiles(dir / "*.gic")).mapIt(it.splitFile.name)
    gits = toSeq(walkFiles(dir / "*.git")).mapIt(it.splitFile.name)

  if not existsFile(fileGff):
    return

  var
    ifoJson = gffToJson(fileGff, bin, args)
    ifoAreas: seq[JsonNode]
    unmatchedAreas: seq[string]

  let
    entryArea = ifoJson["Mod_Entry_Area"]["value"].getStr
    moduleName =
      if opts.hasKey("modName"): opts.get("modName")
      else: target.modName
    moduleVersion =
      if opts.hasKey("modMinGameVersion"): opts.get("modMinGameVersion")
      else: target.modMinGameVersion

  # Area List update
  if entryArea notin areas:
    fatal("This module does not have a valid starting area!")

  if areas.len > 0:
    display("Updating", "area list")
    let plurality = (if areas.len > 1: "s" else: "")

    for area in areas:
      ifoAreas.add(%* {"__struct_id":6,"Area_Name":{"type":"resref","value":area}})

      if area notin gics or area notin gits:
        unmatchedAreas.add(area)

    if unmatchedAreas.len > 0:
      warning("The following do not have matching .gic or .git files and will not be accessible " &
        "in the toolset: " & unmatchedAreas.join(", "))

    ifoJson["Mod_Area_list"]["value"] = %ifoAreas
    success(fmt"area list updated --> {areas.len} area{plurality} listed")
  
  # Module Name Update
  if moduleName.len > 0 and moduleName != ifoJson["Mod_Name"]["value"]["0"].getStr:
    ifoJson["Mod_Name"]["value"]["0"] = %moduleName
    success("module name set to " & moduleName)

  # Module Min Game Version Update
  if moduleVersion.isValid:
    let currentVersion = ifoJson["Mod_MinGameVer"]["value"].getStr

    if moduleVersion == currentVersion:
      display("Version:", fmt"current module min game version is '{currentVersion}', no change required")
    else:
      if askIf(fmt"Changing the module's min game version to '{moduleVersion}' could have unintended consequences.  Continue?"):
        ifoJson["Mod_MinGameVer"]["value"] = %moduleVersion
        success("module min game version set to " & moduleVersion)
  else:
    error(fmt"requested min game version '{moduleVersion}' is not valid")
    
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
