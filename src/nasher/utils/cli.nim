import sequtils, strutils, terminal
import std/wordwrap

export isatty

type
  CLI = ref object
    showColor: bool
    logLevel: Priority
    forceAnswer: Answer
    hints: seq[string]

  DisplayType* = enum
    Error, Warning, Message, Success, Prompt

  Priority* = enum
    DebugPriority, LowPriority, MediumPriority, HighPriority

  Answer* = enum
    None, No, Yes, Default

const
  colWidth = len("Initializing")
  foregrounds: array[Error .. Prompt, ForegroundColor] =
    [fgRed, fgYellow, fgCyan, fgGreen, fgYellow]
  styles: array[DebugPriority .. HighPriority, set[Style]] =
    [{styleDim}, {styleDim}, {}, {styleBright}]

const
  AllAnswers* = {None..Default}
  NotYes* = AllAnswers - {Yes}
  NotNo* = AllAnswers - {No}

var cli = CLI(showColor: stdout.isatty, logLevel: MediumPriority, forceAnswer: None)

proc setLogLevel*(level: Priority) =
  cli.logLevel = level

proc getLogLevel*: Priority =
  cli.logLevel

proc isLogging*(level: Priority): bool =
  cli.logLevel <= level

proc setShowColor*(val: bool) =
  cli.showColor = val

proc getShowColor*: bool =
  cli.showColor

proc setForceAnswer*(val: Answer) =
  cli.forceAnswer = val

proc getForceAnswer*: Answer =
  cli.forceAnswer

proc displayCategory(category: string, displayType: DisplayType, priority: Priority) =
  let
    offset = max(0, colWidth - category.len)
    text =
      if stdout.isatty: "$#$# " % [spaces(offset), category]
      else: category & " "

  if cli.showColor:
    if priority != DebugPriority:
      setForegroundColor(stdout, foregrounds[displayType])
    writeStyled(text, styles[priority])
    resetAttributes()
  else:
    stdout.write(text)

proc displayLine(category, line: string, displayType: DisplayType, priority: Priority) =
  displayCategory(category, displayType, priority)
  echo(line)

proc getMsgWidth(category: string): int =
  let maxWidth = if stdout.isatty: terminalWidth() - category.len else: 80
  result = maxWidth - colWidth - 1

proc display*(category, msg: string, displayType = Message, priority = MediumPriority) =
  ## Displayes a message in the format "{category} {msg}" if the log level is at
  ## or below the given priority. The message is styled based on displayType.
  if priority < cli.logLevel:
    return

  # Word wrap each line so it fits in the terminal
  let
    width = getMsgWidth(category)
    lines = msg.splitLines.mapIt(it.wrapWords(width)).join("\n").splitLines

  var i = 0
  for line in lines:
    if line.len == 0: continue
    displayLine(if i == 0: category else: "...", line, displayType, priority)
    i.inc

proc display*(msg: string, displayType = Message, priority = MediumPriority) =
  ## Convenience proc to display a message with no category
  display("", msg, displayType, priority)

proc debug*(category, msg: string) =
  ## Convenience proc for displaying debug messages
  display(category, msg, priority = DebugPriority)

proc debug*(msg: string) =
  ## Convenience proc for displaying debug messages with a default category
  debug("Debug:", msg)

proc info*(category, msg: string) =
  ## Convenience proc for displaying low priority messages
  display(category, msg, priority = LowPriority)

proc warning*(msg: string, priority: Priority = MediumPriority) =
  ## Convenience proc for displaying warnings
  display("Warning:", msg, displayType = Warning, priority = priority)

proc error*(msg: string) =
  ## Convenience proc for displaying errors
  display("Error:", msg, displayType = Error, priority = HighPriority)

proc fatal*(msg: string) =
  ## Displays an error message and quits
  error(msg)
  quit(QuitFailure)

proc success*(msg: string, priority: Priority = MediumPriority) =
  ## Convenience proc for displaying a success message
  display("Success:", msg, displayType = Success, priority = priority)

proc hint*(msg: string) =
  cli.hints.add(msg)

proc displayHints =
  if stdin.isatty:
    for hint in cli.hints:
      display("Hint:", hint)
  cli.hints = @[]

proc prompt(msg: string): string =
  display("Prompt:", msg, Prompt, HighPriority)
  displayHints()
  displayCategory("Answer:", Prompt, HighPriority)
  try:
    result = stdin.readLine
    if not stdin.isatty:
      echo result
  except:
    stdout.write("\n")
    result = ""

proc forced(msg, answer: string) =
  display("Prompt:", "$1 -> [forced $2]" % [msg, answer], Prompt)
  cli.hints = @[]

proc askIf*(question: string, default: Answer = No, allowed = AllAnswers): bool =
  ## Displays a yes/no question/answer prompt to the user. If the user does not
  ## choose an answer or that answer cannot be converted into a bool, the
  ## default answer is chosen instead. If the user has passed a --yes, --no, or
  ## --default flag, the appropriate choice will be selected.
  let forceAnswer =
    if cli.forceAnswer notin allowed:
      None
    elif cli.forceAnswer == Default:
      default
    else:
      cli.forceAnswer

  case forceAnswer
  of Yes:
    forced(question, "yes")
    result = true
  of No:
    forced(question, "no")
    result = false
  else:
    try:
      let help = if default == Yes: " (Y/n)" else: " (y/N)"
      result = prompt(question & help).parseBool
    except ValueError:
      result = default == Yes
      stdout.cursorUp
      stdout.eraseLine
      displayCategory("Answer:", Prompt, HighPriority)
      echo(if result: "yes" else: "no")

  debug("Answer:", $result)

proc ask*(question: string, default = "", allowBlank = true): string =
  if cli.forceAnswer == Default and (default != "" or allowBlank):
    forced(question, "\"" & default & "\"")
    result = default
  else:
    if default == "":
      result = prompt(question)
      if result.isEmptyOrWhitespace:
        if allowBlank:
          result = ""
        elif stdin.isatty:
          result = ask(question)
        else:
          stdout.write("\n")
          fatal("this answer cannot be blank. Aborting...")
    else:
      result = prompt("$1 (default: $2)" % [question, default])
      if result.isEmptyOrWhitespace:
        result = default
        stdout.cursorUp
        stdout.eraseLine
        displayCategory("Answer:", Prompt, HighPriority)
        echo default

proc choose*(question: string, choices: openarray[string]): string =
  ## Present the user with a question and a list of choices. Returns the text
  ## of the chosen choice.
  doAssert(choices.len > 0)

  if cli.forceAnswer != None:
    result = choices[0]
    forced(question, "\"" & result & "\"")
  else:
    display("Prompt:", question & " (default: 1)", Prompt, HighPriority)

    for i, choice in choices:
      display($(i + 1), choice, Message, HighPriority)

    displayHints()
    displayCategory("Answer:", Prompt, HighPriority)
    try:
      result = stdin.readLine
      if result.isEmptyOrWhitespace:
        result = choices[0]
      else:
        result = choices[result.parseInt - 1]
      if stdin.isatty:
        stdout.cursorUp
      stdout.eraseLine
      displayCategory("Answer:", Prompt, HighPriority)
      echo(result)
    except IOError:
      result = choices[0]
      echo result
    except ValueError, IndexDefect:
      if stdin.isatty:
        error("not a valid choice")
        result = choose(question, choices)
      else:
        echo result
        fatal("not a valid choice. Aborting...")
