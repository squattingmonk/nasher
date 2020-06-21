import os, osproc, strformat

import utils/[cli, options, shared]

const
  helpLaunch* = """
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
    --gameBin      The path to the nwmain binary file (if not the OS default)
    --serverBin    The path to the nwserver binary file (if not the OS default)
    --clean        Clears the cache directory before packing
    --yes, --no    Automatically answer yes/no to prompts
    --default      Automatically accept the default answer to prompts

  Global Options:
    -h, --help     Display help for nasher or one of its commands
    -v, --version  Display version information

  Logging:
    --debug        Enable debug logging
    --verbose      Enable additional messages about normal operation
    --quiet        Disable all logging except errors
    --no-color     Disable color output (automatic if not a tty)
  """


const
  SteamPath = joinPath("Steam", "steamapps", "common", "Neverwinter Nights", "bin")

proc getGameBin: string =
  when defined(Linux):
    result = "~/.local/share" / SteamPath / "linux-x86/nwmain-linux"
  when defined(Windows):
    result = "%PROGRAMFILES(X86)%" / SteamPath / "win32" / "nwmain.exe"
  when defined(MacOS):
    result = "~/Library/Application Support" / SteamPath / "macos/nwmain.app/Contents/MacOS/nwmain"

proc getServerBin: string =
  when defined(Linux):
    result = "~/.local/share" / SteamPath / "linux-x86/nwserver-linux"
  when defined(Windows):
    result = "%PROGRAMFILES(X86)%" / SteamPath / "win32" / "nwmain.exe"
  when defined(MacOS):
    result = "~/Library/Application Support" / SteamPath / "macos/nwserver-macos"

proc launch*(opts: Options) =
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
    file = opts["file"]
    (_, name, ext) = file.splitFile
    (dir, bin) = path.splitPath

  if ext != ".mod":
    display("Skipping", fmt"{cmd}: {file} is not a module")
  else:
    if not existsFile(path):
      fatal(fmt"Cannot {cmd} {file}: {path} does not exist")

    if fpUserExec notin path.getFilePermissions:
      fatal(fmt"Cannot {cmd} {file}: {path} is not executable")
    
    display("Executing", fmt"{bin} {args} {name}")
    var p = startProcess(bin, dir, [args, name], options = options)
    discard p.waitForExit
