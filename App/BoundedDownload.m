#import "BoundedDownload.h"
@interface SLResourceDownload : NSObject <NSURLSessionDataDelegate>
@property(nonatomic,strong) NSMutableData *bytes;
@property(nonatomic,strong) NSHTTPURLResponse *response;
@property(nonatomic,strong) NSError *error;
@property(nonatomic) NSUInteger limit;
@property(nonatomic) BOOL oversized;
@property(nonatomic) BOOL shared;
@property(nonatomic,strong) dispatch_semaphore_t done;
@end
@implementation SLResourceDownload
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    self.response=[response isKindOfClass:NSHTTPURLResponse.class]?(NSHTTPURLResponse *)response:nil;
    if(response.expectedContentLength>0 && (uint64_t)response.expectedContentLength>self.limit){self.oversized=YES;completionHandler(NSURLSessionResponseCancel);}else completionHandler(NSURLSessionResponseAllow);
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveData:(NSData *)data {
    if(self.oversized)return;
    if(data.length>self.limit-self.bytes.length){self.oversized=YES;[self.bytes setLength:0];[task cancel];return;}[self.bytes appendData:data];
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    self.error=error;dispatch_semaphore_signal(self.done);if(!self.shared)[session finishTasksAndInvalidate];
}
@end
// Build 146: one long-lived session for first tries, so YouTube connections (name lookup, secure handshake)
// stay open and warm between pieces and between videos. Retries still use a brand-new connection.
@interface SLDownloadRouter : NSObject <NSURLSessionDataDelegate>
@property(nonatomic,strong) NSMutableDictionary<NSNumber *,SLResourceDownload *> *tasks;
@end
@implementation SLDownloadRouter
- (SLResourceDownload *)owner:(NSURLSessionTask *)task {@synchronized(self){return self.tasks[@(task.taskIdentifier)];}}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    SLResourceDownload *owner=[self owner:task];if(!owner){completionHandler(NSURLSessionResponseAllow);return;}[owner URLSession:session dataTask:task didReceiveResponse:response completionHandler:completionHandler];
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveData:(NSData *)data {[[self owner:task] URLSession:session dataTask:task didReceiveData:data];}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    SLResourceDownload *owner=[self owner:task];@synchronized(self){[self.tasks removeObjectForKey:@(task.taskIdentifier)];}[owner URLSession:session task:task didCompleteWithError:error];
}
@end
static NSURLSessionConfiguration *SLDownloadConfig(void){NSURLSessionConfiguration *config=NSURLSessionConfiguration.ephemeralSessionConfiguration;config.URLCache=nil;config.requestCachePolicy=NSURLRequestReloadIgnoringLocalCacheData;config.timeoutIntervalForRequest=5;config.timeoutIntervalForResource=20;return config;}
static SLDownloadRouter *SLRouter;static NSURLSession *SLSharedSession;
static NSURLSession *SLShared(void){static dispatch_once_t once;dispatch_once(&once,^{SLRouter=[SLDownloadRouter new];SLRouter.tasks=[NSMutableDictionary dictionary];
    NSURLSessionConfiguration *config=SLDownloadConfig();config.HTTPMaximumConnectionsPerHost=6;NSOperationQueue *queue=[NSOperationQueue new];queue.maxConcurrentOperationCount=1;/* serial: pieces of one answer must stay in order */
    SLSharedSession=[NSURLSession sessionWithConfiguration:config delegate:SLRouter delegateQueue:queue];});return SLSharedSession;}
void SLWarmDownloads(NSArray<NSURL *> *urls){
    NSURLSession *session=SLShared();
    for(NSURL *url in urls){NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:url];request.HTTPMethod=@"GET";[request setValue:@"AppleCoreMedia/1.0 ScreenLink" forHTTPHeaderField:@"User-Agent"];
        [[session dataTaskWithRequest:request completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){}] resume];}
}
// Build 118: a download that gets no data for 5 seconds is dropped and tried again on a new connection
// (up to 3 tries, while fewer than 14 seconds have passed), instead of blocking the car for 21 seconds.
// The answer also says how long it took ("ms"), how many tries ("tries") and why it failed ("why").
static NSDictionary *SLBoundedDownloadOnce(NSURLRequest *request,NSUInteger maxBytes,BOOL *retry,BOOL warm){
    SLResourceDownload *delegate=[SLResourceDownload new];delegate.limit=maxBytes;delegate.bytes=[NSMutableData data];delegate.done=dispatch_semaphore_create(0);delegate.shared=warm;
    NSURLSession *session;NSURLSessionDataTask *task;
    if(warm){session=SLShared();task=[session dataTaskWithRequest:request];@synchronized(SLRouter){SLRouter.tasks[@(task.taskIdentifier)]=delegate;}}
    else{NSOperationQueue *queue=[NSOperationQueue new];queue.maxConcurrentOperationCount=1;session=[NSURLSession sessionWithConfiguration:SLDownloadConfig() delegate:delegate delegateQueue:queue];task=[session dataTaskWithRequest:request];}
    [task resume];
    if(dispatch_semaphore_wait(delegate.done,dispatch_time(DISPATCH_TIME_NOW,21*NSEC_PER_SEC))){[task cancel];if(warm){@synchronized(SLRouter){[SLRouter.tasks removeObjectForKey:@(task.taskIdentifier)];}}else [session invalidateAndCancel];return @{@"code":@504,@"why":@"no end after 21 s"};}
    if(delegate.oversized)return @{@"code":@413,@"why":@"too large"};
    if(delegate.error||!delegate.response){*retry=YES;return @{@"code":@502,@"why":delegate.error.code==NSURLErrorTimedOut?@"no data for 5 s":(delegate.error.localizedDescription?:@"no answer")};}
    NSMutableDictionary *result=[@{@"code":@(delegate.response.statusCode),@"data":delegate.bytes} mutableCopy];if(delegate.response.MIMEType)result[@"mime"]=delegate.response.MIMEType;NSString *range=[delegate.response valueForHTTPHeaderField:@"Content-Range"];if(range)result[@"range"]=range;return result;
}
NSDictionary *SLBoundedDownload(NSURLRequest *request,NSUInteger maxBytes){
    CFAbsoluteTime start=CFAbsoluteTimeGetCurrent();NSDictionary *result=nil;NSUInteger tries=0;
    while(tries<3){BOOL retry=NO;tries++;result=SLBoundedDownloadOnce(request,maxBytes,&retry,tries==1);if(!retry||CFAbsoluteTimeGetCurrent()-start>14)break;}
    NSMutableDictionary *answer=[result mutableCopy];answer[@"ms"]=@((NSInteger)((CFAbsoluteTimeGetCurrent()-start)*1000));answer[@"tries"]=@(tries);return answer;
}
