//
//  SBDocument.m
//  Subler
//
//  Created by Damiano Galassi on 29/01/09.
//  Copyright Damiano Galassi 2009 . All rights reserved.
//

#import "SBDocument.h"

#import <MP42Foundation/MP42File.h>
#import <MP42Foundation/MP42FileImporter.h>
#import <IOKit/pwr_mgt/IOPMLib.h>

#import "Subler-Swift.h"

@interface SBDocument ()

@property (atomic) BOOL optimize;

@property (nonatomic, strong, nullable) NSSavePanel *savePanel;
@property (nonatomic, strong, nullable) SaveOptions *saveOptions;
@property (nonatomic, strong, nullable) NSDictionary<NSString *, NSNumber *> *currentSaveAttributes;

@end

@implementation SBDocument

- (void)makeWindowControllers
{
    SBDocumentWindowController *documentWindowController = [[SBDocumentWindowController alloc] init];
    [self addWindowController:documentWindowController];
    [documentWindowController showWindow:self];
}
- (instancetype)initWithMP4:(MP42File *)mp4File error:(NSError * __autoreleasing *)outError
{
    if (self = [super initWithType:@"Video-MPEG4" error:outError]) {
        self.mp4 = mp4File;
        if (mp4File.URL){
            self.fileURL = mp4File.URL;
        }
        else {
            [self updateChangeCount:NSChangeDone];
        }
    }

    return self;
}

- (instancetype)initWithType:(NSString *)typeName error:(NSError * __autoreleasing *)outError
{
    if (self = [super initWithType:typeName error:outError]) {
        self.mp4 = [[MP42File alloc] init];
    }

    return self;
}

#pragma mark - Restorable state

- (void)restoreDocumentWindowWithIdentifier:(NSString *)identifier
                                      state:(NSCoder *)state
                          completionHandler:(void (^)(NSWindow *, NSError *))completionHandler
{
    if (!self.windowControllers.count) {
        [self makeWindowControllers];
    }

    completionHandler(self.windowControllers.firstObject.window, nil);
}

#pragma mark - Read methods

+ (BOOL)canConcurrentlyReadDocumentsOfType:(NSString *)type
{
    return YES;
}

- (BOOL)isEntireFileLoaded
{
    return NO;
}

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError * __autoreleasing *)outError
{
    self.mp4 = [[MP42File alloc] initWithURL:absoluteURL error:outError];

    if (!self.mp4) {
        return NO;
	}

    return YES;
}

- (BOOL)revertToContentsOfURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError * __autoreleasing *)outError
{
    self.mp4 = [[MP42File alloc] initWithURL:absoluteURL error:outError];

    SBDocumentWindowController *docController = self.windowControllers.firstObject;
    [docController reloadData];

    [self updateChangeCount:NSChangeCleared];

    if (!self.mp4) {
        return NO;
	}

    return YES;
}

#pragma mark - Save methods

- (IBAction)saveAndOptimize:(id)sender
{
    self.optimize = YES;
    [self saveDocument:sender];
}

- (BOOL)canAsynchronouslyWriteToURL:(NSURL *)url
                             ofType:(NSString *)typeName
                   forSaveOperation:(NSSaveOperationType)saveOperation
{
    return YES;
}

- (void)saveToURL:(NSURL *)url ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation completionHandler:(void (^)(NSError * _Nullable))completionHandler
{
    SBDocumentWindowController *docController = self.windowControllers.firstObject;

    void (^modifiedCompletionhandler)(NSError * _Nullable) = ^void(NSError * _Nullable error) {
        MP42File *reloadedFile = nil;
        NSError *reloadError;

        if (error == nil) {
            reloadedFile = [[MP42File alloc] initWithURL:[NSURL fileURLWithPath:url.path] error:&reloadError];
        }

        [docController endProgressReporting];

        if (reloadedFile) {
            self.mp4 = reloadedFile;

            [docController reloadData];

            completionHandler(error);
        }
        else if (reloadError) {
            completionHandler(reloadError);
        }
        else {
            completionHandler(error);
        }

        self.savePanel = nil;
        self.saveOptions = nil;
    };

    self.currentSaveAttributes = [self saveAttributes];
    [docController startProgressReporting];
    [super saveToURL:url ofType:typeName forSaveOperation:saveOperation completionHandler:modifiedCompletionhandler];
}

- (BOOL)writeSafelyToURL:(NSURL *)url ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation error:(NSError * _Nullable *)outError
{
    [self unblockUserInteraction];

    IOPMAssertionID assertionID;
    // Enable sleep assertion
    CFStringRef reasonForActivity= CFSTR("Subler Save Operation");
    IOReturn io_success = IOPMAssertionCreateWithName(kIOPMAssertPreventUserIdleSystemSleep,
                                                      kIOPMAssertionLevelOn, reasonForActivity, &assertionID);
    BOOL result = NO;

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"SBOrganizeAlternateGroups"]) {
        [self.mp4 organizeAlternateGroups];
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"SBInferMediaCharacteristics"]) {
            [self.mp4 inferMediaCharacteristics];
        }
    }

    switch (saveOperation) {
        case NSSaveOperation:
            // movie file already exists, so we'll just update
            // the movie resource.
            result = [self.mp4 updateMP4FileWithOptions:self.currentSaveAttributes error:outError];
            break;

        case NSSaveAsOperation:
            // movie does not exist, create a new one from scratch.
            result = [self.mp4 writeToUrl:url options:self.currentSaveAttributes error:outError];
            break;

        default:
            NSAssert(NO, @"Unhandled save operation");
            break;
    }

    if (result && self.optimize) {
        dispatch_async(dispatch_get_main_queue(), ^{
//            [weakSelf.saveOperationName setStringValue:NSLocalizedString(@"Optimizing…", @"Document Optimize sheet.")];
        });
        result = [self.mp4 optimize];
        self.optimize = NO;
    }

    self.mp4.progressHandler = nil;

    if (io_success == kIOReturnSuccess) {
        IOPMAssertionRelease(assertionID);
    }

    return result;
}

#pragma mark - Save panel

- (BOOL)prepareSavePanel:(NSSavePanel *)savePanel
{
    self.savePanel = savePanel;
    self.saveOptions = [[SaveOptions alloc] init];

    savePanel.extensionHidden = NO;
    savePanel.accessoryView = self.saveOptions.view;

    NSArray<NSString *> *formats = [self writableTypesForSaveOperation:NSSaveAsOperation];

    [self.saveOptions.fileFormat removeAllItems];
    for (NSString *format in formats) {
        NSString *formatName = CFBridgingRelease(UTTypeCopyDescription((__bridge CFStringRef _Nonnull)(format)));

        if (formatName == nil) {
            formatName = format;
        }
        [self.saveOptions.fileFormat addItemWithTitle:formatName];
    }

    [self.saveOptions.fileFormat selectItemAtIndex:[[NSUserDefaults standardUserDefaults] integerForKey:@"defaultSaveFormat"]];

    if ([[NSUserDefaults standardUserDefaults] valueForKey:@"SBSaveFormat"]) {
        self.savePanel.allowedFileTypes = @[[[NSUserDefaults standardUserDefaults] valueForKey:@"SBSaveFormat"]];
    }

    NSString *filename = [self.mp4 preferredFileName];

    if (filename) {
        savePanel.nameFieldStringValue = filename;
    }

    if (self.mp4.dataSize > 4200000000) {
        self.saveOptions._64bit_data.state = NSControlStateValueOn;
    }

    return YES;
}

- (IBAction)setSaveFormat:(NSPopUpButton *)sender
{
    NSString *requiredFileType = nil;
    NSInteger index = sender.indexOfSelectedItem;

    switch (index) {
        case 0:
            requiredFileType = MP42FileTypeM4V;
            break;
        case 1:
            requiredFileType = MP42FileTypeMP4;
            break;
        case 2:
            requiredFileType = MP42FileTypeM4A;
            break;
        case 3:
            requiredFileType = MP42FileTypeM4B;
            break;
        case 4:
            requiredFileType = MP42FileTypeM4R;
            break;
        default:
            requiredFileType = MP42FileTypeM4V;
            break;
    }

    self.savePanel.allowedFileTypes = @[requiredFileType];
    [[NSUserDefaults standardUserDefaults] setObject:requiredFileType forKey:@"SBSaveFormat"];
}

- (NSDictionary<NSString *, NSNumber *> *)saveAttributes {
    NSMutableDictionary<NSString *, NSNumber *> * attributes = [[NSMutableDictionary alloc] init];

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"chaptersPreviewTrack"]) {
        attributes[MP42GenerateChaptersPreviewTrack] = @YES;
        attributes[MP42ChaptersPreviewPosition] = @([[NSUserDefaults standardUserDefaults] floatForKey:@"SBChaptersPreviewPosition"]);
    }

    if (self.saveOptions._64bit_data.state) { attributes[MP4264BitData] = @YES; }
    if (self.saveOptions._64bit_time.state) { attributes[MP4264BitTime] = @YES; }

    return attributes;
}

- (BOOL)validateUserInterfaceItem:(id < NSValidatedUserInterfaceItem >)anItem
{
    SEL action = anItem.action;

    if (action == @selector(saveDocument:))
        if (self.documentEdited)
            return YES;

    if (action == @selector(saveDocumentAs:))
        return YES;

    if (action == @selector(revertDocumentToSaved:))
        if (self.documentEdited)
            return YES;

    if (action == @selector(saveAndOptimize:))
        if (!self.documentEdited && self.mp4.hasFileRepresentation)
            return YES;

    return NO;
}

@end
