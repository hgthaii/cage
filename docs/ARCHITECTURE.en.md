# Cage architecture

[Tiếng Việt](ARCHITECTURE.md) · [English](ARCHITECTURE.en.md)

`CageCore` contains the rules for deciding when and where to confine the cursor.
`CageApp` connects those rules to macOS windows, Accessibility, the menu bar,
and Sparkle.

Each allowed app is identified by its bundle identifier. Any `.app` bundle can
be added from Settings → General. Cage confines the cursor only while an allowed app is in
the foreground and has a valid window. Switching elsewhere removes the boundary
immediately.

Cage applies the same boundary to movement, clicks, drags, and scrolling. The
boundary sits slightly inside the window so the Dock, menu bar, and hot corners
do not receive stray events.
