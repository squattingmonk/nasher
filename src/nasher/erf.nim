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

proc createErf*(fileName: string, files: seq[string]) =
  ## Creates a .mod, .erf, or .hak file named fileName from the given files.
  ## TODO: create the file here instead of calling out to nwn_erf
  let fileType = fileName.splitFile.ext.strip(chars = {'.'})
  discard execCmd("nwn_erf -c -e " & fileType & " -f " & fileName & " " & files.join(" "))
