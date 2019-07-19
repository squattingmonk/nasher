import json, os, osproc, streams, strformat, strutils, tables
import neverwinter/[erf, resman, gff, gffjson]

import cli

const
  GffExtensions* = @[
    "utc", "utd", "ute", "uti", "utm", "utp", "uts", "utt", "utw",
    "git", "are", "gic", "mod", "ifo", "fac", "dlg", "itp", "bic",
    "jrl", "gff", "gui"
  ]

proc extractErf*(fileName, destDir: string) =
  ## Extracts a .mod, .erf, or .hak file into destDir.
  ## May throw an IO Exception
  var f = openFileStream(fileName)
  let erf = erf.readErf(f, fileName)

  for c in erf.contents:
    writeFile(destDir / $c, erf.demand(c).readAll())

  close(f)

proc createErf*(fileName: string, files: seq[string]): (string, int) =
  ## Creates a .mod, .erf, or .hak file named fileName from the given files.
  ## TODO: create the file here instead of calling out to nwn_erf
  execCmdEx("nwn_erf --quiet -c -f " & fileName & " " & files.join(" "))

proc getFormat(file: string): string =
  let ext = splitFile(file).ext.strip(chars = {'.'})

  if ext == "json":
    result = "json"
  elif GffExtensions.contains(ext):
    result = "gff"
  else:
    raiseAssert(fmt"Could not convert {file}: format {ext} not supported")

proc postProcessJson(j: JsonNode) =
  ## Post-process json before emitting: We make sure to re-sort.
  ## SM: This comes from nwn_gff.nim. I think the sorting is to ensure a
  ## re-produceable build.
  if j.kind == JObject:
    for k, v in j.fields: postProcessJson(v)
    j.fields.sort do (a, b: auto) -> int: cmpIgnoreCase(a[0], b[0])
  elif j.kind == JArray:
    for e in j.elems: postProcessJson(e)

proc gffConvert*(inFile, destDir = getCurrentDir()) =
  ## Converts inFile from GFF to JSON or vice versa, renaming the file
  ## according to the pattern: module.ifo <-> module.ifo.json.
  let inFormat = inFile.getFormat()
  let inStream = inFile.openFileStream()
  let (_, file, ext) = inFile.splitFile()

  var
    state: GffRoot
    outFile: string

  if inFormat == "gff":
    state = gff.readGffRoot(inStream, false)
    outFile = (destDir / file.addFileExt(ext.addFileExt("json")))
    let
      outStream = openFileStream(outFile, fmWrite)
      j = state.toJson()
    postProcessJson(j)
    outStream.write(j.pretty())
    outStream.write("\c\L")
    outStream.close()
  else:
    outFile = destDir / file
    let outStream = openFileStream(outFile, fmWrite)
    state = inStream.parseJson(inFile).gffRootFromJson()
    outStream.write(state)
    outStream.close()

  let msg = inFile.extractFilename & " -> " & destDir / outFile.extractFilename
  display("Converting", msg, priority = LowPriority)
