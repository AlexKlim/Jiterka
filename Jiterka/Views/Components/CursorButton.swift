//
//  CursorButton.swift
//  Jiterka
//
//  Custom button wrapper that properly handles cursor
//

import SwiftUI
import AppKit

struct CursorButton<Content: View>: View {
    let action: () -> Void
    let isDisabled: Bool
    let tooltip: String
    let onHoverChange: (Bool) -> Void
    let content: Content

    @State private var isHovering = false

    init(
        action: @escaping () -> Void,
        isDisabled: Bool,
        tooltip: String,
        onHoverChange: @escaping (Bool) -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.action = action
        self.isDisabled = isDisabled
        self.tooltip = tooltip
        self.onHoverChange = onHoverChange
        self.content = content()
    }

    var body: some View {
        Button(action: action) {
            content
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .help(tooltip)
        .background(CursorTrackingView(onHoverChange: { hovering in
            isHovering = hovering
            onHoverChange(hovering)
        }))
    }
}

private struct CursorTrackingView: NSViewRepresentable {
    let onHoverChange: (Bool) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = CursorHostingView(onHoverChange: onHoverChange)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private class CursorHostingView: NSView {
    let onHoverChange: (Bool) -> Void
    private var trackingArea: NSTrackingArea?

    init(onHoverChange: @escaping (Bool) -> Void) {
        self.onHoverChange = onHoverChange
        super.init(frame: .zero)
        setupTrackingArea()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupTrackingArea() {
        let options: NSTrackingArea.Options = [
            .mouseEnteredAndExited,
            .activeInKeyWindow,
            .inVisibleRect
        ]
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: options,
            owner: self,
            userInfo: nil
        )
        if let trackingArea = trackingArea {
            addTrackingArea(trackingArea)
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        setupTrackingArea()
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        NSCursor.pointingHand.set()
        onHoverChange(true)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        NSCursor.arrow.set()
        onHoverChange(false)
    }
}
