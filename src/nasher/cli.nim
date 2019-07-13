import sequtils, strutils, terminal

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

proc isLogging*(level: Priority): bool =
  cli.logLevel <= level

proc setShowColor*(val: bool) =
  cli.showColor = val

proc setForceAnswer*(val: Answer) =
  cli.forceAnswer = val

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
    lines = msg.splitLines.mapIt(it.wordWrap(width)).join("\n").splitLines

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
  ## Displays msg as an error, then quits, sending an error code
  error(msg)
  quit(QuitFailure)

proc success*(msg: string, priority: Priority = MediumPriority) =
  display("Success:", msg, displayType = Success, priority = priority)

proc hint*(msg: string) =
  cli.hints.add(msg)

proc displayHints =
  for hint in cli.hints:
    display("Hint:", hint)
  cli.hints = @[]

proc prompt(msg: string): string =
  display("Prompt:", msg, Prompt, HighPriority)
  displayHints()
  displayCategory("Answer:", Prompt, HighPriority)
  result = stdin.readLine

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
      if result.isNilOrWhitespace:
        result = if allowBlank: "" else: ask(question)
    else:
      result = prompt("$1 (default: $2)" % [question, default])
      if result.isNilOrWhitespace:
        result = default
        stdout.cursorUp
        stdout.eraseLine
        displayCategory("Answer:", Prompt, HighPriority)
        echo default

proc choose*(question: string, choices: openarray[string]): string =
  display("Prompt:", question, Prompt, HighPriority)
  displayHints()
  display("Select:", "Cycle with Tab, Choose with Enter", Prompt, HighPriority)

  var
    current = 0
    selected = false

  # In case the cursor is at the bottom of the terminal
  stdout.write(repeat("\n", choices.len - 1))

  # Reset the cursor to the start of the selection prompt
  stdout.cursorUp(choices.len - 1)
  stdout.cursorForward(colWidth)
  stdout.hideCursor

  # The selection loop
  while not selected:
    setForegroundColor(fgDefault)

    # Loop through the options
    for i, choice in choices:
      if i == current:
        writeStyled(" > " & choice, {styleBright})
      else:
        writeStyled("   " & choice, {styleDim})

      # Move the cursor back to the start
      stdout.cursorBackward(choice.len + 3)

      # Move down to the next item
      stdout.cursorDown

    # Move the cursor back to the top of the selection prompt
    stdout.cursorUp(choices.len - 1)

    # Begin key input
    while true:
      case getch():
        of '\t', 'j':
          current = (current + 1) mod choices.len
          break
        of 'k':
          current.dec
          if current < 0:
            current = choices.len - 1
          break
        of '\r':
          selected = true
          break
        of '\3':
          stdout.showCursor
          fatal("keyboard interrupt")
        else:
          discard

  # Erase all lines of the selection
  stdout.cursorUp
  for i in 0..<choices.len:
    stdout.eraseLine
    stdout.cursorDown

  # Move the cursor back up the initial selection line
  stdout.cursorUp(choices.len)
  stdout.showCursor
  display("Answer:", choices[current], Prompt, HighPriority)
  return choices[current]
