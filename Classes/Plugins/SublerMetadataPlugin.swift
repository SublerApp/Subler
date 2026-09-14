//
//  SublerMetadataPlugin.swift
//  Subler
//
//  The interface a dynamically-loaded metadata-source plugin bundle must
//  implement. See MetadataPluginLoader.swift for how a plugin gets found
//  and loaded, and PluginMetadataService.swift for how a loaded plugin is
//  wrapped so it behaves exactly like a built-in provider everywhere
//  Subler uses MetadataService.
//
//  This file is deliberately the ONLY thing shared between Subler's own
//  source and a plugin project -- it references nothing else in Subler
//  (no MetadataResult, no MP42Foundation, nothing internal), just
//  Foundation types. That keeps a plugin project free to build and
//  version itself entirely independently: a plugin author only ever
//  needs a copy of this one small protocol, never Subler's own source
//  or Xcode project.
//

import Foundation

/// A dynamically-loaded metadata-source plugin. A plugin is a normal
/// loadable bundle (.bundle) placed by the user in
/// ~/Library/Application Support/Subler/Plugins -- see
/// MetadataPluginLoader. The bundle's principal class (declared as
/// NSPrincipalClass in its Info.plist) must be an NSObject subclass with
/// a plain, parameterless init() that conforms to this protocol.
///
/// Movie search only, for now -- there's no TV show equivalent yet.
@objc public protocol SublerMetadataPlugin: NSObjectProtocol {

    /// A stable, human-readable name for this source. Shown in the
    /// Search Metadata dialog and batch queue provider popups exactly
    /// like a built-in provider's name, so it should be short and not
    /// collide with an existing provider's name.
    var pluginName: String { get }

    /// Searches for a movie by title. Each result dictionary must at
    /// least contain "id" (String) -- an opaque identifier this plugin
    /// will recognize when it comes back via loadMovieMetadata(id:) --
    /// and "title" (String). All other keys are optional:
    ///   - "releaseDate": String, "yyyy-MM-dd"
    ///   - "synopsis": String
    ///   - "studio": String
    ///   - "director": String
    ///   - "series": String
    ///   - "cast": [String]
    ///   - "genre": [String]
    ///   - "artworkURLs": [String], each an absolute image URL
    /// Any key that isn't relevant or available can simply be omitted.
    func searchMovie(query: String) -> [[String: Any]]

    /// Loads full metadata for one search result, identified by the "id"
    /// value that result carried. Returns a dictionary using the same
    /// key set as searchMovie's results, filled in as completely as
    /// possible. Return an empty dictionary if the id can no longer be
    /// resolved (e.g. the page was removed).
    func loadMovieMetadata(id: String) -> [String: Any]
}
