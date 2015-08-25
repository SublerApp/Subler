//
//  SBImageBrowserView.h
//  Subler
//
//  Created by Damiano Galassi on 02/09/13.
//
//

#import <Quartz/Quartz.h>

NS_ASSUME_NONNULL_BEGIN

@protocol SBImageBrowserViewDelegate
@optional
- (void)_pasteToImageBrowserView:(IKImageBrowserView *)ImageBrowserView;
@end

@interface SBImageBrowserView : IKImageBrowserView {
    NSArray *_pasteboardTypes;
}
@property(nonatomic, readwrite, retain) NSArray<NSString *> *pasteboardTypes;
@end

NS_ASSUME_NONNULL_END
