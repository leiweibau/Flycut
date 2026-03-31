import AppKit
import SwiftUI

@objc public protocol FlycutSearchWindowControllerDelegate: AnyObject {
    func searchWindowController(_ controller: FlycutSearchWindowController, didSelectStoreIndex storeIndex: NSNumber)
    func searchWindowControllerDidClose(_ controller: FlycutSearchWindowController)
}

private struct SearchClipItem: Identifiable, Equatable {
    let id: Int
    let storeIndex: Int
    let title: String
    let rawContent: String
    let isImage: Bool
    let previewImage: NSImage?

    init(dictionary: NSDictionary, index: Int) {
        self.storeIndex = (dictionary["storeIndex"] as? NSNumber)?.intValue ?? index
        self.id = self.storeIndex
        self.title = dictionary["title"] as? String ?? ""
        self.rawContent = dictionary["rawContent"] as? String ?? ""
        self.isImage = (dictionary["isImage"] as? NSNumber)?.boolValue ?? false
        if let data = dictionary["previewData"] as? Data {
            self.previewImage = NSImage(data: data)
        } else {
            self.previewImage = nil
        }
    }

    static func == (lhs: SearchClipItem, rhs: SearchClipItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.storeIndex == rhs.storeIndex &&
        lhs.title == rhs.title &&
        lhs.rawContent == rhs.rawContent &&
        lhs.isImage == rhs.isImage
    }
}

private final class SearchClipViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var items: [SearchClipItem] = []

    var filteredItems: [SearchClipItem] {
        guard !searchText.isEmpty else { return items }
        return items.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.rawContent.localizedCaseInsensitiveContains(searchText)
        }
    }
}

private struct SearchClipRowView: View {
    let item: SearchClipItem

    var body: some View {
        HStack(spacing: 10) {
            if item.isImage, let previewImage = item.previewImage {
                Image(nsImage: previewImage)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .frame(width: 18, height: 18)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }

            if item.isImage {
                Text(LocalizedStringKey("Image"))
                    .italic()
                    .lineLimit(1)
            } else {
                Text(item.title)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 28, maxHeight: 28, alignment: .leading)
    }
}

private struct SearchWindowContentView: View {
    @ObservedObject var viewModel: SearchClipViewModel
    let activate: (Int) -> Void

    @State private var selection: Int?
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 12) {
            TextField(LocalizedStringKey("Search"), text: $viewModel.searchText)
                .textFieldStyle(.roundedBorder)
                .focused($searchFocused)
                .onSubmit {
                    activateSelection()
                }

            List(viewModel.filteredItems, selection: $selection) { item in
                SearchClipRowView(item: item)
                    .tag(item.storeIndex)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selection = item.storeIndex
                    }
                    .onTapGesture(count: 2) {
                        activate(item.storeIndex)
                    }
            }
            .listStyle(.inset)
        }
        .padding(16)
        .frame(minWidth: 640, minHeight: 420)
        .background(.regularMaterial)
        .onAppear {
            selection = selection ?? viewModel.filteredItems.first?.storeIndex
            DispatchQueue.main.async {
                searchFocused = true
            }
        }
        .onChange(of: viewModel.items) { _ in
            syncSelection()
        }
        .onChange(of: viewModel.searchText) { _ in
            syncSelection()
        }
    }

    private func syncSelection() {
        let newValue = viewModel.filteredItems
        if let selection, !newValue.contains(where: { $0.storeIndex == selection }) {
            self.selection = newValue.first?.storeIndex
        } else if self.selection == nil {
            self.selection = newValue.first?.storeIndex
        }
    }

    private func activateSelection() {
        if let selection {
            activate(selection)
        } else if let first = viewModel.filteredItems.first {
            activate(first.storeIndex)
        }
    }
}

private final class FlycutSearchHostWindow: NSWindow {
    var closeHandler: (() -> Void)?

    override func cancelOperation(_ sender: Any?) {
        closeHandler?()
    }

    override func performClose(_ sender: Any?) {
        closeHandler?()
    }
}

@objcMembers public final class FlycutSearchWindowController: NSWindowController, NSWindowDelegate {
    public weak var bridgeDelegate: FlycutSearchWindowControllerDelegate?

    private let viewModel = SearchClipViewModel()
    private var isVisible = false

    public init() {
        let window = FlycutSearchHostWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 420),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        let hostingView = NSHostingView(rootView: SearchWindowContentView(viewModel: viewModel, activate: { _ in }))

        window.contentView = hostingView
        window.title = NSLocalizedString("Search Clipboard", comment: "")
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)

        hostingView.rootView = SearchWindowContentView(
            viewModel: viewModel,
            activate: { [weak self] index in
                if let self {
                    self.bridgeDelegate?.searchWindowController(self, didSelectStoreIndex: NSNumber(value: index))
                    self.hideWindow()
                }
            }
        )

        window.delegate = self
        window.closeHandler = { [weak self] in
            self?.hideWindow()
        }
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func updateItems(_ items: [NSDictionary]) {
        viewModel.items = items.enumerated().map { offset, element in
            SearchClipItem(dictionary: element, index: offset)
        }
    }

    public func showAndFocus() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        isVisible = true
    }

    public func hideWindow() {
        guard isVisible else { return }
        window?.orderOut(nil)
        isVisible = false
        bridgeDelegate?.searchWindowControllerDidClose(self)
    }

    public func windowWillClose(_ notification: Notification) {
        if isVisible {
            isVisible = false
            bridgeDelegate?.searchWindowControllerDidClose(self)
        }
    }
}
