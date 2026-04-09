import AppKit
import ImageIO
import SwiftUI

@objc public protocol FlycutStatusPopoverControllerDelegate: AnyObject {
    func statusPopoverController(_ controller: FlycutStatusPopoverController, didSelectStoreIndex storeIndex: NSNumber)
    func statusPopoverController(_ controller: FlycutStatusPopoverController, searchTextDidChange searchText: String)
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
    let sourceName: String
    let dateText: String
    let isImage: Bool
    let previewData: Data?

    init(dictionary: NSDictionary, index: Int) {
        self.storeIndex = (dictionary["storeIndex"] as? NSNumber)?.intValue ?? index
        self.id = self.storeIndex
        self.title = dictionary["title"] as? String ?? ""
        self.sourceName = dictionary["sourceName"] as? String ?? ""
        self.dateText = dictionary["dateText"] as? String ?? ""
        self.isImage = (dictionary["isImage"] as? NSNumber)?.boolValue ?? false
        if let data = dictionary["previewData"] as? Data {
            self.previewData = data
        } else if let image = dictionary["previewImage"] as? NSImage {
            self.previewData = image.tiffRepresentation
        } else {
            self.previewData = nil
        }
    }
}

private final class FlycutThumbnailCache {
    static let shared = NSCache<NSString, NSImage>()
}

private final class FlycutThumbnailLoader: ObservableObject {
    @Published var image: NSImage?

    private var requestedKey: NSString?

    func load(previewData: Data?, cacheKey: NSString, size: CGFloat) {
        requestedKey = cacheKey

        guard let previewData, !previewData.isEmpty else {
            image = nil
            return
        }

        if let cachedImage = FlycutThumbnailCache.shared.object(forKey: cacheKey) {
            image = cachedImage
            return
        }

        image = nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            guard let cgImageSource = CGImageSourceCreateWithData(previewData as CFData, nil) else { return }

            let options: [NSString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: Int(size * 2.0)
            ]

            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(cgImageSource, 0, options as CFDictionary) else { return }
            let thumbnail = NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))
            FlycutThumbnailCache.shared.setObject(thumbnail, forKey: cacheKey)

            DispatchQueue.main.async { [weak self] in
                guard let self, self.requestedKey == cacheKey else { return }
                self.image = thumbnail
            }
        }
    }
}

private struct FlycutStatusThumbnailView: View {
    let previewData: Data?
    let cacheKey: NSString
    let size: CGFloat

    @StateObject private var loader = FlycutThumbnailLoader()

    var body: some View {
        Group {
            if let image = loader.image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                    Image(systemName: "photo")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        )
        .onAppear {
            loader.load(previewData: previewData, cacheKey: cacheKey, size: size)
        }
        .onChange(of: cacheKey as String) { _ in
            loader.load(previewData: previewData, cacheKey: cacheKey, size: size)
        }
        .onChange(of: previewData?.hashValue ?? 0) { _ in
            loader.load(previewData: previewData, cacheKey: cacheKey, size: size)
        }
    }
}

private final class FlycutStatusPopoverViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var items: [StatusClipItem] = []
    @Published var preferredHeight: CGFloat = 560
    @Published var scrollResetToken = 0
}

private struct FlycutStatusClipRow: View {
    let item: StatusClipItem
    let activate: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: activate) {
            HStack(spacing: 12) {
                if item.isImage {
                    FlycutStatusThumbnailView(
                        previewData: item.previewData,
                        cacheKey: "\(item.id)-34" as NSString,
                        size: 34
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
            ZStack {
                backgroundView

                Text(titleKey)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 10)
            }
            .frame(maxWidth: .infinity, minHeight: 34, maxHeight: 34)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .foregroundStyle(foregroundStyle)
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
    let searchChanged: (String) -> Void

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

                        if model.items.isEmpty {
                            Text(LocalizedStringKey("Empty"))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, minHeight: 220)
                        } else {
                            ForEach(model.items) { item in
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
        .onChange(of: model.searchText) { newValue in
            searchChanged(newValue)
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
                quit: {},
                searchChanged: { _ in }
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
            },
            searchChanged: { [weak self] searchText in
                guard let self else { return }
                self.bridgeDelegate?.statusPopoverController(self, searchTextDidChange: searchText)
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
