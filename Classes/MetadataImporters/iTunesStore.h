//
//  iTunesStore.h
//  Subler
//
//  Created by Douglas Stebila on 2011/01/28.
//  Copyright 2011 Douglas Stebila. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "MetadataImporter.h"

@interface iTunesStore : MetadataImporter

#pragma mark iTunes stores
+ (NSDictionary *) getStoreFor:(NSString *)aLanguageString;

#pragma mark Quick iTunes search for metadata
+ (MP42Metadata *) quickiTunesSearchTV:(NSString *)aSeriesName episodeTitle:(NSString *)aEpisodeTitle;
+ (MP42Metadata *) quickiTunesSearchMovie:(NSString *)aMovieName;

#pragma mark Parse results
+ (NSArray *) readPeople:(NSString *)aPeople fromXML:(NSXMLDocument *)aXml;
+ (NSArray *) metadataForResults:(NSDictionary *)dict store:(NSDictionary *)store;

@end
