import os, osproc, streams, strutils
import neverwinter/erf, neverwinter/resman

proc extractErf*(fileName, destDir: string) =
  ## Extracts a .mod, .erf, or .hak file into destDir.
  ## May throw an IO Exception
  var f = openFileStream(fileName)
  let erf = erf.readErf(f, fileName)

  for c in erf.contents:
    writeFile(destDir / $c, erf.demand(c).readAll())

  close(f)

proc createErf*(fileName: string, files: seq[string]): int =
  ## Creates a .mod, .erf, or .hak file named fileName from the given files.
  ## TODO: create the file here instead of calling out to nwn_erf
  execCmd("nwn_erf --quiet -c -f " & fileName & " " & files.join(" "))
import json, os, streams, strformat, strutils, tables

import neverwinter/gff, neverwinter/gffjson
import cli

const
  GffExtensions* = @[
    "utc", "utd", "ute", "uti", "utm", "utp", "uts", "utt", "utw",
    "git", "are", "gic", "mod", "ifo", "fac", "dlg", "itp", "bic",
    "jrl", "gff", "gui"
  ]

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
import osproc, parseutils, sequtils, streams, strutils

import cli

proc parseCompilerOutput(line: var string) =
  ## Intercepts nwnsc's output and converts it into nasher's cli format
  var
    token: string
    parsed = line.parseUntil(token, ':') + 2

  case token
  of "Compiling":
    info("Compiling", line[parsed..^1])
  of "Error":
    error(line[parsed..^1])
  else:
    if token == line:
      # if token.endsWith("see above for context."):
      if token != "Compilation aborted with errors.":
        warning(token, priority = HighPriority)
    else:
      var lines = line.split(':').mapIt(it.strip)
      if lines.contains("Error"):
        error(lines.filterIt(it != "Error").join("\n"))
      elif lines.contains("Warning"):
        warning(lines.filterIt(it != "Warning").join("\n"))
      else:
        display(lines.join("\n"))

proc runCompiler*(cmd: string, args: openArray[string] = []): int =
  ## Runs the nwnsc compiler and returns its error code
  result = -1
  var
    p = startProcess(cmd, args = args, options = {poUsePath, poStdErrToStdOut})
    s = p.outputStream
    line = ""

  while true:
    if s.readLine(line):
      line.parseCompilerOutput
    else:
      result = p.peekExitCode
      if result != -1:
        break

  p.close()

proc execCmdOrDefault*(cmd: string, default = ""): string =
  let (output, errcode) = execCmdEx(cmd)
  if errcode != 0:
    default
  else:
    output
