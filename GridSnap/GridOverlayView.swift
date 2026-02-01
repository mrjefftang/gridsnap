import SwiftUI

struct GridOverlayView: View {
    let appName: String
    let appIcon: NSImage?
    let rows: Int
    let columns: Int
    let onSelection: (GridRect) -> Void
    let onCancel: () -> Void

    @State private var dragStart: (row: Int, col: Int)?
    @State private var dragCurrent: (row: Int, col: Int)?

    private var selection: (minRow: Int, minCol: Int, maxRow: Int, maxCol: Int)? {
        guard let s = dragStart, let c = dragCurrent else { return nil }
        return (min(s.row, c.row), min(s.col, c.col), max(s.row, c.row), max(s.col, c.col))
    }

    var body: some View {
        ZStack {
            // Full-screen dim background — click outside grid cancels
            Color.black.opacity(0.3)
                .onTapGesture { onCancel() }

            VStack(spacing: 16) {
                // Header
                HStack(spacing: 10) {
                    if let icon = appIcon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 32, height: 32)
                    }
                    Text(appName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }

                // Grid
                GridCellsView(
                    rows: rows,
                    columns: columns,
                    selection: selection,
                    onDragStart: { r, c in dragStart = (r, c); dragCurrent = (r, c) },
                    onDragUpdate: { r, c in dragCurrent = (r, c) },
                    onDragEnd: { r, c in
                        dragCurrent = (r, c)
                        if let sel = selection {
                            onSelection(GridRect(
                                row: sel.minRow,
                                column: sel.minCol,
                                width: sel.maxCol - sel.minCol + 1,
                                height: sel.maxRow - sel.minRow + 1
                            ))
                        }
                        dragStart = nil
                        dragCurrent = nil
                    }
                )
                .frame(width: CGFloat(columns) * 50, height: CGFloat(rows) * 50)

                Text("Drag to select · Esc to cancel")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Grid Cells (NSViewRepresentable for mouse tracking)

struct GridCellsView: NSViewRepresentable {
    let rows: Int
    let columns: Int
    let selection: (minRow: Int, minCol: Int, maxRow: Int, maxCol: Int)?
    let onDragStart: (Int, Int) -> Void
    let onDragUpdate: (Int, Int) -> Void
    let onDragEnd: (Int, Int) -> Void

    func makeNSView(context: Context) -> GridTrackingNSView {
        let view = GridTrackingNSView()
        view.rows = rows
        view.columns = columns
        view.onDragStart = onDragStart
        view.onDragUpdate = onDragUpdate
        view.onDragEnd = onDragEnd
        return view
    }

    func updateNSView(_ nsView: GridTrackingNSView, context: Context) {
        nsView.rows = rows
        nsView.columns = columns
        nsView.selection = selection
        nsView.needsDisplay = true
    }
}

class GridTrackingNSView: NSView {
    var rows = 6
    var columns = 6
    var selection: (minRow: Int, minCol: Int, maxRow: Int, maxCol: Int)?
    var onDragStart: ((Int, Int) -> Void)?
    var onDragUpdate: ((Int, Int) -> Void)?
    var onDragEnd: ((Int, Int) -> Void)?

    private var isDragging = false

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true } // top-left origin to match grid row 0 at top

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let cellW = bounds.width / CGFloat(columns)
        let cellH = bounds.height / CGFloat(rows)

        // Draw cells
        for r in 0..<rows {
            for c in 0..<columns {
                let rect = NSRect(x: CGFloat(c) * cellW, y: CGFloat(r) * cellH, width: cellW, height: cellH)

                if let sel = selection,
                   r >= sel.minRow && r <= sel.maxRow &&
                   c >= sel.minCol && c <= sel.maxCol {
                    NSColor.systemBlue.withAlphaComponent(0.5).setFill()
                } else {
                    NSColor.white.withAlphaComponent(0.08).setFill()
                }
                rect.insetBy(dx: 1.5, dy: 1.5).fill()

                NSColor.white.withAlphaComponent(0.25).setStroke()
                let path = NSBezierPath(roundedRect: rect.insetBy(dx: 1.5, dy: 1.5), xRadius: 3, yRadius: 3)
                path.lineWidth = 1
                path.stroke()
            }
        }

        // Draw selection border
        if let sel = selection {
            let selRect = NSRect(
                x: CGFloat(sel.minCol) * cellW,
                y: CGFloat(sel.minRow) * cellH,
                width: CGFloat(sel.maxCol - sel.minCol + 1) * cellW,
                height: CGFloat(sel.maxRow - sel.minRow + 1) * cellH
            ).insetBy(dx: 1, dy: 1)

            NSColor.systemBlue.setStroke()
            let path = NSBezierPath(roundedRect: selRect, xRadius: 4, yRadius: 4)
            path.lineWidth = 2.5
            path.stroke()
        }
    }

    override func mouseDown(with event: NSEvent) {
        isDragging = true
        let (r, c) = cellAt(event)
        onDragStart?(r, c)
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        let (r, c) = cellAt(event)
        onDragUpdate?(r, c)
    }

    override func mouseUp(with event: NSEvent) {
        guard isDragging else { return }
        isDragging = false
        let (r, c) = cellAt(event)
        onDragEnd?(r, c)
    }

    private func cellAt(_ event: NSEvent) -> (Int, Int) {
        let pt = convert(event.locationInWindow, from: nil)
        let cellW = bounds.width / CGFloat(columns)
        let cellH = bounds.height / CGFloat(rows)
        // isFlipped is true, so pt.y=0 is top
        let col = max(0, min(columns - 1, Int(pt.x / cellW)))
        let row = max(0, min(rows - 1, Int(pt.y / cellH)))
        return (row, col)
    }
}
