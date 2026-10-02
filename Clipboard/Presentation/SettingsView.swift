import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var selectedTab = SettingsTab.general

    var body: some View {
        VStack(spacing: 0) {
            Picker("Settings section", selection: $selectedTab) {
                Label("General", systemImage: "gearshape")
                    .tag(SettingsTab.general)
                Label("Ignored Apps", systemImage: "eye.slash")
                    .tag(SettingsTab.ignoredApps)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityLabel("Settings section")
            .frame(width: 240)
            .padding(.vertical, 12)

            switch selectedTab {
            case .general:
                Form {
                Picker(
                    "History size",
                    selection: Binding(
                        get: { viewModel.historyLimit },
                        set: viewModel.updateHistoryLimit
                    )
                ) {
                    ForEach(SettingsViewModel.availableHistoryLimits, id: \.self) { limit in
                        Text("\(limit) items").tag(limit)
                    }
                }

                Picker(
                    "Displayed clips",
                    selection: Binding(
                        get: { viewModel.displayLimit },
                        set: viewModel.updateDisplayLimit
                    )
                ) {
                    ForEach(SettingsViewModel.availableDisplayLimits, id: \.self) { limit in
                        Text("\(limit) items").tag(limit)
                    }
                }

                Toggle(
                    "Launch at login",
                    isOn: Binding(
                        get: { viewModel.launchAtLoginEnabled },
                        set: viewModel.updateLaunchAtLogin
                    )
                )
                }
                .formStyle(.grouped)

            case .ignoredApps:
                Form {
                    if viewModel.ignoredApplications.isEmpty {
                        Text("No ignored apps")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 20)
                    } else {
                        Section {
                            ForEach(viewModel.ignoredApplications) { application in
                                Toggle(
                                    isOn: Binding(
                                        get: { true },
                                        set: { isIgnored in
                                            if !isIgnored {
                                                viewModel.allowApplication(application)
                                            }
                                        }
                                    )
                                ) {
                                    HStack(spacing: 8) {
                                        ApplicationIcon(
                                            bundleIdentifier: application.bundleIdentifier
                                        )

                                        Text(application.displayName)
                                    }
                                    .padding(.leading, 4)
                                }
                                .toggleStyle(.checkbox)
                                .help("Allow clipboard history from \(application.displayName)")
                                .accessibilityHint(
                                    "Turn off to include this app in clipboard history"
                                )
                            }
                        } header: {
                            Text("Apps excluded from clipboard history")
                        }
                    }
                }
                .formStyle(.grouped)
            }
        }
        .navigationTitle("Settings")
        .frame(width: 440, height: 300)
        .alert(
            "Unable to Update Settings",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        viewModel.errorMessage = nil
                    }
                }
            )
        ) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

private enum SettingsTab: Hashable {
    case general
    case ignoredApps
}

private struct ApplicationIcon: View {
    let bundleIdentifier: String

    var body: some View {
        Group {
            if let applicationURL = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: bundleIdentifier
            ) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: applicationURL.path))
                    .resizable()
            } else {
                Image(systemName: "app")
                    .resizable()
                    .foregroundStyle(.secondary)
            }
        }
        .scaledToFit()
        .frame(width: 20, height: 20)
        .accessibilityHidden(true)
    }
}
