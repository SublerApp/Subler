//
//  ArtworkSelector.m
//  Subler
//
//  Created by Douglas Stebila on 2011/02/03.
//  Copyright 2011 Douglas Stebila. All rights reserved.
//

#import "SBArtworkSelector.h"
#import "SBMetadataHelper.h"

#pragma mark IKImageBrowserItem data source objects

@interface SBArtworkImageObject : NSObject {
    NSURL *_url;
    NSString *_urlString;
	NSString *_artworkProviderName;
    NSData *_data;
    NSInteger _version;

    id _delegate;
    BOOL _isCancelled;
}

@property (atomic, assign) id delegate;

@end

@interface SBArtworkImageObject ()

@property (atomic, retain) NSData *data;
@property (atomic) NSInteger version;
@property (atomic) BOOL isCancelled;

@end

@implementation SBArtworkImageObject

@synthesize data = _data;
@synthesize version = _version;
@synthesize delegate = _delegate;

@synthesize isCancelled = _isCancelled;

- (instancetype)initWithURL:(NSURL *)url artworkProviderName:(NSString *)artworkProvider delegate:(id)delegate
{
    self = [super init];
    if (self) {
        _url = [url copy];
        _urlString = [[url absoluteString] retain];
        _artworkProviderName = [artworkProvider copy];
        _delegate = delegate;
    }
    return self;
}

- (void)dealloc {
    self.delegate = nil;
    [_url release];
    [_urlString release];
	[_artworkProviderName release];
    [_data release];
    [super dealloc];
}

- (void)cancel {
    self.isCancelled = YES;
    self.delegate = nil;
}

- (NSString *)imageRepresentationType {
    return IKImageBrowserNSDataRepresentationType;
}

- (id)imageRepresentation {
    @synchronized(self) {
        if (!self.version) {
            self.version = 1;
            // Get the data outside the main thread
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                if (!self.isCancelled) {
                    self.data = [SBMetadataHelper downloadDataFromURL:_url withCachePolicy:SBDefaultPolicy];
                    self.version = 2;
                    // We got the data, tell the controller to update the view
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (!self.isCancelled) {
                            [self.delegate reloadData];
                        }
                    });
                }
            });
        }
    }

    return self.data;
}

- (NSString *)imageUID {
    return _urlString;
}

- (NSUInteger)imageVersion{
    return self.version;
}

- (NSString *)imageTitle {
	NSArray *a = [_artworkProviderName componentsSeparatedByString:@"|"];
    return [a firstObject];
}

- (NSString *)imageSubtitle {
	NSArray *a = [_artworkProviderName componentsSeparatedByString:@"|"];
	if ([a count] > 1) {
		return [a objectAtIndex:1];
	}
	return nil;
}

@end

#pragma mark -

@implementation SBArtworkSelector

#pragma mark Initialization

- (instancetype)initWithDelegate:(id <SBArtworkSelectorDelegate>)del imageURLs:(NSArray *)imageURLs artworkProviderNames:(NSArray *)aArtworkProviderNames {
	if ((self = [super initWithWindowNibName:@"ArtworkSelector"])) {
		delegate = del;
        imageURLsUnloaded = [[NSMutableArray alloc] initWithArray:imageURLs];
		artworkProviderNames = [aArtworkProviderNames retain];
    }
    return self;
}

#pragma mark Load images

- (void)windowDidLoad {
    images = [[NSMutableArray alloc] initWithCapacity:imageURLsUnloaded.count];

    for (NSUInteger i = 0; (i < 10) && (imageURLsUnloaded.count > 0); i++) {
        SBArtworkImageObject *m = [[SBArtworkImageObject alloc] initWithURL:[imageURLsUnloaded objectAtIndex:0]
                                  artworkProviderName:[artworkProviderNames objectAtIndex:[images count]]
                                             delegate:self];
        [imageURLsUnloaded removeObjectAtIndex:0];
        [images addObject:m];
        [m release];
    }

    [loadMoreArtworkButton setEnabled:([imageURLsUnloaded count] > 0)];
    [imageBrowser reloadData];
    [imageBrowser setSelectionIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
}

- (IBAction) loadMoreArtwork:(id)sender {
    for (NSUInteger i = 0; (i < 10) && (imageURLsUnloaded.count > 0); i++) {
        SBArtworkImageObject *m = [[SBArtworkImageObject alloc] initWithURL:[imageURLsUnloaded objectAtIndex:0]
                                  artworkProviderName:[artworkProviderNames objectAtIndex:[images count]]
                                             delegate:self];
        [imageURLsUnloaded removeObjectAtIndex:0];
        [images addObject:m];
        [m release];
    }
    [loadMoreArtworkButton setEnabled:([imageURLsUnloaded count] > 0)];
    [imageBrowser reloadData];
}

#pragma mark User interface

- (IBAction) zoomSliderDidChange:(id)sender {
    [imageBrowser setZoomValue:[slider floatValue]];
    [imageBrowser setNeedsDisplay:YES];
}

- (void)reloadData {
    [imageBrowser reloadData];
}

#pragma mark Finishing up

- (IBAction) addArtwork:(id)sender {
    [delegate selectArtworkDone:imageBrowser.selectionIndexes];
}

- (IBAction) addNoArtwork:(id)sender {
    [delegate selectArtworkDone:[NSIndexSet indexSet]];
}

- (void) dealloc {
    [imageBrowser setDelegate:nil];
    [imageBrowser setDataSource:nil];

    [images makeObjectsPerformSelector:@selector(cancel)];
    [images release];

    [imageURLsUnloaded release];
	[artworkProviderNames release];
    [super dealloc];
}

#pragma mark -
#pragma mark IKImageBrowserDataSource

- (NSUInteger) numberOfItemsInImageBrowser:(IKImageBrowserView *) aBrowser {
    return [images count];
}

- (id) imageBrowser:(IKImageBrowserView *) aBrowser itemAtIndex:(NSUInteger)index {
    return [images objectAtIndex:index];
}

#pragma mark -
#pragma mark IKImageBrowserDelegate

- (void) imageBrowser:(IKImageBrowserView *) aBrowser cellWasDoubleClickedAtIndex:(NSUInteger) index {
    [self addArtwork:self];
}

- (void) imageBrowserSelectionDidChange:(IKImageBrowserView *) aBrowser {
    if ([[aBrowser selectionIndexes] count]) {
        [addArtworkButton setEnabled:YES];
    } else {
        [addArtworkButton setEnabled:NO];
    }
}

@end
