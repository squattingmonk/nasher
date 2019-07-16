from os import commandLineParams
from strutils import join
import parseopt, strtabs

import shared, cli

const
  nasherCommands =
    ["init", "list", "compile", "pack", "install", "unpack"]

proc dumpOptions(opts: Options) =
  if not isLogging(DebugPriority):
    return

  debug("Args:", commandLineParams().join("\n"))
  debug("Command:", opts.get("command"))
  debug("Target:", opts.get("target"))
  debug("File:", opts.get("file"))
  debug("Directory:", opts.get("directory"))
  debug("Config:", opts.get("config"))
  debug("Help:", $opts.getBool("help"))
  debug("Version:", $opts.getBool("version"))
  debug("Force:", $cli.getForceAnswer())
  stdout.write("\n")

proc parseCmdLine*(): Options =
  var args: int
  for kind, key, val in getopt():
    case kind
    of cmdArgument:
      case result.get("command")
      of "init":
        case args
        of 0: result["directory"] = key
        of 1: result["file"] = key
        else: result["help"] = "true"
        args.inc
      of "list", "compile", "convert", "pack", "install":
        case args
        of 0: result["target"] = key
        else: result["help"] = "true"
        args.inc
      of "unpack":
        case args
        of 0: result["file"] = key
        else: result["help"] = "true"
        args.inc
      else:
        if key in nasherCommands:
          result["command"] = key
        else: break
    of cmdLongOption, cmdShortOption:
      case key
      of "h", "help":
        result["help"] = "true"
      of "v", "version":
        result["version"] = "true"
      of "no-color":
        cli.setShowColor(true)
      of "debug":
        cli.setLogLevel(DebugPriority)
      of "verbose":
        cli.setLogLevel(LowPriority)
      of "quiet":
        cli.setLogLevel(HighPriority)
      of "n", "no":
        cli.setForceAnswer(No)
      of "y", "yes":
        cli.setForceAnswer(Yes)
      of "default":
        cli.setForceAnswer(Default)
      else:
        result[key] = val
    else: discard

  result.dumpOptions
