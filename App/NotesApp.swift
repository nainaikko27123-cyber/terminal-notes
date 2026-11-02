import NotesKit
import SwiftUI

@main
struct NotesApp: App {
    static let terminalWindowID = "terminal"
    static let noteListWindowID = "note-list"

    @State private var model = NotesModel()

    var body: some Scene {
        // The first scene is the one that opens at launch.
        Window("Terminal", id: Self.terminalWindowID) {
            TerminalView()
                .environment(model)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 720, height: 480)
        .commands {
            CommandGroup(replacing: .newItem) {
                NewNoteButton(model: model)
                OpenTerminalButton()
                OpenNoteListButton()
            }
            CommandGroup(replacing: .saveItem) {
                Button("Save") { model.requestSave() }
                    .keyboardShortcut("s")
            }
            CommandMenu("Tabs") {
                ForEach(NoteTab.allCases) { tab in
                    Button(tab.label) { model.currentTab = tab }
                        .keyboardShortcut(KeyEquivalent(Character(String(tab.rawValue))))
                }
            }
            CommandMenu("Theme") {
                Picker("Theme", selection: $model.theme) {
                    ForEach(Theme.allCases) { Text($0.name).tag($0) }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                Divider()
                Button("Next Theme") { model.nextTheme() }
                    .keyboardShortcut("l", modifiers: [.command, .shift])
            }
        }

        WindowGroup("All Notes", id: Self.noteListWindowID) {
            ContentView()
                .environment(model)
        }
    }
}

/// Opens the terminal if it's closed and puts the cursor on the prompt, ready to type.
private struct NewNoteButton: View {
    @Environment(\.openWindow) private var openWindow
    let model: NotesModel

    var body: some View {
        Button("New Note") {
            openWindow(id: NotesApp.terminalWindowID)
            model.focusPrompt()
        }
        .keyboardShortcut("n")
    }
}

private struct OpenNoteListButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open Note List") { openWindow(id: NotesApp.noteListWindowID) }
            .keyboardShortcut("l", modifiers: [.command, .option])
    }
}

private struct OpenTerminalButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open Terminal") { openWindow(id: NotesApp.terminalWindowID) }
            .keyboardShortcut("t", modifiers: [.command, .shift])
    }
}
