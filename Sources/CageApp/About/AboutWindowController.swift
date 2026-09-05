import AppKit
import ApplicationServices
import CageCore
import UniformTypeIdentifiers
import ServiceManagement

private final class TopAlignedClipView: NSClipView {
    override var isFlipped: Bool { true }
}

@MainActor
final class AboutWindowController: NSWindowController, NSWindowDelegate {
    private let registry: GameRegistry
    private let onOpenAccessibility: () -> Void
    private let onCheckForUpdates: () -> Void
    private let gamesStack = NSStackView()
    private let permissionLabel = NSTextField(labelWithString: "")
    private let tabs = SettingsTabBar()
    private let permissionCard = NSView()
    private var gatedControls: [NSControl] = []
    private var removeButtons: [NSButton] = []
    private var hasAccessibilityAccess = false
    private let startupSwitch = NSSwitch()
    private let startupDetail = NSTextField(labelWithString: "")
    private var generalViews: [NSView] = []
    private var aboutViews: [NSView] = []

    init(
        registry: GameRegistry,
        onOpenAccessibility: @escaping () -> Void,
        onCheckForUpdates: @escaping () -> Void
    ) {
        self.registry = registry
        self.onOpenAccessibility = onOpenAccessibility
        self.onCheckForUpdates = onCheckForUpdates
        let window = SettingsWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 490),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Cage Settings"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        configureContent()
        refresh()
        changePage()
    }

    required init?(coder: NSCoder) { nil }

    func present(showAbout: Bool = false) {
        tabs.select(showAbout ? 1 : 0, animated: false)
        changePage()
        refresh()
        showWindow(nil)
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
    }

    func refreshFromRegistry() {
        refresh()
    }

    private func configureContent() {
        guard let contentView = window?.contentView else { return }
        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 18
        root.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(root)

        tabs.onSelection = { [weak self] in self?.changePage() }
        let leftSpacer = NSView()
        let rightSpacer = NSView()
        let navigation = NSStackView(views: [leftSpacer, tabs, rightSpacer])
        leftSpacer.widthAnchor.constraint(equalTo: rightSpacer.widthAnchor).isActive = true
        navigation.orientation = .horizontal
        root.addArrangedSubview(navigation)
        navigation.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true

        let header = NSStackView()
        header.orientation = .vertical
        header.alignment = .centerX
        header.spacing = 12
        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 48).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 48).isActive = true
        let title = NSTextField(labelWithString: AppIdentity.productName)
        title.font = .systemFont(ofSize: 20, weight: .semibold)
        let tagline = NSTextField(labelWithString: AppIdentity.tagline)
        tagline.textColor = .secondaryLabelColor
        tagline.font = .systemFont(ofSize: 12)
        let version = NSTextField(labelWithString: versionText)
        version.textColor = .tertiaryLabelColor
        version.font = .systemFont(ofSize: 11)
        let titleStack = NSStackView(views: [title, version])
        titleStack.orientation = .vertical
        titleStack.alignment = .leading
        titleStack.spacing = 3
        let identity = NSStackView(views: [icon, titleStack])
        identity.orientation = .horizontal
        identity.alignment = .centerY
        identity.spacing = 10
        header.addArrangedSubview(identity)
        header.addArrangedSubview(tagline)
        root.addArrangedSubview(header)
        aboutViews.append(header)

        let startupTitle = NSTextField(labelWithString: "Open at login")
        startupTitle.font = .systemFont(ofSize: 13, weight: .medium)
        startupDetail.font = .systemFont(ofSize: 11)
        startupDetail.textColor = .secondaryLabelColor
        let startupLabels = NSStackView(views: [startupTitle, startupDetail])
        startupLabels.orientation = .vertical
        startupLabels.alignment = .leading
        startupLabels.spacing = 4
        startupSwitch.target = self
        startupSwitch.action = #selector(toggleStartup)
        startupSwitch.setAccessibilityLabel("Open Cage at login")
        let startupRow = NSStackView(views: [startupLabels, NSView(), startupSwitch])
        startupRow.orientation = .horizontal
        startupRow.alignment = .centerY
        let permissionTitle = NSTextField(labelWithString: "Allow Accessibility access")
        permissionTitle.font = .systemFont(ofSize: 13, weight: .medium)
        permissionLabel.font = .systemFont(ofSize: 11)
        permissionLabel.textColor = .secondaryLabelColor
        let permissionText = NSStackView(views: [permissionTitle, permissionLabel])
        permissionText.orientation = .vertical
        permissionText.alignment = .leading
        permissionText.spacing = 3
        let permissionButton = NSButton(title: "Grant Access…", target: self, action: #selector(openAccessibility))
        permissionButton.bezelStyle = .rounded
        let permissionRow = NSStackView(views: [permissionText, NSView(), permissionButton])
        permissionRow.orientation = .horizontal
        permissionRow.alignment = .centerY
        permissionRow.translatesAutoresizingMaskIntoConstraints = false
        permissionCard.addSubview(permissionRow)
        pin(permissionRow, to: permissionCard, inset: 0)
        root.addArrangedSubview(permissionCard)
        generalViews.append(permissionCard)

        let gamesHeader = NSStackView()
        gamesHeader.orientation = .horizontal
        gamesHeader.alignment = .centerY
        let gamesTitle = NSTextField(labelWithString: "Allowed Apps")
        gamesTitle.font = .systemFont(ofSize: 13, weight: .semibold)
        let addButton = NSButton(title: "Add App…", target: self, action: #selector(addGame))
        gatedControls.append(addButton)
        addButton.bezelStyle = .rounded
        gamesHeader.addArrangedSubview(gamesTitle)
        gamesHeader.addArrangedSubview(NSView())
        gamesHeader.addArrangedSubview(addButton)
        root.addArrangedSubview(gamesHeader)
        generalViews.append(gamesHeader)

        gamesStack.orientation = .vertical
        gamesStack.alignment = .leading
        gamesStack.spacing = 0
        let gamesCard = SettingsListFrame()
        gamesStack.translatesAutoresizingMaskIntoConstraints = false
        let scroll = NSScrollView()
        scroll.contentView = TopAlignedClipView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = gamesStack
        gamesCard.addSubview(scroll)
        pin(scroll, to: gamesCard, inset: 6)
        gamesStack.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor).isActive = true
        gamesStack.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor).isActive = true
        gamesStack.topAnchor.constraint(equalTo: scroll.contentView.topAnchor).isActive = true
        root.addArrangedSubview(gamesCard)
        generalViews.append(gamesCard)

        root.addArrangedSubview(startupRow)
        startupRow.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        generalViews.append(startupRow)

        let credits = NSStackView()
        credits.orientation = .vertical
        credits.alignment = .centerX
        credits.spacing = 4
        for text in ["Developed by hgthaii", "Based on MouseLock by mxrlkn"] {
            let label = NSTextField(labelWithString: text)
            label.font = .systemFont(ofSize: 11)
            label.textColor = .secondaryLabelColor
            credits.addArrangedSubview(label)
        }
        root.addArrangedSubview(credits)
        aboutViews.append(credits)

        let updates = NSButton(title: "Check for Updates…", target: self, action: #selector(checkForUpdates))
        let reportBug = NSButton(title: "Report a Bug…", target: self, action: #selector(openIssues))
        let footer = NSStackView()
        footer.orientation = .vertical
        footer.alignment = .centerX
        footer.spacing = 16
        let github = NSButton(title: "GitHub", target: self, action: #selector(openGitHub))
        let actions = [updates, reportBug, github]
        for button in actions {
            button.bezelStyle = .inline
            button.isBordered = false
            button.font = .systemFont(ofSize: 11)
            button.contentTintColor = .secondaryLabelColor
        }
        let aboutActions = NSStackView(views: actions)
        aboutActions.spacing = 16
        footer.addArrangedSubview(aboutActions)
        gatedControls += actions
        let copyright = NSTextField(labelWithString: "© 2026 hgthaii")
        copyright.font = .systemFont(ofSize: 10)
        copyright.textColor = .tertiaryLabelColor
        footer.addArrangedSubview(copyright)
        root.addArrangedSubview(footer)
        aboutViews.append(footer)

        [header, permissionCard, gamesHeader, gamesCard, credits, footer].forEach {
            $0.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        }
        gamesCard.heightAnchor.constraint(equalToConstant: 190).isActive = true
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            root.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            root.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 42),
            root.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -22),
        ])
    }

    private func refresh() {
        removeButtons.removeAll()
        gamesStack.arrangedSubviews.forEach { view in
            gamesStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        if registry.games.isEmpty {
            let empty = NSTextField(labelWithString: "Add an app to keep its cursor inside the window.")
            empty.textColor = .secondaryLabelColor
            empty.font = .systemFont(ofSize: 11)
            empty.alignment = .center
            gamesStack.addArrangedSubview(empty)
            empty.widthAnchor.constraint(equalTo: gamesStack.widthAnchor).isActive = true
            empty.heightAnchor.constraint(equalToConstant: 44).isActive = true
            refreshAccessibility(trusted: AXIsProcessTrusted())
            return
        }
        for (index, game) in registry.games.enumerated() {
            let name = NSTextField(labelWithString: game.displayName)
            name.font = .systemFont(ofSize: 12, weight: .medium)
            name.lineBreakMode = .byTruncatingTail
            name.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            let labels = NSStackView(views: [name])
            labels.orientation = .vertical
            labels.alignment = .leading
            labels.spacing = 2
            let remove = NSButton(title: "Remove", target: self, action: #selector(removeGame(_:)))
            remove.bezelStyle = .inline
            remove.tag = index
            removeButtons.append(remove)
            let appURL = game.applicationPath.map { URL(fileURLWithPath: $0) }
                ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: game.bundleIdentifier)
            let iconImage = appURL.map { NSWorkspace.shared.icon(forFile: $0.path) }
                ?? NSImage(systemSymbolName: "app", accessibilityDescription: nil)!
            let appIcon = NSImageView(image: iconImage)
            appIcon.imageScaling = .scaleProportionallyUpOrDown
            appIcon.widthAnchor.constraint(equalToConstant: 32).isActive = true
            appIcon.heightAnchor.constraint(equalToConstant: 32).isActive = true
            let row = NSStackView(views: [appIcon, labels, NSView(), remove])
            row.spacing = 10
            row.orientation = .horizontal
            row.alignment = .centerY
            row.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
            gamesStack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: gamesStack.widthAnchor).isActive = true
        }
        refreshAccessibility(trusted: AXIsProcessTrusted())
    }

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }

    private func changePage() {
        let about = tabs.selectedIndex == 1
        generalViews.forEach { $0.isHidden = about }
        aboutViews.forEach { $0.isHidden = !about }
        permissionCard.isHidden = about || hasAccessibilityAccess
        let height: CGFloat = about ? 330 : (hasAccessibilityAccess ? 410 : 470)
        window?.setContentSize(NSSize(width: 480, height: height))
    }

    func refreshAccessibility(trusted: Bool) {
        hasAccessibilityAccess = trusted
        permissionLabel.stringValue = "Required to keep the cursor inside your apps."
        (gatedControls + removeButtons).forEach { $0.isEnabled = trusted }
        gamesStack.alphaValue = trusted ? 1 : 0.45
        refreshStartup()
        changePage()
    }

    private func refreshStartup() {
        if #available(macOS 13.0, *) {
            startupSwitch.isEnabled = hasAccessibilityAccess
            let status = SMAppService.mainApp.status
            startupSwitch.state = (status == .enabled || status == .requiresApproval) ? .on : .off
            startupDetail.stringValue = status == .requiresApproval
                ? "Allow Cage in System Settings → Login Items."
                : "Start Cage when you sign in to your Mac."
        } else {
            startupSwitch.isEnabled = false
            startupDetail.stringValue = "Requires macOS 13 or later."
        }
    }

    @objc private func toggleStartup() {
        guard AXIsProcessTrusted() else { refresh(); return }
        guard #available(macOS 13.0, *) else { return }
        do {
            if startupSwitch.state == .on {
                try SMAppService.mainApp.register()
                if SMAppService.mainApp.status == .requiresApproval {
                    SMAppService.openSystemSettingsLoginItems()
                }
            } else {
                try SMAppService.mainApp.unregister()
            }
            refreshStartup()
        } catch {
            refreshStartup()
            let alert = NSAlert()
            alert.messageText = "Couldn’t change login setting"
            alert.informativeText = error.localizedDescription
            if let window { alert.beginSheetModal(for: window) }
        }
    }

    private func pin(_ view: NSView, to container: NSView, inset: CGFloat) {
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: inset),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -inset),
            view.topAnchor.constraint(equalTo: container.topAnchor, constant: inset),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -inset),
        ])
    }

    @objc private func openAccessibility() { onOpenAccessibility() }

    @objc private func addGame() {
        guard AXIsProcessTrusted() else { refresh(); return }
        let panel = NSOpenPanel()
        panel.title = "Add an app"
        panel.prompt = "Add App"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.application]
        guard panel.runModal() == .OK,
              let url = panel.url,
              let game = registry.identity(for: url), AXIsProcessTrusted() else { return }
        registry.add(game)
    }

    @objc private func removeGame(_ sender: NSButton) {
        guard AXIsProcessTrusted() else { refresh(); return }
        guard registry.games.indices.contains(sender.tag) else { return }
        registry.remove(bundleIdentifier: registry.games[sender.tag].bundleIdentifier)
    }

    @objc private func openGitHub() {
        guard AXIsProcessTrusted() else { refresh(); return }
        guard let url = URL(string: AppIdentity.repositoryURL) else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func checkForUpdates() {
        guard AXIsProcessTrusted() else { refresh(); return }
        onCheckForUpdates()
    }

    @objc private func openIssues() {
        guard AXIsProcessTrusted(),
              let url = URL(string: AppIdentity.repositoryURL + "/issues/new") else { return }
        NSWorkspace.shared.open(url)
    }
}
