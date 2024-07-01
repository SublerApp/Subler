//
//  ArtworkSelectorViewItem.swift
//  Subler
//
//  Created by Damiano Galassi on 13/06/2018.
//

import Cocoa
import AVFoundation

final class ArtworkSelectorViewItemLabel : NSTextField {

    @IBInspectable var highlightColor: NSColor = .alternateSelectedControlColor
    @IBInspectable var highlightTextColor: NSColor = .alternateSelectedControlTextColor
    @IBInspectable var cornerRadius: CGFloat = 3

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addObservers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        addObservers()
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: NSWindow.didBecomeKeyNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSWindow.didResignKeyNotification, object: nil)
    }

    private func addObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidBecomeKey), name: NSWindow.didBecomeKeyNotification, object: window)
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidBecomeKey), name: NSWindow.didResignKeyNotification, object: window)
    }

    @objc func windowDidBecomeKey() {
        needsDisplay = true
    }

    private static let inset: CGFloat = 12

    override func draw(_ dirtyRect: NSRect) {
        let windowIsKeyWindow = window?.isKeyWindow ?? false

        var attributedString = attributedStringValue

        if isHighlighted && windowIsKeyWindow == true {
            let mutableAttributedString = attributedString.mutableCopy() as! NSMutableAttributedString
            let range = NSRange(location: 0, length: mutableAttributedString.length)
            mutableAttributedString.removeAttribute(NSAttributedString.Key.foregroundColor, range: range)
            mutableAttributedString.addAttributes([NSAttributedString.Key.foregroundColor : highlightTextColor], range: range)
            attributedString = mutableAttributedString
        }

        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)

        let path = CGMutablePath()
        path.addRect(CGRect(x: 0, y: 0, width: bounds.size.width - ArtworkSelectorViewItemLabel.inset, height: bounds.size.height))

        let totalFrame = CTFramesetterCreateFrame(framesetter, CFRange(), path, nil)

        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.textMatrix = .identity
        context.translateBy(x: 0, y: bounds.size.height)
        context.scaleBy(x: 1, y: -1)

        // Highlight the text specified
        let lines = CTFrameGetLines(totalFrame) as! [CTLine]

        var origins = [CGPoint](repeating: CGPoint.zero, count: lines.count)
        CTFrameGetLineOrigins(totalFrame, CFRange(), &origins)

        for (line, origin) in zip(lines, origins) {
            let glyphRuns = CTLineGetGlyphRuns(line) as! [CTRun]
            let position = CGPoint(x: origin.x + ArtworkSelectorViewItemLabel.inset / 2, y: origin.y)
            var offset: CGFloat = 0

            if isHighlighted {
                for run in glyphRuns {
                    let range = CTRunGetStringRange(run)
                    var runBounds = CGRect.zero
                    var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0

                    runBounds.size.width = CGFloat(CTRunGetTypographicBounds(run, CFRange(), &ascent, &descent, &leading))
                    runBounds.size.height = ascent + descent

                    runBounds.origin.x = CTLineGetOffsetForStringIndex(line, range.location, nil) + position.x + offset
                    runBounds.origin.y = position.y - descent

                    offset = runBounds.origin.x + runBounds.size.width - position.x

                    let roundedPath = NSBezierPath(roundedRect: runBounds.insetBy(dx: -2, dy: 0).integral,
                                                   xRadius: cornerRadius, yRadius: cornerRadius)
                    let fillColor = windowIsKeyWindow ? highlightColor.cgColor : NSColor.gridColor.cgColor

                    context.setFillColor(fillColor)
                    roundedPath.fill()
                }
            }

            context.textPosition = position
            for run in glyphRuns {
                CTRunDraw(run, context, CFRange())
            }
        }
        context.restoreGState()
    }
}

final class ArtworkSelectorViewItemView: NSView {

    private let imageLayer: CALayer = CALayer()
    private let backgroundLayer: CALayer = CALayer()
    private let emptyLayer: CAShapeLayer = CAShapeLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setUp()
    }

    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
        setUp()
    }

    private let padding: CGFloat = 8
    private var paddingBottom: CGFloat = 36 {
        didSet {
            imageLayer.position = CGPoint(x: padding / 2, y: padding / 2 + paddingBottom)
            backgroundLayer.position = CGPoint(x: 0, y: paddingBottom)
            emptyLayer.position = CGPoint(x: padding, y: padding + paddingBottom)
        }
    }
    private let corderRadius: CGFloat = 14

    private func setUp() {
        layer = CALayer()

        layerContentsRedrawPolicy = .onSetNeedsDisplay
        wantsLayer = true

        guard let layer else { return }

        let actions: [String : CAAction] = ["contents": NSNull(),
                                            "hidden": NSNull(),
                                            "bounds": NSNull()]
        imageLayer.actions = actions
        backgroundLayer.actions = actions
        emptyLayer.actions = actions
        layer.actions = actions

        imageLayer.anchorPoint = CGPoint.zero
        imageLayer.position = CGPoint(x: padding / 2, y: padding / 2 + paddingBottom)
        imageLayer.contentsGravity = .resizeAspect
        imageLayer.shadowRadius = 1
        imageLayer.shadowColor = NSColor.labelColor.cgColor
        imageLayer.shadowOffset = CGSize.zero
        imageLayer.shadowOpacity = 0.8
        imageLayer.isOpaque = true

        backgroundLayer.anchorPoint = CGPoint.zero
        backgroundLayer.position = CGPoint(x: 0, y: paddingBottom)
        backgroundLayer.backgroundColor = NSColor.controlHighlightColor.cgColor
        backgroundLayer.cornerRadius = 8
        backgroundLayer.isHidden = true
        backgroundLayer.isOpaque = true

        emptyLayer.anchorPoint = CGPoint.zero
        emptyLayer.position = CGPoint(x: padding, y: padding + paddingBottom)
        emptyLayer.lineWidth = 3.0
        emptyLayer.lineDashPattern = [12,5]
        emptyLayer.strokeColor = NSColor.secondarySelectedControlColor.cgColor
        emptyLayer.fillColor = NSColor.windowBackgroundColor.cgColor
        emptyLayer.isOpaque = true

        updateBackgroundColor()

        layer.addSublayer(backgroundLayer)
        layer.addSublayer(emptyLayer)
        layer.addSublayer(imageLayer)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let superview = superview else { return nil }

        if super.hitTest(point) != nil {
            let convertedPoint = superview.convert(point, to: self)
            if imageLayer.hitTest(convertedPoint) != nil {
                return self
            }
            return superview
        } else {
            return nil
        }
    }

    private func updateBackgroundColor() {
        if #available(OSX 10.14, *) {
            let saved = NSAppearance.current
            NSAppearance.current = effectiveAppearance

            imageLayer.shadowColor = NSColor.labelColor.cgColor
            backgroundLayer.backgroundColor = NSColor.unemphasizedSelectedContentBackgroundColor.cgColor
            emptyLayer.strokeColor = NSColor.secondarySelectedControlColor.cgColor
            emptyLayer.fillColor = NSColor.windowBackgroundColor.cgColor

            NSAppearance.current = saved
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        updateBackgroundColor()
    }

    override func layout() {
        super.layout()

        imageLayer.bounds = CGRect(x: 0, y: 0, width: bounds.width - padding, height: bounds.height - padding - paddingBottom)
        backgroundLayer.bounds = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height - paddingBottom)

        emptyLayer.bounds = CGRect(x: 0, y: 0, width: bounds.width - padding * 2, height: bounds.height - padding * 2 - paddingBottom - 4)
        emptyLayer.path = CGPath(roundedRect: emptyLayer.bounds, cornerWidth: corderRadius, cornerHeight: corderRadius, transform: nil)

        if let image = imageLayer.contents as? NSImage {
            let rect = AVMakeRect(aspectRatio: image.size, insideRect: imageLayer.bounds)
            imageLayer.shadowPath = CGPath(rect: rect, transform: nil)
        } else {
            imageLayer.shadowPath = nil
        }
    }

    var highlighted: Bool = false {
        didSet {
            backgroundLayer.isHidden = !highlighted
        }
    }

    var areLabelsHidden: Bool = false {
        didSet {
            paddingBottom = areLabelsHidden ? 0 : 36
        }
    }

    var image: NSImage? {
        didSet {
            imageLayer.contents = image
            imageLayer.shadowPath = nil
            emptyLayer.isHidden = image != nil
        }
    }

    var imageFrame: NSRect {
        get {
            if let image = imageLayer.contents as? NSImage {
                AVMakeRect(aspectRatio: image.size, insideRect: imageLayer.bounds)
            } else {
                NSRect(x: 0, y: 0, width: 64, height: 32)
            }
        }
    }

}

final class ArtworkSelectorViewItem: NSCollectionViewItem {

    // MARK: Properties

    var itemView : ArtworkSelectorViewItemView? { get { return (view as? ArtworkSelectorViewItemView) } }
    @IBOutlet var subTextField: NSTextField!

    var doubleAction: Selector?
    weak var target: AnyObject?

    override func viewDidLoad() {
        super.viewDidLoad()
        textField?.layer?.isOpaque = true
    }

    private func updateLabels() {
        let state = title?.isEmpty == false && subtitle?.isEmpty == false
        itemView?.areLabelsHidden = !state
        textField?.isHidden = !state
        subTextField?.isHidden = !state
    }

    override var title: String? {
        didSet {
            textField?.stringValue = title ?? ""
            updateLabels()
        }
    }

    var subtitle: String? {
        didSet {
            subTextField?.stringValue = subtitle ?? ""
            updateLabels()
        }
    }

    var image: NSImage? {
        didSet {
            itemView?.image = image
        }
    }

    override var highlightState: NSCollectionViewItem.HighlightState {
        set (value) {
            super.highlightState = value
            updateSelectionHighlight()
        }
        get {
            return super.highlightState
        }
    }

    override var isSelected: Bool {
        set (value) {
            super.isSelected = value
            updateSelectionHighlight()
        }
        get {
            return super.isSelected
        }
    }

    private func updateSelectionHighlight() {
        if highlightState == .forSelection || (isSelected && highlightState != .forDeselection) {
            itemView?.highlighted = true
            textField?.isHighlighted = true
        } else {
            itemView?.highlighted = false
            textField?.isHighlighted = false
        }
    }

    // MARK: Actions

    override func mouseUp(with event: NSEvent) {
        if event.clickCount > 1, let action = doubleAction {
            target?.performSelector(onMainThread: action, with: nil, waitUntilDone: true)
        } else {
            super.mouseUp(with: event)
        }
    }

    override var draggingImageComponents: [NSDraggingImageComponent] {
        var components = Array<NSDraggingImageComponent>()

        if let itemView {
            let icon = NSDraggingImageComponent(key: .icon)
            icon.contents = itemView.image
            icon.frame = itemView.imageFrame
            components.append(icon)
        }

        if let textField, textField.stringValue.isEmpty == false {
            let label = NSDraggingImageComponent(key: .label)
            label.contents = textField.stringValue
            label.frame = textField.frame
            components.append(label)
        }

        return components
    }

    override func prepareForReuse() {
        title = nil
        subtitle = nil
        image = nil
        itemView?.highlighted = false
        textField?.isHighlighted = false
    }

}
