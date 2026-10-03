import SwiftUI

@main
struct ClipboardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Recall", systemImage: "doc.text.magnifyingglass") {
            MenuBarRootView(
                viewModel: appDelegate.historyViewModel,
                imagePreviewPresenter: appDelegate.imagePreviewPresenter
            )
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(viewModel: appDelegate.settingsViewModel)
        }
    }
}
