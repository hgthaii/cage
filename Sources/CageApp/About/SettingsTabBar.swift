import AppKit
import QuartzCore

/// Two native, keyboard-accessible buttons with a sliding selection background.
@MainActor
final class SettingsTabBar: NSView {
    var onSelection: (() -> Void)?
    private(set) var selectedIndex = 0
    private let indicator = NSView()
    private var buttons: [NSButton] = []
    private var indicatorLeading: NSLayoutConstraint!
    private let tabWidth: CGFloat = 76

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.borderWidth = 1
        indicator.wantsLayer = true
        indicator.layer?.cornerRadius = 6
        indicator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(indicator)
        buttons = ["General", "About"].enumerated().map { index, title in
            let button = NSButton(title: title, target: self, action: #selector(selectTab(_:)))
            button.tag = index
            button.isBordered = false
            button.setAccessibilityRole(.radioButton)
            button.widthAnchor.constraint(equalToConstant: tabWidth).isActive = true
            button.heightAnchor.constraint(equalToConstant: 32).isActive = true
            return button
        }
        let stack = NSStackView(views: buttons)
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        indicatorLeading = indicator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 1)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 1),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -1),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 1),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -1),
            indicatorLeading,
            indicator.topAnchor.constraint(equalTo: topAnchor, constant: 1),
            indicator.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -1),
            indicator.widthAnchor.constraint(equalToConstant: tabWidth),
        ])
        select(0, animated: false)
    }

    required init?(coder: NSCoder) { nil }

    func select(_ index: Int, animated: Bool) {
        guard buttons.indices.contains(index), let indicatorLayer = indicator.layer else { return }
        let previous = indicatorLayer.presentation()?.position ?? indicatorLayer.position
        selectedIndex = index
        indicatorLeading.constant = 1 + CGFloat(index) * tabWidth
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layoutSubtreeIfNeeded()
        CATransaction.commit()
        for (i, button) in buttons.enumerated() {
            button.font = .systemFont(ofSize: 13, weight: i == index ? .semibold : .regular)
            button.contentTintColor = i == index ? .labelColor : .secondaryLabelColor
            button.setAccessibilityValue(i == index ? 1 : 0)
        }
        indicatorLayer.removeAnimation(forKey: "tab-slide")
        guard animated, window?.isVisible == true,
              !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        let slide = CABasicAnimation(keyPath: "position")
        slide.fromValue = previous
        slide.toValue = indicatorLayer.position
        slide.duration = 0.20
        slide.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        indicatorLayer.add(slide, forKey: "tab-slide")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateColors()
    }

    private func updateColors() {
        let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        layer?.backgroundColor = NSColor(calibratedWhite: dark ? 0.115 : 0.93, alpha: 1).cgColor
        layer?.borderColor = NSColor(calibratedWhite: dark ? 0.19 : 0.80, alpha: 1).cgColor
        indicator.layer?.backgroundColor = NSColor(calibratedWhite: dark ? 0.055 : 1, alpha: 1).cgColor
    }

    @objc private func selectTab(_ sender: NSButton) {
        select(sender.tag, animated: true)
        onSelection?()
    }
}

/// A quiet, visible boundary for the fixed-height app list in either appearance.
@MainActor
final class SettingsListFrame: NSView {
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateColors()
    }

    private func updateColors() {
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.borderWidth = 1
        layer?.masksToBounds = true
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
            layer?.borderColor = NSColor.separatorColor.cgColor
        }
    }
}
