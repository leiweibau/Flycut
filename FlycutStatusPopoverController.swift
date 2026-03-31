import AppKit
import SwiftUI

@objc public protocol FlycutStatusPopoverControllerDelegate: AnyObject {
    func statusPopoverController(_ controller: FlycutStatusPopoverController, didSelectStoreIndex storeIndex: NSNumber)
    func statusPopoverControllerDidRequestClearAll(_ controller: FlycutStatusPopoverController)
    func statusPopoverControllerDidRequestMergeAll(_ controller: FlycutStatusPopoverController)
    func statusPopoverControllerDidRequestPreferences(_ controller: FlycutStatusPopoverController)
    func statusPopoverControllerDidRequestAbout(_ controller: FlycutStatusPopoverController)
    func statusPopoverControllerDidRequestQuit(_ controller: FlycutStatusPopoverController)
    func statusPopoverControllerDidClose(_ controller: FlycutStatusPopoverController)
}

private struct StatusClipItem: Identifiable, Equatable {
    let id: Int
    let storeIndex: Int
    let title: String
    let rawContent: String
    let sourceName: String
    let dateText: String
    let isImage: Bool
    let previewImage: NSImage?

    init(dictionary: NSDictionary, index: Int) {
        self.storeIndex = (dictionary["storeIndex"] as? NSNumber)?.intValue ?? index
        self.id = self.storeIndex
        self.title = dictionary["title"] as? String ?? ""
        self.rawContent = dictionary["rawContent"] as? String ?? ""
        self.sourceName = dictionary["sourceName"] as? String ?? ""
        self.dateText = dictionary["dateText"] as? String ?? ""
        self.isImage = (dictionary["isImage"] as? NSNumber)?.boolValue ?? false
        if let image = dictionary["previewImage"] as? NSImage {
            self.previewImage = image
        } else if let data = dictionary["previewData"] as? Data {
            self.previewImage = NSImage(data: data)
        } else {
            self.previewImage = nil
        }
    }
}

private final class FlycutStatusPopoverViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var items: [StatusClipItem] = []
    @Published var preferredHeight: CGFloat = 560
    @Published var scrollResetToken = 0

    var filteredItems: [StatusClipItem] {
        guard !searchText.isEmpty else { return items }

        return items.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.rawContent.localizedCaseInsensitiveContains(searchText) ||
            $0.sourceName.localizedCaseInsensitiveContains(searchText)
        }
    }
}

private struct FlycutStatusClipRow: View {
    let item: StatusClipItem
    let activate: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: activate) {
            HStack(spacing: 12) {
                if item.isImage, let previewImage = item.previewImage {
                    Image(nsImage: previewImage)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFill()
                        .frame(width: 34, height: 34)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.system(size: 13, weight: .semibold))
                        .italic(item.isImage)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if !metadata.isEmpty {
                        Text(metadata)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .background(backgroundView)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered in
            self.hovered = hovered
        }
    }

    private var metadata: String {
        [item.sourceName, item.dateText]
            .filter { !$0.isEmpty }
            .joined(separator: " • ")
    }

    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(hovered ? Color.primary.opacity(0.10) : Color.primary.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(hovered ? 0.16 : 0.06), lineWidth: 1)
            )
    }
}

private struct FlycutStatusFooterButton: View {
    let titleKey: LocalizedStringKey
    let role: ButtonRole?
    let action: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(role: role, action: action) {
            Text(titleKey)
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .foregroundStyle(foregroundStyle)
        .background(backgroundView)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(Rectangle())
        .onHover { hovered in
            self.hovered = hovered
        }
    }

    private var foregroundStyle: Color {
        role == .destructive ? .red.opacity(0.9) : .primary
    }

    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(hovered ? Color.primary.opacity(0.10) : Color.primary.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.white.opacity(hovered ? 0.14 : 0.06), lineWidth: 1)
            )
    }
}

private struct FlycutStatusPopoverContentView: View {
    @ObservedObject var model: FlycutStatusPopoverViewModel
    let activate: (Int) -> Void
    let clearAll: () -> Void
    let mergeAll: () -> Void
    let preferences: () -> Void
    let about: () -> Void
    let quit: () -> Void

    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                TextField(LocalizedStringKey("Search"), text: $model.searchText)
                    .textFieldStyle(.roundedBorder)
                    .focused($searchFocused)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 14)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        Color.clear
                            .frame(height: 0)
                            .id("top-anchor")

                        if model.filteredItems.isEmpty {
                            Text(LocalizedStringKey("Empty"))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, minHeight: 220)
                        } else {
                            ForEach(model.filteredItems) { item in
                                FlycutStatusClipRow(item: item) {
                                    activate(item.storeIndex)
                                }
                            }
                        }
                    }
                    .padding(12)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    scrollToTop(using: proxy)
                }
                .onChange(of: model.scrollResetToken) { _ in
                    scrollToTop(using: proxy)
                }
            }

            Divider()

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    FlycutStatusFooterButton(titleKey: LocalizedStringKey("Clear All"), role: .destructive, action: clearAll)
                    FlycutStatusFooterButton(titleKey: LocalizedStringKey("Merge All"), role: nil, action: mergeAll)
                }

                HStack(spacing: 8) {
                    FlycutStatusFooterButton(titleKey: LocalizedStringKey("Preferences…"), role: nil, action: preferences)
                    FlycutStatusFooterButton(titleKey: LocalizedStringKey("About Flycut"), role: nil, action: about)
                    FlycutStatusFooterButton(titleKey: LocalizedStringKey("Quit"), role: nil, action: quit)
                }
            }
            .padding(12)
        }
        .frame(width: 432)
        .frame(height: model.preferredHeight)
        .background(.regularMaterial)
        .onAppear {
            DispatchQueue.main.async {
                searchFocused = true
            }
        }
    }

    private func scrollToTop(using proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            proxy.scrollTo("top-anchor", anchor: .top)
        }
    }
}

@objcMembers public final class FlycutStatusPopoverController: NSObject, NSPopoverDelegate {
    public weak var bridgeDelegate: FlycutStatusPopoverControllerDelegate?

    private let viewModel = FlycutStatusPopoverViewModel()
    private let popover = NSPopover()
    private let hostingController: NSHostingController<FlycutStatusPopoverContentView>

    public override init() {
        self.hostingController = NSHostingController(
            rootView: FlycutStatusPopoverContentView(
                model: viewModel,
                activate: { _ in },
                clearAll: {},
                mergeAll: {},
                preferences: {},
                about: {},
                quit: {}
            )
        )

        super.init()

        self.hostingController.rootView = FlycutStatusPopoverContentView(
            model: viewModel,
            activate: { [weak self] storeIndex in
                guard let self else { return }
                self.closePopover()
                self.bridgeDelegate?.statusPopoverController(self, didSelectStoreIndex: NSNumber(value: storeIndex))
            },
            clearAll: { [weak self] in
                guard let self else { return }
                self.closePopover()
                self.bridgeDelegate?.statusPopoverControllerDidRequestClearAll(self)
            },
            mergeAll: { [weak self] in
                guard let self else { return }
                self.closePopover()
                self.bridgeDelegate?.statusPopoverControllerDidRequestMergeAll(self)
            },
            preferences: { [weak self] in
                guard let self else { return }
                self.closePopover()
                self.bridgeDelegate?.statusPopoverControllerDidRequestPreferences(self)
            },
            about: { [weak self] in
                guard let self else { return }
                self.closePopover()
                self.bridgeDelegate?.statusPopoverControllerDidRequestAbout(self)
            },
            quit: { [weak self] in
                guard let self else { return }
                self.closePopover()
                self.bridgeDelegate?.statusPopoverControllerDidRequestQuit(self)
            }
        )

        popover.animates = true
        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = hostingController
        popover.contentSize = NSSize(width: 432, height: viewModel.preferredHeight)
    }

    public var isShown: Bool {
        popover.isShown
    }

    public func updateItems(_ items: [NSDictionary]) {
        viewModel.items = items.enumerated().map { offset, element in
            StatusClipItem(dictionary: element, index: offset)
        }
    }

    public func resetSearch() {
        viewModel.searchText = ""
    }

    @objc(toggleWithRelativeTo:of:)
    public func toggle(relativeTo positioningRect: NSRect, of positioningView: NSView) {
        if popover.isShown {
            closePopover()
            return
        }

        viewModel.searchText = ""
        viewModel.scrollResetToken += 1

        if let screenHeight = positioningView.window?.screen?.visibleFrame.height {
            let height = max(screenHeight - 40, 420)
            viewModel.preferredHeight = height
            popover.contentSize = NSSize(width: 432, height: height)
        }

        popover.show(relativeTo: positioningRect, of: positioningView, preferredEdge: .minY)
    }

    public func closePopover() {
        popover.performClose(nil)
    }

    public func popoverDidClose(_ notification: Notification) {
        bridgeDelegate?.statusPopoverControllerDidClose(self)
    }
}
