#import "SLSignaling.h"
@interface SLSignaling () <NSURLSessionTaskDelegate>
@property(nonatomic,strong) NSURLSession *session;
@end
@implementation SLSignaling
- (instancetype)initWithBaseURL:(NSURL *)baseURL {
    if((self=[super init])){_baseURL=baseURL;NSURLSessionConfiguration *config=NSURLSessionConfiguration.ephemeralSessionConfiguration;config.URLCache=nil;config.HTTPCookieStorage=nil;config.HTTPShouldSetCookies=NO;config.timeoutIntervalForRequest=8;config.timeoutIntervalForResource=10;config.requestCachePolicy=NSURLRequestReloadIgnoringLocalCacheData;_session=[NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];}return self;
}
+ (BOOL)matches:(id)value pattern:(NSString *)pattern {return [value isKindOfClass:NSString.class]&&[value rangeOfString:pattern options:NSRegularExpressionSearch].location!=NSNotFound;}
+ (BOOL)validSecret:(id)value {return [self matches:value pattern:@"\\A[0-9a-fA-F]{64}\\z"];}
+ (BOOL)validIdentifier:(id)value {return [self matches:value pattern:@"\\A[A-Za-z0-9-]{1,128}\\z"];}
+ (BOOL)validCode:(id)value {return [self matches:value pattern:@"\\A[0-9]{6}\\z"];}
- (void)call:(NSString *)method path:(NSString *)path authorization:(NSString *)authorization body:(NSDictionary *)body completion:(SLAPICompletion)completion {
    BOOL local=[@[@"127.0.0.1",@"localhost"] containsObject:self.baseURL.host];
    if((![self.baseURL.scheme isEqual:@"https"]&&!local)||![path hasPrefix:@"/"]||[path containsString:@".."]||[path containsString:@"?"]||[path containsString:@"#"]){completion(0,@{},[NSError errorWithDomain:@"ScreenLink.Signaling" code:1 userInfo:@{NSLocalizedDescriptionKey:@"Invalid signaling address."}]);return;}
    NSURL *url=[NSURL URLWithString:[self.baseURL.absoluteString stringByAppendingString:path]];NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:url];request.HTTPMethod=method;[request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    if(authorization.length)[request setValue:authorization forHTTPHeaderField:@"Authorization"];
    if(body){[request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];request.HTTPBody=[NSJSONSerialization dataWithJSONObject:body options:0 error:nil];}
    [[self.session dataTaskWithRequest:request completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){
        NSInteger code=[response isKindOfClass:NSHTTPURLResponse.class]?((NSHTTPURLResponse *)response).statusCode:0;NSDictionary *object=@{};NSError *failure=nil;
        if(data.length>512*1024)failure=[NSError errorWithDomain:@"ScreenLink.Signaling" code:2 userInfo:@{NSLocalizedDescriptionKey:@"Signaling response exceeded its limit."}];
        else if(data.length){id json=[NSJSONSerialization JSONObjectWithData:data options:0 error:nil];if([json isKindOfClass:NSDictionary.class])object=json;else failure=[NSError errorWithDomain:@"ScreenLink.Signaling" code:3 userInfo:@{NSLocalizedDescriptionKey:@"Signaling server returned a non-JSON response."}];}
        if(error)failure=[NSError errorWithDomain:@"ScreenLink.Signaling" code:error.code userInfo:@{NSLocalizedDescriptionKey:@"Signaling request failed. Check Internet connectivity."}];
        if(!failure && (code<200||code>=300)){NSString *message=[SLSignaling matches:object[@"error"] pattern:@"\\A[a-z_]{1,80}\\z"]?object[@"error"]:@"request_failed";failure=[NSError errorWithDomain:@"ScreenLink.Signaling" code:code userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Signaling HTTP %ld (%@).",(long)code,message]}];}
        dispatch_async(dispatch_get_main_queue(),^{completion(code,object,failure);});
    }] resume];
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest *))completionHandler {
    // A role secret must never follow a redirect to a different origin or path.
    completionHandler(nil);
}
- (void)close {[self.session invalidateAndCancel];self.session=nil;}
@end
