//
//  SBQueueAction.m
//  Subler
//
//  Created by Damiano Galassi on 12/03/14.
//
//

#import "SBQueueAction.h"

#import "SBQueueItem.h"
#import "MetadataImporter.h"

#import <MP42Foundation/MP42File.h>
#import <MP42Foundation/MP42FileImporter.h>
#import <MP42Foundation/MP42Image.h>
#import <MP42Foundation/MP42Utilities.h>

@implementation SBQueueSubtitlesAction

/**
 *  Loads the subtitles in the parent directory
 */
- (NSArray<MP42SubtitleTrack *> *)loadSubtitles:(NSURL *)url {
    NSError *error = nil;
    NSMutableArray<MP42SubtitleTrack *> *tracksArray = [[NSMutableArray alloc] init];
    NSArray<NSURL *> *directory = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:[url URLByDeletingLastPathComponent]
                                                       includingPropertiesForKeys:nil
                                                                          options:NSDirectoryEnumerationSkipsSubdirectoryDescendants |
                                                                                  NSDirectoryEnumerationSkipsHiddenFiles |
                                                                                  NSDirectoryEnumerationSkipsPackageDescendants
                                                                            error:nil];

    for (NSURL *dirUrl in directory) {
        if ([dirUrl.pathExtension caseInsensitiveCompare:@"srt"] == NSOrderedSame) {
            NSComparisonResult result;
            NSString *movieFilename = [[url URLByDeletingPathExtension] lastPathComponent];
            NSString *subtitleFilename = [[dirUrl URLByDeletingPathExtension] lastPathComponent];
            NSRange range = { 0, movieFilename.length };

            if (movieFilename.length <= subtitleFilename.length) {
                result = [subtitleFilename compare:movieFilename options:NSCaseInsensitiveSearch range:range];

                if (result == NSOrderedSame) {
                    MP42FileImporter *fileImporter = [[[MP42FileImporter alloc] initWithURL:dirUrl
                                                                                      error:&error] autorelease];

                    for (MP42SubtitleTrack *track in fileImporter.tracks) {
                        [tracksArray addObject:track];
                    }
                }
            }
        }
    }

    return [tracksArray autorelease];
}

- (void)runAction:(SBQueueItem *)item {
    // Search for external subtitles files
    NSArray<MP42SubtitleTrack *> *subtitles = [self loadSubtitles:item.URL];
    for (MP42SubtitleTrack *subTrack in subtitles) {
        [item.mp4File addTrack:subTrack];
    }
}

- (NSString *)description {
    return NSLocalizedString(@"Load Subtitles", @"");
}

- (NSString *)localizedDescription {
    return NSLocalizedString(@"Loading subtitles", @"");
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
}

@end

@implementation SBQueueMetadataAction

- (instancetype)init {
    self = [super init];
    if (self) {
        _movieLanguage = [MetadataImporter defaultMovieLanguage];
        _tvShowLanguage = [MetadataImporter defaultTVLanguage];
        _movieProvider = [[MetadataImporter movieProviders] firstObject];
        _tvShowProvider = [[MetadataImporter tvProviders] firstObject];
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

- (void)dealloc
{
    [_movieLanguage release];
    [_tvShowLanguage release];
    [_movieProvider release];
    [_tvShowProvider release];

    [super dealloc];
}

- (MP42Image *)loadArtwork:(NSURL *)url {
    NSData *artworkData = [SBMetadataHelper downloadDataFromURL:url withCachePolicy:SBDefaultPolicy];
    if (artworkData && artworkData.length) {
        MP42Image *artwork = [[MP42Image alloc] initWithData:artworkData type:MP42_ART_JPEG];
        if (artwork != nil) {
            return [artwork autorelease];
        }
    }

    return nil;
}

- (MP42Metadata *)searchMetadataForFile:(NSURL *)url {
    id currentSearcher = nil;
    MP42Metadata *metadata = nil;

    // Parse FileName and search for metadata
    NSDictionary<NSString *, NSString *> *parsed = [SBMetadataHelper parseFilename:url.lastPathComponent];
    NSString *type = parsed[@"type"];

    if ([@"movie" isEqualToString:type]) {
		currentSearcher = [MetadataImporter importerForProvider:_movieProvider];
		NSArray<MP42Metadata *> *results = [currentSearcher searchMovie:parsed[@"title"] language:_movieLanguage];
        if (results.count) {
            metadata = [currentSearcher loadMovieMetadata:results.firstObject language:_movieLanguage];
        }
    }
    else if ([@"tv" isEqualToString:type]) {
		currentSearcher = [MetadataImporter importerForProvider:_tvShowProvider];
		NSArray *results = [currentSearcher searchTVSeries:parsed[@"seriesName"]
                                                  language:_tvShowLanguage
                                                 seasonNum:parsed[@"seasonNum"]
                                                episodeNum:parsed[@"episodeNum"]];
        if (results.count) {
            metadata = [currentSearcher loadTVMetadata:results.firstObject language:_tvShowLanguage];
        }
    }

    if (metadata.artworkThumbURLs && metadata.artworkThumbURLs.count) {
        NSURL *artworkURL = nil;
        if ([type isEqualToString:@"movie"]) {
            artworkURL = [metadata.artworkFullsizeURLs firstObject];
        }
        else if ([type isEqualToString:@"tv"]) {
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
            else {
                artworkURL = metadata.artworkFullsizeURLs.firstObject;
            }
        }

        MP42Image *artwork = [self loadArtwork:artworkURL];

        if (artwork) {
            [metadata.artworks addObject:artwork];
        }
    }

    return metadata;
}

- (void)runAction:(SBQueueItem *)item {
    // Search for metadata
    MP42Metadata *metadata = [self searchMetadataForFile:item.URL];

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
    return NSLocalizedString(@"Search Metadata", @"");
}

- (NSString *)localizedDescription {
    return NSLocalizedString(@"Searching metadata", @"");
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];

    _movieLanguage = [[coder decodeObjectForKey:@"_movieLanguage"] retain];
    _tvShowLanguage = [[coder decodeObjectForKey:@"_tvShowLanguage"] retain];
    _movieProvider = [[coder decodeObjectForKey:@"_movieProvider"] retain];
    _tvShowProvider = [[coder decodeObjectForKey:@"_tvShowProvider"] retain];

    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:_movieLanguage forKey:@"_movieLanguage"];
    [coder encodeObject:_tvShowLanguage forKey:@"_tvShowLanguage"];
    [coder encodeObject:_movieProvider forKey:@"_movieProvider"];
    [coder encodeObject:_tvShowProvider forKey:@"_tvShowProvider"];
}

@end

@implementation SBQueueSetAction

- (id)initWithSet:(MP42Metadata *)set {
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
        _set = [[coder decodeObjectForKey:@"SBQueueActionSet"] retain];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:_set forKey:@"SBQueueActionSet"];
}

- (void)dealloc {
    [_set release];
    [super dealloc];
}

@end

@implementation SBQueueOrganizeGroupsAction

- (void)runAction:(SBQueueItem *)item {
    [item.mp4File organizeAlternateGroups];
}

- (NSString *)description {
    return NSLocalizedString(@"Organize Groups", @"");
}

- (NSString *)localizedDescription {
    return NSLocalizedString(@"Organizing groups", @"");
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
@implementation SBQueueFixFallbacksAction : NSObject

- (void)runAction:(SBQueueItem *)item {
    [item.mp4File setAutoFallback];
}

- (NSString *)description {
    return NSLocalizedString(@"Fixing Fallbacks", @"");
}

- (NSString *)localizedDescription {
    return NSLocalizedString(@"Fixing Fallbacks", @"");
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
}

@end
