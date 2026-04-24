import AppKit

enum SparklineRenderer {
    /// Renders a mini sparkline suitable for embedding in an NSStatusItem button.
    static func makeImage(
        values: [Double],
        isPositive: Bool,
        size: CGSize = CGSize(width: 64, height: 18)
    ) -> NSImage? {
        guard values.count >= 2 else { return nil }

        let minV = values.min()!
        let maxV = values.max()!
        // Flat line — nothing useful to draw
        guard maxV > minV else { return nil }

        let color: NSColor = isPositive ? .systemGreen : .systemRed
        let range = maxV - minV
        let padX: CGFloat = 1.0
        let padY: CGFloat = 2.5
        let drawW = size.width  - padX * 2
        let drawH = size.height - padY * 2

        func pt(_ i: Int) -> NSPoint {
            let x = padX + CGFloat(i) / CGFloat(values.count - 1) * drawW
            let y = padY + CGFloat((values[i] - minV) / range) * drawH
            return NSPoint(x: x, y: y)
        }

        let image = NSImage(size: size, flipped: false) { _ in
            // ── filled area under the curve ────────────────────────────────
            let fillPath = NSBezierPath()
            fillPath.move(to: NSPoint(x: padX, y: padY))
            for i in 0 ..< values.count { fillPath.line(to: pt(i)) }
            fillPath.line(to: NSPoint(x: padX + drawW, y: padY))
            fillPath.close()
            color.withAlphaComponent(0.18).setFill()
            fillPath.fill()

            // ── line ───────────────────────────────────────────────────────
            let linePath = NSBezierPath()
            linePath.lineWidth      = 1.5
            linePath.lineJoinStyle  = .round
            linePath.lineCapStyle   = .round
            linePath.move(to: pt(0))
            for i in 1 ..< values.count { linePath.line(to: pt(i)) }
            color.setStroke()
            linePath.stroke()

            // ── terminal dot ───────────────────────────────────────────────
            let last = pt(values.count - 1)
            let dot = NSBezierPath(
                ovalIn: NSRect(x: last.x - 2, y: last.y - 2, width: 4, height: 4)
            )
            color.setFill()
            dot.fill()

            return true
        }

        image.isTemplate = false
        return image
    }
}
