//
//  JSONPath.swift
//  Subler
//

import Foundation

/// A small path language for pulling values out of an arbitrary decoded
/// JSON object (the `Any` that JSONSerialization hands back: nested
/// [String: Any] / [Any] / String / NSNumber). Built for CustomMetadataSource
/// field mappings, where the response shape isn't known ahead of time and
/// isn't worth a bespoke Codable model for every possible source.
///
/// Syntax: dot-separated keys, e.g. "data.title". A key may end in:
///   - "[n]"  -- pick element n of the array at that key, e.g. "images[0].url"
///   - "[]"   -- map over every element of the array at that key, applying
///               the rest of the path to each and collecting the results,
///               e.g. "performers[].name" or "credits.cast[].name"
/// A path made only of "[]"/"[n]" with no key applies to the current value
/// itself, so a source whose search response *is* the results array can
/// use "" as its results path, and "[].name" is valid inside a mapping.
public enum JSONPath {

    private enum Bracket {
        case none
        case index(Int)
        case mapAll
    }

    /// Resolves `path` against `root`. Returns nil if any segment along the
    /// way is missing or the wrong shape (an absent field, not a source of
    /// truth to report an error to the UI about).
    public static func resolve(_ path: String, in root: Any) -> Any? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return root }
        let segments = trimmed.components(separatedBy: ".")
        return resolve(segments: segments[...], value: root)
    }

    /// Resolves a path to a single display string, joining an array result
    /// (from a "[]" segment) with ", " -- matching how Subler already
    /// stores multi-value annotations like Cast or Genre.
    public static func resolveString(_ path: String, in root: Any) -> String? {
        guard let value = resolve(path, in: root) else { return nil }
        return stringify(value)
    }

    private static func resolve(segments: ArraySlice<String>, value: Any) -> Any? {
        guard let first = segments.first else { return value }
        let rest = segments.dropFirst()

        let (key, bracket) = parseSegment(first)

        var current: Any = value
        if key.isEmpty == false {
            guard let dict = value as? [String: Any], let next = dict[key] else { return nil }
            current = next
        }

        switch bracket {
        case .none:
            return resolve(segments: rest, value: current)
        case .index(let i):
            guard let array = current as? [Any], i >= 0, i < array.count else { return nil }
            return resolve(segments: rest, value: array[i])
        case .mapAll:
            guard let array = current as? [Any] else { return nil }
            if rest.isEmpty {
                return array
            }
            return array.compactMap { resolve(segments: rest, value: $0) }
        }
    }

    private static func parseSegment(_ segment: String) -> (key: String, bracket: Bracket) {
        guard let openIndex = segment.firstIndex(of: "["),
              let closeIndex = segment.firstIndex(of: "]"),
              openIndex < closeIndex else {
            return (segment, .none)
        }

        let key = String(segment[segment.startIndex..<openIndex])
        let inside = String(segment[segment.index(after: openIndex)..<closeIndex])

        if inside.isEmpty {
            return (key, .mapAll)
        } else if let index = Int(inside) {
            return (key, .index(index))
        } else {
            return (key, .none)
        }
    }

    /// Turns whatever a path resolved to (a string, a number, or a nested
    /// array of either) into the single string Subler stores annotations
    /// as. Arrays join with ", "; nested dictionaries have nothing
    /// meaningful to stringify and are dropped.
    private static func stringify(_ value: Any) -> String? {
        switch value {
        case let string as String:
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        case let number as NSNumber:
            return number.stringValue
        case let array as [Any]:
            let parts = array.compactMap { stringify($0) }
            return parts.isEmpty ? nil : parts.joined(separator: ", ")
        default:
            return nil
        }
    }
}
