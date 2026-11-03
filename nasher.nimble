# Package

version       = "1.2.0"
author        = "Michael A. Sinclair"
description   = "A build tool for Neverwinter Nights projects"
license       = "MIT"
srcDir        = "src"
bin           = @["nasher"]


# Dependencies

requires "nim >= 2.4.0"
requires "checksums"
requires "neverwinter >= 2.3.2"
requires "nwnt >= 1.4.0"
requires "blarg >= 0.1.0"
requires "regex >= 0.27.0"
requires "glob#ab6087b"
