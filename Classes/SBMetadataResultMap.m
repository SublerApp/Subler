//
//  SBMetadataDefaultSet.m
//  Subler
//
//  Created by Damiano Galassi on 28/07/2016.
//
//

#import "SBMetadataResultMap.h"

@implementation SBMetadataResultMapItem

- (instancetype)initWithKey:(NSString *)key value:(NSArray *)value
{
    self = [super init];
    if (self) {
        _key = [key copy];
        _value = [value copy];
    }
    return self;
}

+ (instancetype)itemWithKey:(NSString *)key value:(NSArray *)value
{
    return [[self alloc] initWithKey:key value:value];
}

#pragma mark - NSCoding

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [self init];
    if (self) {
        id temp;
        temp = [coder decodeObjectOfClass:[NSString class] forKey:@"key"];
        if (temp) {
            _key = temp;
        }
        temp = [coder decodeObjectOfClass:[NSArray class] forKey:@"value"];
        if (temp) {
            _value = temp;
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self.key forKey:@"key"];
    [coder encodeObject:self.value forKey:@"value"];
}

@end

@implementation SBMetadataResultMap

+ (NSArray<NSString *> *)movieKeys
{
    return @[@"{Name}",
             @"{Composer}",
             @"{Genre}",
             @"{Release Date}",
             @"{Description}",
             @"{Long Description}",
             @"{Rating}",
             @"{Studio}",
             @"{Cast}",
             @"{Director}",
             @"{Producers}",
             @"{Screenwriters}",
             @"{Copyright}",
             @"{contentID}",
             @"{iTunes Country}",
             @"{Executive Producer}"];
}

+ (instancetype)movieDefaultMap
{
    NSArray<SBMetadataResultMapItem *> *items = @[
             [SBMetadataResultMapItem itemWithKey:@"Name"               value:@[@"{Name}"]],
             [SBMetadataResultMapItem itemWithKey:@"Artist"             value:@[@"{Director}"]],
             [SBMetadataResultMapItem itemWithKey:@"Composer"           value:@[@"{Composer}"]],
             [SBMetadataResultMapItem itemWithKey:@"Genre"              value:@[@"{Genre}"]],
             [SBMetadataResultMapItem itemWithKey:@"Release Date"       value:@[@"{Release Date}"]],
             [SBMetadataResultMapItem itemWithKey:@"Description"        value:@[@"{Description}"]],
             [SBMetadataResultMapItem itemWithKey:@"Long Description"   value:@[@"{Long Description}"]],
             [SBMetadataResultMapItem itemWithKey:@"Rating"             value:@[@"{Rating}"]],
             [SBMetadataResultMapItem itemWithKey:@"Studio"             value:@[@"{Studio}"]],
             [SBMetadataResultMapItem itemWithKey:@"Cast"               value:@[@"{Cast}"]],
             [SBMetadataResultMapItem itemWithKey:@"Director"           value:@[@"{Director}"]],
             [SBMetadataResultMapItem itemWithKey:@"Producers"          value:@[@"{Producers}"]],
             [SBMetadataResultMapItem itemWithKey:@"Screenwriters"      value:@[@"{Screenwriters}"]],
             [SBMetadataResultMapItem itemWithKey:@"Copyright"          value:@[@"{Copyright}"]],
             [SBMetadataResultMapItem itemWithKey:@"contentID"          value:@[@"{contentID}"]],
             [SBMetadataResultMapItem itemWithKey:@"iTunes Country"     value:@[@"{iTunes Country}"]],
             [SBMetadataResultMapItem itemWithKey:@"Executive Producer" value:@[@"{Executive Producer}"]],
             ];

    return [[self alloc] initWithItems:items type:SBMetadataResultMapTypeMovie];
}

+ (NSArray<NSString *> *)tvShowKeys
{
    return @[@"{Name}",
             @"{Series Name}",
             @"{Composer}",
             @"{Genre}",
             @"{Release Date}",

             @"{Track #}",
             @"{Disk #}",
             @"{Episode #}",
             @"{Network}",
             @"{Episode ID}",
             @"{Season}",

             @"{Description}",
             @"{Long Description}",
             @"{Series Description}",

             @"{Rating}",
             @"{Studio}",
             @"{Cast}",
             @"{Director}",
             @"{Producers}",
             @"{Screenwriters}",
             @"{Copyright}",
             @"{contentID}",
             @"{artistID}",
             @"{playlistID}",
             @"{iTunes Country}",
             @"{Executive Producer}"];
}

+ (instancetype)tvShowDefaultMap
{
    NSArray<SBMetadataResultMapItem *> *items = @[
             [SBMetadataResultMapItem itemWithKey:@"Name"         value:@[@"{Name}"]],
             [SBMetadataResultMapItem itemWithKey:@"Artist"       value:@[@"{Series Name}"]],
             [SBMetadataResultMapItem itemWithKey:@"Album Artist" value:@[@"{Series Name}"]],
             [SBMetadataResultMapItem itemWithKey:@"Album"        value:@[@"{Series Name}", @", Season ", @"{Season}"]],
             [SBMetadataResultMapItem itemWithKey:@"Composer"     value:@[@"{Composer}"]],
             [SBMetadataResultMapItem itemWithKey:@"Genre"        value:@[@"{Genre}"]],
             [SBMetadataResultMapItem itemWithKey:@"Release Date" value:@[@"{Release Date}"]],

             [SBMetadataResultMapItem itemWithKey:@"Track #"          value:@[@"{Track #}"]],
             [SBMetadataResultMapItem itemWithKey:@"Disk #"           value:@[@"{Disk #}"]],
             [SBMetadataResultMapItem itemWithKey:@"TV Show"          value:@[@"{Series Name}"]],
             [SBMetadataResultMapItem itemWithKey:@"TV Episode #"     value:@[@"{Episode #}"]],
             [SBMetadataResultMapItem itemWithKey:@"TV Network"       value:@[@"{Network}"]],
             [SBMetadataResultMapItem itemWithKey:@"TV Episode ID"    value:@[@"{Episode ID}"]],
             [SBMetadataResultMapItem itemWithKey:@"TV Season"        value:@[@"{Season}"]],

             [SBMetadataResultMapItem itemWithKey:@"Description"          value:@[@"{Description}"]],
             [SBMetadataResultMapItem itemWithKey:@"Long Description"     value:@[@"{Long Description}"]],
             [SBMetadataResultMapItem itemWithKey:@"Series Description"   value:@[@"{Series Description}"]],

             [SBMetadataResultMapItem itemWithKey:@"Rating"               value:@[@"{Rating}"]],
             [SBMetadataResultMapItem itemWithKey:@"Studio"               value:@[@"{Studio}"]],
             [SBMetadataResultMapItem itemWithKey:@"Cast"                 value:@[@"{Cast}"]],
             [SBMetadataResultMapItem itemWithKey:@"Director"             value:@[@"{Director}"]],
             [SBMetadataResultMapItem itemWithKey:@"Producers"            value:@[@"{Producers}"]],
             [SBMetadataResultMapItem itemWithKey:@"Screenwriters"        value:@[@"{Screenwriters}"]],
             [SBMetadataResultMapItem itemWithKey:@"Executive Producer"   value:@[@"{Executive Producer}"]],
             [SBMetadataResultMapItem itemWithKey:@"Copyright"            value:@[@"{Copyright}"]],
             [SBMetadataResultMapItem itemWithKey:@"contentID"            value:@[@"{contentID}"]],
             [SBMetadataResultMapItem itemWithKey:@"artistID"             value:@[@"{artistID}"]],
             [SBMetadataResultMapItem itemWithKey:@"playlistID"           value:@[@"{playlistID}"]],
             [SBMetadataResultMapItem itemWithKey:@"iTunes Country"       value:@[@"{iTunes Country}"]],
             ];

    return [[self alloc] initWithItems:items type:SBMetadataResultMapTypeTvShow];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _items = [[NSMutableArray alloc] init];
        _type = SBMetadataResultMapTypeMovie;
    }
    return self;
}

- (instancetype)initWithItems:(NSArray<SBMetadataResultMapItem *> *)items type:(SBMetadataResultMapType)type
{
    self = [super init];
    if (self) {
        _items = [items mutableCopy];
        _type = type;
    }
    return self;
}

#pragma mark - NSCoding

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [self init];
    if (self) {
        id temp;
        temp = [coder decodeObjectOfClass:[NSArray class] forKey:@"items"];
        if (temp) {
            _items = temp;
        }
        _type = [coder decodeIntegerForKey:@"type"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self.items forKey:@"items"];
    [coder encodeInteger:self.type forKey:@"type"];
}

@end

@implementation NSUserDefaults (SublerMetadataResultMapAdditions)

- (nullable SBMetadataResultMap *)SB_resultMapForKey:(NSString *)defaultName
{
    NSData *encodedObject = [self objectForKey:defaultName];
    if (encodedObject) {
        @try {
            SBMetadataResultMap *decodedMap = [NSKeyedUnarchiver unarchiveObjectWithData:encodedObject];
            if ([decodedMap isKindOfClass:[SBMetadataResultMap class]]) {
                return decodedMap;
            }
        }
        @catch (NSException *exception) {}
        @finally {}
    }
    return nil;
}

- (void)SB_setResultMap:(nullable SBMetadataResultMap *)value forKey:(NSString *)defaultName
{
    NSData *encodedObject = [NSKeyedArchiver archivedDataWithRootObject:value];
    [self setObject:encodedObject forKey:defaultName];
}

@end
