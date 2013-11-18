//
//  ArtworkSelector.m
//  Subler
//
//  Created by Douglas Stebila on 2011/02/03.
//  Copyright 2011 Douglas Stebila. All rights reserved.
//

#import "SBArtworkSelector.h"
#import "MetadataImporter.h"
#import <MP42Foundation/MP42Image.h>

#pragma mark IKImageBrowserItem data source objects

@interface myImageObject : NSObject{
    NSURL *_url;
    NSString *_urlString;
	NSString *_artworkProviderName;
}
@end

@implementation myImageObject

- (void) dealloc {
    [_url release];
    [_urlString release];
	[_artworkProviderName release];
    [super dealloc];
}

- (void) setURL:(NSURL *)url {
    if(_url != url){
        [_url release];
        [_urlString release];
        _url = [url retain];
        _urlString = [[url absoluteString] retain];
    }
}

- (NSURL *) url {
    return _url;
}

- (void) setArtworkProviderName:(NSString *)artworkProviderName {
	_artworkProviderName = [artworkProviderName retain];
}

- (NSString *) imageRepresentationType {
    return IKImageBrowserNSDataRepresentationType;
}

- (id)  imageRepresentation {
    return [MetadataImporter downloadDataOrGetFromCache:_url];
}

- (NSString *) imageUID {
    return _urlString;
}

- (NSString *) imageTitle {
	NSArray *a = [_artworkProviderName componentsSeparatedByString:@"|"];
	if ([a count] > 0) {
		return [a objectAtIndex:0];
	}
	return nil;
}

- (NSString *) imageSubtitle {
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

- (void)awakeFromNib {
    images = [[NSMutableArray alloc] initWithCapacity:[imageURLsUnloaded count]];
    myImageObject *m;
    for (int i = 0; (i < 10) && ([imageURLsUnloaded count] > 0); i++) {
        m = [[myImageObject alloc] init];
        [m setURL:[imageURLsUnloaded objectAtIndex:0]];
		[m setArtworkProviderName:[artworkProviderNames objectAtIndex:[images count]]];
        [imageURLsUnloaded removeObjectAtIndex:0];
        [images addObject:m];
        [m release];
    }
    [loadMoreArtworkButton setEnabled:([imageURLsUnloaded count] > 0)];
    [imageBrowser reloadData];
    [imageBrowser setSelectionIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
}

- (IBAction) loadMoreArtwork:(id)sender {
    myImageObject *m;
    for (int i = 0; (i < 10) && ([imageURLsUnloaded count] > 0); i++) {
        m = [[myImageObject alloc] init];
        [m setURL:[imageURLsUnloaded objectAtIndex:0]];
		[m setArtworkProviderName:[artworkProviderNames objectAtIndex:[images count]]];
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

#pragma mark Finishing up

- (IBAction) addArtwork:(id)sender {
    [delegate performSelector:@selector(selectArtworkDone:) withObject:[[[imageBrowser selectionIndexes] retain] autorelease]];
}

- (IBAction) addNoArtwork:(id)sender {
    [delegate performSelector:@selector(selectArtworkDone:) withObject:nil];
}

- (void) dealloc {
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
    [self addArtwork:nil];
}

- (void) imageBrowserSelectionDidChange:(IKImageBrowserView *) aBrowser {
    if ([[aBrowser selectionIndexes] count]) {
        [addArtworkButton setEnabled:YES];
    } else {
        [addArtworkButton setEnabled:NO];
    }
}

@end
