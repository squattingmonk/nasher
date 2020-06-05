# Package

version       = "0.11.7"
author        = "Michael A. Sinclair"
description   = "A build tool for Neverwinter Nights projects"
license       = "MIT"
srcDir        = "src"
bin           = @["nasher"]


# Dependencies

requires "nim >= 1.2.0"
requires "neverwinter >= 1.2.10"
requires "glob >= 0.9.0"
