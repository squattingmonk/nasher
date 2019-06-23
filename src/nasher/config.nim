import logging, os, osproc, parsecfg, streams, strformat, strutils, tables

import common

const userCfgText* = """
[User]
name = ""
email = ""
install = "~/Documents/Neverwinter Nights"

[Compiler]
binary = "nwnsc"
flags = "-lowqey"
"""

const pkgCfgText* = """
[Package]
name = "Demo Package"
description = "This is a demo package"
version = "0.1.0"
author = "Squatting Monk <squattingmonk@gmail.com>"
url = "www.example.com"

[sm-utils]
description = "These are utilities"
file = "sm_utils.erf"
source = "../sm-utils/src/*"

[Demo]
description = "This is a demo module"
file = "demo.mod"
source = "src/*"
source = "demo/src/*"
"""


type
  Config* = object
    install*: string
    user*: tuple[name, email: string]
    name*, description*, version*, url*: string
    flat*: bool
    compiler*: tuple[binary: string, flags: seq[string]]
    authors*: seq[string]
    targets*: OrderedTable[string, Target]

  Target = object
    name*, file*, description*: string
    sources*: seq[string]

proc writeCfgFile*(fileName, text: string) =
  try:
    notice(fmt"Creating configuration file at {fileName}")
    createDir(fileName.splitFile().dir)
    writeFile(fileName, text)
  except IOError:
    fatal(fmt"Could not create config file at {fileName}")
    quit(QuitFailure)

proc initConfig(): Config =
  result.install = nwnInstallDir
  result.compiler = ("nwnsc", @["-lowqey"])

proc initTarget(name: string): Target =
  case name.normalize
  of "user", "compiler", "package":
    discard
  else:
    result.name = name

proc addTarget(cfg: var Config, target: Target) =
  if target.name.len() > 0:
    cfg.targets[target.name.normalize] = target

proc parseUser(cfg: var Config, key, value: string) =
  case key:
  of "name": cfg.user.name = value
  of "email": cfg.user.email = value
  of "install": cfg.install = value
  else:
    raise newException(NasherError, fmt"Unknown key/value pair '{key}={value}'")

proc parseCompiler(cfg: var Config, key, value: string) =
  case key
  of "binary": cfg.compiler.binary = value
  of "flags": cfg.compiler.flags.add(value)
  else:
    raise newException(NasherError, fmt"Unknown key/value pair '{key}={value}'")

proc parsePackage(cfg: var Config, key, value: string) =
  case key
  of "name": cfg.name = value
  of "description": cfg.description = value
  of "version": cfg.version = value
  of "author": cfg.authors.add(value)
  of "url": cfg.url = value
  of "flat": cfg.flat = parseBool(value)
  else:
    raise newException(NasherError, fmt"Unknown key/value pair '{key}={value}'")

proc parseTarget(target: var Target, key, value: string) =
  case key
  of "description": target.description = value
  of "file": target.file = value
  of "source": target.sources.add(value)
  else:
    raise newException(NasherError, fmt"Unknown key/value pair '{key}={value}'")

proc parseConfig*(cfg: var Config, fileName: string) =
  var f = newFileStream(fileName)
  if not isNil(f):
    debug(fmt"Reading config file {fileName}")
    var p: CfgParser
    var section, key: string
    var target: Target
    p.open(f, fileName)
    while true:
      var e = p.next()
      case e.kind
      of cfgEof: break
      of cfgSectionStart:
        # Add any finished target to the list and prep a new one
        cfg.addTarget(target)
        target = initTarget(e.section)

        debug(fmt"Parsing section [{e.section}]")
        section = e.section.normalize
      of cfgKeyValuePair, cfgOption:
        key = e.key.normalize
        debug(fmt"Found key/value pair {key}: {e.value}")
        try:
          case section
          of "user":
            parseUser(cfg, key, e.value)
          of "compiler":
            parseCompiler(cfg, key, e.value)
          of "package":
            parsePackage(cfg, key, e.value)
          else:
            parseTarget(target, key, e.value)
        except NasherError:
          let msg = getCurrentExceptionMsg()
          error(fmt"Error parsing {fileName.extractFilename}: {msg}")
        except ValueError:
          fatal(fmt"Error parsing {fileName.extractFilename}:")
          fatal(fmt"  Unknown value '{e.value}' for key '{e.key}' in [{section}]")
          quit(QuitFailure)
      of cfgError:
        error(e.msg)

    # Add any final target to the list
    cfg.addTarget(target)
    p.close()
  else:
    fatal(fmt"Cannot open {fileName}")
    quit(QuitFailure)

proc dumpConfig(cfg: Config) =
  if getLogFilter() != lvlDebug:
    return

  debug("Dumping config...")
  debug "user.name: ", cfg.user.name.escape()
  debug "user.email: ", cfg.user.name.escape()
  debug "install: ", cfg.install.escape()
  debug "name: ", cfg.name.escape()
  debug "description: ", cfg.description.escape()
  debug "version: ", cfg.version.escape()
  debug "url: ", cfg.url.escape()
  debug "flat: ", cfg.flat
  for author in cfg.authors:
    debug "author: ", author

  for key, target in cfg.targets.pairs():
    debug "targets[", key, "].name: ", target.name.escape()
    debug "targets[", key, "].description: ", target.description.escape()
    debug "targets[", key, "].file: ", target.file.escape()
    for source in target.sources:
      debug "targets[", key, "].source: ", source.escape()

  debug("End dump")


proc loadConfig*(configs: seq[string]): Config =
  result = initConfig()
  for config in configs:
    result.parseConfig(config)
  result.dumpConfig()
