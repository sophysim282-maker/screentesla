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
NSDictionary *SLBoundedDownload(NSURLRequest *request,NSUInteger maxBytes){
    SLResourceDownload *delegate=[SLResourceDownload new];delegate.limit=maxBytes;delegate.bytes=[NSMutableData data];delegate.done=dispatch_semaphore_create(0);
    NSURLSessionConfiguration *config=NSURLSessionConfiguration.ephemeralSessionConfiguration;config.URLCache=nil;config.requestCachePolicy=NSURLRequestReloadIgnoringLocalCacheData;config.timeoutIntervalForRequest=12;config.timeoutIntervalForResource=20;
    NSOperationQueue *queue=[NSOperationQueue new];queue.maxConcurrentOperationCount=1;
    NSURLSession *session=[NSURLSession sessionWithConfiguration:config delegate:delegate delegateQueue:queue];NSURLSessionDataTask *task=[session dataTaskWithRequest:request];[task resume];
    if(dispatch_semaphore_wait(delegate.done,dispatch_time(DISPATCH_TIME_NOW,21*NSEC_PER_SEC))){[task cancel];[session invalidateAndCancel];return @{@"code":@504};}
    if(delegate.oversized)return @{@"code":@413};
    if(delegate.error||!delegate.response)return @{@"code":@502};
    NSMutableDictionary *result=[@{@"code":@(delegate.response.statusCode),@"data":delegate.bytes} mutableCopy];if(delegate.response.MIMEType)result[@"mime"]=delegate.response.MIMEType;NSString *range=[delegate.response valueForHTTPHeaderField:@"Content-Range"];if(range)result[@"range"]=range;return result;
}
