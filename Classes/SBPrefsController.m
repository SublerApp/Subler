//
//  SBPrefsController.m
//
//  Created by Damiano Galassi on 13/05/08.
//  Copyright 2008 Damiano Galassi. All rights reserved.
//

#import "SBPrefsController.h"

#import "SBMetadataPrefsViewController.h"
#import "SBSetPrefsViewController.h"

#import "Subler-Swift.h"

#import <MP42Foundation/MP42Ratings.h>

#define TOOLBAR_GENERAL     @"TOOLBAR_GENERAL"
#define TOOLBAR_METADATA    @"TOOLBAR_METADATA"
#define TOOLBAR_ADVANCED    @"TOOLBAR_ADVANCED"
#define TOOLBAR_SETS        @"TOOLBAR_SETS"

@interface SBPrefsController () <NSWindowDelegate>

@property (nonatomic, strong) IBOutlet NSView *generalView;
@property (nonatomic, strong) IBOutlet NSView *advancedView;

@property (nonatomic, strong) SBMetadataPrefsViewController *metadataController;
@property (nonatomic, strong) SBSetPrefsViewController      *setController;

@end

@implementation SBPrefsController

+ (void)registerUserDefaults
{
    NSData *movieDefaultMap = [NSKeyedArchiver archivedDataWithRootObject:[SBMetadataResultMap movieDefaultMap]];
    NSData *tvShowDefaultMap = [NSKeyedArchiver archivedDataWithRootObject:[SBMetadataResultMap tvShowDefaultMap]];

    // Migrate 1.2.9 DTS setting
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"SBAudioKeepDts"] != nil)
    {
        if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"SBAudioKeepDts"] boolValue])
        {
            [[NSUserDefaults standardUserDefaults] setInteger:2 forKey:@"SBAudioDtsOptions"];
        }
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"SBAudioKeepDts"];
    }
    
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{@"SBSaveFormat":                  @"m4v",
                                                              @"defaultSaveFormat":             @"0",
                                                              @"SBOrganizeAlternateGroups":     @"YES",
                                                              @"SBAudioMixdown":                @"1",
                                                              @"SBAudioBitrate":                @"96",
                                                              @"SBAudioConvertAC3":             @"YES",
                                                              @"SBAudioKeepAC3":                @"YES",
                                                              @"SBAudioConvertDts":             @"YES",
                                                              @"SBAudioDtsOptions":             @"0",
                                                              @"SBSubtitleConvertBitmap":       @"YES",
                                                              @"SBRatingsCountry":              @"All countries",
                                                              @"SBSaveFormat":                  @"m4v",
                                                              @"mp464bitOffset":                @"NO",
                                                              @"chaptersPreviewTrack":          @"YES",
                                                              @"SBChaptersPreviewPosition":     @0.5f,

                                                              @"SBMetadataPreference|Movie": @"TheMovieDB",
                                                              @"SBMetadataPreference|Movie|iTunes Store|Language": @"USA (English)",
                                                              @"SBMetadataPreference|Movie|TheMovieDB|Language": @"en",
                                                              @"SBMetadataPreference|TV": @"TheTVDB",
                                                              @"SBMetadataPreference|TV|iTunes Store|Language": @"USA (English)",
                                                              @"SBMetadataPreference|TV|TheTVDB|Language": @"en",

                                                              @"SBMetadataMovieResultMap" : movieDefaultMap,
                                                              @"SBMetadataTvShowResultMap" : tvShowDefaultMap,
                                                              @"SBMetadataKeepEmptyAnnotations" : @NO,
                                                              }];
}

- (instancetype)init
{
    if ((self = [super initWithWindowNibName:@"Prefs"])) {
        _metadataController = [[SBMetadataPrefsViewController alloc] init];
        _setController = [[SBSetPrefsViewController alloc] init];
    }

    return self;
}

- (void)awakeFromNib
{
    self.window.toolbar.allowsUserCustomization = NO;
    [self.window.toolbar setSelectedItemIdentifier:TOOLBAR_GENERAL];
    [self setPrefView:nil];
}

#pragma mark - General

- (IBAction)clearRecentSearches:(id)sender
{
    [SBMetadataSearchController clearRecentSearches];
}

- (IBAction)deleteCachedMetadata:(id)sender
{
    [SBMetadataSearchController deleteCachedMetadata];
}

- (NSArray *)ratingsCountries
{
    return [[MP42Ratings defaultManager] ratingsCountries];
}

- (IBAction) updateRatingsCountry:(id)sender
{
    [[MP42Ratings defaultManager] updateRatingsCountry];
}

- (IBAction)setPrefView:(id)sender
{
    NSView *view = self.generalView;
    if (sender) {
        NSString *identifier = [sender itemIdentifier];
        if ([identifier isEqualToString:TOOLBAR_ADVANCED]) {
            view = self.advancedView;
        }
        else if ([identifier isEqualToString:TOOLBAR_SETS]) {
            view = self.setController.view;
        }
        else if ([identifier isEqualToString:TOOLBAR_METADATA]) {
            view = self.metadataController.view;
        }
    }

    NSWindow *window = self.window;
    if (window.contentView == view) {
        return;
    }

    window.contentView = view;

    if (window.isVisible) {
        view.hidden = YES;

        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            if (NSClassFromString(@"NSVisualEffectView")) {
                context.allowsImplicitAnimation = YES;
            }
            [window layoutIfNeeded];

        } completionHandler:^{
            view.hidden = NO;
            [self SB_setTitle:sender];
        }];
    }
    else {
        [self SB_setTitle:sender];
    }
}

- (void)SB_setTitle:(id)sender
{
    // Set title label
    if (sender) {
        self.window.title = [sender label];
    }
    else {
        NSToolbar *toolbar = self.window.toolbar;
        NSString *itemIdentifier = toolbar.selectedItemIdentifier;
        for (NSToolbarItem *item in toolbar.items)
            if ([item.itemIdentifier isEqualToString:itemIdentifier]) {
                self.window.title = item.label;
                break;
            }
    }
}

@end
