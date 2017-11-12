//
//  LanguageTransformer.swift
//  Subler
//
//  Created by Damiano Galassi on 11/11/2017.
//

import Foundation

@objc(SBLanguageTransformer) class LanguageTransformer : ValueTransformer {

    private let langManager = MP42Languages.defaultManager

    override class func transformedValueClass() -> Swift.AnyClass {
        return NSString.self
    }

    override class func allowsReverseTransformation() -> Bool {
        return true
    }

    override func transformedValue(_ value: Any?) -> Any? {
        return langManager.localizedLang(forExtendedTag: value as! String)
    }

    override func reverseTransformedValue(_ value: Any?) -> Any? {
        return langManager.extendedTag(forLocalizedLang: value as! String)
    }

}
