# Package

version       = "0.7.2"
author        = "Michael A. Sinclair"
description   = "A build tool for Neverwinter Nights projects"
license       = "MIT"
srcDir        = "src"
bin           = @["nasher"]


# Dependencies

requires "nim >= 0.20.0"
requires "neverwinter >= 1.2.5"
requires "glob >= 0.9.0"
requires "regex >= 0.11.1"
