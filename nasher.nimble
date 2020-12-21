# Package

version       = "0.14.0"
author        = "Michael A. Sinclair"
description   = "A build tool for Neverwinter Nights projects"
license       = "MIT"
srcDir        = "src"
bin           = @["nasher"]


# Dependencies

requires "nim >= 1.4.0"
requires "neverwinter >= 1.4.1"
requires "glob >= 0.10.0"
requires "nwnt >= 1.2.2"
