#import "BoundedDownload.h"
@interface SLResourceDownload : NSObject <NSURLSessionDataDelegate>
@property(nonatomic,strong) NSMutableData *bytes;
@property(nonatomic,strong) NSHTTPURLResponse *response;
@property(nonatomic,strong) NSError *error;
@property(nonatomic) NSUInteger limit;
@property(nonatomic) BOOL oversized;
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
    self.error=error;dispatch_semaphore_signal(self.done);[session finishTasksAndInvalidate];
}
@end
// Build 118: a download that gets no data for 5 seconds is dropped and tried again on a new connection
// (up to 3 tries, while fewer than 14 seconds have passed), instead of blocking the car for 21 seconds.
// The answer also says how long it took ("ms"), how many tries ("tries") and why it failed ("why").
static NSDictionary *SLBoundedDownloadOnce(NSURLRequest *request,NSUInteger maxBytes,BOOL *retry){
    SLResourceDownload *delegate=[SLResourceDownload new];delegate.limit=maxBytes;delegate.bytes=[NSMutableData data];delegate.done=dispatch_semaphore_create(0);
    NSURLSessionConfiguration *config=NSURLSessionConfiguration.ephemeralSessionConfiguration;config.URLCache=nil;config.requestCachePolicy=NSURLRequestReloadIgnoringLocalCacheData;config.timeoutIntervalForRequest=5;config.timeoutIntervalForResource=20;
    NSOperationQueue *queue=[NSOperationQueue new];queue.maxConcurrentOperationCount=1;
    NSURLSession *session=[NSURLSession sessionWithConfiguration:config delegate:delegate delegateQueue:queue];NSURLSessionDataTask *task=[session dataTaskWithRequest:request];[task resume];
    if(dispatch_semaphore_wait(delegate.done,dispatch_time(DISPATCH_TIME_NOW,21*NSEC_PER_SEC))){[task cancel];[session invalidateAndCancel];return @{@"code":@504,@"why":@"no end after 21 s"};}
    if(delegate.oversized)return @{@"code":@413,@"why":@"too large"};
    if(delegate.error||!delegate.response){*retry=YES;return @{@"code":@502,@"why":delegate.error.code==NSURLErrorTimedOut?@"no data for 5 s":(delegate.error.localizedDescription?:@"no answer")};}
    NSMutableDictionary *result=[@{@"code":@(delegate.response.statusCode),@"data":delegate.bytes} mutableCopy];if(delegate.response.MIMEType)result[@"mime"]=delegate.response.MIMEType;NSString *range=[delegate.response valueForHTTPHeaderField:@"Content-Range"];if(range)result[@"range"]=range;return result;
}
NSDictionary *SLBoundedDownload(NSURLRequest *request,NSUInteger maxBytes){
    CFAbsoluteTime start=CFAbsoluteTimeGetCurrent();NSDictionary *result=nil;NSUInteger tries=0;
    while(tries<3){BOOL retry=NO;tries++;result=SLBoundedDownloadOnce(request,maxBytes,&retry);if(!retry||CFAbsoluteTimeGetCurrent()-start>14)break;}
    NSMutableDictionary *answer=[result mutableCopy];answer[@"ms"]=@((NSInteger)((CFAbsoluteTimeGetCurrent()-start)*1000));answer[@"tries"]=@(tries);return answer;
}
