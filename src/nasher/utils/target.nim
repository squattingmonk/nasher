from sequtils import filterIt

type
  Target* = ref object
    name*, description*, file*, branch*, modName*, modMinGameVersion*: string
    includes*, excludes*, filters*, flags*: seq[string]
    rules*: seq[Rule]

  Rule* = tuple[pattern, dest: string]
    
proc `==`*(a, b: Target): bool =
  result = true
  for _, valA, valB in fieldPairs(a[], b[]):
    if valA != valB:
      return false

proc getTarget*(targets: seq[Target], name: string): Target =
  ## Returns the first target in `targets` that is named `name`.
  for target in targets:
    if target.name == name:
      return target

proc getTargets*(targets: seq[Target], names: seq[string]): seq[Target] =
  ## Returns all targets in `targets` that match a name in `names`. If the name
  ## "all" is present in `names`, will return all targets.
  if "all" in names or targets.len == 0:
    return targets
  result = targets.filterIt(it.name in names)

