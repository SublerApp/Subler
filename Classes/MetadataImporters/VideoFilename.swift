//
//  VideoFilename.swift
//  Subler
//
//  Native Swift port of the bundled ParseFilename perl script,
//  i.e. of Video::Filename 0.35.1 by Behan Webster (with the 2010
//  movie-year modification by Douglas Stebila) and of the roman2int
//  function from Text::Roman by Peter de Padua Krauss. Those modules are
//  dual-licensed Artistic/GPL; this derived port inherits those terms.
//
//  Only Foundation is used, so this file can also be compiled standalone
//  for the test harness.
//

import Foundation

// MARK: - Regex helpers

private func regex(_ pattern: String) -> NSRegularExpression {
    return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
}

private func captures(of re: NSRegularExpression, in string: String) -> [String?]? {
    let range = NSRange(string.startIndex..., in: string)
    guard let match = re.firstMatch(in: string, options: [], range: range) else { return nil }
    return (1..<match.numberOfRanges).map {
        let r = match.range(at: $0)
        guard r.location != NSNotFound, let swiftRange = Range(r, in: string) else { return nil }
        return String(string[swiftRange])
    }
}

/// Replaces every match of `re` in `string` with the result of `transform`,
/// which receives the capture groups (group 0 first, like perl's $&, $1...).
private func replacingMatches(of re: NSRegularExpression, in string: String,
                              transform: ([String?]) -> String) -> String {
    let range = NSRange(string.startIndex..., in: string)
    var result = ""
    var last = string.startIndex
    for match in re.matches(in: string, options: [], range: range) {
        guard let matchRange = Range(match.range, in: string) else { continue }
        let groups: [String?] = (0..<match.numberOfRanges).map {
            let r = match.range(at: $0)
            guard r.location != NSNotFound, let swiftRange = Range(r, in: string) else { return nil }
            return String(string[swiftRange])
        }
        result += string[last..<matchRange.lowerBound]
        result += transform(groups)
        last = matchRange.upperBound
    }
    result += string[last...]
    return result
}

// MARK: - Text::Roman (roman2int)

/// Strict parser for conventional roman numerals (1...3999), replicating
/// Text::Roman's roman2int: all-uppercase or all-lowercase only, no
/// over-repetition, subtractive pairs validated.
func roman2int(_ input: String) -> Int? {
    guard !input.isEmpty else { return nil }
    let upper = input.uppercased()
    // Mixed case (e.g. "Xv") is not a roman numeral.
    guard upper == input || input.lowercased() == input else { return nil }
    guard upper.range(of: "^[IXCMVLD]+$", options: .regularExpression) != nil else { return nil }
    guard upper.range(of: "([IXCM])\\1{3,}|([VLD])\\2+", options: .regularExpression) == nil
        else { return nil }

    // Substitute subtractive pairs with placeholder symbols, then reject
    // smaller-order symbols appearing after a subtractive pair of that order.
    var t = upper
    for (pair, sub) in [("IV", "A"), ("IX", "B"), ("XL", "E"),
                        ("XC", "F"), ("CD", "G"), ("CM", "H")] {
        t = t.replacingOccurrences(of: pair, with: sub)
    }
    guard t.range(of: "[AB].*?I|[EF].*?X|[GH].*?C", options: .regularExpression) == nil
        else { return nil }

    let values: [Character: Int] = ["I": 1, "V": 5, "X": 10, "L": 50, "C": 100,
                                    "D": 500, "M": 1000,
                                    "A": 4, "B": 9, "E": 40, "F": 90, "G": 400, "H": 900]
    var sum = 0
    var previous = 0
    for ch in t.reversed() {
        guard let value = values[ch] else { return nil }
        if value < previous { return nil }
        sum += value
        previous = value
    }
    return sum
}

// MARK: - English number words (Video::Filename _num2int/_allnum2int)

/// Converts an English number phrase ("twenty five", "one hundred and two")
/// to an integer, replicating _num2int's parsing order exactly.
func englishNumberToInt(_ input: String) -> Int {
    var str = input.lowercased()[...]
    var n = 0, c = 0, sum = 0

    // (prefix, action); order matters and mirrors the perl cascade.
    let steps: [(String, () -> Void)] = [
        ("zero", {}), ("and", {}), ("&", {}),
        ("one", { n += 1 }),
        ("two", { n += 2 }), ("twen", { n += 2 }),
        ("three", { n += 3 }), ("thir", { n += 3 }),
        ("four", { n += 4 }),
        ("five", { n += 5 }), ("fif", { n += 5 }),
        ("six", { n += 6 }),
        ("seven", { n += 7 }),
        ("eight", { n += 8 }),
        ("nine", { n += 9 }),
        ("ten", { n += 10 }), ("teen", { n += 10 }), ("een", { n += 10 }),
        ("eleven", { n += 11 }),
        ("twelve", { n += 12 }),
        ("ty", { n *= 10 }), ("y", { n *= 10 }),
        ("hundred", { c += n * 100; n = 0 }),
        ("thousand", { sum += (c + n) * 1000; c = 0; n = 0 }),
        ("million", { sum += (c + n) * 1_000_000; c = 0; n = 0 }),
        ("billion", { sum += (c + n) * 1_000_000_000; c = 0; n = 0 }),
        ("trillion", { sum += (c + n) * 1_000_000_000_000; c = 0; n = 0 }),
    ]

    outer: while !str.isEmpty {
        while let first = str.first, first == " " || first == "," || first.isWhitespace {
            str = str.dropFirst()
        }
        if str.isEmpty { break }
        for (prefix, action) in steps {
            if str.hasPrefix(prefix) {
                str = str.dropFirst(prefix.count)
                action()
                continue outer
            }
        }
        break // unlike perl, don't spin forever on unparseable input
    }
    return sum + c + n
}

private let numberWordsPattern: String = {
    let single = "zero|one|two|three|five|(?:twen|thir|four|fif|six|seven|nine)(?:teen|ty)?" +
                 "|eight(?:een|y)?|ten|eleven|twelve"
    let mult = "hundred|thousand|(?:m|b|tr)illion"
    let word = "(?:\(single)|\(mult))"
    let wordOrJoiner = "(?:\(single)|\(mult)|\\s|,|and|&)"
    return "((?:\(word)\(wordOrJoiner)+)?\(word))"
}()

// The keyword contexts in which numbers are translated.
private let numberPrefix = "(?:d|dvd|disc|disk|s|se|season|e|ep|episode)[\\s._-]+"
private let numberEnd = "(?:day|part)[\\s._-]+"

private let romanPattern = "[MC]*[DC]*[CX]*[LX]*[XI]*[VI]*"

private let romanAfterPrefixRE = regex("\\b(\(numberPrefix))(\(romanPattern))\\b")
private let romanAtEndRE = regex("\\b(\(numberEnd))(\(romanPattern))$")
private let wordsAfterPrefixRE = regex("(\(numberPrefix))\\b\(numberWordsPattern)\\b")
private let wordsAtEndRE = regex("(\(numberEnd))\\b\(numberWordsPattern)$")
private let wordsAnywhereRE = regex("\\b\(numberWordsPattern)\\b")

/// Translates roman numerals appearing after season/episode/disc keywords.
private func allRomanToInt(_ string: String) -> String {
    var result = replacingMatches(of: romanAfterPrefixRE, in: string) { groups in
        let prefix = groups[1] ?? ""
        let numeral = groups[2] ?? ""
        if let value = roman2int(numeral) { return prefix + String(value) }
        return groups[0] ?? ""
    }
    result = replacingMatches(of: romanAtEndRE, in: result) { groups in
        let prefix = groups[1] ?? ""
        let numeral = groups[2] ?? ""
        if let value = roman2int(numeral) { return prefix + String(value) }
        return groups[0] ?? ""
    }
    return result
}

/// Translates English number words after season/episode/disc keywords
/// (or anywhere, if contextFree is true).
private func allNumberWordsToInt(_ string: String, contextFree: Bool = false) -> String {
    if contextFree {
        return replacingMatches(of: wordsAnywhereRE, in: string) { groups in
            String(englishNumberToInt(groups[1] ?? groups[0] ?? ""))
        }
    }
    var result = replacingMatches(of: wordsAfterPrefixRE, in: string) { groups in
        (groups[1] ?? "") + String(englishNumberToInt(groups[2] ?? ""))
    }
    result = replacingMatches(of: wordsAtEndRE, in: result) { groups in
        (groups[1] ?? "") + String(englishNumberToInt(groups[2] ?? ""))
    }
    return result
}

// MARK: - Video::Filename

/// The parse result. String fields are nil if never matched; numeric
/// accessors convert on demand (nil for empty or non-numeric values).
struct ParsedVideoFilename {
    var name: String?
    var dvd: String?
    var season: String?
    var episode: String?
    var endep: String?
    var subep: String?
    var part: String?
    var epname: String?
    var movie: String?
    var year: String?
    var imdb: String?
    var title: String?
    var ext: String?

    var seasonInt: Int? { season.flatMap { Int($0) } }
    var episodeInt: Int? { episode.flatMap { Int($0) } }
    var dvdInt: Int? { dvd.flatMap { Int($0) } }
    var partInt: Int? { part.flatMap { Int($0) } }

    var isTVShow: Bool { season != nil && episode != nil }
    var isEpisode: Bool { episode != nil }
    var isMovie: Bool { movie != nil || imdb != nil }
}

/// One filename pattern: an ICU-compatible regex plus the field each capture
/// group maps to (nil for groups whose value is not stored). Groups mapping
/// to an already-set field are ignored (first match wins), like perl's
/// "unless defined" assignment.
private struct FilePattern {
    let re: NSRegularExpression
    let keys: [WritableKeyPath<ParsedVideoFilename, String?>?]
}

// The 9 patterns of Video::Filename, in priority order. Where the perl
// 5.10+ originals use conditional groups -- (?(<openb>)...) -- or named
// backreferences, they are rewritten as bracketed/unbracketed alternations
// with duplicate capture groups mapped to the same field.
private let filePatterns: [FilePattern] = [
    // DVD Episode Support - DddEee
    FilePattern(
        re: regex("^(?:(.*?)[\\/\\s._-]+)?(?:d|dvd|disc|disk)[\\s._]?(\\d{1,2})" +
                  "[x\\/\\s._-]*(?:e|ep|episode)[\\s._]?(\\d{1,2}(?:\\.\\d{1,2})?)" +
                  "(?:-?(?:(?:e|ep)[\\s._]*)?(\\d{1,2}))?" +
                  "(?:[\\s._]?(?:p|part)[\\s._]?(\\d+))?([a-z])?" +
                  "(?:[\\/\\s._-]*([^\\/]+?))?$"),
        keys: [\.name, \.dvd, \.episode, \.endep, \.part, \.subep, \.epname]),

    // TV Show Support - SssEee or Season_ss_Episode_ss
    FilePattern(
        re: regex("^(?:(.*?)[\\/\\s._-]+)?(?:s|se|season|series)[\\s._-]?(\\d+)" +
                  "[x\\/\\s._-]*(?:e|ep|episode|[\\/\\s._-]+)[\\s._-]?(\\d+)" +
                  "(?:-?(?:(?:e|ep)[\\s._]*)?(\\d+))?" +
                  "(?:[\\s._]?(?:p|part)[\\s._]?(\\d+))?([a-z])?" +
                  "(?:[\\/\\s._-]*([^\\/]+?))?$"),
        keys: [\.name, \.season, \.episode, \.endep, \.part, \.subep, \.epname]),

    // Movie IMDB Support
    FilePattern(
        re: regex("^(.*?)?(?:[\\/\\s._-]*(?:\\[((?:19|20)\\d{2})\\]|((?:19|20)\\d{2})))?" +
                  "(?:[\\/\\s._-]*(?:\\[(?:(?:imdb|tt)[\\s._-]*)*(\\d{7})\\]" +
                  "|(?:(?:imdb|tt)[\\s._-]*)*(\\d{7})))" +
                  "(?:[\\s._-]*([^\\/]+?))?$"),
        keys: [\.movie, \.year, \.year, \.imdb, \.imdb, \.title]),

    // Movie + Year Support
    FilePattern(
        re: regex("^(?:(.*?)[\\/\\s._-]*)?(?:\\[\\(?((?:19|20)\\d{2})\\)?\\]" +
                  "|((?:19|20)\\d{2}))(?:[\\s._-]*([^\\/]+?))?$"),
        keys: [\.movie, \.year, \.year, \.title]),

    // TV Show Support - see
    FilePattern(
        re: regex("^(?:(.*?)[\\/\\s._-]*)?(\\d{1,2}?)(\\d{2})" +
                  "(?:[^0-9][\\s._-]*(.+?))?$"),
        keys: [\.name, \.season, \.episode, \.epname]),

    // TV Show Support - sxee
    FilePattern(
        re: regex("^(?:(.*?)[\\/\\s._-]*)?" +
                  "(?:\\[(\\d{1,2})[x\\/](\\d{1,2})(?:-(?:\\d{1,2}x)?(\\d{1,2}))?\\]" +
                  "|(\\d{1,2})[x\\/](\\d{1,2})(?:-(?:\\d{1,2}x)?(\\d{1,2}))?)" +
                  "(?:[\\s._-]*([^\\/]+?))?$"),
        keys: [\.name, \.season, \.episode, \.endep, \.season, \.episode, \.endep, \.epname]),

    // TV Show Support - season only
    FilePattern(
        re: regex("^(?:(.*?)[\\/\\s._-]+)?(?:s|se|season|series)[\\s._]?(\\d{1,2})" +
                  "(?:[\\/\\s._-]*([^\\/]+?))?$"),
        keys: [\.name, \.season, \.epname]),

    // TV Show Support - episode only
    FilePattern(
        re: regex("^(?:(.*?)[\\/\\s._-]*)?(?:(?:e|ep|episode)[\\s._]?)?(\\d{1,2})" +
                  "(?:-(?:e|ep)?(\\d{1,2}))?(?:(?:p|part)(\\d+))?([a-z])?" +
                  "(?:[\\/\\s._-]*([^\\/]+?))?$"),
        keys: [\.name, \.episode, \.endep, \.part, \.subep, \.epname]),

    // Default Movie Support
    FilePattern(re: regex("^(.*)$"), keys: [\.movie]),
]

extension ParsedVideoFilename {

    static func parse(_ path: String) -> ParsedVideoFilename {
        var result = ParsedVideoFilename()
        var file = path

        // Strip the extension.
        if let extMatch = captures(of: extRE, in: file), let ext = extMatch.first ?? nil {
            result.ext = ext.lowercased()
            file = String(file.dropLast(ext.count + 1))
        }

        // Translate appropriate roman/english numbers to numerals.
        file = allRomanToInt(file)
        file = allNumberWordsToInt(file)

        // Strip out any irrelevant numbers which screw up parsing.
        // (Like perl's s/// without /g: first occurrence only, case-sensitive.)
        for noise in ["480p", "720p", "1080p", "x264", "x265"] {
            if let range = file.range(of: noise) {
                file.removeSubrange(range)
            }
        }

        // Run the pre-processed filename through the list of patterns;
        // first match wins.
        for pattern in filePatterns {
            guard let groups = captures(of: pattern.re, in: file) else { continue }
            for (index, keyPath) in pattern.keys.enumerated() {
                guard let keyPath, index < groups.count, let value = groups[index] else { continue }
                if result[keyPath: keyPath] == nil {
                    result[keyPath: keyPath] = value
                }
            }
            break
        }

        // Process Series/Movie: strip directory parts, trim whitespace.
        for keyPath in [\ParsedVideoFilename.name, \.movie, \.epname, \.title] {
            guard var value = result[keyPath: keyPath] else { continue }
            if let slash = value.range(of: "/", options: .backwards) {
                value = String(value[slash.upperBound...])
            }
            value = value.trimmingCharacters(in: .whitespaces)
            result[keyPath: keyPath] = value
        }

        // Guess part from epname.
        if let epname = result.epname, result.part == nil {
            let converted = allNumberWordsToInt(epname, contextFree: true)
            for pattern in ["(?:Episode|Part|PT) (\\d+)",
                            "(\\d+)\\s*(?:of|-)\\s*\\d+",
                            "^(\\d+)",
                            "[\\s._-](\\d+)$"] {
                if let groups = captures(of: regex(pattern), in: converted),
                   let value = groups.first ?? nil {
                    result.part = value
                    break
                }
            }
        }

        // Cosmetics: strip leading zeros.
        for keyPath in [\ParsedVideoFilename.dvd, \.season, \.episode, \.endep, \.part] {
            if let value = result[keyPath: keyPath] {
                result[keyPath: keyPath] = value.replacingOccurrences(
                    of: "^0+", with: "", options: .regularExpression)
            }
        }
        if let endep = result.endep, endep == result.episode {
            result.endep = nil
        }

        return result
    }
}

private let extRE = regex("\\.([0-9a-z]+)$")
