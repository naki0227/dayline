import Foundation
import SQLite3

public struct ChromeHistorySQLiteReader: Sendable {
  fileprivate static let chromeEpochOffset: TimeInterval = 11_644_473_600
  private let historyURL: URL

  public init(historyURL: URL) {
    self.historyURL = historyURL
  }

  public func visits(
    after cursor: ChromeHistoryCursor,
    limit: Int = 500
  ) throws -> ChromeHistoryBatch {
    guard (1...5_000).contains(limit) else {
      throw MacContextCollectionFailure.invalidObservation
    }
    var database: OpaquePointer?
    let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_URI | SQLITE_OPEN_NOMUTEX
    guard sqlite3_open_v2(historyURL.path, &database, flags, nil) == SQLITE_OK,
      let database
    else {
      if let database { sqlite3_close(database) }
      throw MacContextCollectionFailure.historyUnavailable
    }
    defer { sqlite3_close(database) }

    let query = """
      SELECT visits.id, urls.url, urls.title, visits.visit_time
      FROM visits
      JOIN urls ON urls.id = visits.url
      WHERE visits.visit_time > ?
         OR (visits.visit_time = ? AND visits.id > ?)
      ORDER BY visits.visit_time ASC, visits.id ASC
      LIMIT ?
      """
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK,
      let statement
    else {
      throw MacContextCollectionFailure.historyReadFailed
    }
    defer { sqlite3_finalize(statement) }

    sqlite3_bind_int64(statement, 1, cursor.visitTime)
    sqlite3_bind_int64(statement, 2, cursor.visitTime)
    sqlite3_bind_int64(statement, 3, cursor.visitID)
    sqlite3_bind_int(statement, 4, Int32(limit))
    var observations: [ChromeVisitObservation] = []
    var nextCursor = cursor
    while sqlite3_step(statement) == SQLITE_ROW {
      let visitID = sqlite3_column_int64(statement, 0)
      guard let urlText = sqlite3_column_text(statement, 1) else { continue }
      let rawURL = String(cString: urlText)
      guard let url = URL(string: rawURL) else { continue }
      let title: String?
      if let titleText = sqlite3_column_text(statement, 2) {
        title = String(cString: titleText)
      } else {
        title = nil
      }
      let timestamp = sqlite3_column_int64(statement, 3)
      observations.append(
        ChromeVisitObservation(
          url: url,
          title: title,
          occurredAt: date(fromChromeTimestamp: timestamp)
        )
      )
      nextCursor = ChromeHistoryCursor(visitTime: timestamp, visitID: visitID)
    }
    guard sqlite3_errcode(database) == SQLITE_OK || sqlite3_errcode(database) == SQLITE_DONE else {
      throw MacContextCollectionFailure.historyReadFailed
    }
    return ChromeHistoryBatch(observations: observations, nextCursor: nextCursor)
  }

  private func date(fromChromeTimestamp timestamp: Int64) -> Date {
    Date(timeIntervalSince1970: (Double(timestamp) / 1_000_000) - Self.chromeEpochOffset)
  }
}

public struct ChromeHistoryCursor: Codable, Equatable, Sendable {
  public let visitTime: Int64
  public let visitID: Int64

  public init(visitTime: Int64, visitID: Int64) {
    self.visitTime = visitTime
    self.visitID = visitID
  }

  public init(date: Date) {
    visitTime = Int64(
      (date.timeIntervalSince1970 + ChromeHistorySQLiteReader.chromeEpochOffset) * 1_000_000
    )
    visitID = 0
  }
}

public struct ChromeHistoryBatch: Equatable, Sendable {
  public let observations: [ChromeVisitObservation]
  public let nextCursor: ChromeHistoryCursor

  public init(observations: [ChromeVisitObservation], nextCursor: ChromeHistoryCursor) {
    self.observations = observations
    self.nextCursor = nextCursor
  }
}
