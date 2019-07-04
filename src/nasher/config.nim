import logging, os, osproc, parsecfg, streams, strformat, strutils, tables

import common

const globalCfgText* = """
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

[Target]
name = "sm-utils"
description = "These are utilities"
file = "sm_utils.erf"
source = "../sm-utils/src/*"

[Target]
name = "Demo"
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

  Target* = object
    name*, file*, description*: string
    sources*: seq[string]

proc writeCfgFile*(fileName, text: string) =
  tryOrQuit(fmt"Could not create config file at {fileName}"):
    notice(fmt"Creating configuration file at {fileName}")
    createDir(fileName.splitFile().dir)
    writeFile(fileName, text)

proc initConfig(): Config =
  result.install = getNwnInstallDir()
  result.compiler.binary = "nwnsc"

proc initTarget(): Target =
  result.name = ""

proc addTarget(cfg: var Config, target: Target) =
  if target.name.len() > 0:
    cfg.targets[target.name] = target

proc parseUser(cfg: var Config, key, value: string) =
  case key
  of "name": cfg.user.name = value
  of "email": cfg.user.email = value
  of "install": cfg.install = value
  else:
    error(fmt"Unknown key/value pair '{key}={value}'")

proc parseCompiler(cfg: var Config, key, value: string) =
  case key
  of "binary": cfg.compiler.binary = value
  of "flags": cfg.compiler.flags.add(value)
  else:
    error(fmt"Unknown key/value pair '{key}={value}'")

proc parsePackage(cfg: var Config, key, value: string) =
  case key
  of "name": cfg.name = value
  of "description": cfg.description = value
  of "version": cfg.version = value
  of "author": cfg.authors.add(value)
  of "url": cfg.url = value
  of "flat": cfg.flat = parseBool(value)
  else:
    error(fmt"Unknown key/value pair '{key}={value}'")

proc parseTarget(target: var Target, key, value: string) =
  case key
  of "name": target.name = value.normalize
  of "description": target.description = value
  of "file": target.file = value
  of "source": target.sources.add(value)
  else:
    error(fmt"Unknown key/value pair '{key}={value}'")

proc parseConfig*(cfg: var Config, fileName: string) =
  var f = newFileStream(fileName)
  if isNil(f):
    quit(fmt"Cannot open config file: {fileName}", QuitFailure)

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
      cfg.addTarget(target)

      debug(fmt"Parsing section [{e.section}]")
      section = e.section.normalize
      target = initTarget()

    of cfgKeyValuePair, cfgOption:
      key = e.key.normalize
      debug(fmt"Found key/value pair {key}: {e.value}")
      tryOrQuit(fmt"Error parsing {fileName}: {getCurrentExceptionMsg()}"):
        case section
        of "user":
          parseUser(cfg, key, e.value)
        of "compiler":
          parseCompiler(cfg, key, e.value)
        of "package":
          parsePackage(cfg, key, e.value)
        of "target":
          parseTarget(target, key, e.value)
        else:
          discard
    of cfgError:
      error(e.msg)
  cfg.addTarget(target)
  p.close()

proc dumpConfig(cfg: Config) =
  if getLogFilter() != lvlDebug:
    return

  debug("Dumping config...")
  debug "user.name: ", cfg.user.name.escape()
  debug "user.email: ", cfg.user.name.escape()
  debug "compiler.binary: ", cfg.compiler.binary
  debug "compiler.flags: ", $cfg.compiler.flags
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
