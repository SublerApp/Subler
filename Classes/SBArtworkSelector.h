//
//  ArtworkSelector.h
//  Subler
//
//  Created by Douglas Stebila on 2011/02/03.
//  Copyright 2011 Douglas Stebila. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

@protocol SBArtworkSelectorDelegate <NSObject>
- (void)selectArtworkDone:(NSURL *)url;
@end

@interface SBArtworkSelector : NSWindowController {
    id <SBArtworkSelectorDelegate>  delegate;
    IBOutlet IKImageBrowserView     *imageBrowser;
    IBOutlet NSSlider               *slider;
    IBOutlet NSButton               *addArtworkButton;
    IBOutlet NSButton               *loadMoreArtworkButton;
    NSMutableArray                  *imageURLsUnloaded;
    NSMutableArray                  *images;
	NSArray							*artworkProviderNames;
}

#pragma mark Initialization
- (instancetype)initWithDelegate:(id <SBArtworkSelectorDelegate>)del imageURLs:(NSArray *)imageURLs artworkProviderNames:(NSArray *)artworkProviderNames;

#pragma mark Load images
- (IBAction) loadMoreArtwork:(id)sender;

#pragma mark User interface
- (IBAction) zoomSliderDidChange:(id)sender;

#pragma mark Finishing up
- (IBAction) addArtwork:(id)sender;
- (IBAction) addNoArtwork:(id)sender;

@end
