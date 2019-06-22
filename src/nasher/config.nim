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
  let
    absPath = if fileName.isAbsolute(): fileName else: getCurrentDir() / fileName
    relPath = absPath.relativePath(getCurrentDir())

  try:
    notice(fmt"Creating configuration file at {relPath}")
    createDir(fileName.splitFile().dir)
    writeFile(fileName, text)
  except IOError:
    fatal(fmt"Could not create config file at {relPath}")
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
        case section.normalize
        of "user":
          case key:
          of "name": cfg.user.name = e.value
          of "email": cfg.user.email = e.value
          of "install": cfg.install = e.value
          else: discard
        of "compiler":
          case key
          of "binary": cfg.compiler.binary = e.value
          of "flags": cfg.compiler.flags.add(e.value)
          else: discard
        of "package":
          case key
          of "name": cfg.name = e.value
          of "description": cfg.description = e.value
          of "version": cfg.version = e.value
          of "author": cfg.authors.add(e.value)
          of "url": cfg.url = e.value
          of "flat":
            try:
              cfg.flat = parseBool(e.value)
            except ValueError:
              let shortName = fileName.extractFilename
              error(fmt"Unknown value '{e.value}' for key '{e.key}' in {shortName}")
          else: discard
        else:
          case key
          of "description": target.description = e.value
          of "file": target.file = e.value
          of "source": target.sources.add(e.value)
          else: discard
      of cfgError:
        error(e.msg)
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
