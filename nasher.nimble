# Package

version       = "0.22.0"
author        = "Michael A. Sinclair"
description   = "A build tool for Neverwinter Nights projects"
license       = "MIT"
srcDir        = "src"
bin           = @["nasher"]


# Dependencies

requires "nim >= 1.6.4"
requires "neverwinter >= 1.7.3"
requires "nwnt >= 1.3.3"
requires "blarg >= 0.1.0"

when NimMajor == 2:
  requires "glob#head"
  requires "checksums"
else:
  requires "glob >= 0.11.1"
