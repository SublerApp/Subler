//
//  ScriptCommand.swift
//  Subler
//
//  Created by Michael Mock on 6/9/25.
//

import Foundation
import AppKit
import MP42Foundation

// Protocol for universal document targeting
protocol ScriptCommandDocumentTargeting {}
extension ScriptCommandDocumentTargeting where Self: NSScriptCommand {
    func targetedDocument() -> Document? {
        // First, check for explicit document parameters ('into' or 'doc')
        if let evaluatedArgs = self.evaluatedArguments {
            if let doc = evaluatedArgs["into"] as? Document {
                return doc
            }
            if let doc = evaluatedArgs["doc"] as? Document {
                return doc
            }
        }

        // Then, try to get document from direct parameter
        if let directParameter = self.directParameter as? Document {
            return directParameter
        }

        // Then, try to get document from receiver specifier (window targeting)
        if let receiver = self.receiversSpecifier?.objectsByEvaluatingSpecifier as? Document {
            return receiver
        }

        // If receiver is a window, get its document
        if let window = self.receiversSpecifier?.objectsByEvaluatingSpecifier as? NSWindow,
           let windowController = window.windowController as? DocumentWindowController {
            return windowController.document as? Document
        }

        // Finally, fall back to current document (frontmost)
        return NSDocumentController.shared.currentDocument as? Document
    }

    func extractFilePath() -> String? {
        // Try different ways AppleScript might pass a file path
        if let param = self.directParameter as? String {
            return param
        } else if let fileURL = self.directParameter as? URL {
            return fileURL.path
        } else if let fileDescriptor = self.directParameter as? [String: Any],
                  let path = fileDescriptor["path"] as? String {
            return path
        } else if let specifier = self.directParameter as? NSScriptObjectSpecifier {
            // Handle AppleScript file references like POSIX file
            return specifier.key
        }
        return nil
    }
}

@objc(SBImportFileScriptCommand)
class SBImportFileScriptCommand: NSScriptCommand, ScriptCommandDocumentTargeting {
    
    override func performDefaultImplementation() -> Any? {
        let logger = Logger.shared

        // Get file path using the helper method
        guard let path = extractFilePath() else {
            logger.write(toLog: "Script failed to get file parameter - expected file reference or path string")
            return nil
        }

        // Get target document using universal method
        guard let doc = targetedDocument() else {
            logger.write(toLog: "No document available for import")
            return nil
        }

        // Perform import into the target document
        let fileURL = URL(fileURLWithPath: path)
        
        // Import directly into the target document
        if let windowController = doc.windowControllers.first {
            let selector = NSSelectorFromString("importFilesDirectly:")
            if windowController.responds(to: selector) {
                let fileURLs = [fileURL]
                _ = windowController.perform(selector, with: fileURLs)
                logger.write(toLog: "Script successfully imported file into target document")
            } else {
                logger.write(toLog: "importFilesDirectly method not found on target document")
            }
        } else {
            logger.write(toLog: "No window controller found for target document")
        }

        return path
    }
}

@objc(SBFetchMetadataScriptCommand)
class SBFetchMetadataScriptCommand: NSScriptCommand, ScriptCommandDocumentTargeting {
    
    override func performDefaultImplementation() -> Any? {
        let logger = Logger.shared
        guard let sublerDoc = targetedDocument() else {
            logger.write(toLog: "No document available for fetching metadata")
            return nil
        }

        // Access the MP42File through the custom Document subclass
        let mp4File = sublerDoc.mp4
        let searchTerms = mp4File.extractSearchTerms(fallbackURL: sublerDoc.fileURL)
        
        // Perform headless metadata search with completion handling
        searchMetadata(terms: searchTerms) { metadata in
            DispatchQueue.main.async {
                if let metadata = metadata {
                    // Apply the metadata to the file
                    mp4File.metadata.merge(metadata)
                    sublerDoc.updateChangeCount(.changeDone)
                    
                    // Trigger UI refresh by calling reloadData on the window controller
                    if let windowController = sublerDoc.windowControllers.first as? DocumentWindowController {
                        windowController.reloadData()
                    }
                    
                    // Log the metadata that was applied
                    let metadataCount = mp4File.metadata.items.count
                    logger.write(toLog: "Script successfully applied \(metadataCount) metadata items")
                } else {
                    logger.write(toLog: "No metadata found")
                }
            }
        }

        return nil
    }
    
    private func searchMetadata(terms: MetadataSearchTerms, completion: @escaping (MP42Metadata?) -> Void) {
        var metadata: MetadataResult? = nil
        
        // Use default services and settings
        let movieService = MetadataSearch.defaultMovieService
        let tvShowService = MetadataSearch.defaultTVService
        
        // Get user preferences for artwork from Queue preferences
        let queuePrefs = QueuePreferences()
        let preferredArtwork = ArtworkType(rawValue: queuePrefs.providerArtwork) ?? .poster
        let preferredArtworkSize = ArtworkSize(rawValue: queuePrefs.providerArtworkSize) ?? .standard
        
        switch terms {
        case let .movie(title):
            let movieSearch = MetadataSearch.movieSeach(service: movieService, movie: title, language: MetadataSearch.defaultLanguage(service: movieService, type: .movie))
            _ = movieSearch.search(completionHandler: { results in
                if let result = results.first {
                    _ = movieSearch.loadAdditionalMetadata(result, completionHandler: { additionalMetadata in
                        metadata = additionalMetadata
                        
                        // Handle artwork similar to QueueMetadataAction
                        if let metadataResult = metadata {
                            let artworks = metadataResult.remoteArtworks
                            
                            if preferredArtwork != .none && artworks.isEmpty == false {
                                let artwork: Artwork? = {
                                    let type = preferredArtwork.isMovieType ? preferredArtwork : .poster
                                    if let artwork = artworks.filter(by: type, size: preferredArtworkSize, service: movieService.name) {
                                        return artwork
                                    } else if let artwork = artworks.filter(by: .poster, size: .standard, service: movieService.name) {
                                        return artwork
                                    } else {
                                        return artworks.first
                                    }
                                }()
                                
                                // Load and add artwork to metadata result BEFORE mapping
                                if let url = artwork?.url, let artworkData = URLSession.data(from: url) {
                                    let mp42Image = MP42Image(data: artworkData, type: MP42_ART_JPEG)
                                    metadataResult.artworks.append(mp42Image)
                                }
                            }
                            
                            // Map the metadata using the same logic as QueueAction (now includes artwork)
                            let map = metadataResult.mediaKind == .movie ? MetadataPrefs.movieResultMap : MetadataPrefs.tvShowResultMap
                            let mappedMetadata = metadataResult.mappedMetadata(to: map, keepEmptyKeys: false)
                            completion(mappedMetadata)
                        } else {
                            completion(nil)
                        }
                    }).run()
                } else {
                    completion(nil)
                }
            }).run()
            
        case let .tvShow(seriesName, season, episode):
            let tvSearch = MetadataSearch.tvSearch(service: tvShowService, tvShow: seriesName, season: season, episode: episode, language: MetadataSearch.defaultLanguage(service: tvShowService, type: .tvShow))
            _ = tvSearch.search(completionHandler: { results in
                if let result = results.first {
                    _ = tvSearch.loadAdditionalMetadata(result, completionHandler: { additionalMetadata in
                        metadata = additionalMetadata
                        
                        // Handle artwork similar to QueueMetadataAction
                        if let metadataResult = metadata {
                            let artworks = metadataResult.remoteArtworks
                            
                            if preferredArtwork != .none && artworks.isEmpty == false {
                                let artwork: Artwork? = {
                                    if let artwork = artworks.filter(by: preferredArtwork, size: preferredArtworkSize, service: tvShowService.name) {
                                        return artwork
                                    } else if let artwork = artworks.filter(by: .season, size: preferredArtworkSize, service: tvShowService.name) {
                                        return artwork
                                    } else if let artwork = artworks.filter(by: .poster, size: .standard, service: tvShowService.name) {
                                        return artwork
                                    } else {
                                        return artworks.first
                                    }
                                }()
                                
                                // Load and add artwork to metadata result BEFORE mapping
                                if let url = artwork?.url, let artworkData = URLSession.data(from: url) {
                                    let mp42Image = MP42Image(data: artworkData, type: MP42_ART_JPEG)
                                    metadataResult.artworks.append(mp42Image)
                                }
                            }
                            
                            // Map the metadata using the same logic as QueueAction (now includes artwork)
                            let map = metadataResult.mediaKind == .movie ? MetadataPrefs.movieResultMap : MetadataPrefs.tvShowResultMap
                            let mappedMetadata = metadataResult.mappedMetadata(to: map, keepEmptyKeys: false)
                            completion(mappedMetadata)
                        } else {
                            completion(nil)
                        }
                    }).run()
                } else {
                    completion(nil)
                }
            }).run()
            
        case .none:
            completion(nil)
        }
    }
}

@objc(SBOrganizeAlternateGroupsScriptCommand)
class SBOrganizeAlternateGroupsScriptCommand: NSScriptCommand, ScriptCommandDocumentTargeting {
    
    override func performDefaultImplementation() -> Any? {
        let logger = Logger.shared
        guard let sublerDoc = targetedDocument() else {
            logger.write(toLog: "No document available for organizing alternate groups")
            return nil
        }
        
        // Use the existing IBAction instead of duplicating logic
        if let windowController = sublerDoc.windowControllers.first as? DocumentWindowController {
            windowController.iTunesFriendlyTrackGroups(self)
            logger.write(toLog: "Script successfully organized alternate groups")
        } else {
            logger.write(toLog: "No window controller found for organizing alternate groups")
        }
        
        return nil
    }
}

@objc(SBClearTrackNamesScriptCommand)
class SBClearTrackNamesScriptCommand: NSScriptCommand, ScriptCommandDocumentTargeting {
    
    override func performDefaultImplementation() -> Any? {
        let logger = Logger.shared
        guard let sublerDoc = targetedDocument() else {
            logger.write(toLog: "No document available for clearing track names")
            return nil
        }
        
        // Use the existing IBAction instead of duplicating logic
        if let windowController = sublerDoc.windowControllers.first as? DocumentWindowController {
            windowController.clearTrackNames(self)
            logger.write(toLog: "Script successfully cleared all track names")
        } else {
            logger.write(toLog: "No window controller found for clearing track names")
        }
        
        return nil
    }
}

@objc(SBPrettifyAudioTrackNamesScriptCommand)
class SBPrettifyAudioTrackNamesScriptCommand: NSScriptCommand, ScriptCommandDocumentTargeting {
    
    override func performDefaultImplementation() -> Any? {
        let logger = Logger.shared
        guard let sublerDoc = targetedDocument() else {
            logger.write(toLog: "No document available for prettifying audio track names")
            return nil
        }
        
        // Use the existing IBAction instead of duplicating logic
        if let windowController = sublerDoc.windowControllers.first as? DocumentWindowController {
            windowController.prettifyAudioTrackNames(self)
            logger.write(toLog: "Script successfully prettified audio track names")
        } else {
            logger.write(toLog: "No window controller found for prettifying audio track names")
        }
        
        return nil
    }
}

@objc(SBFixAudioFallbacksScriptCommand)
class SBFixAudioFallbacksScriptCommand: NSScriptCommand, ScriptCommandDocumentTargeting {
    
    override func performDefaultImplementation() -> Any? {
        let logger = Logger.shared
        guard let sublerDoc = targetedDocument() else {
            logger.write(toLog: "No document available for fixing audio fallbacks")
            return nil
        }
        
        // Use the existing IBAction instead of duplicating logic
        if let windowController = sublerDoc.windowControllers.first as? DocumentWindowController {
            windowController.fixAudioFallbacks(self)
            logger.write(toLog: "Script successfully fixed audio fallbacks")
        } else {
            logger.write(toLog: "No window controller found for fixing audio fallbacks")
        }
        
        return nil
    }
}

@objc(SBSaveAsScriptCommand)
class SBSaveAsScriptCommand: NSScriptCommand, ScriptCommandDocumentTargeting {
    
    override func performDefaultImplementation() -> Any? {
        let logger = Logger.shared
        
        // Get the target document (frontmost or specified)
        guard let sublerDoc = targetedDocument() else {
            logger.write(toLog: "No document available for save as operation")
            return nil
        }
        
        // Use the helper method to extract the destination path
        guard let path = extractFilePath() else {
            return nil
        }
        
        let destinationURL = URL(fileURLWithPath: path)
        let fileName = destinationURL.lastPathComponent
        
        // Build options dictionary with 64-bit settings from UI preferences
        var options: [String: Any] = [:]
        options[MP4264BitData] = Prefs.mp464bitOffset
        options[MP4264BitTime] = Prefs.mp464bitTimes
        
        // Get the window controller for progress reporting
        guard let windowController = sublerDoc.windowControllers.first as? DocumentWindowController else {
            logger.write(toLog: "No window controller found for progress reporting")
            return nil
        }
        
        // Start progress reporting to show the save modal
        windowController.startProgressReporting()
        windowController.setProgress(title: NSLocalizedString("Saving…", comment: "Document Save sheet."))
        
        // Perform the save operation asynchronously to keep UI responsive
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try sublerDoc.mp4.write(to: destinationURL, options: options)
                
                DispatchQueue.main.async {
                    
                    // Optimize if requested in UI save dialog preferences
                    if Prefs.mp4SaveAsOptimize {
                        windowController.setProgress(title: NSLocalizedString("Optimizing…", comment: "Document Optimize sheet."))
                        
                        // Run optimization on background queue
                        DispatchQueue.global(qos: .userInitiated).async {
                            _ = sublerDoc.mp4.optimize()
                            
                            DispatchQueue.main.async {
                                
                                // Update the document's file URL and mark as saved
                                sublerDoc.fileURL = destinationURL
                                sublerDoc.updateChangeCount(.changeCleared)
                                
                                // End progress reporting and refresh the UI
                                windowController.endProgressReporting()
                                windowController.reloadData()
                            }
                        }
                    } else {
                        // Update the document's file URL and mark as saved
                        sublerDoc.fileURL = destinationURL
                        sublerDoc.updateChangeCount(.changeCleared)
                        
                        // End progress reporting and refresh the UI
                        windowController.endProgressReporting()
                        windowController.reloadData()
                    }
                }
                logger.write(toLog: "Script save of \(fileName) completed")
            } catch {
                DispatchQueue.main.async {
                    // End progress reporting on error
                    windowController.endProgressReporting()
                    logger.write(toLog: "Failed to save document: \(error.localizedDescription)")
                }
            }
        }
        
        return path
    }
}

@objc(SBSendToQueueScriptCommand)
class SBSendToQueueScriptCommand: NSScriptCommand, ScriptCommandDocumentTargeting {
    
    override func performDefaultImplementation() -> Any? {
        let logger = Logger.shared
        
        // Get the target document (frontmost or specified)
        guard let sublerDoc = targetedDocument() else {
            logger.write(toLog: "No document available for send to queue operation")
            return nil
        }
        
        // Use the helper method to extract the destination path
        guard let path = extractFilePath() else {
            return nil
        }
        
        let destinationURL = URL(fileURLWithPath: path)
        let fileName = destinationURL.lastPathComponent
        
        // Build options dictionary with 64-bit settings from UI preferences
        var options: [String: Any] = [:]
        options[MP4264BitData] = Prefs.mp464bitOffset
        options[MP4264BitTime] = Prefs.mp464bitTimes
        
        // Create queue item and add to queue
        let item = QueueItem(mp4: sublerDoc.mp4, destURL: destinationURL, attributes: options, optimize: Prefs.mp4SaveAsOptimize)
        
        // Add the queue item
        QueueController.shared.add(item)
        logger.write(toLog: "Script successfully sent document to queue: \(fileName)")
        
        // Close the document window since it's now in the queue
        DispatchQueue.main.async {
            sublerDoc.close()
        }
        
        return path
    }
}

@objc(SBCloseFileScriptCommand)
class SBCloseFileScriptCommand: NSScriptCommand, ScriptCommandDocumentTargeting {
    
    override func performDefaultImplementation() -> Any? {
        let logger = Logger.shared
        
        // Get the target document (frontmost or specified)
        guard let sublerDoc = targetedDocument() else {
            logger.write(toLog: "No document available for close operation")
            return nil
        }
        
        // Close the document without prompting for unsaved changes
        DispatchQueue.main.async {
            sublerDoc.close()
        }
        
        logger.write(toLog: "Script successfully closed document")
        return nil
    }
}

@objc(SBMetadataResult)
class SBMetadataResult: NSObject {
    @objc dynamic var title: String?
    @objc dynamic var year: NSNumber?
    @objc dynamic var series: String?
    @objc dynamic var season: NSNumber?
    @objc dynamic var episode: NSNumber?
    @objc dynamic var mediaType: String?
    
    init(title: String?, year: Int? = nil, series: String? = nil, season: Int? = nil, episode: Int? = nil, mediaType: String?) {
        self.title = title
        self.year = year.map { NSNumber(value: $0) }
        self.series = series
        self.season = season.map { NSNumber(value: $0) }
        self.episode = episode.map { NSNumber(value: $0) }
        self.mediaType = mediaType
        super.init()
    }
}

@objc(SBFetchMetadataResultsScriptCommand)
class SBFetchMetadataResultsScriptCommand: NSScriptCommand, ScriptCommandDocumentTargeting {
    
    override func performDefaultImplementation() -> Any? {
        let logger = Logger.shared
        guard let sublerDoc = targetedDocument() else {
            logger.write(toLog: "No document available for fetching metadata results")
            return []
        }

        // Access the MP42File through the custom Document subclass
        let mp4File = sublerDoc.mp4
        let searchTerms = mp4File.extractSearchTerms(fallbackURL: sublerDoc.fileURL)
        
        logger.write(toLog: "Starting metadata search for terms: \(searchTerms)")
        
        // Use a semaphore to make this synchronous, but run search on background queue
        let semaphore = DispatchSemaphore(value: 0)
        var searchResults: [SBMetadataResult] = []
        
        // Get the optional limit parameter
        let limit = self.evaluatedArguments?["limit"] as? Int
        
        // Get the optional provider and language parameters
        let provider = self.evaluatedArguments?["provider"] as? String
        let language = self.evaluatedArguments?["language"] as? String
        
        // Run the search on a background queue to avoid blocking main thread
        DispatchQueue.global(qos: .userInitiated).async {
            self.searchMetadataResults(terms: searchTerms, provider: provider, language: language) { results in
                searchResults = results ?? []
                logger.write(toLog: "Metadata search completed with \(searchResults.count) results")
                semaphore.signal()
            }
        }
        
        // Wait for the search to complete
        semaphore.wait()
        
        // Apply limit if specified
        if let limit = limit, limit > 0 {
            let limitedResults = Array(searchResults.prefix(limit))
            searchResults = limitedResults
        }
        
        // Convert results to formatted strings
        let formattedResults = searchResults.map { result in
            if result.mediaType == "movie" {
                if let year = result.year {
                    return "Movie: \(result.title ?? "Unknown") (\(year))"
                } else {
                    return "Movie: \(result.title ?? "Unknown")"
                }
            } else if result.mediaType == "tvshow" {
                var tvString = "TV: "
                if let series = result.series {
                    tvString += series
                }
                if let season = result.season {
                    tvString += " S\(season)"
                }
                if let episode = result.episode {
                    tvString += "E\(episode)"
                }
                if let title = result.title {
                    tvString += " \(title)"
                }
                return tvString.isEmpty ? "Unknown TV Show" : tvString
            } else {
                return result.title ?? "Unknown"
            }
        }
        
        logger.write(toLog: "Returning \(formattedResults.count) results")
        return formattedResults
    }
    
    private func searchMetadataResults(terms: MetadataSearchTerms, provider: String? = nil, language: String? = nil, completion: @escaping ([SBMetadataResult]?) -> Void) {
        // Determine which services to use based on provider parameter
        let movieService: MetadataService
        let tvShowService: MetadataService
        
        if let providerName = provider {
            // Use the specified provider for both movie and TV searches
            let service = MetadataSearch.service(name: providerName)
            movieService = service
            tvShowService = service
        } else {
            // Use default services
            movieService = MetadataSearch.defaultMovieService
            tvShowService = MetadataSearch.defaultTVService
        }
        
        // Convert language to appropriate format for the service
        let convertedLanguage: String?
        if let languageCode = language {
            if movieService.languageType == .ISO {
                // For ISO services (TheMovieDB, TheTVDB), use the language code as-is
                convertedLanguage = languageCode
            } else {
                // For custom services (Apple TV, iTunes Store), try to find a matching store
                let availableLanguages = movieService.languages
                if let matchingLanguage = availableLanguages.first(where: { $0.lowercased().contains(languageCode.lowercased()) }) {
                    convertedLanguage = matchingLanguage
                } else {
                    // Fall back to default language if no match found
                    convertedLanguage = movieService.defaultLanguage
                }
            }
        } else {
            convertedLanguage = nil
        }
        
        // Determine which language to use for the search
        let searchLanguage = convertedLanguage ?? movieService.defaultLanguage
        
        // Perform the search based on media type
        switch terms {
        case .movie(let title):
            let results = movieService.search(movie: title, language: searchLanguage)
            
            // Convert MetadataResult to SBMetadataResult
            let sbResults = results.map { result in
                // Extract year from releaseDate if it's a string
                let year: Int? = {
                    if let releaseDate = result[.releaseDate] as? String {
                        // Try to extract year from date string (e.g., "2023-12-25" -> 2023)
                        let components = releaseDate.split(separator: "-")
                        if let yearString = components.first {
                            return Int(yearString)
                        }
                    }
                    return nil
                }()
                
                return SBMetadataResult(
                    title: result[.name] as? String,
                    year: year,
                    series: nil,
                    season: nil,
                    episode: nil,
                    mediaType: "movie"
                )
            }
            completion(sbResults)
            
        case .tvShow(let title, let season, let episode):
            let results = tvShowService.search(tvShow: title, language: searchLanguage, season: season, episode: episode)
            
            // Convert MetadataResult to SBMetadataResult
            let sbResults = results.map { result in
                // Extract year from releaseDate if it's a string
                let year: Int? = {
                    if let releaseDate = result[.releaseDate] as? String {
                        // Try to extract year from date string (e.g., "2023-12-25" -> 2023)
                        let components = releaseDate.split(separator: "-")
                        if let yearString = components.first {
                            return Int(yearString)
                        }
                    }
                    return nil
                }()
                
                return SBMetadataResult(
                    title: result[.name] as? String,
                    year: year,
                    series: result[.seriesName] as? String,
                    season: result[.season] as? Int,
                    episode: result[.episodeNumber] as? Int,
                    mediaType: "tvshow"
                )
            }
            completion(sbResults)
            
        case .none:
            completion([])
        }
    }
}

@objc(SBFetchAndSetMetadataResultScriptCommand)
class SBFetchAndSetMetadataResultScriptCommand: NSScriptCommand, ScriptCommandDocumentTargeting {
    
    override func performDefaultImplementation() -> Any? {
        let logger = Logger.shared
        
        // Get the result index from direct parameter
        guard let resultIndex = self.directParameter as? Int else {
            logger.write(toLog: "Missing result index parameter")
            return nil
        }
        
        // Get the optional provider and language parameters
        let provider = self.evaluatedArguments?["provider"] as? String
        let language = self.evaluatedArguments?["language"] as? String
        
        guard let sublerDoc = targetedDocument() else {
            logger.write(toLog: "No document available for metadata operation")
            return nil
        }
        
        // Access the MP42File through the custom Document subclass
        let mp4File = sublerDoc.mp4
        let searchTerms = mp4File.extractSearchTerms(fallbackURL: sublerDoc.fileURL)
        
        // Perform search and apply the nth result
        searchMetadataAndSetResult(terms: searchTerms, resultIndex: resultIndex - 1, provider: provider, language: language) { success in
            DispatchQueue.main.async {
                if success {
                    // Trigger UI refresh
                    if let windowController = sublerDoc.windowControllers.first as? DocumentWindowController {
                        windowController.reloadData()
                    }
                    logger.write(toLog: "Successfully set metadata result \(resultIndex)")
                } else {
                    logger.write(toLog: "Failed to set metadata result \(resultIndex) - index out of bounds or no results")
                }
            }
        }
        
        return nil
    }
    
    private func searchMetadataAndSetResult(terms: MetadataSearchTerms, resultIndex: Int, provider: String?, language: String?, completion: @escaping (Bool) -> Void) {
        // Determine which services to use based on provider parameter
        let movieService: MetadataService
        let tvShowService: MetadataService
        
        if let providerName = provider {
            // Use the specified provider for both movie and TV searches
            let service = MetadataSearch.service(name: providerName)
            movieService = service
            tvShowService = service
        } else {
            // Use default services
            movieService = MetadataSearch.defaultMovieService
            tvShowService = MetadataSearch.defaultTVService
        }
        
        // Convert language to appropriate format for the service
        let convertedLanguage: String?
        if let languageCode = language {
            if movieService.languageType == .ISO {
                // For ISO services (TheMovieDB, TheTVDB), use the language code as-is
                convertedLanguage = languageCode
            } else {
                // For custom services (Apple TV, iTunes Store), try to find a matching store
                let availableLanguages = movieService.languages
                if let matchingLanguage = availableLanguages.first(where: { $0.lowercased().contains(languageCode.lowercased()) }) {
                    convertedLanguage = matchingLanguage
                } else {
                    // Fall back to default language if no match found
                    convertedLanguage = movieService.defaultLanguage
                }
            }
        } else {
            convertedLanguage = nil
        }
        
        // Determine which language to use for the search
        let searchLanguage = convertedLanguage ?? movieService.defaultLanguage
        
        // Get user preferences for artwork from Queue preferences
        let queuePrefs = QueuePreferences()
        let preferredArtwork = ArtworkType(rawValue: queuePrefs.providerArtwork) ?? .poster
        let preferredArtworkSize = ArtworkSize(rawValue: queuePrefs.providerArtworkSize) ?? .standard
        
        // Perform the search based on media type
        switch terms {
        case let .movie(title):
            let movieSearch = MetadataSearch.movieSeach(service: movieService, movie: title, language: searchLanguage)
            _ = movieSearch.search(completionHandler: { results in
                if resultIndex >= 0 && resultIndex < results.count {
                    let selectedResult = results[resultIndex]
                    
                    // Load additional metadata for the selected result
                    _ = movieSearch.loadAdditionalMetadata(selectedResult, completionHandler: { metadataResult in
                        // Handle artwork similar to QueueMetadataAction
                        let artworks = metadataResult.remoteArtworks
                        
                        if preferredArtwork != .none && artworks.isEmpty == false {
                            let artwork: Artwork? = {
                                let type = preferredArtwork.isMovieType ? preferredArtwork : .poster
                                if let artwork = artworks.filter(by: type, size: preferredArtworkSize, service: movieService.name) {
                                    return artwork
                                } else if let artwork = artworks.filter(by: .poster, size: .standard, service: movieService.name) {
                                    return artwork
                                } else {
                                    return artworks.first
                                }
                            }()
                            
                            // Load and add artwork to metadata result BEFORE mapping
                            if let url = artwork?.url, let artworkData = URLSession.data(from: url) {
                                let mp42Image = MP42Image(data: artworkData, type: MP42_ART_JPEG)
                                metadataResult.artworks.append(mp42Image)
                            }
                        }
                        
                        // Map the metadata using the same logic as QueueAction
                        let map = metadataResult.mediaKind == .movie ? MetadataPrefs.movieResultMap : MetadataPrefs.tvShowResultMap
                        let mappedMetadata = metadataResult.mappedMetadata(to: map, keepEmptyKeys: false)
                        
                        // Apply the metadata
                        DispatchQueue.main.async {
                            if let sublerDoc = self.targetedDocument() {
                                sublerDoc.mp4.metadata.merge(mappedMetadata)
                                sublerDoc.updateChangeCount(.changeDone)
                                completion(true)
                            } else {
                                completion(false)
                            }
                        }
                    }).run()
                } else {
                    completion(false)
                }
            }).run()
            
        case let .tvShow(title, season, episode):
            let tvSearch = MetadataSearch.tvSearch(service: tvShowService, tvShow: title, season: season, episode: episode, language: searchLanguage)
            _ = tvSearch.search(completionHandler: { results in
                if resultIndex >= 0 && resultIndex < results.count {
                    let selectedResult = results[resultIndex]
                    
                    // Load additional metadata for the selected result
                    _ = tvSearch.loadAdditionalMetadata(selectedResult, completionHandler: { metadataResult in
                        // Handle artwork similar to QueueMetadataAction
                        let artworks = metadataResult.remoteArtworks
                        
                        if preferredArtwork != .none && artworks.isEmpty == false {
                            let artwork: Artwork? = {
                                let type = preferredArtwork.isMovieType ? preferredArtwork : .poster
                                if let artwork = artworks.filter(by: type, size: preferredArtworkSize, service: tvShowService.name) {
                                    return artwork
                                } else if let artwork = artworks.filter(by: .poster, size: .standard, service: tvShowService.name) {
                                    return artwork
                                } else {
                                    return artworks.first
                                }
                            }()
                            
                            // Load and add artwork to metadata result BEFORE mapping
                            if let url = artwork?.url, let artworkData = URLSession.data(from: url) {
                                let mp42Image = MP42Image(data: artworkData, type: MP42_ART_JPEG)
                                metadataResult.artworks.append(mp42Image)
                            }
                        }
                        
                        // Map the metadata using the same logic as QueueAction
                        let map = metadataResult.mediaKind == .movie ? MetadataPrefs.movieResultMap : MetadataPrefs.tvShowResultMap
                        let mappedMetadata = metadataResult.mappedMetadata(to: map, keepEmptyKeys: false)
                        
                        // Apply the metadata
                        DispatchQueue.main.async {
                            if let sublerDoc = self.targetedDocument() {
                                sublerDoc.mp4.metadata.merge(mappedMetadata)
                                sublerDoc.updateChangeCount(.changeDone)
                                completion(true)
                            } else {
                                completion(false)
                            }
                        }
                    }).run()
                } else {
                    completion(false)
                }
            }).run()
        case .none:
            completion(false)
        }
    }
}
