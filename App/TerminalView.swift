import NotesKit
import SwiftUI

/// The main terminal screen: tabs on top, then the page for the current tab.
struct TerminalView: View {
    @Environment(NotesModel.self) private var model

    private var palette: TerminalPalette { model.theme.palette }
    /// How solid the window's color is. Lower shows more of what's behind it.
    private var backgroundOpacity: Double { Double(model.windowOpacity) / 100 }
    /// The bars sit on top of the background, so they need less to look about the same strength.
    private var barOpacity: Double { backgroundOpacity * 2 / 3 }

    var body: some View {
        VStack(spacing: 0) {
            TabBar(palette: palette, backgroundOpacity: barOpacity)
            if model.currentTab == .notes {
                NotesScreen(palette: palette, barOpacity: barOpacity)
            } else {
                AutosavingNoteEditor(note: model.page(for: model.currentTab)) { text in
                    VStack(spacing: 0) {
                        TerminalTextEditor(text: text, palette: palette)
                            .padding(.top, 6)
                            .overlay {
                                if text.wrappedValue.isEmpty {
                                    WelcomeScreen(
                                        message: "nothing in \(model.currentTab.name) yet",
                                        tip: model.currentTab == .todo ? "try: buy milk #home" : "tip: use #tags and [ ] to-dos",
                                        palette: palette
                                    )
                                }
                            }
                        PromptLine(palette: palette, focusRequestCount: model.promptFocusRequestCount) { input in
                            if let command = PromptCommand.parse(input) {
                                model.run(command)
                                return
                            }
                            text.wrappedValue = text.wrappedValue.appendingLine(model.currentTab.line(from: input))
                            model.requestSave()
                        }
                        StatusBar(
                            tab: model.currentTab,
                            tasksLeft: Todos.openCount(in: text.wrappedValue)
                                + model.openTaskCount(excludingNoteID: model.page(for: model.currentTab).id),
                            notesCount: model.sidebarNotes.count,
                            message: model.statusMessage,
                            palette: palette,
                            backgroundOpacity: barOpacity
                        )
                    }
                }
                .id(model.currentTab)
            }
        }
        .background(Color(nsColor: palette.background).opacity(backgroundOpacity))
        .background { TranslucentBackground().ignoresSafeArea() }
        .preferredColorScheme(.dark)
    }
}

/// The tabs along the top: the current one is highlighted and the others are dimmed.
private struct TabBar: View {
    @Environment(NotesModel.self) private var model
    @State private var nowPlaying = NowPlayingMonitor()
    let palette: TerminalPalette
    let backgroundOpacity: Double

    var body: some View {
        HStack(spacing: 14) {
            ForEach(NoteTab.allCases) { tab in
                let isCurrent = tab == model.currentTab
                Button(tab.label) { model.currentTab = tab }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: isCurrent ? .bold : .regular, design: .monospaced))
                    .foregroundStyle(Color(nsColor: isCurrent ? palette.background : palette.dim))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(nsColor: isCurrent ? palette.accent : .clear), in: .rect(cornerRadius: 3))
            }
            Spacer(minLength: 12)
            if let song = nowPlaying.song {
                Text(verbatim: "♪ \(song.text)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color(nsColor: palette.done))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 12)
            }
            ChompingDots(palette: palette)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .background(Color(nsColor: palette.surface).opacity(backgroundOpacity))
        .task { await nowPlaying.checkCurrentSong() }
    }
}

/// Shown instead of a blank page when a tab has nothing in it yet.
struct WelcomeScreen: View {
    let message: String
    let tip: String
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
                Text(verbatim: message)
                    .foregroundStyle(Color(nsColor: palette.text))
                Text("type below and press enter")
                    .foregroundStyle(Color(nsColor: palette.dim))
                Text(verbatim: tip)
                    .foregroundStyle(Color(nsColor: palette.tag))
            }
        }
        .font(.system(size: 13, design: .monospaced))
        .multilineTextAlignment(.leading)
        .allowsHitTesting(false)
    }
}

/// A tmux-style bar: current tab on the left, notes and tasks left in the middle, time on the right.
struct StatusBar: View {
    let tab: NoteTab
    let tasksLeft: Int
    let notesCount: Int
    /// Takes the place of the task count for a moment, as a reply to a command.
    let message: String?
    let palette: TerminalPalette
    let backgroundOpacity: Double

    private var notesText: String {
        switch notesCount {
        case 0: "no notes"
        case 1: "1 note"
        default: "\(notesCount) notes"
        }
    }

    private var tasksText: String {
        switch tasksLeft {
        case 0: "no tasks left"
        case 1: "1 task left"
        default: "\(tasksLeft) tasks left"
        }
    }

    var body: some View {
        HStack {
            Text(tab.label)
                .fontWeight(.bold)
                .foregroundStyle(Color(nsColor: palette.accent))
            Spacer()
            Text(message ?? "\(notesText) · \(tasksText)")
                .foregroundStyle(Color(nsColor: message != nil ? palette.tag : tasksLeft == 0 ? palette.done : palette.date))
            Spacer()
            HStack(spacing: 6) {
                LEDDot()
                TimelineView(.everyMinute) { context in
                    Text(context.date, format: .dateTime.hour().minute())
                        .foregroundStyle(Color(nsColor: palette.tag))
                }
            }
        }
        .font(.system(size: 12, design: .monospaced))
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .background(Color(nsColor: palette.surface).opacity(backgroundOpacity))
    }
}

extension String {
    func appendingLine(_ line: String) -> String {
        if isEmpty { return line }
        return hasSuffix("\n") ? self + line : self + "\n" + line
    }
}
