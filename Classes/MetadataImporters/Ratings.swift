//
//  Ratings.swift
//  Subler
//
//  Created by Damiano Galassi on 04/02/2020.
//

import Foundation

final class Ratings {
    static let shared = Ratings()
    let countries: [Country]

    private init() {
        guard let url = Bundle.main.url(forResource: "Ratings", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let countries = try? JSONDecoder().decode([Country].self, from: data) else { fatalError() }

        self.countries = countries
    }

    func rating(countryCode: String, mediaKind: MediaKind, name: String) -> Rating? {
        guard let country = countries.first(where: { $0.displayName == countryCode }) else { return nil }
        return country.ratings.first(where: {$0.media.contains(mediaKind.description) && $0.displayName == name})
    }

    func rating(storeCode: Int, mediaKind: MediaKind, code: String) -> Rating? {
        guard let country = countries.first(where: { $0.storeCode == storeCode }) else { return nil }
        return country.ratings.first(where: {$0.media.contains(mediaKind.description) && $0.code == code})
    }
}

struct Country: Decodable {
    let displayName: String
    let storeCode: Int
    let ratings: [Rating]

    enum CodingKeys: String, CodingKey {
        case displayName = "country", storeCode, ratings
    }
}

struct Rating: Decodable {
    let media: String
    let prefix: String
    let code: String
    let value: String
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case media, prefix, code = "itunes-code", value = "itunes-value", displayName = "description"
    }

    var iTunesCode: String { "\(prefix)|\(code)|\(value)|" }
}
