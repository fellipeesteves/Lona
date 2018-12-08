//
//  RenderableView.swift
//  LonaStudio
//
//  Created by Devin Abbott on 12/5/18.
//  Copyright © 2018 Devin Abbott. All rights reserved.
//

import AppKit

enum RenderableType: Equatable {
    case view
    case text(TextAttributes)
    case image(ImageAttributes)
    //        case animation
    case vector(ImageAttributes)
}

struct ViewAttributes: Equatable {
    init() {
        layerName = ""
        frame = .zero
        multipliedFillColor = .clear
        opacity = 1
        cornerRadius = 0
        borderWidth = 0
        multipliedBorderColor = .clear
        shadow = nil
        type = .view
    }

    var layerName: String
    var frame: NSRect
    var multipliedFillColor: NSColor
    var opacity: CGFloat
    var cornerRadius: CGFloat
    var borderWidth: CGFloat
    var multipliedBorderColor: NSColor
    var shadow: NSShadow?
    var type: RenderableType

    func makeView() -> CSView {
        let view = CSView(frame: frame)

        configureView(view)

        return view
    }

    func configureView(_ view: CSView) {
        view.frame = frame
        view.layerName = layerName
        view.multipliedFillColor = multipliedFillColor
        view.opacity = opacity
        view.cornerRadius = cornerRadius
        view.borderWidth = borderWidth
        view.multipliedBorderColor = multipliedBorderColor
        view.shadow = shadow

        view.getInnerSubviews().filter { $0 is CSTextView }.forEach { $0.removeFromSuperview() }

        switch type {
        case .view:
            view.backgroundImage = nil
        case .text(let params):
            view.backgroundImage = nil
            let textView = params.makeTextView(size: frame.size)

            view.addInnerSubview(textView)
        case .image(let params), .vector(let params):
            view.backgroundImage = params.image
            view.resizingMode = params.resizingMode
        }
    }
}

struct TextAttributes: Equatable {
    var text: String
    var textStyle: TextStyle
    var textAlignment: NSTextAlignment
    var numberOfLines: Int

    func makeAttributedString() -> NSAttributedString {
        var attributeDictionary = textStyle.attributeDictionary

        // Add alignment to text style attributes
        let titleParagraphStyle = textStyle.paragraphStyle
        titleParagraphStyle.alignment = textAlignment
        attributeDictionary[.paragraphStyle] = titleParagraphStyle

        return NSAttributedString(string: text, attributes: attributeDictionary)
    }

    func makeTextView(size: CGSize) -> NSTextView {
        let textView = CSTextView()
        textView.isEditable = false
        textView.isSelectable = false

        textView.frame = NSRect(origin: .zero, size: size)
        textView.textContainer?.lineFragmentPadding = 0.0
        textView.textContainer?.lineBreakMode = .byTruncatingTail
        textView.textContainer?.maximumNumberOfLines = numberOfLines

        textView.textStorage?.append(makeAttributedString())
        textView.drawsBackground = false

        return textView
    }

    static func fromConfiguredLayer(_ configuredLayer: ConfiguredLayer) -> TextAttributes {
        let text = getLayerText(configuredLayer: configuredLayer)

        let textStyleId = configuredLayer.config.get(
            attribute: "textStyle",
            for: configuredLayer.layer.name).string ?? configuredLayer.layer.font ?? "regular"

        let textStyle = CSTypography.getFontBy(id: textStyleId).font

        let textAlignment = NSTextAlignment(configuredLayer.layer.textAlign ?? "left")

        var maximumNumberOfLines = 0

        if let numberOfLines = configuredLayer.layer.numberOfLines, numberOfLines > -1 {
            maximumNumberOfLines = numberOfLines
        }

        return TextAttributes(
            text: text,
            textStyle: textStyle,
            textAlignment: textAlignment,
            numberOfLines: maximumNumberOfLines)
    }
}

struct ImageAttributes: Equatable {
    var image: NSImage
    var resizingMode: CGSize.ResizingMode
}

struct RenderableElement {
    var node: ViewAttributes
    var children: [RenderableElement]

    func makeViewHierarchy() -> CSView {
        let view = node.makeView()

        children.forEach { child in
            let childView = child.makeViewHierarchy()

            view.addInnerSubview(childView)
        }

        return view
    }

    func updateViewHierarchy(_ view: NSView, previous: RenderableElement) {
        guard let view = view as? CSView else { return }

        if node != previous.node {
            node.configureView(view)
        }

        let subviews = view.getInnerSubviews().map { $0 as? CSView }.compactMap { $0 }

        for index in 0..<max(children.count, previous.children.count) {
            if index < children.count && index < previous.children.count {
                children[index].updateViewHierarchy(subviews[index], previous: previous.children[index])
            } else if index < children.count && index >= previous.children.count {
                let childView = children[index].makeViewHierarchy()

                view.addSubview(childView)
            } else if index >= children.count && index < previous.children.count {
                subviews[index].removeFromSuperview()
            }
        }
    }
}
