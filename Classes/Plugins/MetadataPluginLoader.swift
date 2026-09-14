//
//  MetadataPluginLoader.swift
//  Subler
//
//  Discovers and loads metadata-source plugin bundles. Plugins are
//  entirely optional -- with none installed, Subler behaves exactly as
//  it does with only its built-in providers and JSON-configured Custom
//  Sources. See SublerMetadataPlugin.swift for the contract a plugin
//  implements, and PluginMetadataService.swift for how a loaded plugin
//  gets wired into the rest of the app.
//

import Foundation

enum MetadataPluginLoader {

    /// Where Subler looks for plugin bundles. Not created automatically --
    /// a user installing a plugin creates it (or the plugin's own
    /// installer does), same as QueuePreferences.destination is just a
    /// folder the user picked rather than one Subler manages the
    /// lifecycle of.
    static var pluginsDirectory: URL? {
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Subler", isDirectory: true)
            .appendingPathComponent("Plugins", isDirectory: true)
    }

    /// Loads every plugin bundle found in pluginsDirectory. A bundle that
    /// fails to load, or whose principal class doesn't conform to
    /// SublerMetadataPlugin, is logged and skipped rather than treated as
    /// fatal -- one broken or incompatible plugin should never keep the
    /// rest of Subler from launching normally.
    static func loadPlugins() -> [SublerMetadataPlugin] {
        guard let directory = pluginsDirectory else { return [] }

        let bundleURLs = (try? FileManager.default.contentsOfDirectory(at: directory,
                                                                         includingPropertiesForKeys: nil,
                                                                         options: [.skipsHiddenFiles])) ?? []

        return bundleURLs
            .filter { $0.pathExtension == "bundle" }
            .compactMap { loadPlugin(at: $0) }
    }

    private static func loadPlugin(at url: URL) -> SublerMetadataPlugin? {
        guard let bundle = Bundle(url: url) else {
            NSLog("[MetadataPluginLoader] %@ is not a valid bundle", url.lastPathComponent)
            return nil
        }
        guard bundle.load() else {
            NSLog("[MetadataPluginLoader] Failed to load %@", url.lastPathComponent)
            return nil
        }
        guard let principalClass = bundle.principalClass as? NSObject.Type else {
            NSLog("[MetadataPluginLoader] %@ has no usable principal class", url.lastPathComponent)
            return nil
        }
        guard let instance = principalClass.init() as? SublerMetadataPlugin else {
            NSLog("[MetadataPluginLoader] %@'s principal class doesn't conform to SublerMetadataPlugin", url.lastPathComponent)
            return nil
        }
        return instance
    }
}
