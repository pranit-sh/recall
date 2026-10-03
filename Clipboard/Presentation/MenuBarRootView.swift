import AppKit
import SwiftUI

struct MenuBarRootView: View {
    @Environment(\.openSettings) private var openSettings
    @ObservedObject var viewModel: ClipboardHistoryViewModel
    @FocusState private var isSearchFocused: Bool
    @State private var hoveredItemID: ClipboardItem.ID?
    @State private var selectedAction: PopoverAction?

    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.items.isEmpty {
                searchField

                Divider()
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if viewModel.filteredItems.isEmpty {
                            Text(viewModel.items.isEmpty ? "No Clipboard History" : "No Results")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 10)
                                .frame(height: emptyStateHeight)
                        } else {
                            ForEach(viewModel.displayedItems) { item in
                                ClipboardHistoryRow(
                                    item: item,
                                    isSelected: item.id == viewModel.selectedItemID,
                                    isHighlighted: item.id == hoveredItemID
                                        || (hoveredItemID == nil && item.id == viewModel.selectedItemID)
                                ) {
                                    viewModel.select(item)
                                } onHoverChange: { isHovered in
                                    updateHoveredItem(item.id, isHovered: isHovered)
                                }
                                .id(item.id)
                            }
                        }

                        Divider()
                            .padding(.vertical, 3)

                        actionRows
                    }
                    .padding(3)
                }
                .onChange(of: viewModel.selectedItemID) { selectedItemID in
                    guard let selectedItemID else { return }
                    proxy.scrollTo(selectedItemID)
                }
            }
        }
        .padding(4)
        .frame(width: 320, height: popoverHeight)
        .onAppear {
            viewModel.prepareForPresentation()
            hoveredItemID = nil
            selectedAction = nil
            isSearchFocused = true
        }
        .onChange(of: viewModel.searchText) { _ in
            selectedAction = nil
        }
        .onHover { isInsidePopover in
            guard !isInsidePopover else { return }
            hoveredItemID = nil
            viewModel.clearSelection()
        }
        .background {
            KeyboardNavigationMonitor(
                onMove: moveKeyboardSelection,
                onConfirm: activateKeyboardSelection
            )
        }
    }

    private var searchField: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            TextField(viewModel.searchPrompt, text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
                .accessibilityLabel("Search clipboard history")

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Clear Search")
                .accessibilityLabel("Clear Search")
            }
        }
        .padding(.horizontal, 6)
        .frame(height: 30)
    }

    private var actionRows: some View {
        VStack(spacing: 0) {
            PopoverActionRow(
                title: viewModel.currentApplicationPrivacyActionTitle,
                isEnabled: viewModel.canConfigureCurrentApplication,
                isKeyboardHighlighted: selectedAction == .privacy,
                showsCheckmark: viewModel.isCurrentApplicationIgnored
            ) {
                viewModel.toggleCurrentApplicationPrivacy()
            } onHoverChange: { isHovered in
                clearKeyboardSelectionWhenHovering(isHovered)
            }

            Divider()
                .padding(.vertical, 3)

            PopoverActionRow(
                title: "Clear History",
                isEnabled: !viewModel.items.isEmpty,
                isKeyboardHighlighted: selectedAction == .clearHistory
            ) {
                confirmClearHistory()
            } onHoverChange: { isHovered in
                clearKeyboardSelectionWhenHovering(isHovered)
            }

            PopoverActionRow(
                title: "Settings",
                isKeyboardHighlighted: selectedAction == .settings
            ) {
                openSettingsInForeground()
            } onHoverChange: { isHovered in
                clearKeyboardSelectionWhenHovering(isHovered)
            }

            Divider()
                .padding(.vertical, 3)

            PopoverActionRow(
                title: "Quit",
                isKeyboardHighlighted: selectedAction == .quit
            ) {
                NSApp.terminate(nil)
            } onHoverChange: { isHovered in
                clearKeyboardSelectionWhenHovering(isHovered)
            }
        }
    }

    private var enabledActions: [PopoverAction] {
        var actions: [PopoverAction] = []
        if viewModel.canConfigureCurrentApplication {
            actions.append(.privacy)
        }
        if !viewModel.items.isEmpty {
            actions.append(.clearHistory)
        }
        actions.append(.settings)
        actions.append(.quit)
        return actions
    }

    private func moveKeyboardSelection(by offset: Int) {
        hoveredItemID = nil

        if let selectedAction,
           let currentIndex = enabledActions.firstIndex(of: selectedAction) {
            let nextIndex = currentIndex + offset
            if nextIndex < 0, !viewModel.displayedItems.isEmpty {
                self.selectedAction = nil
                viewModel.moveSelection(by: -1)
            } else {
                self.selectedAction = enabledActions[
                    min(max(nextIndex, 0), enabledActions.count - 1)
                ]
            }
            return
        }

        if viewModel.displayedItems.isEmpty {
            selectedAction = offset < 0 ? enabledActions.last : enabledActions.first
        } else if offset > 0,
                  viewModel.selectedItemID == viewModel.displayedItems.last?.id {
            viewModel.clearSelection()
            selectedAction = enabledActions.first
        } else {
            viewModel.moveSelection(by: offset)
        }
    }

    private func activateKeyboardSelection() {
        switch selectedAction {
        case .privacy:
            viewModel.toggleCurrentApplicationPrivacy()
        case .clearHistory:
            confirmClearHistory()
        case .settings:
            openSettingsInForeground()
        case .quit:
            NSApp.terminate(nil)
        case nil:
            viewModel.selectCurrentItem()
        }
    }

    private func clearKeyboardSelectionWhenHovering(_ isHovered: Bool) {
        guard isHovered else { return }
        selectedAction = nil
        viewModel.clearSelection()
        hoveredItemID = nil
    }

    private func openSettingsInForeground() {
        viewModel.dismissPopover()
        openSettings()

        DispatchQueue.main.async {
            NSApp.activate()
            NSApp.orderedWindows
                .first(where: { $0.isVisible && $0.canBecomeKey })?
                .makeKeyAndOrderFront(nil)
        }
    }

    private func confirmClearHistory() {
        viewModel.dismissPopover()

        DispatchQueue.main.async {
            NSApp.activate()

            let alert = NSAlert()
            alert.messageText = "Clear History?"
            alert.informativeText = "This removes all saved clipboard items."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Clear")
            alert.addButton(withTitle: "Cancel")
            alert.buttons.first?.hasDestructiveAction = true

            if alert.runModal() == .alertFirstButtonReturn {
                viewModel.clearHistory()
            }
        }
    }

    private func updateHoveredItem(_ itemID: ClipboardItem.ID, isHovered: Bool) {
        if isHovered {
            selectedAction = nil
            hoveredItemID = itemID
        } else if hoveredItemID == itemID {
            hoveredItemID = nil
        }
    }

    private var popoverHeight: CGFloat {
        let rowHeight: CGFloat = 24
        let chromeHeight: CGFloat = viewModel.items.isEmpty ? 35 : 66
        let historyHeight = viewModel.displayedItems.isEmpty
            ? emptyStateHeight
            : CGFloat(viewModel.displayedItems.count) * rowHeight
        let actionCount = 4
        let contentHeight = chromeHeight
            + historyHeight
            + CGFloat(actionCount) * rowHeight

        return contentHeight
    }

    private var emptyStateHeight: CGFloat { 24 }
}

private enum PopoverAction {
    case privacy
    case clearHistory
    case settings
    case quit
}

private struct ClipboardHistoryRow: View {
    let item: ClipboardItem
    let isSelected: Bool
    let isHighlighted: Bool
    let action: () -> Void
    let onHoverChange: (Bool) -> Void

    var body: some View {
        Button(action: action) {
            Text(item.text)
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(
                    isHighlighted
                        ? Color(nsColor: .alternateSelectedControlTextColor)
                        : Color.primary
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .frame(height: 24)
                .contentShape(Rectangle())
                .background(
                    isHighlighted
                        ? Color(nsColor: .selectedContentBackgroundColor)
                        : Color.clear,
                    in: RoundedRectangle(cornerRadius: 6)
                )
        }
        .buttonStyle(.plain)
        .help(item.text)
        .accessibilityLabel(item.text)
        .accessibilityHint("Copies this item to the clipboard")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .onHover(perform: onHoverChange)
    }
}

private struct PopoverActionRow: View {
    let title: String
    var isEnabled = true
    var isKeyboardHighlighted = false
    var showsCheckmark = false
    let action: () -> Void
    var onHoverChange: (Bool) -> Void = { _ in }

    @State private var isHovered = false

    private var isHighlighted: Bool {
        isHovered || isKeyboardHighlighted
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if showsCheckmark {
                    Image(systemName: "checkmark")
                        .accessibilityHidden(true)
                }
            }
                .foregroundStyle(
                    isHighlighted
                        ? Color(nsColor: .alternateSelectedControlTextColor)
                        : Color.primary
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .frame(height: 24)
                .contentShape(Rectangle())
                .background(
                    isHighlighted
                        ? Color(nsColor: .selectedContentBackgroundColor)
                        : Color.clear,
                    in: RoundedRectangle(cornerRadius: 6)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityValue(showsCheckmark ? "On" : "Off")
        .accessibilityAddTraits(isKeyboardHighlighted ? .isSelected : [])
        .onHover {
            isHovered = isEnabled && $0
            onHoverChange(isHovered)
        }
    }
}
