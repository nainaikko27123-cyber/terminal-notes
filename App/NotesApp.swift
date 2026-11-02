import NotesKit
import SwiftUI

@main
struct NotesApp: App {
    static let terminalWindowID = "terminal"

    @State private var model = NotesModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Note") { model.createNote() }
                    .keyboardShortcut("n")
                OpenTerminalButton()
            }
            CommandGroup(replacing: .saveItem) {
                Button("Save") { model.requestSave() }
                    .keyboardShortcut("s")
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

        Window("Terminal", id: Self.terminalWindowID) {
            TerminalView()
                .environment(model)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 720, height: 480)
    }
}

private struct OpenTerminalButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open Terminal") { openWindow(id: NotesApp.terminalWindowID) }
            .keyboardShortcut("t", modifiers: [.command, .shift])
    }
}
