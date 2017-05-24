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
@property (nonatomic, readwrite) NSArray<NSString *> *languagues;

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

            self->_languagues = result;
        }
    }
}

- (NSString *)token
{
    __block NSString *token = nil;

    dispatch_sync(_tokenQueue, ^{

        if (self->_token == nil) {
            [self updateToken];
        }

        token = self->_token;
    });

    return token;
}

- (NSArray<NSString *> *)languagues
{
    __block NSArray<NSString *> *languages = @[];

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

@end
