import ContextCoreKit
import SwiftUI

struct RootView: View {
  var body: some View {
    VStack(spacing: 12) {
      Text("Dayline")
        .font(.largeTitle)

      Text("Context schema v\(ContextCoreKit.schemaVersion)")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding()
  }
}
