import AppKit

class SettingsWindow: NSWindow {
    override func cancelOperation(_ sender: Any?) {
        guard attachedSheet == nil else { super.cancelOperation(sender); return }
        performClose(sender)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let close = (event.keyCode == 53 && modifiers.isEmpty)
            || (event.charactersIgnoringModifiers == "w" && modifiers == .command)
        guard close, attachedSheet == nil else { return super.performKeyEquivalent(with: event) }
        performClose(nil)
        return true
    }
}
