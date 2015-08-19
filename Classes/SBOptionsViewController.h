//
//  QueueOptionsController.h
//  Subler
//
//  Created by Damiano Galassi on 16/03/14.
//
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface SBOptionsViewController : NSViewController {
@private
    IBOutlet NSPopUpButton *_destButton;

    NSMutableDictionary *_options;
    NSMutableArray *_sets;

    NSArray *_moviesProviders;
    NSArray *_tvShowsProviders;
    NSArray *_movieLanguages;
    NSArray *_tvShowLanguages;

    NSURL *_destination;
}

- (instancetype)initWithOptions:(NSMutableDictionary *)options;

@end

NS_ASSUME_NONNULL_END
