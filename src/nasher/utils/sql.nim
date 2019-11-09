import db_sqlite, std/sha1, os, times

proc dbTableInit(db: DbConn) =
  db.exec(sql"""CREATE TABLE IF NOT EXISTS tmp (
                  filename TEXT NOT NULL PRIMARY KEY,
                  sha1 TEXT NOT NULL,
                  datemod INTEGER NOT NULL
                )""")

proc getDB*(fileName: string): DbConn =
  result = open(".nasher" / fileName & ".db", "", "", "")
  result.dbTableInit()

proc sqlDelete*(db:DbConn, fileName: string) =
  db.exec(sql"DELETE FROM tmp WHERE filename = ?", filename)

proc sqlBegin*(db:DBConn) =
  db.exec(sql"BEGIN")

proc sqlCommit*(db:DBConn) =
  db.exec(sql"COMMIT")

proc sqlUpsert*(db:DbConn, fileName: string, fileSha1: string, packTime: Time, sqlSha1: string) =
  #Can't use true sqlite 'upsert' due to nim library not wrapping it.
  if sqlsha1 == "":
    db.exec(sql"INSERT INTO tmp(filename, sha1, datemod) VALUES (?, ?, ?)", fileName, fileSha1, $packTime)
  else:
    db.exec(sql"UPDATE tmp SET sha1 = ?, datemod = ? WHERE filename = ?", fileSha1, $packtime, fileName)

proc sqlUpdate*(db:DbConn, fileName: string, fileSha1: string, packTime: Time) =
  db.exec(sql"UPDATE tmp SET sha1 = ?, datemod = ? WHERE filename = ?", fileSha1, $packTime, fileName)

proc getFileDetail(file: string): tuple[fileName: string, fileSha1: string] =
  let
    fileName = file.extractFileName
    fileSha1 = $file.secureHashFile
    details: tuple = (fileName, fileSha1)

  result = details

proc parsedbTime(sqlTime: string): Time =
  if sqlTime == "":
    result = fromUnix(0)
  else:
    result = sqlTime.parseTime("yyyy-MM-dd\'T\'HH:mm:sszzz",now().timezone)

proc sqlRetrieveAllNames*(db: DbConn): seq[string] =
  let fullDB= db.getAllRows(sql"SELECT filename FROM tmp")

  ##to avoid returning seq[seq[]] with internal seq length = 1
  for x in fullDB:
    result.add(x[0])


proc getChangedFiles*(db: DbConn, tmpDir: string): seq[tuple[fileName: string, fileSha1: string, sqlSha1: string, sqlTime: Time]] =
  for file in walkFiles(tmpDir / "*"):

    let
      fileDetail = file.getFileDetail()
      row = db.getRow(sql"SELECT * FROM tmp WHERE fileName = ?", fileDetail.fileName)
      sqlDetail: tuple[fileName: string, sqlSha1: string, sqlTime: Time] = (row[0],row[1], row[2].parsedbTime())

    if fileDetail.fileName.splitFile.ext == ".ncs":
      continue
    elif fileDetail.fileSha1 == sqlDetail.sqlSha1:
      continue
    else:
      result.add((fileDetail.fileName, fileDetail.fileSha1, sqlDetail.sqlSha1, sqlDetail.sqlTime))
