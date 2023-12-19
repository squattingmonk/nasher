import os, osproc, parseutils, pegs, sequtils, streams, strutils

import cli

type Compiler* = enum
  Organic = "nwn_script_comp" #default
  Legacy = "nwnsc"

const compilerFlags* =
  # Default compiler flags; ordered referenced to `Compiler` enum above
  ["-y", "-lowqey"]

proc parseCompilerOutput(line: var string, compiler: Compiler): bool =
  ## Intercepts the compiler's output and converts it into nasher's cli format.
  case compiler:
    of Organic:
      if line =~ peg"""
          output <- error / result
          error <- type data* path file errorData data
          result <- type data* results
          type <- {[EI]} \s*
          data <- \[ @ \] \s*
          path <- (([A-Z][:]) / '~' / \/)? (![:] . )* [:] \s*
          file <- {(![:] .)*}[:] \s*
          errorData <- "ERROR:" \s* {(!\[.)*} &\[
          results <- {.*}
        """:
        case matches[0]:
          of "I":
            display("Results:", matches[1])
          of "E":
            error("Compile Error:", "$1 :: $2" % [matches[1], matches[2].strip])
            result = true
          else:
            #Catchall to find other errors I didn't expect
            display("Unknown Compiler Output", line)
    of Legacy:
      var
        token: string
        parsed = line.parseUntil(token, ':') + 2

      case token
      of "Compiling":
        info("Compiling", line[parsed..^1])
      of "Error":
        error(line[parsed..^1])
      else:
        if token == line:
          debug("Compiler:", line)
        else:
          var lines = line.split(':').mapIt(it.strip)
          if lines.contains("Error"):
            error(lines.filterIt(it != "Error").join("\n"))
            result = true
          elif lines.contains("Warning"):
            warning(lines.filterIt(it != "Warning").join("\n"))
          else:
            display(lines.join("\n"))

proc runCompiler*(cmd: string, args: openArray[string] = []): int =
  ## Runs the compiler and returns its error code
  let
    params = args.filterIt(it.len > 0)
    options = {poUsePath, poStdErrToStdOut}
    compiler = parseEnum[Compiler](cmd.splitPath.tail.splitFile.name, Compiler.low)

  debug("Executing", "$1 $2" % [cmd, params.join(" ")])
  var
    p = startProcess(cmd, args = params, options = options)
    s = p.outputStream
    line = ""

  while p.running:
    if s.readLine(line):
      if line.parseCompilerOutput(compiler):
        result = 1

  p.close
