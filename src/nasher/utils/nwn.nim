import json, os, osproc, strformat, strutils, math, streams, tables
from sequtils import mapIt, toSeq

import neverwinter/gffjson, neverwinter/gff
from nwnt import toNwnt, gffRootFromNwnt

import cli, options
from shared import getFileExt

const
  Options = {poUsePath, poStdErrToStdOut}

  GffExtensions* = @[
    "utc", "utd", "ute", "uti", "utm", "utp", "uts", "utt", "utw", "git", "are",
    "gic", "ifo", "fac", "dlg", "itp", "bic", "jrl", "gff", "gui"
  ]

type
  FileTypeError* = object of CatchableError

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

proc postProcessJson(j: JsonNode) =
  ## Post-process json before emitting: We make sure to re-sort.
  if j.kind == JObject:
    for k, v in j.fields: postProcessJson(v)
    j.fields.sort do (a, b: auto) -> int: cmpIgnoreCase(a[0], b[0])
  elif j.kind == JArray:
    for e in j.elems: postProcessJson(e)

proc convertFile*(inFile, outFile, bin, args: string) =
  let
    inFileName = inFile.extractFilename
    outFileName = outFile.extractFilename
    cmd = join([bin, args, "-i", inFile.escape, "-o", outFile.escape], " ")
    (output, errCode) = execCmdEx(cmd, Options)

  if errCode != 0:
    fatal(fmt"Could not convert {inFileName} to {outFileName}: {output}")

proc createOutDir(file: string) =
  let dir = splitPath(file).head
  try:
    createDir(dir)
  except OSError:
    let msg = osErrorMsg(osLastError())
    fatal(fmt"Could not create {dir}: {msg}")
  except:
    fatal(getCurrentExceptionMsg())

proc toGff*(inFile, outFile: string) =
  ## Converts the nwnt or json source ``inFile`` into a gff ``outFile``.
  let
    inFormat = getFileExt(inFile)
    outFormat = getFileExt(outFile)

  try:
    if inFormat notin ["json", "nwnt"]:
      raise newException(FileTypeError, fmt"{inFormat} is not a supported source type")
    if outFormat notin GffExtensions:
      raise newException(FileTypeError, fmt"{outFormat} is not a valid gff filetype")

    createOutDir(outFile)

    let
      input = openFileStream(inFile)
      output = openFileStream(outFile, fmWrite)

    try:
      case inFormat
      of "nwnt":
        output.write(input.gffRootFromNwnt())
      of "json":
        output.write(input.parseJson(inFile).gffRootFromJson())
      else:
        assert false
    except:
      raise
    finally:
      input.close()
      output.close()
  except FileTypeError:
    raise
  except:
    let msg = getCurrentExceptionMsg()
    fatal(fmt"Could not convert {inFile} to {outFile.extractFilename}: {msg}")

proc fromGff*(inFile, outFile: string, precision: range[1..32] = 4) =
  ## Converts the gff file ``inFile`` to an nwnt or json ``outFile``. Any floats
  ## in the resulting data structure are truncated to ``precision`` places. This
  ## also strips the module ID (an unused field which nwn_gff has trouble
  ## read back) and any area version info (to reduce unnecessary diffs).
  let
    inFormat = getFileExt(inFile)
    outFormat = getFileExt(outFile)

  createOutDir(outFile)

  try:
    if inFormat notin GffExtensions:
      raise newException(FileTypeError, fmt"{inFormat} is not a valid gff filetype")
    if outFormat notin ["json", "nwnt"]:
      raise newException(FileTypeError, fmt"{outFormat} is not a supported source type")

    let
      input = openFileStream(inFile)
      output = openFileStream(outFile, fmWrite)
    var
      state = input.readGffRoot(false)

    if inFormat == "ifo" and state.hasField("Mod_ID", GffVoid):
      state.del("Mod_ID")
    elif inFormat == "are" and state.hasField("Version", GffDword):
      state.del("Version")

    try:
      case outFormat
      of "nwnt":
        output.toNwnt(state, precision) # does writeFile in-proc
      of "json":
        var j = state.toJson()
        j.postProcessJson()
        j.truncateFloats(precision)
        output.write(j.pretty() & "\c\L")
      else:
        assert false
    except:
      raise
    finally:
      input.close()
      output.close()
  except FileTypeError:
    raise
  except:
    let msg = getCurrentExceptionMsg()
    fatal(fmt"Could not convert {inFile} to {outFile.extractFilename}: {msg}")

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

proc updateIfo*(dir: string, opts: options.Options, target: options.Target) =
  ## Updates the areas listing in module.ifo, checks for matching .git files,
  ## and sets module name and min version, if specified
  let
    ifoFile = dir / "module.ifo"
    areas = toSeq(walkFiles(dir / "*.are")).mapIt(it.splitFile.name)
    gits = toSeq(walkFiles(dir / "*.git")).mapIt(it.splitFile.name)

  if not fileExists(ifoFile):
    return
  
  let
    input = openFileStream(ifoFile)
    state = input.readGffRoot(false)

  input.close

  var
    ifoJson = state.toJson
    ifoAreas: seq[JsonNode]
    unmatchedAreas: seq[string]

  let
    entryArea = ifoJson["Mod_Entry_Area"]["value"].getStr
    removeUnused = opts.get("removeUnusedAreas", true)
    moduleName = opts.get("modName", target.modName)
    moduleVersion = opts.get("modMinGameVersion", target.modMinGameVersion)

  # Area List update
  if entryArea notin areas:
    fatal("This module does not have a valid starting area!")

  if areas.len > 0 and removeUnused:
    display("Updating", "area list")
    let plurality = (if areas.len > 1: "s" else: "")

    for area in areas:
      ifoAreas.add(%* {"__struct_id":6,"Area_Name":{"type":"resref","value":area}})

      if area notin gits:
        unmatchedAreas.add(area)

    if unmatchedAreas.len > 0:
      warning("The following do not have matching .git files and will not be accessible " &
        "in the toolset: " & unmatchedAreas.join(", "))

    ifoJson["Mod_Area_list"]["value"] = %ifoAreas
    success(fmt"area list updated --> {areas.len} area{plurality} listed")

  # Module Name Update
  if moduleName.len > 0 and moduleName != ifoJson["Mod_Name"]["value"]["0"].getStr:
    ifoJson["Mod_Name"]["value"]["0"] = %moduleName
    success("module name set to " & moduleName)

  # Module Min Game Version Update
  if moduleVersion.len > 0:
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
      display("Skipping", "setting module min game version")

  let 
    output = openFileStream(ifoFile, fmWrite)

  ifoJson.postProcessJson
  ifoJson.truncateFloats
  output.write(ifoJson.gffRootFromJson)
  output.close

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
