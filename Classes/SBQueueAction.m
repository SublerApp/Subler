//
//  SBQueueAction.m
//  Subler
//
//  Created by Damiano Galassi on 12/03/14.
//
//

#import "SBQueueAction.h"

#import "SBQueueItem.h"
#import "SBMetadataResultMap.h"

#import <MP42Foundation/MP42File.h>
#import <MP42Foundation/MP42FileImporter.h>
#import <MP42Foundation/MP42Image.h>
#import <MP42Foundation/MP42Utilities.h>

#import "Subler-Swift.h"

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
            track.format == kMP42VideoCodecType_HEVC_PSinBitstream ||
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

