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

+ (BOOL)supportsSecureCoding {
    return YES;
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
    SBQueueMetadataActionPreferredArtwork _preferredArtwork;
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
                       tvShowProvider:(NSString *)tvShowProvider
                     preferredArtwork:(SBQueueMetadataActionPreferredArtwork)preferredArtwork {
    if (!movieLang || !tvLang || !movieProvider || !tvShowProvider) {
        return nil;
    }

    self = [self init];
    if (self) {
        _movieLanguage = [movieLang copy];
        _tvShowLanguage = [tvLang copy];
        _movieProvider = [movieProvider copy];
        _tvShowProvider = [tvShowProvider copy];
        _preferredArtwork = preferredArtwork;
    }
    return self;
}


- (MP42Image *)loadArtwork:(nonnull NSURL *)url {
    NSData *artworkData = [SBMetadataHelper downloadDataFromURL:url cachePolicy:SBDefaultPolicy];
    if (artworkData && artworkData.length) {
        MP42Image *artwork = [[MP42Image alloc] initWithData:artworkData type:MP42_ART_JPEG];
        if (artwork != nil) {
            return artwork;
        }
    }

    return nil;
}

- (NSInteger)indexOfPreferredArtworkForType:(SBQueueMetadataActionPreferredArtwork)preferredType provider:(NSString *)provider artworks:(NSArray<NSString *> *)artworkProviderNames
{
    NSString *preferredTypeName = nil;

    switch (preferredType) {
        case SBQueueMetadataActionPreferredArtworkiTunes:
            preferredTypeName = @"iTunes";
            break;
        case SBQueueMetadataActionPreferredArtworkEpisode:
            preferredTypeName = [NSString stringWithFormat:@"%@|%@", provider, @"episode"];
            break;
        case SBQueueMetadataActionPreferredArtworkSeason:
            preferredTypeName = [NSString stringWithFormat:@"%@|%@", provider, @"season"];
            break;
        default:
            preferredTypeName = [NSString stringWithFormat:@"%@|%@", provider, @"poster"];
            break;
    }

    NSUInteger index = 0;
    for (NSString *name in artworkProviderNames) {
        if ([name hasPrefix:preferredTypeName]) {
            break;
        }
        index += 1;
    }

    return index == artworkProviderNames.count ? -1 : index;
}

- (MP42Metadata *)searchMetadataForFile:(NSURL *)url {
    id currentSearcher = nil;
    SBMetadataResult *metadata = nil;

    // Parse FileName and search for metadata
    NSDictionary<NSString *, NSString *> *parsed = [SBMetadataHelper parseFilename:url.lastPathComponent];
    NSString *type = parsed[@"type"];
    NSString *provider = nil;

    if ([@"movie" isEqualToString:type]) {
        provider = _movieProvider;
		currentSearcher = [SBMetadataImporter importerForProvider:_movieProvider];
		NSArray<SBMetadataResult *> *results = [currentSearcher searchMovie:parsed[@"title"] language:_movieLanguage];
        if (results.count) {
            metadata = [currentSearcher loadMovieMetadata:results.firstObject language:_movieLanguage];
        }
    }
    else /*if ([@"tv" isEqualToString:type]) */ {
        provider = _tvShowProvider;
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
        NSURL *artworkURL = nil;
        NSInteger index = [self indexOfPreferredArtworkForType:_preferredArtwork
                                                       provider:provider
                                                       artworks:metadata.artworkProviderNames];

        // Fallback to the poster if type is tv
        if (index == -1 && [@"tv" isEqualToString:type]) {
            index = [self indexOfPreferredArtworkForType:SBQueueMetadataActionPreferredArtworkDefault
                                                provider:provider
                                                artworks:metadata.artworkProviderNames];
        }

        if (index > -1) {
            artworkURL = metadata.artworkFullsizeURLs[index];
        }
        else {
            artworkURL = metadata.artworkFullsizeURLs.firstObject;
        }

        MP42Image *artwork = [self loadArtwork:artworkURL];

        if (artwork) {
            [metadata.artworks addObject:artwork];
        }
    }

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    SBMetadataResultMap *map = metadata.mediaKind == 9 ? [defaults SB_resultMapForKey:@"SBMetadataMovieResultMap"] : [defaults SB_resultMapForKey:@"SBMetadataTvShowResultMap"];
    MP42Metadata *mappedMetadata = [metadata metadataUsingMap:map keepEmptyKeys:NO];

    return mappedMetadata;
}

- (void)runAction:(SBQueueItem *)item {
    // Search for metadata
    MP42Metadata *metadata = [self searchMetadataForFile:item.fileURL];

    for (MP42Track *track in [item.mp4File tracksWithMediaType:kMP42MediaType_Video])
        if ([track isKindOfClass:[MP42VideoTrack class]]) {
            MP42VideoTrack *videoTrack = (MP42VideoTrack *)track;
            int hdVideo = isHdVideo((uint64_t)videoTrack.trackWidth, (uint64_t)videoTrack.trackHeight);

            if (hdVideo) {
                NSArray <MP42MetadataItem *> *hdVideos = [metadata metadataItemsFilteredByIdentifier:MP42MetadataKeyHDVideo];
                for (MP42MetadataItem *metadataItem in hdVideos) {
                    [metadata removeMetadataItem:metadataItem];
                }
                [metadata addMetadataItem:[MP42MetadataItem metadataItemWithIdentifier:MP42MetadataKeyHDVideo
                                                                                          value:@(hdVideo)
                                                                                       dataType:MP42MetadataItemDataTypeInteger
                                                                            extendedLanguageTag:nil]];
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

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];

    _movieLanguage = [coder decodeObjectOfClass:[NSString class] forKey:@"_movieLanguage"];
    _tvShowLanguage = [coder decodeObjectOfClass:[NSString class] forKey:@"_tvShowLanguage"];
    _movieProvider = [coder decodeObjectOfClass:[NSString class] forKey:@"_movieProvider"];
    _tvShowProvider = [coder decodeObjectOfClass:[NSString class] forKey:@"_tvShowProvider"];
    _preferredArtwork = [coder decodeIntForKey:@"_preferredArtwork"];

    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:_movieLanguage forKey:@"_movieLanguage"];
    [coder encodeObject:_tvShowLanguage forKey:@"_tvShowLanguage"];
    [coder encodeObject:_movieProvider forKey:@"_movieProvider"];
    [coder encodeObject:_tvShowProvider forKey:@"_tvShowProvider"];
    [coder encodeInt:_preferredArtwork forKey:@"_preferredArtwork"];
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

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _set = [coder decodeObjectOfClass:[MP42Metadata class] forKey:@"SBQueueActionSet"];
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

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {}

@end

/**
 *  An actions that fix the item tracks' fallbacks.
 */
@implementation SBQueueFixFallbacksAction

- (void)runAction:(SBQueueItem *)item {
    [item.mp4File setAutoFallback];
}

- (NSString *)description {
    return NSLocalizedString(@"Fix Fallbacks", @"Action description.");
}

- (NSString *)localizedDescription {
    return NSLocalizedString(@"Fixing Fallbacks", @"Action localized description.");
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {}

@end

/**
 *  An actions that remove the tracks names.
 */
@implementation SBQueueClearTrackNameAction

- (void)runAction:(SBQueueItem *)item {
    for (MP42Track *track in item.mp4File.tracks) {
        track.name = @"";
    }
}

- (NSString *)description {
    return NSLocalizedString(@"Clear tracks names", @"Action description.");
}

- (NSString *)localizedDescription {
    return NSLocalizedString(@"Clearing tracks names", @"Action localized description.");
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {}

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
        if ([track.language isEqualToString:@"und"]) {
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

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    _language = [coder decodeObjectOfClass:[NSString class] forKey:@"SBQueueSetLanguageAction"];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.language forKey:@"SBQueueSetLanguageAction"];
}

@end

@interface SBQueueColorSpaceAction ()
@property(nonatomic, readonly) uint16_t colorPrimaries;
@property(nonatomic, readonly) uint16_t transferCharacteristics;
@property(nonatomic, readonly) uint16_t matrixCoefficients;
@end

@implementation SBQueueColorSpaceAction

- (instancetype)initWithTag:(uint16_t)tag {
    self = [super init];
    if (self) {
        switch (tag) {
            case SBQueueColorSpaceActionTagRec601PAL:
                _colorPrimaries = 5;
                _transferCharacteristics = 1;
                _matrixCoefficients = 6;
                break;

            case SBQueueColorSpaceActionTagRec601SMPTEC:
                _colorPrimaries = 6;
                _transferCharacteristics = 1;
                _matrixCoefficients = 6;
                break;

            case SBQueueColorSpaceActionTagRec709:
                _colorPrimaries = 1;
                _transferCharacteristics = 1;
                _matrixCoefficients = 1;
                break;

            case SBQueueColorSpaceActionTagRec2020:
                _colorPrimaries = 9;
                _transferCharacteristics = 1;
                _matrixCoefficients = 9;
                break;

            case SBQueueColorSpaceActionTagNone:
            default:
                _colorPrimaries = 0;
                _transferCharacteristics = 0;
                _matrixCoefficients = 0;
                break;
        }
    }
    return self;
}

- (instancetype)initWithColorPrimaries:(uint16_t)colorPrimaries transferCharacteristics:(uint16_t)transferCharacteristics matrixCoefficients:(uint16_t)matrixCoefficients {
    self = [super init];
    if (self) {
        _colorPrimaries = colorPrimaries;
        _transferCharacteristics = transferCharacteristics;
        _matrixCoefficients = matrixCoefficients;
    }
    return self;
}

- (void)runAction:(SBQueueItem *)item {
    for (MP42VideoTrack *track in [item.mp4File tracksWithMediaType:kMP42MediaType_Video]) {
        if (track.format == kMP42VideoCodecType_H264 ||
            track.format == kMP42VideoCodecType_HEVC ||
            track.format == kMP42VideoCodecType_HEVC_2 ||
            track.format == kMP42VideoCodecType_MPEG4Video) {
            track.colorPrimaries = self.colorPrimaries;
            track.transferCharacteristics = self.transferCharacteristics;
            track.matrixCoefficients = self.matrixCoefficients;
        }
    }
}

- (NSString *)description {
    return NSLocalizedString(@"Set color space.", @"Set track color space action description");
}

- (NSString *)localizedDescription {
    return NSLocalizedString(@"Setting color space", @"Set track color space action local description");
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    _colorPrimaries = [coder decodeInt32ForKey:@"SBQueueColorSpaceActionColorPrimaries"];
    _transferCharacteristics = [coder decodeInt32ForKey:@"SBQueueColorSpaceActionTransferCharacteristics"];
    _matrixCoefficients = [coder decodeInt32ForKey:@"SBQueueColorSpaceActionMatrixCoefficients"];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeInt32:self.colorPrimaries forKey:@"SBQueueColorSpaceActionColorPrimaries"];
    [coder encodeInt32:self.transferCharacteristics forKey:@"SBQueueColorSpaceActionTransferCharacteristics"];
    [coder encodeInt32:self.matrixCoefficients forKey:@"SBQueueColorSpaceActionMatrixCoefficients"];
}

@end

