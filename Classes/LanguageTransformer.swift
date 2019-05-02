//
//  LanguageTransformer.swift
//  Subler
//
//  Created by Damiano Galassi on 11/11/2017.
//

import Foundation
import MP42Foundation

class LanguageTransformer : ValueTransformer {

    private let langManager = MP42Languages.defaultManager

    override class func transformedValueClass() -> Swift.AnyClass {
        return NSString.self
    }

    override class func allowsReverseTransformation() -> Bool {
        return true
    }

    override func transformedValue(_ value: Any?) -> Any? {
        let code = value as! String
        let lang = langManager.localizedLang(forExtendedTag: code)
        return lang
    }

    override func reverseTransformedValue(_ value: Any?) -> Any? {
        let lang = value as! String
        let code = langManager.extendedTag(forLocalizedLang: lang)
        return code
    }

}
