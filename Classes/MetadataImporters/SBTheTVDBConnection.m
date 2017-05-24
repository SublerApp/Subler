//
//  SBTheTVDBConnection.m
//  Subler
//
//  Created by Damiano Galassi on 24/05/17.
//
//

#import "SBTheTVDBConnection.h"

#import <MP42Foundation/MP42Ratings.h>
#import <MP42Foundation/MP42Languages.h>

#import "SBMetadataHelper.h"

#define API_KEY @"3498815BE9484A62"

@interface SBTheTVDBConnection ()

@property (nonatomic, readwrite, nullable) NSString *token;
@property (nonatomic, readwrite) NSTimeInterval tokenTimestamp;

@property (nonatomic, readwrite) NSArray<NSString *> *languagues;
@property (nonatomic, readwrite) NSTimeInterval languagesTimestamp;

@property (nonatomic, readonly) dispatch_queue_t queue;
@property (nonatomic, readonly) dispatch_queue_t tokenQueue;

@end

@implementation SBTheTVDBConnection

+ (instancetype)defaultManager
{
    static dispatch_once_t pred;
    static SBTheTVDBConnection *shared = nil;

    dispatch_once(&pred, ^{
        shared = [[SBTheTVDBConnection alloc] init];
    });
    return shared;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _queue = dispatch_queue_create("org.subler.TheTVDBQueue", DISPATCH_QUEUE_SERIAL);
        _tokenQueue = dispatch_queue_create("org.subler.TheTVDBTokenQueue", DISPATCH_QUEUE_SERIAL);

        _languagesTimestamp = [[NSUserDefaults.standardUserDefaults objectForKey:@"SBTheTVBDLanguagesArrayTimestamp"] doubleValue];

        if (_languagesTimestamp + 60 * 60 * 60 > [NSDate timeIntervalSinceReferenceDate]) {
            _languagues = [NSUserDefaults.standardUserDefaults objectForKey:@"SBTheTVBDLanguagesArray"];
        }

        _tokenTimestamp = [[NSUserDefaults.standardUserDefaults objectForKey:@"SBTheTVBDTokenTimestamp"] doubleValue];

        if (_tokenTimestamp + 60 * 60 * 4 > [NSDate timeIntervalSinceReferenceDate]) {
            _token = [NSUserDefaults.standardUserDefaults objectForKey:@"SBTheTVBDToken"];
        }
    }

    return self;
}

- (void)updateToken
{
    NSDictionary *apiKey = @{@"apikey" : API_KEY};
    NSData *jsonApiKey = [NSJSONSerialization dataWithJSONObject:apiKey options:0 error:NULL];

    NSDictionary *headerOptions = @{@"Content-Type" : @"application/json",
                                    @"Accept" : @"application/json"};

    NSURL *url = [NSURL URLWithString:@"https://api.thetvdb.com/login"];
    NSData *data = [SBMetadataHelper downloadDataFromURL:url HTTPMethod:@"POST" HTTPBody:jsonApiKey headerOptions:headerOptions cachePolicy:SBDefaultPolicy];

    if (data) {
        id response = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
        if ([response isKindOfClass:[NSDictionary class]]) {
            NSString *token = response[@"token"];
            if ([token isKindOfClass:[NSString class]]) {
                _token = token;
                _tokenTimestamp = [NSDate timeIntervalSinceReferenceDate];
                [NSUserDefaults.standardUserDefaults setObject:token forKey:@"SBTheTVBDToken"];
                [NSUserDefaults.standardUserDefaults setObject:@(_tokenTimestamp)
                                                        forKey:@"SBTheTVBDTokenTimestamp"];
            }
        }
    }
}

- (void)updateLanguages
{
    NSURL *url = [NSURL URLWithString:@"https://api.thetvdb.com/languages"];
    NSData *languagesJSON = [self requestData:url language:@"en"];

    NSDictionary *languagesDict = [NSJSONSerialization JSONObjectWithData:languagesJSON options:0 error:NULL];

    if (languagesDict || [languagesDict isKindOfClass:[NSDictionary class]]) {

        NSArray<NSDictionary *> *languagesArray = languagesDict[@"data"];

        if (languagesArray || [languagesArray isKindOfClass:[NSArray class]]) {

            MP42Languages *langManager = MP42Languages.defaultManager;
            NSMutableArray<NSString *> *result = [NSMutableArray array];

            for (NSDictionary *lang in languagesArray) {
                if ([lang isKindOfClass:[NSDictionary class]]) {
                    NSString *abbreviation = lang[@"abbreviation"];
                    if (abbreviation && [abbreviation isKindOfClass:[NSString class]]) {
                        [result addObject:[langManager extendedTagForISO_639_1:abbreviation]];
                    }
                }
            }

            _languagues = result;
            _languagesTimestamp = [NSDate timeIntervalSinceReferenceDate];
            [NSUserDefaults.standardUserDefaults setObject:result forKey:@"SBTheTVBDLanguagesArray"];
            [NSUserDefaults.standardUserDefaults setObject:@(_languagesTimestamp)
                                                    forKey:@"SBTheTVBDLanguagesArrayTimestamp"];
        }
    }
}

- (NSString *)token
{
    __block NSString *token = nil;

    dispatch_sync(_tokenQueue, ^{

        if (self->_tokenTimestamp + 60 * 60 * 4 < [NSDate timeIntervalSinceReferenceDate]
            || self->_token == nil) {
            [self updateToken];
        }

        token = self->_token;
    });

    return token;
}

- (NSArray<NSString *> *)languagues
{
    __block NSArray<NSString *> *languages = @[@"en"];

    dispatch_sync(_queue, ^{

        if (self->_languagues == nil) {
            [self updateLanguages];
        }

        if (self->_languagues) {
            languages = self->_languagues;
        }
    });

    return languages;
}

- (NSData *)requestData:(NSURL *)url language:(NSString *)language
{
    NSString *token = self.token;

    if (token == nil) {
        return nil;
    }

    NSDictionary *headerOptions = @{@"Authorization" : [NSString stringWithFormat:@"Bearer %@", token],
                                    @"Content-Type" : @"application/json",
                                    @"Accept" : @"application/json",
                                    @"Accept-Language" : language};
    NSData *data = [SBMetadataHelper downloadDataFromURL:url HTTPMethod:@"GET" HTTPBody:nil headerOptions:headerOptions cachePolicy:SBDefaultPolicy];
    
    return data;
}

#pragma mark - wrapper

- (NSArray<NSDictionary *> *)fetchSeries:(NSString *)seriesName language:(NSString *)language
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.thetvdb.com/search/series?name=%@", seriesName]];
    NSData *seriesJSON = [self requestData:url language:language];

    if (seriesJSON) {

        NSDictionary *series = [NSJSONSerialization JSONObjectWithData:seriesJSON options:0 error:NULL];

        if (series || [series isKindOfClass:[NSDictionary class]]) {

            NSArray<NSDictionary *> *seriesArray = series[@"data"];

            if ([seriesArray isKindOfClass:[NSArray class]] && seriesArray.count) {
                return seriesArray;
            }
        }
    }

    return @[];
}

- (nullable NSDictionary *)fetchSeriesInfo:(NSNumber *)seriesID language:(NSString *)language
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.thetvdb.com/series/%@", seriesID]];
    NSData *seriesInfoJSON = [SBTheTVDBConnection.defaultManager requestData:url language:language];

    if (!seriesInfoJSON) { return nil; }

    NSDictionary *seriesInfo = [NSJSONSerialization JSONObjectWithData:seriesInfoJSON options:0 error:NULL];

    if (!seriesInfo || ![seriesInfo isKindOfClass:[NSDictionary class]]) { return nil; }

    seriesInfo = seriesInfo[@"data"];

    if (!seriesInfo || ![seriesInfo isKindOfClass:[NSDictionary class]]) { return nil; }

    return seriesInfo;

}

- (NSArray<NSDictionary *> *)fetchSeriesActors:(NSNumber *)seriesID language:(NSString *)language
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.thetvdb.com/series/%@/actors", seriesID]];
    NSData *seriesActorsJSON = [SBTheTVDBConnection.defaultManager requestData:url language:language];

    if (!seriesActorsJSON) { return @[]; }

    NSDictionary *seriesActorsDictionary = [NSJSONSerialization JSONObjectWithData:seriesActorsJSON options:0 error:NULL];

    if (!seriesActorsDictionary || ![seriesActorsDictionary isKindOfClass:[NSDictionary class]]) { return @[]; }

    NSArray<NSDictionary *> *seriesActors = seriesActorsDictionary[@"data"];

    if (!seriesActors || ![seriesActors isKindOfClass:[NSArray class]]) { return @[]; }

    return seriesActors;
}

- (NSArray<NSDictionary *> *)fetchSeriesImages:(NSNumber *)seriesID type:(NSString *)type language:(NSString *)language;
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.thetvdb.com/series/%@/images/query?keyType=%@", seriesID, type]];
    NSData *imagesJSON = [SBTheTVDBConnection.defaultManager requestData:url language:language];

    if (!imagesJSON) { return @[]; }

    NSDictionary *imagesDictionary = [NSJSONSerialization JSONObjectWithData:imagesJSON options:0 error:NULL];

    if (!imagesDictionary || ![imagesDictionary isKindOfClass:[NSDictionary class]]) { return @[]; }

    NSArray<NSDictionary *> *imagesArray = imagesDictionary[@"data"];

    if (!imagesArray || ![imagesArray isKindOfClass:[NSArray class]]) { return @[]; }

    return imagesArray;
}

- (NSArray<NSDictionary *> *)fetchEpisodes:(NSNumber *)seriesID season:(NSString *)season number:(NSString *)number language:(NSString *)language;
{
    NSURL *url;
    if (season.length && number.length) {
        url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.thetvdb.com/series/%@/episodes/query?airedSeason=%@&airedEpisode=%@",
                                    seriesID, season, number]];
    } else if (season.length) {
        url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.thetvdb.com/series/%@/episodes/query?airedSeason=%@",
                                    seriesID, season]];
    }
    else {
        url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.thetvdb.com/series/%@/episodes", seriesID]];
    }

    NSData *episodesJSON = [SBTheTVDBConnection.defaultManager requestData:url language:language];

    if (!episodesJSON) { return @[]; }

    NSDictionary *episodes = [NSJSONSerialization JSONObjectWithData:episodesJSON options:0 error:NULL];

    if (!episodes || ![episodes isKindOfClass:[NSDictionary class]]) { return @[]; }

    // Decode the individual episodes

    NSArray<NSDictionary *> *episodesArray = episodes[@"data"];

    if ([episodesArray isKindOfClass:[NSArray class]]) {
        return episodesArray;
    }

    return @[];
}

- (NSDictionary *)fetchEpisodesInfo:(NSNumber *)episodeID language:(NSString *)language;
{
    NSURL *episodesUrl = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.thetvdb.com/episodes/%@", episodeID]];
    NSData *episodesJSON = [SBTheTVDBConnection.defaultManager requestData:episodesUrl language:language];

    if (!episodesJSON) { return nil; }

    NSDictionary *episodesInfo = [NSJSONSerialization JSONObjectWithData:episodesJSON options:0 error:NULL];

    if (!episodesInfo || ![episodesInfo isKindOfClass:[NSDictionary class]]) { return nil; }

    episodesInfo = episodesInfo[@"data"];

    if (!episodesInfo || ![episodesInfo isKindOfClass:[NSDictionary class]]) { return nil; }

    return episodesInfo;
}

@end
