import AppKit
import Foundation
import Testing
@testable import NotesKit

@Suite struct ThemeTests {
    let defaults: UserDefaults = {
        let name = "ThemeTests-\(UUID().uuidString)"
        return UserDefaults(suiteName: name)!
    }()

    @Test func nextCyclesThroughEveryThemeAndWraps() {
        #expect(Theme.matrixGreen.next == .nordBlue)
        #expect(Theme.nordBlue.next == .draculaDark)
        #expect(Theme.draculaDark.next == .matrixGreen)
    }

    @Test func themeIsDefaultUntilSavedThenPersists() {
        #expect(Theme.saved(in: defaults) == .default)
        Theme.draculaDark.save(to: defaults)
        #expect(Theme.saved(in: defaults) == .draculaDark)
    }

    @Test func unknownSavedValueFallsBackToDefault() {
        defaults.set("removedTheme", forKey: "theme")
        #expect(Theme.saved(in: defaults) == .default)
    }

    @Test func defaultThemeKeepsTheOriginalTerminalBackground() {
        let color = Theme.default.palette.background
        #expect(Int((color.redComponent * 255).rounded()) == 0x1E)
        #expect(Int((color.greenComponent * 255).rounded()) == 0x1E)
        #expect(Int((color.blueComponent * 255).rounded()) == 0x1E)
    }

    /// WCAG contrast of at least 4.5:1, so body text stays readable in every theme.
    @Test(arguments: Theme.allCases) func textIsReadableOnBackground(theme: Theme) {
        func luminance(_ color: NSColor) -> CGFloat {
            func channel(_ value: CGFloat) -> CGFloat {
                value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * channel(color.redComponent) + 0.7152 * channel(color.greenComponent) + 0.0722 * channel(color.blueComponent)
        }
        let palette = theme.palette
        for color in [palette.text, palette.accent, palette.link, palette.code] {
            let (lighter, darker) = (luminance(color), luminance(palette.background))
            #expect((lighter + 0.05) / (darker + 0.05) >= 4.5, "\(theme.name)")
        }
    }
}
