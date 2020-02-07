//
//  Token.swift
//  Subler
//
//  Created by Damiano Galassi on 06/03/2018.
//

import Foundation
import MP42Foundation

public class Token: Codable {

    private static let calendar: Calendar = {
        return Calendar(identifier: .gregorian)
    }()

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private static let partialFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

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

    enum DateFormat: Int, Codable {
        case none
        case year
        case month
        case day
    }

    let text: String
    let isPlaceholder: Bool

    var textCase: Case
    var textPadding: Padding
    var textDateFormat: DateFormat

    init(text: String, isPlaceholder: Bool = true) {
        self.text = text
        self.textCase = .none
        self.textPadding = .none
        self.textDateFormat = .none
        self.isPlaceholder = isPlaceholder
    }

    public required init (from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.text = try values.decode(String.self, forKey: .text)
        self.isPlaceholder = try values.decode(Bool.self, forKey: .isPlaceholder)
        self.textCase = try values.decode(Case.self, forKey: .textCase)
        self.textPadding = try values.decode(Padding.self, forKey: .textPadding)
        self.textDateFormat = (try? values.decode(DateFormat.self, forKey: .textDateFormat)) ?? .none
    }

    private func component(_ component: Calendar.Component, from string: String) -> Int? {
        if let date = Token.formatter.date(from: string) ?? Token.partialFormatter.date(from: string) {
            return Token.calendar.component(component, from: date)
        } else {
            return nil
        }
    }

    func format(metadataItem item: MP42MetadataItem) -> String {
        if item.dataType == .date, let date = item.dateValue {
            return format(date: date)
        } else if let text = item.stringValue {
            return format(text: text)
        } else {
            return ""
        }
    }

    func format(date: Date) -> String {
        var formattedText = Token.partialFormatter.string(from: date)

        switch textDateFormat {
        case .none:
            break
        case .year:
            formattedText = String(Token.calendar.component(.year, from: date))
        case .month:
            formattedText = String(Token.calendar.component(.month, from: date))
        case .day:
            formattedText = String(Token.calendar.component(.day, from: date))
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

    func format(text: String) -> String {
        var formattedText = text

        switch textDateFormat {
        case .none:
            break
        case .year:
            if let year = component(.year, from: text) {
                formattedText = String(year)
            }
        case .month:
            if let month = component(.month, from: text) {
                formattedText = String(month)
            }
        case .day:
            if let day = component(.day, from: text) {
                formattedText = String(day)
            }
        }

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
        prefix(1).uppercased() + dropFirst()
    }

    func camelCased() -> String {
        split(separator: " ")
            .map { $0.lowercased().capitalizingFirstLetter() }
            .joined()
    }

    func snakeCased() -> String {
        split(separator: " ")
            .map { $0.lowercased() }
            .joined(separator: "_")
    }

    func trainCased() -> String {
        split(separator: " ")
            .map { $0.lowercased() }
            .joined(separator: "-")
    }

    func dotCased() -> String {
        split(separator: " ")
            .map { $0.lowercased() }
            .joined(separator: ".")
    }
}

