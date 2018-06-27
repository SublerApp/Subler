//
//  ArtworkSelectorViewItem.swift
//  Subler
//
//  Created by Damiano Galassi on 13/06/2018.
//

import Cocoa

class ArtworkSelectorViewItemLabel : NSTextField {

    @IBInspectable var highlightColor: NSColor = .alternateSelectedControlColor
    @IBInspectable var highlightTextColor: NSColor = .alternateSelectedControlTextColor
    @IBInspectable var cornerRadius: CGFloat = 3

    override func draw(_ dirtyRect: NSRect) {
        var attributedString = attributedStringValue
        if isHighlighted {
            let mutableAttributedString = attributedString.mutableCopy() as! NSMutableAttributedString
            let range = NSRange(location: 0, length: mutableAttributedString.length)
            mutableAttributedString.removeAttribute(NSAttributedString.Key.foregroundColor, range: range)
            mutableAttributedString.addAttributes([NSAttributedString.Key.foregroundColor : highlightTextColor], range: range)
            attributedString = mutableAttributedString
        }
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)

        let path = CGMutablePath()
        path.addRect(CGRect(x: 0, y: 0, width: bounds.size.width, height: bounds.size.height))

        let totalFrame = CTFramesetterCreateFrame(framesetter, CFRange(), path, nil)

        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.textMatrix = .identity
        context.translateBy(x: 0, y: bounds.size.height)
        context.scaleBy(x: 1, y: -1)

        // Highlight the text specified
        let lines = CTFrameGetLines(totalFrame) as! [CTLine]
        let lineCount = lines.count

        var origins = [CGPoint](repeating: CGPoint.zero, count: lineCount)
        CTFrameGetLineOrigins(totalFrame, CFRange(), &origins)

        if isHighlighted {
            for index in 0 ..< lineCount {
                let line = lines[index]
                let glyphRuns = CTLineGetGlyphRuns(line) as! [CTRun]
                let glyphCount = glyphRuns.count

                let origin = origins[index]
                // context.textPosition = pos

                for i in 0 ..< glyphCount {
                    let run = glyphRuns[i]
                    // let attributes = CTRunGetAttributes(run)

                    // if CFDictionaryGetValue(attributes, "HighlightText") {
                    var runBounds = CGRect.zero
                    var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0

                    runBounds.size.width = CGFloat(CTRunGetTypographicBounds(run, CFRange(), &ascent, &descent, &leading))
                    runBounds.size.height = ascent + descent

                    runBounds.origin.x = CTLineGetOffsetForStringIndex(line, CTRunGetStringRange(run).location, nil) + origin.x
                    runBounds.origin.y = origin.y - descent

                    let highlightCGColor = highlightColor.cgColor
                    let roundeRect = runBounds.insetBy(dx: -4, dy: 0)
                    let roundedPath = NSBezierPath(roundedRect: roundeRect.integral, xRadius: cornerRadius, yRadius: cornerRadius)
                    context.setFillColor(highlightCGColor)
                    roundedPath.fill()

                    // CTRunDraw(run, context, CFRange())
                    // }
                }
            }
        }
        CTFrameDraw(totalFrame, context)
        context.restoreGState()
    }
}

class ArtworkSelectorViewItemView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let superview = superview else { return nil }

        if super.hitTest(point) != nil {
            let convertedPoint = superview.convert(point, to: self)
            if let layer = layer?.sublayers?.last  {
                if layer.hitTest(convertedPoint) != nil {
                    return self
                }
            }
            return superview
        } else {
            return nil
        }
    }
}

@available(OSX 10.11, *)
class ArtworkSelectorViewItem: NSCollectionViewItem {

    @IBOutlet var subTextField: NSTextField!

    private let imageLayer: CALayer = CALayer()
    private let backgroundLayer: CALayer = CALayer()

    // MARK: Properties

    var doubleAction: Selector?
    weak var target: AnyObject?

    override var title: String? {
        set (title) {
            textField?.stringValue = title ?? ""
            super.title = title
        }
        get {
            return super.title
        }
    }

    var subtitle: String? {
        didSet {
            subTextField?.stringValue = subtitle ?? ""
        }
    }

    var image: NSImage? {
        didSet {
            if image != nil {
                imageLayer.contents = image
                imageLayer.shadowOpacity = 0.8
            } else {
                imageLayer.contents = NSImage(imageLiteralResourceName: "Placeholder")
            }
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

    // MARK: View Controller life cycle

    override func viewDidLoad() {
        super.viewDidLoad()

//        self.view.layer?.shouldRasterize = true
        self.view.canDrawSubviewsIntoLayer = true

        imageLayer.anchorPoint = CGPoint.zero
        imageLayer.position = CGPoint(x: 4, y: 40)
        imageLayer.contentsGravity = .resizeAspect
        imageLayer.shadowRadius = 1
        imageLayer.shadowColor = NSColor.labelColor.cgColor
        imageLayer.shadowOffset = CGSize.zero
        imageLayer.isOpaque = true
        backgroundLayer.anchorPoint = CGPoint.zero
        backgroundLayer.position = CGPoint(x: 0, y: 36)
        backgroundLayer.backgroundColor = NSColor.controlHighlightColor.cgColor
        backgroundLayer.cornerRadius = 8
        backgroundLayer.isHidden = true
        backgroundLayer.isOpaque = true

        let actions: [String : CAAction] = ["contents": NSNull(),
                                            "hidden": NSNull(),
                                            "bounds": NSNull()]
        imageLayer.actions = actions
        backgroundLayer.actions = actions

        view.layer?.addSublayer(backgroundLayer)
        view.layer?.addSublayer(imageLayer)
    }

    override func viewDidLayout() {
        let bounds = self.view.bounds

        imageLayer.bounds = CGRect(x: 0, y: 0, width: bounds.width - 8, height: bounds.height - 44)
        backgroundLayer.bounds = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height - 36)

        super.viewDidLayout()
    }

    static private let paragraph: NSParagraphStyle = {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        return paragraph
    }()

    private func updateSelectionHighlight() {
        if highlightState == .forSelection || (isSelected && highlightState != .forDeselection) {
            backgroundLayer.isHidden = false
            textField?.isHighlighted = true
        } else {
            backgroundLayer.isHidden = true
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

    override func keyDown(with event: NSEvent) {
        if event.keyCode == NSEnterCharacter, let action = doubleAction {
            target?.performSelector(onMainThread: action, with: nil, waitUntilDone: true)
        } else {
            super.keyDown(with: event)
        }
    }
    
}
