//
//  Token.swift
//  Subler
//
//  Created by Damiano Galassi on 06/03/2018.
//

import Foundation

class Token: Codable {

    enum Case: Int, Codable {
        case none
        case capitalize
        case lower
        case upper
        case camel
        case snake
        case train
        case dot
    }

    enum Padding: Int, Codable {
        case none
        case leadingzero
    }

    let text: String
    let isPlaceholder: Bool

    var textCase: Case
    var textPadding: Padding

    init(text: String, isPlaceholder: Bool = true) {
        self.text = text
        self.textCase = .none
        self.textPadding = .none
        self.isPlaceholder = isPlaceholder
    }

    func format(text: String) -> String {
        var formattedText = text

        switch textCase {
        case .none:
            break
        case .capitalize:
            formattedText = text.capitalized
        case .lower:
            formattedText = text.lowercased()
        case .upper:
            formattedText = text.uppercased()
        case .camel:
            formattedText = text.camelCased()
        case .snake:
            formattedText = text.snakeCased()
        case .train:
            formattedText = text.trainCased()
        case .dot:
            formattedText = text.dotCased()
        }

        switch textPadding {
        case .none:
            break
        case .leadingzero:
            let formatter = NumberFormatter()
            formatter.minimumIntegerDigits = 2
            formatter.paddingPosition = .beforePrefix
            formatter.paddingCharacter = "0"
            if let number = Int(formattedText) {
                formattedText = formatter.string(from: number as NSNumber) ?? formattedText
            }
        }

        return formattedText
    }
}

fileprivate extension String {
    func capitalizingFirstLetter() -> String {
        return prefix(1).uppercased() + dropFirst()
    }

    func camelCased() -> String {
        return self.components(separatedBy: " ")
            .map { return $0.lowercased().capitalizingFirstLetter() }
            .joined()
    }

    func snakeCased() -> String {
        return self.components(separatedBy: " ")
            .map { return $0.lowercased() }
            .joined(separator: "_")
    }

    func trainCased() -> String {
        return self.components(separatedBy: " ")
            .map { return $0.lowercased() }
            .joined(separator: "-")
    }

    func dotCased() -> String {
        return self.components(separatedBy: " ")
            .map { return $0.lowercased() }
            .joined(separator: ".")
    }
}

extension UserDefaults {

    func tokenArray(forKey defaultName: String) -> [Token] {
        let decoder = JSONDecoder()

        guard let jsonData = self.data(forKey: defaultName),
             let decoded = try? decoder.decode([Token].self, from: jsonData) else { return [] }

        return decoded
    }

    func set(_ tokenArray: [Token], forKey defaultName: String) {
        let encoder = JSONEncoder()
        let jsonData = try? encoder.encode(tokenArray)
        self.set(jsonData, forKey: defaultName)
    }

}
