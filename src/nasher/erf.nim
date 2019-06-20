import os, streams
import neverwinter/erf, neverwinter/resman

proc extractErf*(fileName, destDir: string) =
  ## Extracts a .mod, .erf, or .hak file into destDir.
  ## May throw an IO Exception
  var f = openFileStream(fileName)
  let erf = erf.readErf(f, fileName)
  
  for c in erf.contents:
    writeFile(destDir / $c, erf.demand(c).readAll())

  close(f)
