//
//  Woodoo.m
//  Appwoodoo
//
//  Created by Tamas Dancsi on 17/03/15.
//  Copyright (c) 2015 Appwoodoo. All rights reserved.
//

#import "Woodoo.h"
#import "WoodooSettingsHandler.h"
#import "WoodooLogHandler.h"

#define API_ENDPOINT @"http://www.appwoodoo.com/api/v1"

@interface Woodoo () {
    NSString *APPKey;
    NSMutableData *data;
    BOOL needCompletion;
    id target;
    SEL selector;
    NSString *requestType;
}

@end

@implementation Woodoo

+ (void)takeOff:(NSString *)APPKey {
    Woodoo *woodoo = [[Woodoo alloc] initWithKey:APPKey target:nil selector:nil];
    [woodoo downloadSettings];
}

+ (void)takeOff:(NSString *)APPKey target:(id)target selector:(SEL)selector {
    Woodoo *woodoo = [[Woodoo alloc] initWithKey:APPKey target:target selector:selector];
    [woodoo downloadSettings];
}

+ (void)registerDeviceToken:(NSString *)token forAPPKey:(NSString *)woodooKey {
    if (!token || [token isEqualToString:@""] ||
        !woodooKey || [woodooKey isEqualToString:@""]) {
        return;
    }

    NSString *savedToken = [WoodooSettingsHandler getDeviceToken];
    if (savedToken && [savedToken isEqualToString:token]) {
        [WoodooLogHandler log:@"Appwoodoo: device token already exists, won't send."];
        return;
    }

    Woodoo *woodoo = [[Woodoo alloc] init];
    [woodoo sendDeviceToken:token forAPPKey:woodooKey];
}

+ (void)setHideLogs:(BOOL)hide {
    [WoodooSettingsHandler setHideLogs:hide];
}

- (id)initWithKey:(NSString *)woodooKey target:(id)woodooTarget selector:(SEL)woodooSelector {
    self = [super init];
    if (self) {
        needCompletion = NO;
        if (woodooTarget && woodooSelector) {
            needCompletion = YES;
        }
        
        APPKey = woodooKey;
        target = woodooTarget;
        selector = woodooSelector;
        
        [WoodooSettingsHandler removeConfig];
    }
    return self;
}

- (void)downloadSettings {
    requestType = @"settings";

    NSString *urlString = [NSString stringWithFormat:@"%@/settings/%@.plist", API_ENDPOINT, APPKey];
    NSURL *url = [NSURL URLWithString:urlString];
    NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:60.0];
    [NSURLConnection connectionWithRequest:request delegate:self];
}

- (void)downloadSettingsResultHandler:(NSDictionary *)result {
    NSError *error;
    NSPropertyListFormat format;
    result = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:&format error:&error];
    if (error) {
        [WoodooLogHandler log:[NSString stringWithFormat:@"Appwoodoo: parsing settings error: %@", [error localizedDescription]]];
    }
    
    [WoodooSettingsHandler saveConfig:result];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"WoodooArrived" object:nil];
    
    if (needCompletion) {
#       pragma clang diagnostic push
#       pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [target performSelector:selector];
#       pragma clang diagnostic pop
    }
}

- (void)sendDeviceToken:(NSString *)token forAPPKey:(NSString *)woodooKey {
    requestType = @"token";
    [WoodooSettingsHandler saveDeviceToken:token];

    NSString *urlString = [NSString stringWithFormat:@"%@/push/ios/register/", API_ENDPOINT];
    NSURL *url = [NSURL URLWithString:urlString];

    NSString *params = [NSString stringWithFormat:@"api_key=%@&dev_id=%@", woodooKey, token];
    NSData *requestData = [params dataUsingEncoding:NSUTF8StringEncoding];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:60.0];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Accept"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)[requestData length]] forHTTPHeaderField:@"Content-Length"];
    [request setHTTPBody:requestData];
    [NSURLConnection connectionWithRequest:request delegate:self];
}

- (void)sendDeviceTokenResultHandler:(NSDictionary *)result {
    NSError *error;
    result = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&error];
    if (error != nil) {
        [WoodooLogHandler log:[NSString stringWithFormat:@"Appwoodoo: sending device token error: %@", [error localizedDescription]]];
        [WoodooSettingsHandler removeDeviceToken];
    }
}

#pragma mark - NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    data = [[NSMutableData alloc] init];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)received {
    [data appendData:received];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    NSDictionary *result;

    // Device token sending result handler
    if ([requestType isEqualToString:@"token"]) {
        [WoodooLogHandler log:@"Appwoodoo: device token saved"];
        return [self sendDeviceTokenResultHandler:result];
    }

    // Downloading settings result handler
    if ([requestType isEqualToString:@"settings"]) {
        [WoodooLogHandler log:@"Appwoodoo: settings retrieved"];
        return [self downloadSettingsResultHandler:result];
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [WoodooLogHandler log:[NSString stringWithFormat:@"Appoodoo: download error: %@", [error localizedDescription]]];
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse {
    return nil;
}

+ (BOOL)isDownloaded {
    return [WoodooSettingsHandler isDownloaded];
}

+ (NSDictionary *)getSettings {
    return [WoodooSettingsHandler getSettings];
}

+ (BOOL)boolForKey:(NSString *)key {
    return [WoodooSettingsHandler boolForKey:key];
}

+ (NSString *)stringForKey:(NSString *)key {
    return [WoodooSettingsHandler stringForKey:key];
}

+ (NSInteger)integerForKey:(NSString *)key {
    return [WoodooSettingsHandler integerForKey:key];
}

+ (CGFloat)floatForKey:(NSString *)key {
    return [WoodooSettingsHandler floatForKey:key];
}

@end
