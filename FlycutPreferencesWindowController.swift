import AppKit
import SwiftUI

@objc public protocol FlycutPreferencesWindowControllerDelegate: AnyObject {
    func preferencesWindowControllerDidRequestAccessibilityCheck(_ controller: FlycutPreferencesWindowController)
    func preferencesWindowController(_ controller: FlycutPreferencesWindowController, didRequestSelectSaveLocation autoSave: NSNumber)
    func preferencesWindowController(_ controller: FlycutPreferencesWindowController, didChangeMainHotKeyKeyCode keyCode: NSNumber, modifierFlags: NSNumber)
    func preferencesWindowController(_ controller: FlycutPreferencesWindowController, didChangeSearchHotKeyKeyCode keyCode: NSNumber, modifierFlags: NSNumber)
    func preferencesWindowController(_ controller: FlycutPreferencesWindowController, didChangeRememberNum value: NSNumber)
    func preferencesWindowController(_ controller: FlycutPreferencesWindowController, didChangeFavoritesRememberNum value: NSNumber)
    func preferencesWindowControllerDidChangeDisplayNum(_ controller: FlycutPreferencesWindowController)
    func preferencesWindowControllerDidChangeBezelAppearance(_ controller: FlycutPreferencesWindowController)
    func preferencesWindowControllerDidChangeMenuIcon(_ controller: FlycutPreferencesWindowController)
    func preferencesWindowControllerDidChangeDisplaySource(_ controller: FlycutPreferencesWindowController)
    func preferencesWindowControllerDidChangeLoadOnStartup(_ controller: FlycutPreferencesWindowController)
    func preferencesWindowControllerDidChangeSyncSettings(_ controller: FlycutPreferencesWindowController)
    func preferencesWindowControllerDidChangeSyncClippings(_ controller: FlycutPreferencesWindowController)
    func preferencesWindowControllerDidChangeSavePreference(_ controller: FlycutPreferencesWindowController)
}

private enum PreferencesTab: String, CaseIterable, Identifiable {
    case general
    case hotkeys
    case appearance
    case acknowledgements

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .general:
            return "General"
        case .hotkeys:
            return "Hotkeys"
        case .appearance:
            return "Appearance"
        case .acknowledgements:
            return "Acknowledgements"
        }
    }

    var symbolName: String {
        switch self {
        case .general:
            return "slider.horizontal.3"
        case .hotkeys:
            return "keyboard"
        case .appearance:
            return "paintbrush"
        case .acknowledgements:
            return "text.document"
        }
    }
}

private struct HotKeyValue: Equatable {
    var keyCode: Int
    var modifierFlags: Int

    static let empty = HotKeyValue(keyCode: -1, modifierFlags: 0)
}

private struct ShortcutReference: Identifiable {
    let shortcutKey: LocalizedStringKey
    let actionKey: LocalizedStringKey

    var id: String { "\(String(describing: shortcutKey))-\(String(describing: actionKey))" }
}

private struct ShortcutReferenceSection: Identifiable {
    let title: LocalizedStringKey
    let entries: [ShortcutReference]

    var id: String { String(describing: title) }
}

private let inAppShortcutSections: [ShortcutReferenceSection] = [
    ShortcutReferenceSection(title: "Bezel Navigation", entries: [
        ShortcutReference(shortcutKey: "Up/Left Arrow or K", actionKey: "Move to newer item"),
        ShortcutReference(shortcutKey: "Down/Right Arrow or J", actionKey: "Move to older item"),
        ShortcutReference(shortcutKey: "Home", actionKey: "Jump to most recent item"),
        ShortcutReference(shortcutKey: "End", actionKey: "Jump to oldest item"),
        ShortcutReference(shortcutKey: "Page Up / Page Down", actionKey: "Move 10 items forward/back"),
        ShortcutReference(shortcutKey: "1-9, 0", actionKey: "Jump to position (0 = 10th)"),
        ShortcutReference(shortcutKey: "Scroll Wheel", actionKey: "Navigate history"),
    ]),
    ShortcutReferenceSection(title: "Bezel Actions", entries: [
        ShortcutReference(shortcutKey: "Return", actionKey: "Paste selected item"),
        ShortcutReference(shortcutKey: "Fn+Return", actionKey: "Move item to top of history"),
        ShortcutReference(shortcutKey: "Backspace/Delete", actionKey: "Delete selected item"),
        ShortcutReference(shortcutKey: "Escape", actionKey: "Close without pasting"),
        ShortcutReference(shortcutKey: "Double-Click", actionKey: "Paste item"),
        ShortcutReference(shortcutKey: "Command+,", actionKey: "Open preferences"),
        ShortcutReference(shortcutKey: "S", actionKey: "Save item to Desktop"),
        ShortcutReference(shortcutKey: "Shift+S", actionKey: "Save to Desktop and delete"),
        ShortcutReference(shortcutKey: "F", actionKey: "Toggle favorites store"),
        ShortcutReference(shortcutKey: "Shift+F", actionKey: "Move item to favorites"),
        ShortcutReference(shortcutKey: "Space", actionKey: "Pin bezel open (sticky mode)"),
        ShortcutReference(shortcutKey: "Right-Click", actionKey: "Pin bezel open (sticky mode)"),
    ]),
    ShortcutReferenceSection(title: "Menu Bar", entries: [
        ShortcutReference(shortcutKey: "Option+Click menu icon", actionKey: "Toggle clipboard tracking on/off"),
    ]),
]

private final class FlycutPreferencesBridge: ObservableObject {
    weak var delegate: FlycutPreferencesWindowControllerDelegate?

    @Published var selectedTab: PreferencesTab = .general
    @Published var mainHotKey: HotKeyValue = .empty
    @Published var searchHotKey: HotKeyValue = .empty
    @Published var saveToLocationTitle = NSLocalizedString("Choose Folder…", comment: "")
    @Published var autoSaveToLocationTitle = NSLocalizedString("Choose Folder…", comment: "")
    @Published var acknowledgementsText = ""

    func refreshDynamicContent() {
        mainHotKey = hotKeyValue(for: "ShortcutRecorder mainHotkey")
        searchHotKey = hotKeyValue(for: "ShortcutRecorder searchHotkey")
        saveToLocationTitle = titleForURL(defaultsKey: "saveToLocation")
        autoSaveToLocationTitle = titleForURL(defaultsKey: "autoSaveToLocation")
        acknowledgementsText = loadAcknowledgements()
    }

    func updateMainHotKey(_ value: HotKeyValue, controller: FlycutPreferencesWindowController) {
        mainHotKey = value
        persistHotKey(value, key: "ShortcutRecorder mainHotkey")
        delegate?.preferencesWindowController(controller, didChangeMainHotKeyKeyCode: NSNumber(value: value.keyCode), modifierFlags: NSNumber(value: value.modifierFlags))
    }

    func updateSearchHotKey(_ value: HotKeyValue, controller: FlycutPreferencesWindowController) {
        searchHotKey = value
        persistHotKey(value, key: "ShortcutRecorder searchHotkey")
        delegate?.preferencesWindowController(controller, didChangeSearchHotKeyKeyCode: NSNumber(value: value.keyCode), modifierFlags: NSNumber(value: value.modifierFlags))
    }

    private func hotKeyValue(for key: String) -> HotKeyValue {
        let defaults = UserDefaults.standard
        guard
            let dictionary = defaults.dictionary(forKey: key),
            let keyCode = dictionary["keyCode"] as? NSNumber,
            let modifierFlags = dictionary["modifierFlags"] as? NSNumber
        else {
            return .empty
        }

        return HotKeyValue(keyCode: keyCode.intValue, modifierFlags: modifierFlags.intValue)
    }

    private func persistHotKey(_ value: HotKeyValue, key: String) {
        UserDefaults.standard.set([
            "keyCode": NSNumber(value: value.keyCode),
            "modifierFlags": NSNumber(value: value.modifierFlags),
        ], forKey: key)
    }

    private func titleForURL(defaultsKey: String) -> String {
        if let url = UserDefaults.standard.url(forKey: defaultsKey) {
            return url.lastPathComponent
        }

        return NSLocalizedString("Choose Folder…", comment: "")
    }

    private func loadAcknowledgements() -> String {
        guard let fileRoot = Bundle.main.path(forResource: "acknowledgements", ofType: "txt") else {
            return NSLocalizedString("No acknowledgements found.", comment: "")
        }

        return (try? String(contentsOfFile: fileRoot, encoding: .utf8)) ?? NSLocalizedString("No acknowledgements found.", comment: "")
    }
}

private struct HotKeyRecorderView: NSViewRepresentable {
    @Binding var value: HotKeyValue

    func makeCoordinator() -> Coordinator {
        Coordinator(value: $value)
    }

    func makeNSView(context: Context) -> SRRecorderControl {
        let recorder = SRRecorderControl(frame: NSRect(x: 0, y: 0, width: 260, height: 25))
        recorder.setCanCaptureGlobalHotKeys(true)
        recorder.setAllowsKeyOnly(false, escapeKeysRecord: false)
        recorder.setDelegate(context.coordinator)
        recorder.setKeyCombo(makeKeyCombo(from: value))
        return recorder
    }

    func updateNSView(_ nsView: SRRecorderControl, context: Context) {
        let combo = nsView.keyCombo()
        if Int(combo.code) != value.keyCode || Int(combo.flags) != value.modifierFlags {
            nsView.setKeyCombo(makeKeyCombo(from: value))
        }
    }

    private func makeKeyCombo(from value: HotKeyValue) -> KeyCombo {
        KeyCombo(flags: UInt(value.modifierFlags), code: value.keyCode)
    }

    final class Coordinator: NSObject {
        @Binding private var value: HotKeyValue

        init(value: Binding<HotKeyValue>) {
            _value = value
        }

        @objc override func shortcutRecorder(_ aRecorder: SRRecorderControl, keyComboDidChange newKeyCombo: KeyCombo) {
            value = HotKeyValue(keyCode: Int(newKeyCombo.code), modifierFlags: Int(newKeyCombo.flags))
        }

        @objc override func shortcutRecorder(_ aRecorder: SRRecorderControl, isKeyCode keyCode: Int, andFlagsTaken flags: UInt, reason: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
            false
        }
    }
}

private struct PreferenceSection<Content: View>: View {
    let titleKey: LocalizedStringKey
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(titleKey)
                .font(.headline)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}

private struct PreferencesSidebarButton: View {
    let tab: PreferencesTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: tab.symbolName)
                    .frame(width: 18)
                Text(tab.titleKey)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.primary.opacity(0.001))
            )
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

private struct PreferencesDetailContainer<Content: View>: View {
    let tab: PreferencesTab
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text(tab.titleKey)
                    .font(.system(size: 24, weight: .semibold))
                Text(descriptionText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 18)

            Divider()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var descriptionText: LocalizedStringKey {
        switch tab {
        case .general:
            return "Clipboard behavior and retention"
        case .hotkeys:
            return "Keyboard shortcuts and accessibility"
        case .appearance:
            return "Bezel and menu presentation"
        case .acknowledgements:
            return "Credits and bundled open-source software"
        }
    }
}

private struct GeneralPreferencesView: View {
    weak var controller: FlycutPreferencesWindowController?
    @ObservedObject var bridge: FlycutPreferencesBridge

    @AppStorage("stickyBezel") private var stickyBezel = false
    @AppStorage("wraparoundBezel") private var wraparoundBezel = false
    @AppStorage("menuSelectionPastes") private var menuSelectionPastes = true
    @AppStorage("loadOnStartup") private var loadOnStartup = false
    @AppStorage("rememberNum") private var rememberNum = 40
    @AppStorage("favoritesRememberNum") private var favoritesRememberNum = 40
    @AppStorage("displayNum") private var displayNum = 10
    @AppStorage("savePreference") private var savePreference = 1
    @AppStorage("syncSettingsViaICloud") private var syncSettingsViaICloud = false
    @AppStorage("syncClippingsViaICloud") private var syncClippingsViaICloud = false
    @AppStorage("removeDuplicates") private var removeDuplicates = false
    @AppStorage("pasteMovesToTop") private var pasteMovesToTop = false
    @AppStorage("skipPasswordFields") private var skipPasswordFields = true
    @AppStorage("skipPasswordLengths") private var skipPasswordLengths = false
    @AppStorage("skipPasswordLengthsList") private var skipPasswordLengthsList = "12, 20, 32"
    @AppStorage("revealPasteboardTypes") private var revealPasteboardTypes = false
    @AppStorage("saveForgottenClippings") private var saveForgottenClippings = true
    @AppStorage("saveForgottenFavorites") private var saveForgottenFavorites = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PreferenceSection(titleKey: "Behavior") {
                    Toggle("Sticky bezel (bezel, or pop-up, stays visible after hotkey is released)", isOn: $stickyBezel)
                    Toggle("Wraparound bezel (the first and last items are adjacent in order)", isOn: $wraparoundBezel)
                    Toggle("Menu selection pastes", isOn: $menuSelectionPastes)
                    Toggle("Launch Flycut on login", isOn: Binding(
                        get: { loadOnStartup },
                        set: { newValue in
                            loadOnStartup = newValue
                            if let controller {
                                bridge.delegate?.preferencesWindowControllerDidChangeLoadOnStartup(controller)
                            }
                        }
                    ))
                }

                PreferenceSection(titleKey: "Storage") {
                    Stepper(value: Binding(
                        get: { rememberNum },
                        set: { newValue in
                            rememberNum = max(1, newValue)
                            if let controller {
                                bridge.delegate?.preferencesWindowController(controller, didChangeRememberNum: NSNumber(value: rememberNum))
                            }
                            if displayNum > rememberNum {
                                displayNum = rememberNum
                                if let controller {
                                    bridge.delegate?.preferencesWindowControllerDidChangeDisplayNum(controller)
                                }
                            }
                        }
                    ), in: 1...500) {
                        Text("\(NSLocalizedString("Recent clippings to remember", comment: "")): \(rememberNum)")
                    }

                    Stepper(value: Binding(
                        get: { favoritesRememberNum },
                        set: { newValue in
                            favoritesRememberNum = max(1, newValue)
                            if let controller {
                                bridge.delegate?.preferencesWindowController(controller, didChangeFavoritesRememberNum: NSNumber(value: favoritesRememberNum))
                            }
                        }
                    ), in: 1...500) {
                        Text("\(NSLocalizedString("Favorite clippings to remember", comment: "")): \(favoritesRememberNum)")
                    }

                    Stepper(value: Binding(
                        get: { displayNum },
                        set: { newValue in
                            displayNum = min(max(1, newValue), rememberNum)
                            if let controller {
                                bridge.delegate?.preferencesWindowControllerDidChangeDisplayNum(controller)
                            }
                        }
                    ), in: 1...500) {
                        Text("\(NSLocalizedString("Display in menu", comment: "")): \(displayNum)")
                    }

                    Picker("Saving:", selection: Binding(
                        get: { savePreference },
                        set: { newValue in
                            savePreference = newValue
                            if let controller {
                                bridge.delegate?.preferencesWindowControllerDidChangeSavePreference(controller)
                            }
                        }
                    )) {
                        Text("Never").tag(0)
                        Text("On exit").tag(1)
                        Text("After each clip").tag(2)
                    }
                    .pickerStyle(.segmented)
                }

                PreferenceSection(titleKey: "Folders") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Save from bezel to:")
                            .font(.subheadline.weight(.medium))
                        HStack {
                            Button(bridge.saveToLocationTitle) {
                                if let controller {
                                    bridge.delegate?.preferencesWindowController(controller, didRequestSelectSaveLocation: 0)
                                }
                            }
                            Spacer()
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Save forgotten items to:")
                            .font(.subheadline.weight(.medium))
                        HStack {
                            Button(bridge.autoSaveToLocationTitle) {
                                if let controller {
                                    bridge.delegate?.preferencesWindowController(controller, didRequestSelectSaveLocation: 1)
                                }
                            }
                            Spacer()
                        }
                    }
                }

                PreferenceSection(titleKey: "iCloud Sync:") {
                    Toggle("Settings", isOn: Binding(
                        get: { syncSettingsViaICloud },
                        set: { newValue in
                            syncSettingsViaICloud = newValue
                            if let controller {
                                bridge.delegate?.preferencesWindowControllerDidChangeSyncSettings(controller)
                            }
                        }
                    ))

                    Toggle("Clippings", isOn: Binding(
                        get: { syncClippingsViaICloud },
                        set: { newValue in
                            syncClippingsViaICloud = newValue
                            if let controller {
                                bridge.delegate?.preferencesWindowControllerDidChangeSyncClippings(controller)
                            }
                        }
                    ))
                }

                PreferenceSection(titleKey: "Capture") {
                    Toggle("Remove duplicates", isOn: $removeDuplicates)
                    Toggle("Move pasted item to top of stack", isOn: $pasteMovesToTop)
                    Toggle("Don't copy from password fields", isOn: $skipPasswordFields)
                    Toggle("Include pasteboard types in clippings list", isOn: $revealPasteboardTypes)
                    Toggle("Save forgotten clippings", isOn: $saveForgottenClippings)
                    Toggle("Save forgotten favorites", isOn: $saveForgottenFavorites)
                    Toggle("Detect with Upper, Lower, Digit, and Symbol lengths:", isOn: $skipPasswordLengths)

                    TextField(LocalizedStringKey("Ignored password lengths"), text: $skipPasswordLengthsList)
                        .textFieldStyle(.roundedBorder)
                        .disabled(!skipPasswordLengths)
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(20)
        }
    }
}

private struct HotkeyPreferencesView: View {
    weak var controller: FlycutPreferencesWindowController?
    @ObservedObject var bridge: FlycutPreferencesBridge

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PreferenceSection(titleKey: "Hotkeys") {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Activation shortcut")
                            .font(.subheadline.weight(.medium))
                        HotKeyRecorderView(value: Binding(
                            get: { bridge.mainHotKey },
                            set: { newValue in
                                if let controller {
                                    bridge.updateMainHotKey(newValue, controller: controller)
                                }
                            }
                        ))
                        .frame(width: 280, height: 26)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Search shortcut")
                            .font(.subheadline.weight(.medium))
                        HotKeyRecorderView(value: Binding(
                            get: { bridge.searchHotKey },
                            set: { newValue in
                                if let controller {
                                    bridge.updateSearchHotKey(newValue, controller: controller)
                                }
                            }
                        ))
                        .frame(width: 280, height: 26)
                    }
                }

                PreferenceSection(titleKey: "Accessibility") {
                    Button("Check Accessibility Permissions") {
                        if let controller {
                            bridge.delegate?.preferencesWindowControllerDidRequestAccessibilityCheck(controller)
                        }
                    }
                }

                PreferenceSection(titleKey: "Application Shortcuts") {
                    ForEach(inAppShortcutSections) { section in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(section.title)
                                .font(.subheadline.weight(.semibold))

                            ShortcutReferenceHeaderRow()

                            ForEach(section.entries) { entry in
                                ShortcutReferenceRow(entry: entry)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                    }
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(20)
        }
    }
}

private struct ShortcutReferenceHeaderRow: View {
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text("Shortcut")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 220, alignment: .leading)

            Text("Action")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 2)
    }
}

private struct ShortcutReferenceRow: View {
    let entry: ShortcutReference

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(entry.shortcutKey)
                .font(.system(.body, design: .monospaced))
                .frame(width: 220, alignment: .leading)

            Text(entry.actionKey)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }
}

private struct AppearancePreferencesView: View {
    weak var controller: FlycutPreferencesWindowController?
    @AppStorage("bezelAlpha") private var bezelAlpha = 0.25
    @AppStorage("bezelWidth") private var bezelWidth = 500.0
    @AppStorage("bezelHeight") private var bezelHeight = 320.0
    @AppStorage("menuIcon") private var menuIcon = 0
    @AppStorage("displayClippingSource") private var displayClippingSource = true
    @ObservedObject var bridge: FlycutPreferencesBridge

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PreferenceSection(titleKey: "Bezel") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Bezel transparency")
                        Slider(value: Binding(
                            get: { bezelAlpha },
                            set: { newValue in
                                bezelAlpha = newValue
                                if let controller {
                                    bridge.delegate?.preferencesWindowControllerDidChangeBezelAppearance(controller)
                                }
                            }
                        ), in: 0.1...0.9)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Bezel width")
                        Slider(value: Binding(
                            get: { bezelWidth },
                            set: { newValue in
                                bezelWidth = newValue
                                if let controller {
                                    bridge.delegate?.preferencesWindowControllerDidChangeBezelAppearance(controller)
                                }
                            }
                        ), in: 200...1200)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Bezel height")
                        Slider(value: Binding(
                            get: { bezelHeight },
                            set: { newValue in
                                bezelHeight = newValue
                                if let controller {
                                    bridge.delegate?.preferencesWindowControllerDidChangeBezelAppearance(controller)
                                }
                            }
                        ), in: 180...900)
                    }

                    Toggle("Show clipping source app and time", isOn: Binding(
                        get: { displayClippingSource },
                        set: { newValue in
                            displayClippingSource = newValue
                            if let controller {
                                bridge.delegate?.preferencesWindowControllerDidChangeDisplaySource(controller)
                            }
                        }
                    ))
                }

                PreferenceSection(titleKey: "Menu item icon") {
                    Picker("Menu item icon", selection: Binding(
                        get: { menuIcon },
                        set: { newValue in
                            menuIcon = newValue
                            if let controller {
                                bridge.delegate?.preferencesWindowControllerDidChangeMenuIcon(controller)
                            }
                        }
                    )) {
                        Text("Flycut icon").tag(0)
                        Text("Black Flycut icon").tag(1)
                        Text("White scissors").tag(2)
                        Text("Black scissors").tag(3)
                    }
                    .pickerStyle(.radioGroup)
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(20)
        }
    }
}

private struct AcknowledgementsPreferencesView: View {
    @ObservedObject var bridge: FlycutPreferencesBridge

    var body: some View {
        ScrollView {
            Text(bridge.acknowledgementsText)
                .frame(maxWidth: 760, alignment: .leading)
                .padding(20)
                .textSelection(.enabled)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}

private struct PreferencesWindowContentView: View {
    weak var controller: FlycutPreferencesWindowController?
    @ObservedObject var bridge: FlycutPreferencesBridge

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Flycut")
                    .font(.system(size: 20, weight: .semibold))
                    .padding(.horizontal, 14)
                    .padding(.top, 18)
                    .padding(.bottom, 8)

                ForEach(PreferencesTab.allCases) { tab in
                    PreferencesSidebarButton(tab: tab, isSelected: bridge.selectedTab == tab) {
                        bridge.selectedTab = tab
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(width: 220)
            .frame(maxHeight: .infinity, alignment: .topLeading)
            .padding(14)
            .background(Color(nsColor: .underPageBackgroundColor))

            Divider()

            Group {
                switch bridge.selectedTab {
                case .general:
                    PreferencesDetailContainer(tab: .general) {
                        GeneralPreferencesView(controller: controller, bridge: bridge)
                    }
                case .hotkeys:
                    PreferencesDetailContainer(tab: .hotkeys) {
                        HotkeyPreferencesView(controller: controller, bridge: bridge)
                    }
                case .appearance:
                    PreferencesDetailContainer(tab: .appearance) {
                        AppearancePreferencesView(controller: controller, bridge: bridge)
                    }
                case .acknowledgements:
                    PreferencesDetailContainer(tab: .acknowledgements) {
                        AcknowledgementsPreferencesView(bridge: bridge)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 920, minHeight: 720)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

@objcMembers public final class FlycutPreferencesWindowController: NSWindowController {
    public weak var bridgeDelegate: FlycutPreferencesWindowControllerDelegate? {
        didSet {
            bridge.delegate = bridgeDelegate
        }
    }

    private let bridge = FlycutPreferencesBridge()

    public init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        super.init(window: window)

        bridge.refreshDynamicContent()

        let hostingView = NSHostingView(rootView: PreferencesWindowContentView(controller: self, bridge: bridge))
        window.contentView = hostingView
        window.title = NSLocalizedString("Preferences", comment: "")
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 920, height: 720)
        window.center()
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func showAndFocus() {
        bridge.refreshDynamicContent()
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    public func refreshDynamicContent() {
        bridge.refreshDynamicContent()
    }
}
