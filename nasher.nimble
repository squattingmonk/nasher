# Package

version       = "0.8.3"
author        = "Michael A. Sinclair"
description   = "A build tool for Neverwinter Nights projects"
license       = "MIT"
srcDir        = "src"
bin           = @["nasher"]


# Dependencies

requires "nim >= 0.20.2"
requires "neverwinter >= 1.2.7"
requires "glob >= 0.9.0"
requires "regex >= 0.11.1"
