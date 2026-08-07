# Package

version       = "1.1.3"
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
requires "regex >= 0.25.0"
requires "glob#ab6087b"

when NimMajor == 2:
  requires "checksums"
