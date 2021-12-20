# Package

version       = "0.16.2"
author        = "Michael A. Sinclair"
description   = "A build tool for Neverwinter Nights projects"
license       = "MIT"
srcDir        = "src"
bin           = @["nasher"]


# Dependencies

requires "nim >= 1.6.0"
requires "neverwinter >= 1.5.4"
requires "glob >= 0.10.0"
requires "nwnt >= 1.3.0"
