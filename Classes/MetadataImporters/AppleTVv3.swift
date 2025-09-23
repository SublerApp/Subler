//
//  AppleTVv3.swift
//
//  Created by Are Digranes on 04/11/2022.
//

import Foundation
import MP42Foundation

extension URLComponents {
    init(staticString string: StaticString) {
        guard let url = URLComponents(string: "\(string)") else {
            preconditionFailure("Invalid static URL string: \(string)")
        }
        self = url
    }
}

extension String {
    func unCamel() -> String {
        return unicodeScalars.reduce("") {
            if CharacterSet.uppercaseLetters.contains($1) && $0.count > 0 { return $0 + " " + String($1) } else if $0.count == 0 { return String($1).uppercased()}
            return $0 + String($1)
        }
    }
}

private extension MetadataResult {
    convenience init(item: AppleTVv3.Item, content: AppleTVv3.Content? = nil ) {
        self.init()
        switch item.type {

        case "Movie":

            self.mediaKind          = .movie
            self[.name]             = item.title
            self[.serviceContentID]  = item.id

            self[.genre]            = item.genres?.first?.name

            if let releaseDate = item.releaseDate {
                self[.releaseDate] = ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: (releaseDate / 1000)))
            }

            // Images
            if let artworks = item.images?.compactMap( { $0.value.addArtwork(type: .poster, title: $0.key.replacingOccurrences(of: "16X9", with: "Widescreen").unCamel()) } ) {
                self.remoteArtworks += artworks
            }
            // itunes
            let group = DispatchGroup()
            DispatchQueue.global().async(group: group) {
                if let iTunesMetadata = iTunesStore.quickiTunesSearch(movieName: item.title ?? "") {
                    self.remoteArtworks += iTunesMetadata.remoteArtworks
                }
            }
            group.wait()
            self.remoteArtworks = Artwork.unique(artworks: self.remoteArtworks)


        case "Show":

            self.mediaKind          = .tvShow
            self[.seriesName]       = item.title
            self[.serviceContentID]  = item.id

            self[.genre]            = item.genres?.first?.name

            if let episode = content {

                self[.serviceEpisodeID] = episode.id

                self[.name]             = episode.title
                self[.season]           = episode.seasonNumber
                self[.episodeNumber]    = episode.episodeNumber
                self[.genre]            = episode.genres?.first?.name
                self[.copyright]        = episode.copyright
                self[.network]          = episode.network
                self[.description]      = episode.description

                self[.serviceAdditionalContentID] = episode.seasonId

                self[.episodeID]        = String(format: "S%02dE%02d", episode.seasonNumber ?? 0, episode.episodeNumber ?? 0)
                self[.cast]             = episode.rolesSummary?.cast?.joined(separator: ", ")
                self[.director]         = episode.rolesSummary?.directors?.joined(separator: ", ")

                if let releaseDate = episode.releaseDate {
                    self[.releaseDate] = ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: (releaseDate / 1000)))
                }

                if let rating = episode.rating {
                    let prefix = rating.system
                        /*.replacingOccurrences(of: "_", with: "-")*/
                        .uppercased()
                    self[.rating] = "\(prefix)|\(rating.displayName)|\(rating.value)|"
                }

                // Images
                if let artworks = item.images?.compactMap( { $0.value.addArtwork(type: .poster, title: $0.key.replacingOccurrences(of: "16X9", with: "Widescreen").unCamel()) } ) {
                    self.remoteArtworks += artworks
                }
                if let artworks = episode.images?.compactMap( { $0.value.addArtwork(type: .episode, title: $0.key.replacingOccurrences(of: "16X9", with: "Widescreen").unCamel()) } ) {
                    self.remoteArtworks += artworks
                }
                // itunes
                let group = DispatchGroup()
                DispatchQueue.global().async(group: group) {
                    if let iTunesMetadata = iTunesStore.quickiTunesSearch(tvSeriesName: item.title ?? "", seasonNum: episode.seasonNumber ?? 1, episodeNum: episode.episodeNumber ?? 1) {
                        self.remoteArtworks += iTunesMetadata.remoteArtworks
                    }
                }
                group.wait()
                self.remoteArtworks = Artwork.unique(artworks: self.remoteArtworks)
            }

        default:

            self[.name]             = item.title
            self[.serviceContentID]  = item.id
            self[.description]      = item.type

            if let releaseDate = item.releaseDate {
                self[.releaseDate] = ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: (releaseDate / 1000)))
            }
        }
    }

    func insert(contentOf content: AppleTVv3.Content) {

        self[.copyright]    = content.copyright
        self[.studio]       = content.studio
        self[.network]      = content.network

        self[.cast]         = content.rolesSummary?.cast?.joined(separator: ", ")
        self[.director]     = content.rolesSummary?.directors?.joined(separator: ", ")

        if let rating = content.rating {
            let prefix = rating.system
                /*.replacingOccurrences(of: "_", with: "-")*/
                .uppercased()
            self[.rating] = "\(prefix)|\(rating.displayName)|\(rating.value)|"
        }

        if self[.releaseDate] == nil {
            if let releaseDate = content.releaseDate {
                self[.releaseDate] = ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: (releaseDate / 1000)))
            }
        }

        switch content.type {
        case "Movie":

            self[.description] = content.description

            if let artworks = content.images?.compactMap( { $0.value.addArtwork(type: .poster, title: $0.key.replacingOccurrences(of: "16X9", with: "Widescreen").unCamel()) } ) {
                self.remoteArtworks += artworks
            }
            self.remoteArtworks = Artwork.unique(artworks: self.remoteArtworks)

        case "Season":

            self[.seriesDescription] = content.description
            // FIXME
//            self[.seasonTitle] = content.title

            if let artworks = content.images?.compactMap( { $0.value.addArtwork(type: .season, title: $0.key.replacingOccurrences(of: "16X9", with: "Widescreen").unCamel()) } ) {
                self.remoteArtworks += artworks
            }
            self.remoteArtworks = Artwork.unique(artworks: self.remoteArtworks)

        default:
            print(content.type)
        }
    }

    func insert(contentOf items: [AppleTVv3.Item]) {

//        print("===== Cast & Crew =====")

        var cast: [String]          = []
        var directors: [String]     = []
        var producers: [String]     = []
        var execProducers: [String] = []
        var writers: [String]       = []
        var composers: [String]     = []
        var creators: [String]      = []
        var performers: [String]    = []

        for item in items {

//            print("[\(item.type)] \(item.roleTitle ?? "nil"): \(item.title ?? "nil") (\(item.characterName ?? "nil"))")

            if item.type == "Person" {
                // TODO: roleTitle is localized so need some solution
                if item.characterName != nil {
                    cast.append(item.title ?? "??")
                } else {

                    if item.roleTitle == "Actor"
                        || item.roleTitle == "演員"
                        || item.roleTitle == "演员"
                        || item.roleTitle == "出演者"
                        || item.roleTitle == "Interprete"
                        || item.roleTitle == "Reparto"
                        || item.roleTitle == "Schauspieler:in"
                        || item.roleTitle == "Interprétation"
                        || item.roleTitle == "الممثل"
                        || item.roleTitle == "Herec/herečka"
                        || item.roleTitle == "Skuespiller"
                        || item.roleTitle == "Näyttelijä"
                        || item.roleTitle == "Ηθοποιός"
                        || item.roleTitle == "Színész"
                        || item.roleTitle == "कलाकार"
                        || item.roleTitle == "Pemeran"
                        || item.roleTitle == "Pelakon"
                        || item.roleTitle == "משחק"
                        || item.roleTitle == "배우"
                        || item.roleTitle == "Acteur"
                        || item.roleTitle == "Aktor"
                        || item.roleTitle == "Elenco"
                        || item.roleTitle == "Актер/актриса"
                        || item.roleTitle == "Актор"
                        || item.roleTitle == "Skådespelare"
                        || item.roleTitle == "นักแสดง"
                        || item.roleTitle == "Aktör"
                        || item.roleTitle == "Diễn Viên"
                        || item.roleTitle == "Repartiment" { cast.append(item.title ?? "??")}
                    if item.roleTitle == "Voice"
                        || item.roleTitle == "配音"
                        || item.roleTitle == "声の出演"
                        || item.roleTitle == "Voce"
                        || item.roleTitle == "Stimmen"
                        || item.roleTitle == "Voix"
                        || item.roleTitle == "Veu"
                        || item.roleTitle == "الصوت"
                        || item.roleTitle == "Hlas"
                        || item.roleTitle == "Stemme"
                        || item.roleTitle == "Ääni"
                        || item.roleTitle == "Φωνή"
                        || item.roleTitle == "Narrátor"
                        || item.roleTitle == "קול"
                        || item.roleTitle == "성우"
                        || item.roleTitle == "Stem"
                        || item.roleTitle == "Głos"
                        || item.roleTitle == "Голос"
                        || item.roleTitle == "Озвучення"
                        || item.roleTitle == "Röst"
                        || item.roleTitle == "Seslendiren"
                        || item.roleTitle == "Lồng Tiếng"
                        || item.roleTitle == "Voz"  { cast.append(item.title ?? "??")}
                    if item.roleTitle == "Self"
                        || item.roleTitle == "本人"
                        || item.roleTitle == "Als sich selbst"
                        || item.roleTitle == "Ell/a mateix/a"
                        || item.roleTitle == "Se stesso"
                        || item.roleTitle == "Dans son propre rôle"
                        || item.roleTitle == "ذاتي"
                        || item.roleTitle == "Osobně"
                        || item.roleTitle == "Osobne"
                        || item.roleTitle == "Sig selv"
                        || item.roleTitle == "Omana itsenään"
                        || item.roleTitle == "Αυτοπροσώπως"
                        || item.roleTitle == "Önmaga"
                        || item.roleTitle == "עצמי"
                        || item.roleTitle == "본인"
                        || item.roleTitle == "Zichzelf"
                        || item.roleTitle == "Seg selv"
                        || item.roleTitle == "W roli własnej"
                        || item.roleTitle == "Próprio papel"
                        || item.roleTitle == "В роли себя"
                        || item.roleTitle == "У ролі себе"
                        || item.roleTitle == "Sig själv"
                        || item.roleTitle == "Kendisi"
                        || item.roleTitle == "Bản Thân"
                        || item.roleTitle == "Rol propio" { cast.append(item.title ?? "??")}
                    if item.roleTitle == "Guest star"
                        || item.roleTitle == "Gaststar"
                        || item.roleTitle == "Estrella convidada"
                        || item.roleTitle == "Estrella invitada" { cast.append(item.title ?? "??")}
                    if item.roleTitle == "Director"
                        || item.roleTitle == "導演"
                        || item.roleTitle == "导演"
                        || item.roleTitle == "監督"
                        || item.roleTitle == "Regista"
                        || item.roleTitle == "Regie"
                        || item.roleTitle == "Réalisation"
                        || item.roleTitle == "Dirección"
                        || item.roleTitle == "إخراج"
                        || item.roleTitle == "Režie"
                        || item.roleTitle == "Réžia"
                        || item.roleTitle == "Instruktør"
                        || item.roleTitle == "Ohjaaja"
                        || item.roleTitle == "Σκηνοθέτης"
                        || item.roleTitle == "Rendező"
                        || item.roleTitle == "निर्देशक"
                        || item.roleTitle == "Sutradara"
                        || item.roleTitle == "Pengarah"
                        || item.roleTitle == "בימוי"
                        || item.roleTitle == "감독"
                        || item.roleTitle == "Regisseur"
                        || item.roleTitle == "Regissør"
                        || item.roleTitle == "Reżyser"
                        || item.roleTitle == "Realização"
                        || item.roleTitle == "Direção"
                        || item.roleTitle == "Режиссер"
                        || item.roleTitle == "Режисер"
                        || item.roleTitle == "Regissör"
                        || item.roleTitle == "ผู้กำกับ"
                        || item.roleTitle == "Yönetmen"
                        || item.roleTitle == "Đạo Diễn"
                        || item.roleTitle == "Direcció" { directors.append(item.title ?? "??")}
                    if item.roleTitle == "Producer"
                        || item.roleTitle == "製作人"
                        || item.roleTitle == "制作人"
                        || item.roleTitle == "プロデューサー"
                        || item.roleTitle == "Produzione"
                        || item.roleTitle == "Produzent:in"
                        || item.roleTitle == "Production"
                        || item.roleTitle == "Producción"
                        || item.roleTitle == "انتاج"
                        || item.roleTitle == "Produkce"
                        || item.roleTitle == "Produkcia"
                        || item.roleTitle == "Tuottaja"
                        || item.roleTitle == "Παραγωγός"
                        || item.roleTitle == "निर्माता"
                        || item.roleTitle == "Produser"
                        || item.roleTitle == "Penerbit"
                        || item.roleTitle == "הפקה"
                        || item.roleTitle == "제작"
                        || item.roleTitle == "Producent"
                        || item.roleTitle == "Produsent"
                        || item.roleTitle == "Produção"
                        || item.roleTitle == "Продюсер"
                        || item.roleTitle == "ผู้อำนวยการสร้าง"
                        || item.roleTitle == "Yapımcı"
                        || item.roleTitle == "Nhà Sản Xuất"
                        || item.roleTitle == "Producció" { producers.append(item.title ?? "??") }
                    if item.roleTitle == "Executive Producer"
                        || item.roleTitle == "Produzione esecutiva"
                        || item.roleTitle == "Producción ejecutiva"
                        || item.roleTitle == "Produção executiva"
                        || item.roleTitle == "Producció executiva" { execProducers.append(item.title ?? "??") }
                    if item.roleTitle == "Writer"
                        || item.roleTitle == "作者"
                        || item.roleTitle == "編劇"
                        || item.roleTitle == "编剧"
                        || item.roleTitle == "脚本"
                        || item.roleTitle == "Sceneggiatura"
                        || item.roleTitle == "Drehbuchautor:in"
                        || item.roleTitle == "Scénario"
                        || item.roleTitle == "Escritor"
                        || item.roleTitle == "Guió"
                        || item.roleTitle == "كتابة"
                        || item.roleTitle == "Scénář"
                        || item.roleTitle == "Scenár"
                        || item.roleTitle == "Manuskriptforfatter"
                        || item.roleTitle == "Käsikirjoittaja"
                        || item.roleTitle == "Συγγραφέας"
                        || item.roleTitle == "Író"
                        || item.roleTitle == "लेखक"
                        || item.roleTitle == "Penulis"
                        || item.roleTitle == "כתיבה"
                        || item.roleTitle == "작가"
                        || item.roleTitle == "Schrijver"
                        || item.roleTitle == "Manusforfatter"
                        || item.roleTitle == "Scenarzysta"
                        || item.roleTitle == "Argumento"
                        || item.roleTitle == "Roteiro"
                        || item.roleTitle == "Сценарист"
                        || item.roleTitle == "Författare"
                        || item.roleTitle == "ผู้เขียนบท"
                        || item.roleTitle == "Yazan"
                        || item.roleTitle == "Tác Giả"
                        || item.roleTitle == "Guion"  { writers.append(item.title ?? "??")}
                    if item.roleTitle == "Music"
                        || item.roleTitle == "音樂"
                        || item.roleTitle == "音乐"
                        || item.roleTitle == "音楽"
                        || item.roleTitle == "음악"
                        || item.roleTitle == "Musik"
                        || item.roleTitle == "Musica"
                        || item.roleTitle == "الموسيقى"
                        || item.roleTitle == "מוזיקה"
                        || item.roleTitle == "Hudba"
                        || item.roleTitle == "Muzyka"
                        || item.roleTitle == "Muziek"
                        || item.roleTitle == "Musikk"
                        || item.roleTitle == "Musiikki"
                        || item.roleTitle == "Μουσική"
                        || item.roleTitle == "Zene"
                        || item.roleTitle == "संगीत"
                        || item.roleTitle == "ดนตรี"
                        || item.roleTitle == "Müzik"
                        || item.roleTitle == "Музыка"
                        || item.roleTitle == "Музика"
                        || item.roleTitle == "Nhạc"
                        || item.roleTitle == "Música" { composers.append(item.title ?? "??")}
                    if item.roleTitle == "Creator"
                        || item.roleTitle == "Creazione"
                        || item.roleTitle == "Creación"
                        || item.roleTitle == "Creació" { creators.append(item.title ?? "??")}
                    if item.roleTitle == "Performer"
                        || item.roleTitle == "演出者"
                        || item.roleTitle == "Artista"
                        || item.roleTitle == "Künstler"
                        || item.roleTitle == "Interprète"
                        || item.roleTitle == "Intérprete" { performers.append(item.title ?? "??")}
                    if item.roleTitle == "Narrator"
                        || item.roleTitle == "旁白"
                        || item.roleTitle == "叙述者"
                        || item.roleTitle == "ナレーター"
                        || item.roleTitle == "내레이터"
                        || item.roleTitle == "Narració"
                        || item.roleTitle == "الراوي"
                        || item.roleTitle == "קריינות"
                        || item.roleTitle == "Narrazione"
                        || item.roleTitle == "Verteller"
                        || item.roleTitle == "Narrátor"
                        || item.roleTitle == "Erzähler"
                        || item.roleTitle == "Αφηγητής"
                        || item.roleTitle == "Vypráví"
                        || item.roleTitle == "Narator"
                        || item.roleTitle == "Rozpráva"
                        || item.roleTitle == "Kertoja"
                        || item.roleTitle == "Fortæller"
                        || item.roleTitle == "Fortellerstemme"
                        || item.roleTitle == "Berättarröst"
                        || item.roleTitle == "कथावाचक"
                        || item.roleTitle == "Рассказчик"
                        || item.roleTitle == "Диктор"
                        || item.roleTitle == "Anlatıcı"
                        || item.roleTitle == "Narração"
                        || item.roleTitle == "Người Dẫn Chuyện"
                        || item.roleTitle == "Narración" { cast.append(item.title ?? "??")}
                    if item.roleTitle == "Host"
                        || item.roleTitle == "Presentador/a"
                        || item.roleTitle == "Conducció"
                        || item.roleTitle == "Presentatore"
                        || item.roleTitle == "Moderator:in"
                        || item.roleTitle == "Presentación" { cast.append(item.title ?? "??")}
                }
            }

            self[.cast]                 = cast.joined(separator: ", ")
            self[.director]             = directors.joined(separator: ", ")
            self[.producers]            = producers.joined(separator: ", ")
            self[.executiveProducer]    = execProducers.joined(separator: ", ")
            self[.screenwriters]        = writers.joined(separator: ", ")
            self[.composer]             = composers.joined(separator: ", ")


            if let artworks = item.images?.compactMap( { $0.value.addArtwork(type: .person, title: item.title ?? $0.key.unCamel() ) } ) {
                self.remoteArtworks += artworks
            }
            self.remoteArtworks = Artwork.unique(artworks: self.remoteArtworks)

        }

    }
}

public struct AppleTVv3: MetadataService {

    // MARK: Static constants

    private static let AppleTVAPI           = "Apple TV"
    private static let DefaultCountry       = "US"
    private static let DefaultLanguageCode  = "en_US"
    private static let StorefrontsFile      = "Storefronts"
    private static let Alpha2File           = "Alpha2"
    private static let TypeJSON             = "json"

    private static let FullsizeArtwork      = "1600x1600.jpg"
    private static let ThumbnailArtwork     = "330x330.jpg"

    // MARK: Set up URL
    private static let defaultVersion   = "82"
    private static let defaultCaller    = "js"

    private static let castShelfId      = "uts.col.CastAndCrew"

    public enum searchFilter {
        case movies
        case tvshows
        case sports
        case channels
        case castcrew
        case topresults

        var filter: String {
            switch self {
            case .castcrew: return "uts.col.search.PN"
            case .channels: return "uts.col.search.BR"
            case .movies: return "uts.col.search.MV"
            case .sports: return "uts.col.search.SE"
            case .topresults: return "uts.col.search.TR"
            case .tvshows: return "uts.col.search.SH"
            }
        }
    }

    private static let urlComponents = URLComponents(staticString: "https://uts-api.itunes.apple.com/")

    private static let configurationsPath   = "/uts/v3/configurations"
    private static let searchPath           = "/uts/v3/search"
    private static let showsPath            = "/uts/v3/shows"
    private static let seasonsPath          = "/uts/v3/seasons"
    private static let episodesPath         = "/uts/v3/episodes/"
    private static let moviesPath           = "/uts/v3/movies"

    private static let qualifierEpisodes    = "/episodes"
    private static let qualifierMetadata    = "/metadata"

    private func JSONRequest<T>(components: URLComponents, type: T.Type) -> T? where T : Decodable {
        guard let url = components.url else { return nil }
        //print(url)
        do {
            guard let data = URLSession.data(from: url) else { return nil }
            return try JSONDecoder().decode(type, from: data)
        } catch {
            print(error)
            return nil
        }
    }

    // MARK: Configuration

    private var current = CurrentConfiguration()

    private class CurrentConfiguration {
        var config: [String:String?] = [
            "caller":defaultCaller,
            "v":defaultVersion,
            "locale":"auto"
        ]

        public func set(store: (Int, String)) {
            config["sf"]     = String(store.0)
            config["locale"] = store.1
        }

        public func set(key: String, value: String) {
            config[key] = value
        }

        public func get(key: String) -> String? {
            if let value = config[key] { return value }
            return nil
        }

        public func configurationRequired() -> Bool {
            return (get(key: "utsk") ==  nil) || (get(key: "utscf") == nil) || (get(key: "pfm") == nil)
        }

        public func configuration() -> [URLQueryItem] {
            return config.compactMap({URLQueryItem(name: $0.key, value: $0.value)})
        }
    }

    private func urlConfiguration(storefront: Int, language: String = "auto") {

        current.set(store: (storefront,language))

        guard current.configurationRequired() else { return }

        var components = AppleTVv3.urlComponents
        components.path = AppleTVv3.configurationsPath
        components.queryItems = current.configuration()

        if let results = JSONRequest(components: components, type: DataWrapper<ConfigurationCodable>.self)?
            .data.applicationProps.requiredParamsMap.Default {
            current.set(key: "utsk", value: results.utsk)
            current.set(key: "utscf", value: results.utscf)
            current.set(key: "pfm", value: results.pfm)
        }

    }

    // Create list of all Apple storefronts
    struct Storefront: Codable {

        fileprivate let data: [String:StorefrontDetail]

        fileprivate struct StorefrontDetail: Codable {
            let localesSupported: [String]
            let storefrontId: Int
        }

        fileprivate static let storefronts: Storefront? = {
            guard let url = Bundle.main.url(forResource: StorefrontsFile, withExtension: TypeJSON) else { return nil }
            return try? JSONDecoder().decode(Storefront.self, from: try Data(contentsOf: url))
        }()

        fileprivate static func language(from countryCode: String, countryLanguages: [String]) -> [String] { return countryLanguages.map { "\(getCountryName(countryCode) ?? "Unknown") (\(languageDecode($0)))" }
        }

        public static func getCountryCode(storefront: Int) -> String? {
            guard let country = Storefront.storefronts?.data.filter({ $0.value.storefrontId == storefront }).first else { return nil }
            return country.key
        }

        public static func getCountryCode(name: String) -> String? {
            guard let url = Bundle.main.url(forResource: Alpha2File, withExtension: TypeJSON) else { return nil }
            if let results = try? JSONDecoder().decode([String:String].self, from: try Data(contentsOf: url)).filter({ $0.value == name }) {
                return results.first?.key ?? nil
            }
            return nil
        }

        public static func getCountryName(_ code: String) -> String? {
            guard let url = Bundle.main.url(forResource: Alpha2File, withExtension: TypeJSON) else { return nil }
            if let results = try? JSONDecoder().decode([String:String].self, from: try Data(contentsOf: url)).filter({ $0.key == code }) {
                return results.first?.value ?? nil
            }
            return nil
        }

        private static func languageDecode(_ code: String) -> String {
            let code = code.split(separator: "_")
            guard code.count == 2 else { return "" }
            return "\(MP42Languages.defaultManager .localizedLang(forExtendedTag: String(code[0]))) \(String(code[1]))"
        }

        public static func getStorefront(from country: String) -> (Int, String)? {
            let split = country.components(separatedBy: " (")
            guard let storefront = storefronts?.data.first(where: {
                getCountryName($0.key) == split[0] } ),
               let language = storefront.value.localesSupported.first(where: { "\(languageDecode($0)))" == split[1] }) else { return nil }
            return (storefront.value.storefrontId, language)
        }
    }


    public var languageType: LanguageType { return .custom }

    public var languages: [String] {
        get {
            guard let results = Storefront.storefronts?.data
                .compactMap({ Storefront.language(from: $0.key, countryLanguages: $0.value.localesSupported) })
                .flatMap({ $0 })
                .sorted() else { return [] }
            return results
        }
    }

    public var defaultLanguage: String { get { return Storefront.language(from: AppleTVv3.DefaultCountry, countryLanguages: [AppleTVv3.DefaultLanguageCode]).first ?? "Unknown" } }

    public var name: String { return AppleTVv3.AppleTVAPI }

    public func search(tvShow: String, language: String) -> [String] {
        return []
    }

    public func search(tvShow: String, language: String, season: Int?, episode: Int?) -> [MetadataResult] {

        if let storefront = Storefront.getStorefront(from: language) {
            urlConfiguration(storefront: storefront.0, language: storefront.1)
        }

        let results = search(term: tvShow, filter: .tvshows)
        let show = results.first(where: { $0.title?.caseInsensitiveCompare(tvShow) == .orderedSame }) ?? results.first

        guard let show = show else { return [] }

        let contentResults = getEpisodes(showId: show.id, season: season, episode: episode)

        return contentResults.map { MetadataResult(item: show, content: $0 )}
    }

    public func loadTVMetadata(_ metadata: MetadataResult, language: String) -> MetadataResult {
        return details(metadata)
    }

    public func search(movie: String, language: String) -> [MetadataResult] {

        if let storefront = Storefront.getStorefront(from: language) {
            urlConfiguration(storefront: storefront.0, language: storefront.1)
        }

        return search(term: movie, filter: .movies).map { MetadataResult(item: $0) }
    }

    public func loadMovieMetadata(_ metadata: MetadataResult, language: String) -> MetadataResult {
        return details(metadata)
    }

    public enum MediaType {
        case movie
        case tvShow(season: Int?)

        var description: String {
            get {
                switch self {
                case .movie:
                    return "Movie"
                case .tvShow:
                    return "Show"
                }
            }
        }
    }

    func searchArtwork(term: String, store: iTunesStore.Store, type: MediaType = .movie) -> [Artwork] {
        urlConfiguration(storefront: store.storeCode)

        let results = search(term: term, filter: .topresults )

        guard let artworks = results.first?.images?.compactMap( { $0.value.addArtwork(type: .poster) } ) else { return [] }

        return artworks
    }

    private func search(term: String, filter: searchFilter) -> [Item] {

        var components = AppleTVv3.urlComponents
        components.path = AppleTVv3.searchPath
        components.queryItems = current.configuration()
        components.queryItems?.append(URLQueryItem(name: "searchTerm", value: term))

        if filter == .topresults {
            components.queryItems?.append(URLQueryItem(name: "topResultsOnly", value: "true"))
        }

        guard let results = JSONRequest(components: components, type: DataWrapper<GeneralResult>.self) else { return [] }
        guard let item = results.data.canvas?.shelves?
            .filter({ $0.id == filter.filter })
            .compactMap({ $0.items })
            .flatMap({ $0 }) else { return [] }
        return item

    }

    private func details(_ metadata: MetadataResult) -> MetadataResult {

        guard let id = metadata[.serviceContentID] else { return metadata }

        if metadata.mediaKind == .movie {

            var components = AppleTVv3.urlComponents
            components.path = AppleTVv3.moviesPath + "/\(id)"
            components.queryItems = current.configuration()

            guard let results = JSONRequest(components: components, type: DataWrapper<GeneralResult>.self) else { return metadata }
            guard let content = results.data.content else { return metadata }
            metadata.insert(contentOf: content)

            guard let cast = results.data.canvas?.shelves?
                .filter({ $0.id == AppleTVv3.castShelfId })
                .first?.items else { return metadata }
            metadata.insert(contentOf: cast)

        }

        if metadata.mediaKind == .tvShow {

            guard let sID = metadata[.serviceAdditionalContentID] else { return metadata }

            var components = AppleTVv3.urlComponents
            components.path = AppleTVv3.seasonsPath + "/\(sID)" + AppleTVv3.qualifierMetadata
            components.queryItems = current.configuration()

            guard let results = JSONRequest(components: components, type: ContentDetail.self) else { return metadata }
            metadata.insert(contentOf: results.data)

            guard let shID = metadata[.serviceContentID] else { return metadata }
            components.path = AppleTVv3.showsPath + "/\(shID)"
            guard let results = JSONRequest(components: components, type: DataWrapper<GeneralResult>.self) else { return metadata }

            guard let cast = results.data.canvas?.shelves?
                .filter({ $0.id == AppleTVv3.castShelfId })
                .first?.items else { return metadata }
            metadata.insert(contentOf: cast)

        }

        return metadata
    }

    private func getEpisodes(showId: String, season: Int? = nil, episode: Int? =  nil) -> [Content] {

        var components = AppleTVv3.urlComponents
        components.path = AppleTVv3.showsPath + "/\(showId)" + AppleTVv3.qualifierEpisodes
        components.queryItems = current.configuration()
        components.queryItems?.append(URLQueryItem(name: "nextToken", value: "0:1"))
        components.queryItems?.append(URLQueryItem(name: "includeSeasonSummary", value: "true"))

        guard let results = JSONRequest(components: components, type: DataWrapper<ShowEpisodes>.self) else { return [] }

        components.queryItems = current.configuration()

        if season != nil {
            if let summaries = results.data.seasonSummaries {
                var startToken = 0, endToken = 1
                for s in summaries {
                    if s.seasonNumber == season {
                        if let e = episode {
                            startToken += e - 1
                        } else {
                            endToken += s.episodeCount - 1
                        }
                    } else if s.seasonNumber > season! {
                    } else {
                        startToken += s.episodeCount
                    }
                }
                components.queryItems?.append(URLQueryItem(name: "nextToken", value: "\(startToken):\(endToken)"))
            }

        } else {
            let token = results.data.totalEpisodeCount
            components.queryItems?.append(URLQueryItem(name: "nextToken", value: "0:\(token)"))
        }


        guard let results = JSONRequest(components: components, type: DataWrapper<ShowEpisodes>.self) else { return [] }

        return results.data.episodes ?? []
    }

    // MARK: JSON structs

    private struct DataWrapper<T>: Codable where T : Codable  {
        let data: T
    }

    private struct ContentDetail: Codable {
        let data: Content
    }

    private struct ConfigurationCodable: Codable {
        let applicationProps: ApplicationProps
        struct ApplicationProps: Codable     { let requiredParamsMap: RequiredParamsMap}
        struct RequiredParamsMap: Codable    { let Default: RequiredParams }
    }

    private struct RequiredParams: Codable {
        let caller:     String
        let locale:     String
        let utscf:      String
        let utsk:       String
        let pfm:        String
        let sf:         String
        let v:          String
    }

    private struct GeneralResult: Codable {
        let canvas: Canvas?
        let content: Content?
        struct Canvas: Codable { let shelves: [Shelf]? }
    }

    private struct Shelf: Codable {
        let displayType: String?
        let id: String
        let markerType: String?
        let title: String?
        let url: URL?
        let items: [Item]?
    }

    private struct ShowEpisodes: Codable {
        let episodes: [Content]?
        let seasonSummaries: [SeasonSummary]?
        let selectedEpisodeIndex: Int?
        let totalEpisodeCount: Int
    }

    private struct SeasonSummary: Codable {
        let episodeCount: Int
        let id: String
        let seasonNumber: Int
        let title: String
    }

    fileprivate struct Item: Codable {
        let genres: [Genre]?
        let id: String
        let images: [String:Image]?
        let releaseDate: TimeInterval?
        let title: String?
        let type: String
        let url: URL?
        let airingType: String?
        let endAirTime: TimeInterval?
        let isGeoRestricted: Bool?
        let leagueAbbreviation: String?
        let leagueId: String?
        let leagueName: String?
        let leagueShortName: String?
        let shortTitle: String?
        let showVersions: Bool?
        let sportId: String?
        let sportName: String?
        let startAirTime: TimeInterval?
        let startTime: TimeInterval?
        let flavorType: String?
        let isExternalUrl: Bool?
        let shortNote: String?
        let tagLine: String?
        let characterName: String?
        let roleTitle: String?
    }

    fileprivate struct Content: Codable {
        let commonSenseMedia: CommonSenseMedia?
        let copyright: String?
        let countriesOfOrigin: [CountryCode]?
        let description: String?
        let duration: Int?
        let genres: [Genre]?
        let id: String
        let images: [String:Image]?
        let network: String?
        let originalSpokenLanguages: [Language]?
        let rating: Rating?
        let releaseDate: TimeInterval?
        let rolesSummary: Roles?
        let studio: String?
        let title: String
        let type: String
        let url: URL?
        let episodeIndex: Int?
        let episodeNumber: Int?
        let fractionalEpisodeNumber: Float?
        let isFirstEpisode: Bool?
        let seasonId: String?
        let seasonNumber: Int?
        let seasonUrl: URL?
        let showId: String?
        let showTitle: String?
        let showUrl: URL?
    }

    fileprivate struct Genre: Codable {
        let id: String
        let name: String
        let type: String
        let url: URL
    }

    fileprivate struct Roles: Codable {
        let cast: [String]?
        let directors: [String]?
    }

    fileprivate struct CountryCode: Codable {
        let countryCode: String
        let displayName: String
    }

    fileprivate struct Language: Codable {
        let displayName: String
        let locale: String
    }

    fileprivate struct Rating: Codable {
        let displayName: String
        let name: String
        let system: String
        let systemType: String
        let value: Int
    }

    fileprivate struct CommonSenseMedia: Codable {
        let contentInfo: [CommonSenseContentInfo]
        let oneLiner: String
        let recommendedAge: Int
    }

    fileprivate struct CommonSenseContentInfo: Codable {
        let label: String
        let rating: Int
    }

    fileprivate struct Image: Codable {
        let height: Int
        let width: Int
        let supportsLayeredImage: Bool
        let url: String

        var size: ArtworkSize {
            get {
                if 100*width/height == 46 { return .vertical }
                if 100*width/height == 144 { return .fullscreen }
                if 100*width/height == 177 { return .widescreen }
                if width == height { return .square }
                if width > height { return .rectangle }
                return .standard
            }
        }

        func addArtwork(type: ArtworkType, title: String = "Apple TV") -> Artwork? {
            guard var c = URLComponents(string: url) else { return nil }
            c.path = String(c.path[..<(c.path.lastIndex(of: "/") ?? c.path.endIndex)]) + "/\(AppleTVv3.FullsizeArtwork)"
            guard let fullsizeURL = c.url else { return nil }
            c.path = String(c.path[..<(c.path.lastIndex(of: "/") ?? c.path.endIndex)]) + "/\(AppleTVv3.ThumbnailArtwork)"
            guard let thumbnailURL = c.url else { return nil }
            return Artwork(url: fullsizeURL, thumbURL: thumbnailURL, service: title , type: type, size: size)
        }

    }
}

