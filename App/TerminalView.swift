import NotesKit
import SwiftUI

/// The main terminal screen: tabs on top, then the page for the current tab.
struct TerminalView: View {
    @Environment(NotesModel.self) private var model

    /// How solid the window's color is. Lower shows more of what's behind it.
    private static let backgroundOpacity = 0.82

    private var palette: TerminalPalette { model.theme.palette }

    var body: some View {
        VStack(spacing: 0) {
            TabBar(palette: palette)
            AutosavingNoteEditor(note: model.page(for: model.currentTab)) { text in
                VStack(spacing: 0) {
                    TerminalTextEditor(text: text, palette: palette)
                        .padding(.top, 6)
                        .overlay {
                            if text.wrappedValue.isEmpty {
                                WelcomeScreen(tab: model.currentTab, palette: palette)
                            }
                        }
                    PromptLine(palette: palette, focusRequestCount: model.promptFocusRequestCount) { input in
                        text.wrappedValue = text.wrappedValue.appendingLine(model.currentTab.line(from: input))
                        model.requestSave()
                    }
                    StatusBar(
                        tab: model.currentTab,
                        tasksLeft: Todos.openCount(in: text.wrappedValue) + model.openTaskCount(excluding: model.currentTab),
                        palette: palette
                    )
                }
            }
            .id(model.currentTab)
        }
        .background(Color(nsColor: palette.background).opacity(Self.backgroundOpacity))
        .background { TranslucentBackground().ignoresSafeArea() }
        .preferredColorScheme(.dark)
    }
}

/// tmux-style tabs, like `[1:notes] [2:todo] [3:ideas]`.
private struct TabBar: View {
    @Environment(NotesModel.self) private var model
    let palette: TerminalPalette

    var body: some View {
        HStack(spacing: 8) {
            ForEach(NoteTab.allCases) { tab in
                let isCurrent = tab == model.currentTab
                Button("[\(tab.label)]") { model.currentTab = tab }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: isCurrent ? .bold : .regular, design: .monospaced))
                    .foregroundStyle(Color(nsColor: isCurrent ? palette.background : palette.dim))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(nsColor: isCurrent ? palette.accent : .clear), in: .rect(cornerRadius: 3))
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .background(Color(nsColor: palette.surface).opacity(0.6))
    }
}

/// Shown instead of a blank page when a tab has nothing in it yet.
private struct WelcomeScreen: View {
    let tab: NoteTab
    let palette: TerminalPalette

    private static let logo = #"""
         _   _  ___ _____ ___ ___
        | \ | |/ _ \_   _| __/ __|
        |  \| | (_) || | | _|\__ \
        |_|\__|\___/ |_| |___|___/
        """#

    var body: some View {
        VStack(spacing: 14) {
            Text(Self.logo)
                .foregroundStyle(Color(nsColor: palette.header))
            VStack(spacing: 4) {
                Text("nothing in \(tab.name) yet")
                    .foregroundStyle(Color(nsColor: palette.text))
                Text("type below and press enter")
                    .foregroundStyle(Color(nsColor: palette.dim))
                Text(tab == .todo ? "try: buy milk #home" : "tip: use #tags and [ ] to-dos")
                    .foregroundStyle(Color(nsColor: palette.tag))
            }
        }
        .font(.system(size: 13, design: .monospaced))
        .multilineTextAlignment(.leading)
        .allowsHitTesting(false)
    }
}

/// A tmux-style bar: current tab on the left, tasks left in the middle, time on the right.
private struct StatusBar: View {
    let tab: NoteTab
    let tasksLeft: Int
    let palette: TerminalPalette

    private var tasksText: String {
        switch tasksLeft {
        case 0: "no tasks left"
        case 1: "1 task left"
        default: "\(tasksLeft) tasks left"
        }
    }

    var body: some View {
        HStack {
            Text("[\(tab.label)]")
                .fontWeight(.bold)
                .foregroundStyle(Color(nsColor: palette.accent))
            Spacer()
            Text(tasksText)
                .foregroundStyle(Color(nsColor: tasksLeft == 0 ? palette.done : palette.date))
            Spacer()
            TimelineView(.everyMinute) { context in
                Text(context.date, format: .dateTime.hour().minute())
                    .foregroundStyle(Color(nsColor: palette.tag))
            }
        }
        .font(.system(size: 12, design: .monospaced))
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .background(Color(nsColor: palette.surface).opacity(0.6))
    }
}

private extension String {
    func appendingLine(_ line: String) -> String {
        if isEmpty { return line }
        return hasSuffix("\n") ? self + line : self + "\n" + line
    }
}
