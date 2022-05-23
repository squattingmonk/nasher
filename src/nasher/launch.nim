import os, osproc, strformat

import utils/shared

const helpLaunch* = """
Usage:
  nasher (serve|play|test) [options] [<target>...]

Description:
  Converts, compiles, and packs all sources for <target>, installs the packed
  file into the NWN installation directory, then launches NWN and loads the
  module. This command is only valid for module targets.

  The exact behavior depends on the command. 'serve' launches with nwserver.
  'play' launches with nwmain. 'test' launches with nwmain using the first
  player character in the localvault.

Options:
  --gameBin              The path to the nwmain binary file
  --serverBin            The path to the nwserver binary file
  --clean                Clears the cache directory before packing
  --branch:<branch>      Selects git branch before operation
  --abortOnCompileError  Automatically abort launching if compilation fails
"""

proc getGameBin: string =
  let binDir = getEnv("NWN_ROOT") / "bin"
  when defined(Linux):
    result = binDir / "linux-x86" / "nwmain-linux"
  elif defined(Windows):
    result = binDir / "win32" / "nwmain.exe"
  elif defined(MacOSX):
    result = binDir / "macos" / "nwmain.app" / "Contents" / "MacOS" / "nwmain"
  else:
    raise newException(ValueError, "Cannot find nwmain: unsupported OS")

proc getServerBin: string =
  let binDir = getEnv("NWN_ROOT") / "bin"
  when defined(Linux):
    result = binDir / "linux-x86" / "nwserver-linux"
  elif defined(Windows):
    result = binDir / "win32" / "nwserver.exe"
  elif defined(MacOSX):
    result = binDir / "macos" / "nwserver-macos"
  else:
    raise newException(ValueError, "Cannot find nwserver: unsupported OS")

proc launch*(opts: Options, target: Target) =
  let
    cmd = opts["command"]

  var
    path, args: string
    options = {poStdErrToStdOut}

  case cmd
  of "play":
    path = opts.get("gameBin", getGameBin())
    args = "+LoadNewModule"
  of "test":
    path = opts.get("gameBin", getGameBin())
    args = "+TestNewModule"
  of "serve":
    path = opts.get("serverBin", getServerBin())
    args = "-module"
    options.incl(poParentStreams)
  else:
    assert false

  path = path.expandPath

  let
    file = target.file
    (_, name, ext) = file.splitFile
    (dir, bin) = path.splitPath

  if ext != ".mod":
    display("Skipping", fmt"{cmd}: {file} is not a module")
  else:
    if not fileExists(path):
      fatal(fmt"Cannot {cmd} {file}: {path} does not exist")

    if fpUserExec notin path.getFilePermissions:
      fatal(fmt"Cannot {cmd} {file}: {path} is not executable")
    
    display("Executing", fmt"{bin} {args} {name}")
    var p = startProcess(path, dir, [args, name], options = options)
    discard p.waitForExit
