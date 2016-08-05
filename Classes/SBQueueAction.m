//
//  SBQueueAction.m
//  Subler
//
//  Created by Damiano Galassi on 12/03/14.
//
//

#import "SBQueueAction.h"

#import "SBQueueItem.h"
#import "SBMetadataImporter.h"
#import "SBMetadataResultMap.h"

#import <MP42Foundation/MP42File.h>
#import <MP42Foundation/MP42FileImporter.h>
#import <MP42Foundation/MP42Image.h>
#import <MP42Foundation/MP42Utilities.h>

@implementation SBQueueSubtitlesAction

/**
 *  Loads the subtitles in the parent directory
 */
- (NSArray<MP42FileImporter *> *)loadSubtitles:(NSURL *)url {
    NSError *error = nil;
    NSMutableArray<MP42FileImporter *> *importersArray = [[NSMutableArray alloc] init];
    NSArray<NSURL *> *directory = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:url.URLByDeletingLastPathComponent
                                                       includingPropertiesForKeys:nil
                                                                          options:NSDirectoryEnumerationSkipsSubdirectoryDescendants |
                                                                                  NSDirectoryEnumerationSkipsHiddenFiles |
                                                                                  NSDirectoryEnumerationSkipsPackageDescendants
                                                                            error:nil];

    for (NSURL *dirUrl in directory) {
        if ([dirUrl.pathExtension caseInsensitiveCompare:@"srt"] == NSOrderedSame) {
            NSComparisonResult result;
            NSString *movieFilename = url.URLByDeletingPathExtension.lastPathComponent;
            NSString *subtitleFilename = dirUrl.URLByDeletingPathExtension.lastPathComponent;
            NSRange range = { 0, movieFilename.length };

            if (movieFilename.length <= subtitleFilename.length) {
                result = [subtitleFilename compare:movieFilename options:NSCaseInsensitiveSearch range:range];

                if (result == NSOrderedSame) {
                    MP42FileImporter *fileImporter = [[MP42FileImporter alloc] initWithURL:dirUrl
                                                                                      error:&error];
                    if (fileImporter) {
                        [importersArray addObject:fileImporter];
                    }
                }
            }
        }
    }

    return importersArray;
}

- (void)runAction:(SBQueueItem *)item {
    // Search for external subtitles files
    NSArray<MP42FileImporter *> *subtitles = [self loadSubtitles:item.fileURL];
    for (MP42FileImporter *fileImporter in subtitles) {
        for (MP42SubtitleTrack *subTrack in fileImporter.tracks) {
            [item.mp4File addTrack:subTrack];
        }
    }
}

- (NSString *)description {
    return NSLocalizedString(@"Load Subtitles", @"Action description.");
}

- (NSString *)localizedDescription {
    return NSLocalizedString(@"Loading subtitles", @"Action localized description.");
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
}

@end

@implementation SBQueueMetadataAction {
    NSString *_movieLanguage;
    NSString *_tvShowLanguage;
    NSString *_movieProvider;
    NSString *_tvShowProvider;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _movieLanguage = [SBMetadataImporter defaultMovieLanguage];
        _tvShowLanguage = [SBMetadataImporter defaultTVLanguage];
        _movieProvider = [SBMetadataImporter movieProviders].firstObject;
        _tvShowProvider = [SBMetadataImporter tvProviders].firstObject;
    }
    return self;
}

- (instancetype)initWithMovieLanguage:(NSString *)movieLang
                       tvShowLanguage:(NSString *)tvLang
                        movieProvider:(NSString *)movieProvider
                       tvShowProvider:(NSString *)tvShowProvider {
    if (!movieLang || !tvLang || !movieProvider || !tvShowProvider) {
        return nil;
    }

    self = [self init];
    if (self) {
        _movieLanguage = [movieLang copy];
        _tvShowLanguage = [tvLang copy];
        _movieProvider = [movieProvider copy];
        _tvShowProvider = [tvShowProvider copy];
    }
    return self;
}


- (MP42Image *)loadArtwork:(nonnull NSURL *)url {
    NSData *artworkData = [SBMetadataHelper downloadDataFromURL:url withCachePolicy:SBDefaultPolicy];
    if (artworkData && artworkData.length) {
        MP42Image *artwork = [[MP42Image alloc] initWithData:artworkData type:MP42_ART_JPEG];
        if (artwork != nil) {
            return artwork;
        }
    }

    return nil;
}

- (MP42Metadata *)searchMetadataForFile:(NSURL *)url {
    id currentSearcher = nil;
    SBMetadataResult *metadata = nil;

    // Parse FileName and search for metadata
    NSDictionary<NSString *, NSString *> *parsed = [SBMetadataHelper parseFilename:url.lastPathComponent];
    NSString *type = parsed[@"type"];

    if ([@"movie" isEqualToString:type]) {
		currentSearcher = [SBMetadataImporter importerForProvider:_movieProvider];
		NSArray<SBMetadataResult *> *results = [currentSearcher searchMovie:parsed[@"title"] language:_movieLanguage];
        if (results.count) {
            metadata = [currentSearcher loadMovieMetadata:results.firstObject language:_movieLanguage];
        }
    }
    else if ([@"tv" isEqualToString:type]) {
		currentSearcher = [SBMetadataImporter importerForProvider:_tvShowProvider];
		NSArray *results = [currentSearcher searchTVSeries:parsed[@"seriesName"]
                                                  language:_tvShowLanguage
                                                 seasonNum:parsed[@"seasonNum"]
                                                episodeNum:parsed[@"episodeNum"]];
        if (results.count) {
            metadata = [currentSearcher loadTVMetadata:results.firstObject language:_tvShowLanguage];
        }
    }

    if (metadata.artworkFullsizeURLs.count) {
        NSURL *artworkURL = metadata.artworkFullsizeURLs.firstObject;

        if ([type isEqualToString:@"tv"]) {
            if (metadata.artworkFullsizeURLs.count > 1) {
                int i = 0;
                for (NSString *artworkProviderName in metadata.artworkProviderNames) {
                    NSArray<NSString *> *a = [artworkProviderName componentsSeparatedByString:@"|"];
                    if (a.count > 1 && ![a[1] isEqualToString:@"episode"]) {
                        artworkURL = metadata.artworkFullsizeURLs[i];
                        break;
                    }
                    i++;
                }
            }
        }

        MP42Image *artwork = [self loadArtwork:artworkURL];

        if (artwork) {
            [metadata.artworks addObject:artwork];
        }
    }

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    SBMetadataResultMap *map = metadata.mediaKind == 9 ?
    [defaults SB_resultMapForKey:@"SBMetadataMovieResultMap"] : [defaults SB_resultMapForKey:@"SBMetadataTVShowResultMap"];
    MP42Metadata *mappedMetadata = [metadata metadataUsingMap:map keepEmptyKeys:NO];

    return mappedMetadata;
}

- (void)runAction:(SBQueueItem *)item {
    // Search for metadata
    MP42Metadata *metadata = [self searchMetadataForFile:item.fileURL];

    for (MP42Track *track in [item.mp4File tracksWithMediaType:MP42MediaTypeVideo])
        if ([track isKindOfClass:[MP42VideoTrack class]]) {
            MP42VideoTrack *videoTrack = (MP42VideoTrack *)track;
            int hdVideo = isHdVideo((uint64_t)videoTrack.trackWidth, (uint64_t)videoTrack.trackHeight);

            if (hdVideo) {
                metadata[@"HD Video"] = @(hdVideo);
            }
        }

    [item.mp4File.metadata mergeMetadata:metadata];
}

- (NSString *)description {
    return NSLocalizedString(@"Search Metadata", @"Action description.");
}

- (NSString *)localizedDescription {
    return NSLocalizedString(@"Searching metadata", @"Action localized description.");
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];

    _movieLanguage = [coder decodeObjectForKey:@"_movieLanguage"];
    _tvShowLanguage = [coder decodeObjectForKey:@"_tvShowLanguage"];
    _movieProvider = [coder decodeObjectForKey:@"_movieProvider"];
    _tvShowProvider = [coder decodeObjectForKey:@"_tvShowProvider"];

    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:_movieLanguage forKey:@"_movieLanguage"];
    [coder encodeObject:_tvShowLanguage forKey:@"_tvShowLanguage"];
    [coder encodeObject:_movieProvider forKey:@"_movieProvider"];
    [coder encodeObject:_tvShowProvider forKey:@"_tvShowProvider"];
}

@end

@implementation SBQueueSetAction {
    MP42Metadata *_set;
}

- (instancetype)initWithSet:(MP42Metadata *)set {
    self = [super init];
    if (self) {
        _set = [set copy];
    }
    return self;
}

- (void)runAction:(SBQueueItem *)item {
    [item.mp4File.metadata mergeMetadata:_set];
}

- (NSString *)description {
    return [NSString stringWithFormat:NSLocalizedString(@"Apply %@ Set", @""), _set.presetName];
}

- (NSString *)localizedDescription {
    return [NSString stringWithFormat:NSLocalizedString(@"Applying %@ set", @""), _set.presetName];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _set = [coder decodeObjectForKey:@"SBQueueActionSet"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:_set forKey:@"SBQueueActionSet"];
}


@end

@implementation SBQueueOrganizeGroupsAction

- (void)runAction:(SBQueueItem *)item {
    [item.mp4File organizeAlternateGroups];
}

- (NSString *)description {
    return NSLocalizedString(@"Organize Groups", @"Organize Groups action description");
}

- (NSString *)localizedDescription {
    return NSLocalizedString(@"Organizing groups", @"Organize Groups action local description");
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
}

@end

/**
 *  An actions that fix the item tracks' fallbacks.
 */
@implementation SBQueueFixFallbacksAction

- (void)runAction:(SBQueueItem *)item {
    [item.mp4File setAutoFallback];
}

- (NSString *)description {
    return NSLocalizedString(@"Fixing Fallbacks", @"Action description.");
}

- (NSString *)localizedDescription {
    return NSLocalizedString(@"Fixing Fallbacks", @"Action localized description.");
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
}

@end

/**
 *  An actions that set unknown language tracks to preferred one.
 */
@interface SBQueueSetLanguageAction ()
@property (nonatomic, readonly) NSString *language;
@end

@implementation SBQueueSetLanguageAction

- (instancetype)initWithLanguage:(NSString *)language {
    self = [super init];
    if (self) {
        _language = [language copy];
    }
    return self;
}

- (void)runAction:(SBQueueItem *)item {
    for (MP42Track *track in item.mp4File.tracks) {
        if ([track.language isEqualToString:@"Unknown"]) {
            track.language = self.language;
        }
    }
}

- (NSString *)description {
    return NSLocalizedString(@"Set tracks language.", @"Set Language action description");
}

- (NSString *)localizedDescription {
    return NSLocalizedString(@"Setting tracks language", @"Set Language action local description");
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    _language = [coder decodeObjectForKey:@"SBQueueSetLanguageAction"];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.language forKey:@"SBQueueSetLanguageAction"];
}

@end

