import AuthenticationServices
import Foundation
import UIKit

enum AppWebAuthenticationFailure: Error {
  case unavailable
  case cancelled
  case missingCallback
}

@MainActor
protocol AppWebAuthenticating {
  func authenticate(at url: URL, callbackScheme: String) async throws -> URL
}

@MainActor
final class WebAuthenticationSession: NSObject, AppWebAuthenticating, ASWebAuthenticationPresentationContextProviding {
  private var session: ASWebAuthenticationSession?

  func authenticate(at url: URL, callbackScheme: String) async throws -> URL {
    try await withCheckedThrowingContinuation { continuation in
      let session = ASWebAuthenticationSession(
        url: url,
        callbackURLScheme: callbackScheme
      ) { [weak self] callbackURL, error in
        self?.session = nil
        let authenticationError = error as? ASWebAuthenticationSessionError
        if authenticationError?.code == .canceledLogin {
          continuation.resume(throwing: AppWebAuthenticationFailure.cancelled)
        } else if error != nil {
          continuation.resume(throwing: AppWebAuthenticationFailure.unavailable)
        } else if let callbackURL {
          continuation.resume(returning: callbackURL)
        } else {
          continuation.resume(throwing: AppWebAuthenticationFailure.missingCallback)
        }
      }
      session.presentationContextProvider = self
      session.prefersEphemeralWebBrowserSession = false
      self.session = session
      guard session.start() else {
        self.session = nil
        continuation.resume(throwing: AppWebAuthenticationFailure.unavailable)
        return
      }
    }
  }

  func presentationAnchor(for _: ASWebAuthenticationSession) -> ASPresentationAnchor {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow)
    return window ?? ASPresentationAnchor()
  }
}
