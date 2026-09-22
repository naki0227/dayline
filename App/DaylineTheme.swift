import SwiftUI

enum DaylineTheme {
  static let navy = Color(red: 15 / 255, green: 30 / 255, blue: 61 / 255)
  static let navyMid = Color(red: 30 / 255, green: 53 / 255, blue: 88 / 255)
  static let sky = Color(red: 74 / 255, green: 159 / 255, blue: 212 / 255)
  static let skyDark = Color(red: 39 / 255, green: 119 / 255, blue: 188 / 255)
  static let canvas = Color(red: 240 / 255, green: 245 / 255, blue: 1)
  static let recording = Color(red: 1, green: 59 / 255, blue: 48 / 255)

  static let primaryGradient = LinearGradient(
    colors: [skyDark, sky],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
  )

  static let heroGradient = LinearGradient(
    colors: [navy, navyMid],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
  )
}

struct DaylineCardModifier: ViewModifier {
  @Environment(\.colorScheme) private var colorScheme

  func body(content: Content) -> some View {
    content
      .padding(18)
      .background(colorScheme == .dark ? Color.white.opacity(0.06) : .white)
      .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
          .stroke(Color.primary.opacity(0.06))
      }
  }
}

extension View {
  func daylineCard() -> some View {
    modifier(DaylineCardModifier())
  }
}
