import Foundation
import NotionKit
import Observation

enum NotionConnectionState: Equatable {
  case loading
  case disconnected
  case connecting
  case connected(NotionConnectionSummary)
  case disconnecting(NotionConnectionSummary)
  case unavailable
  case failed
}

@MainActor
@Observable
final class NotionConnectionModel {
  private(set) var state: NotionConnectionState = .loading
  private(set) var disconnectRevocationFailed = false
  private(set) var destinations: [NotionDestination] = []
  private(set) var destinationLoading = false
  private(set) var destinationLoadFailed = false

  private let broker: any NotionOAuthBrokering
  private let credentials: any NotionCredentialStoring
  private let webAuthentication: any AppWebAuthenticating
  private let destinationListing: any NotionDestinationListing
  private let callbackURL: URL

  init(
    broker: any NotionOAuthBrokering,
    credentials: any NotionCredentialStoring,
    webAuthentication: any AppWebAuthenticating,
    destinationListing: any NotionDestinationListing,
    callbackURL: URL
  ) {
    self.broker = broker
    self.credentials = credentials
    self.webAuthentication = webAuthentication
    self.destinationListing = destinationListing
    self.callbackURL = callbackURL
  }

  var isConnected: Bool {
    if case .connected = state { return true }
    return false
  }

  func load() async {
    do {
      let summary = try await credentials.connectionSummary()
      state = .connected(summary)
      if summary.authorization == .oauth { await loadDestinations() }
    } catch NotionCredentialFailure.unavailable {
      state = .disconnected
    } catch {
      state = .failed
    }
  }

  func connect() async {
    guard state != .connecting else { return }
    let previousState = state
    state = .connecting
    disconnectRevocationFailed = false
    do {
      let session = try await broker.start(callbackURL: callbackURL)
      let callback = try await webAuthentication.authenticate(
        at: session.authorizationURL,
        callbackScheme: callbackURL.scheme ?? ""
      )
      try NotionOAuthCallback.validate(callback, expected: callbackURL, sessionID: session.id)
      let connection = try await broker.complete(sessionID: session.id)
      try await credentials.save(connection: connection)
      state = .connected(connection.summary)
      await loadDestinations()
    } catch AppWebAuthenticationFailure.cancelled {
      state = previousState
    } catch NotionOAuthFailure.notConfigured {
      state = .unavailable
    } catch {
      state = .failed
    }
  }

  func disconnect() async {
    guard case .connected(let summary) = state else { return }
    state = .disconnecting(summary)
    disconnectRevocationFailed = false
    do {
      if let connection = try await credentials.connection() {
        do {
          try await broker.revoke(
            connectionID: connection.connectionID,
            revocationToken: connection.revocationToken
          )
        } catch {
          disconnectRevocationFailed = true
        }
      }
      try await credentials.remove()
      destinations = []
      state = .disconnected
    } catch {
      state = .failed
    }
  }

  func loadDestinations() async {
    destinationLoading = true
    destinationLoadFailed = false
    defer { destinationLoading = false }
    do {
      destinations = try await destinationListing.listDestinations()
    } catch {
      destinations = []
      destinationLoadFailed = true
    }
  }
}
