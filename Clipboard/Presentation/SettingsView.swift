import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    private let githubProfileURL = URL(string: "https://github.com/pranit-sh")!
    private let githubRepositoryURL = URL(string: "https://github.com/pranit-sh/recall")!

    var body: some View {
        VStack(spacing: 0) {
            TabView {
                Form {
                    Section("Storage") {
                        Picker(
                            "Saved text clips",
                            selection: Binding(
                                get: { viewModel.textHistoryLimit },
                                set: viewModel.updateTextHistoryLimit
                            )
                        ) {
                            ForEach(
                                SettingsViewModel.availableTextHistoryLimits,
                                id: \.self
                            ) { limit in
                                Text("\(limit) clips").tag(limit)
                            }
                        }

                        Picker(
                            "Saved images",
                            selection: Binding(
                                get: { viewModel.imageLimit },
                                set: viewModel.updateImageLimit
                            )
                        ) {
                            ForEach(SettingsViewModel.availableImageLimits, id: \.self) { limit in
                                Text("\(limit) images").tag(limit)
                            }
                        }

                        Picker(
                            "Image storage",
                            selection: Binding(
                                get: { viewModel.imageStorageLimitInMegabytes },
                                set: viewModel.updateImageStorageLimitInMegabytes
                            )
                        ) {
                            ForEach(
                                SettingsViewModel.availableImageStorageLimitsInMegabytes,
                                id: \.self
                            ) { limit in
                                Text("\(limit) MB").tag(limit)
                            }
                        }
                    }

                    Section("Application") {
                        Picker(
                            "Items shown",
                            selection: Binding(
                                get: { viewModel.displayLimit },
                                set: viewModel.updateDisplayLimit
                            )
                        ) {
                            ForEach(SettingsViewModel.availableDisplayLimits, id: \.self) { limit in
                                Text("\(limit) clips").tag(limit)
                            }
                        }

                        Toggle(
                            "Launch on system startup",
                            isOn: Binding(
                                get: { viewModel.launchAtLoginEnabled },
                                set: viewModel.updateLaunchAtLogin
                            )
                        )
                    }
                }
                .formStyle(.grouped)
                .navigationTitle("Settings")
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

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
                .navigationTitle("Settings")
                .tabItem {
                    Label("Ignored Apps", systemImage: "eye.slash")
                }
            }

            Divider()

            HStack {
                Text("Version \(viewModel.currentVersion)")

                updateStatusView

                Spacer()

                Text("© 2026")

                Link("pranit-sh", destination: githubProfileURL)
                    .accessibilityLabel("Copyright 2026, pranit-sh on GitHub")

                Text("·")

                Link("GitHub", destination: githubRepositoryURL)
                    .accessibilityLabel("Recall project on GitHub")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, 8)
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
        .frame(width: 420, height: 300)
        .task {
            await viewModel.checkForUpdates()
        }
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

    @ViewBuilder
    private var updateStatusView: some View {
        switch viewModel.updateStatus {
        case .idle, .checking, .upToDate, .failed:
            EmptyView()
        case .updateAvailable(let release):
            Link(destination: release.pageURL) {
                Label("\(release.version) available", systemImage: "arrow.down.circle")
            }
            .help("Open the Recall \(release.version) release on GitHub")
        }
    }
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
