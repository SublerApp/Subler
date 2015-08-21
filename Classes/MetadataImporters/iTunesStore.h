//
//  iTunesStore.h
//  Subler
//
//  Created by Douglas Stebila on 2011/01/28.
//  Copyright 2011 Douglas Stebila. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "MetadataImporter.h"

NS_ASSUME_NONNULL_BEGIN

@interface iTunesStore : MetadataImporter

#pragma mark iTunes stores
+ (nullable NSDictionary *) getStoreFor:(NSString *)aLanguageString;

#pragma mark Quick iTunes search for metadata
+ (MP42Metadata *) quickiTunesSearchTV:(NSString *)aSeriesName episodeTitle:(NSString *)aEpisodeTitle;
+ (MP42Metadata *) quickiTunesSearchMovie:(NSString *)aMovieName;

#pragma mark Parse results
+ (NSArray<NSString *> *) readPeople:(NSString *)aPeople fromXML:(NSXMLDocument *)aXml;
+ (NSArray<MP42Metadata *> *) metadataForResults:(NSDictionary *)dict store:(NSDictionary *)store;

@end

NS_ASSUME_NONNULL_END
