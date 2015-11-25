//
//  SBChapterDB.m
//  Subler
//
//  Created by Damiano Galassi on 25/11/15.
//
//

#import "SBChapterDB.h"
#import "SBChapterResult.h"

#import <MP42Foundation/MP42ChapterTrack.h>

#define API_KEY @"ETET7TXFJH45YNYW0I4A"

@implementation SBChapterDB

- (NSArray<SBChapterResult *> *)searchTitle:(NSString *)aTitle duration:(NSUInteger)duration
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://www.chapterdb.org/chapters/search?title=%@", [SBMetadataHelper urlEncoded:aTitle]]];

    NSDictionary *headerOptions = @{@"ApiKey" : API_KEY};
    NSData *xmlData = xmlData = [SBMetadataHelper dataFromUrl:url withHTTPMethod:@"GET" headerOptions:headerOptions error:nil];

    NSXMLDocument *xml = [[NSXMLDocument alloc] initWithData:xmlData
                                                     options:0
                                                       error:nil];

    NSMutableArray<SBChapterResult *> *resultsArray = [[[NSMutableArray alloc] init] autorelease];

    if (xml) {
        NSArray<NSXMLNode *> *children = [xml nodesForXPath:@"//*:chapterInfo" error:nil];

        for (NSXMLNode *child in children) {
            SBChapterResult *result = [self parseResult:child];
            if (result) {
                [resultsArray addObject:result];
            }
        }
    }

    [xml release];

    if (duration > 0) {
        NSArray<SBChapterResult *> *filteredArray = [self filterArray:resultsArray byDuration:duration delta:10000];
        if (filteredArray.count) {
            return filteredArray;
        }
    }
    
    return resultsArray;
}

/**
 *  Filters the results by the duration plus/minus a delta time
 *
 *  @param array    the array of SBChapterResult
 *  @param duration the movie duration
 *  @param delta    the delta in ms
 *
 *  @return the filtered array.
 */
- (NSArray<SBChapterResult *> *)filterArray:(NSArray *)array byDuration:(NSUInteger)duration delta:(NSUInteger)delta
{
    NSMutableArray<SBChapterResult *> *filteredArray = [NSMutableArray array];

    for (SBChapterResult *result in array) {
        if (result.duration < (duration + delta) && result.duration > (duration - delta)) {
            [filteredArray addObject:result];
        }
    }

    return filteredArray;
}

#pragma mark - Result convertion

- (NSString *)titleForNode:(NSXMLNode *)node
{
    NSArray<NSXMLNode *> *tag = [node nodesForXPath:@"./*:title" error:NULL];
    return tag.firstObject.stringValue;
}

- (NSUInteger)confirmationsForNode:(NSXMLNode *)node
{
    NSArray<NSXMLNode *> *tag = [node nodesForXPath:@"./@confirmations" error:NULL];
    return tag.firstObject.stringValue.integerValue;
}

- (NSUInteger)durationForNode:(NSXMLNode *)node
{
    NSArray<NSXMLNode *> *tag = [node nodesForXPath:@"./*:source/*:duration" error:NULL];
    NSString *durationString = tag.firstObject.stringValue;
    if (durationString) {
        return ParseSubTime(durationString.UTF8String, 1000, NO);
    }
    return 0;
}

- (SBChapterResult *)parseResult:(NSXMLNode *)child
{
    NSMutableArray<MP42TextSample *> *chapters = [NSMutableArray array];

    NSString *title = [self titleForNode:child];
    NSUInteger confirmations = [self confirmationsForNode:child];
    NSUInteger duration = [self durationForNode:child];

    NSArray<NSXMLNode *> *times = [child nodesForXPath:@"./*:chapters/*:chapter/@time" error:NULL];
    NSArray<NSXMLNode *> *names = [child nodesForXPath:@"./*:chapters/*:chapter/@name" error:NULL];

    if (times && names) {

        for (NSInteger i = 0; i < times.count && i < names.count; i++) {

            NSString *name = names[i].stringValue;
            NSString *timestamp = times[i].stringValue;

            if (name && timestamp) {
                unsigned time = ParseSubTime(timestamp.UTF8String, 1000, NO);

                MP42TextSample *chapter = [[MP42TextSample alloc] init];
                chapter.title = name;
                chapter.timestamp = time;

                [chapters addObject:chapter];
                [chapter release];
            }
        }

        SBChapterResult *result = [[SBChapterResult alloc] initWithTitle:title
                                                                duration:duration
                                                           confirmations:confirmations
                                                                chapters:chapters];
        
        return [result autorelease];
    }

    return nil;
}

@end
