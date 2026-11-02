#import "SLMediaBridge.h"
#import <arpa/inet.h>
#import <math.h>
static const NSUInteger SLResourceLimit=6*1024*1024;
@interface SLMediaBridge ()
@property(nonatomic,strong) NSMutableArray<NSMutableDictionary *> *pending;
@property(nonatomic,strong) NSMutableDictionary *active;
@property(nonatomic,strong) NSTimer *timer;
@property(nonatomic,strong) NSData *body;
@property(nonatomic,strong) NSDictionary *metadata;
@property(nonatomic) NSUInteger offset,generation;
@property(nonatomic) BOOL closed,headerSent;
@property(nonatomic) uint64_t bytesForwarded;
@property(nonatomic,strong) dispatch_queue_t worker;
@end
@implementation SLMediaBridge
- (instancetype)init {if((self=[super init])){_pending=[NSMutableArray array];_worker=dispatch_queue_create("ScreenLink.rtc.media",DISPATCH_QUEUE_SERIAL);}return self;}
- (BOOL)json:(NSDictionary *)object {NSData *data=[NSJSONSerialization dataWithJSONObject:object options:0 error:nil];return data&&self.send&&self.send(data,NO);}
- (void)open {if(self.closed)return;[self json:@{@"type":@"hello",@"protocol":@"screenlink-media-v1",@"maxResourceBytes":@(SLResourceLimit)}];if(!self.timer){__weak SLMediaBridge *weak=self;self.timer=[NSTimer timerWithTimeInterval:.01 repeats:YES block:^(NSTimer *timer){[weak pump];}];[NSRunLoop.mainRunLoop addTimer:self.timer forMode:NSRunLoopCommonModes];}}
- (void)error:(NSNumber *)identifier code:(NSInteger)code {[self json:@{@"type":@"response",@"id":identifier,@"status":@(code),@"length":@0,@"mime":@"text/plain"}];}
- (void)receive:(NSData *)data {
    if(self.closed||data.length>8192)return;id object=[NSJSONSerialization JSONObjectWithData:data options:0 error:nil];if(![object isKindOfClass:NSDictionary.class])return;
    id identifier=object[@"id"];double number=[identifier isKindOfClass:NSNumber.class]?[identifier doubleValue]:0;if(number<1||number>1000000000||floor(number)!=number)return;
    if([object[@"type"] isEqual:@"cancel"]){if([self.active[@"id"] isEqual:identifier]){self.active[@"cancelled"]=@YES;if(self.metadata)[self finish];}NSIndexSet *indices=[self.pending indexesOfObjectsPassingTest:^BOOL(NSDictionary *item,NSUInteger idx,BOOL *stop){return [item[@"id"] isEqual:identifier];}];[self.pending removeObjectsAtIndexes:indices];return;}
    if(![object[@"type"] isEqual:@"request"])return;
    NSString *path=[object[@"path"] isKindOfClass:NSString.class]?object[@"path"]:@"";
    BOOL resource=[path hasPrefix:@"/media/resource/"]&&[[NSUUID alloc]initWithUUIDString:[path substringFromIndex:16]]!=nil;
    if(!resource&&![@[@"/media/state",@"/media/report"] containsObject:path]){[self error:identifier code:403];return;}
    if([self.active[@"id"] isEqual:identifier]||[[self.pending valueForKey:@"id"] containsObject:identifier]){[self error:identifier code:409];return;}
    if(self.pending.count>=8){[self error:identifier code:429];return;}
    if(object[@"range"]&&(![object[@"range"] isKindOfClass:NSString.class]||[object[@"range"] length]>120||[object[@"range"] rangeOfString:@"\\Abytes=[0-9]+-[0-9]*\\z" options:NSRegularExpressionSearch].location==NSNotFound)){[self error:identifier code:400];return;}
    if([path isEqual:@"/media/report"]&&![object[@"body"] isKindOfClass:NSDictionary.class]){[self error:identifier code:400];return;}
    if([path isEqual:@"/media/report"]){NSDictionary *report=object[@"body"];BOOL valid=[report[@"epoch"] isKindOfClass:NSString.class]&&[report[@"epoch"] length]<=128;
        for(NSString *key in @[@"position",@"duration",@"command"])if(report[key])valid=valid&&[report[key] isKindOfClass:NSNumber.class]&&isfinite([report[key] doubleValue])&&[report[key] doubleValue]>=0&&[report[key] doubleValue]<=1000000000;
        for(NSString *key in @[@"paused",@"ready",@"ended"])if(report[key])valid=valid&&[report[key] isKindOfClass:NSNumber.class]&&CFGetTypeID((__bridge CFTypeRef)report[key])==CFBooleanGetTypeID();
        if(report[@"error"])valid=valid&&[report[@"error"] isKindOfClass:NSString.class]&&[report[@"error"] length]<=240;
        if(!valid){[self error:identifier code:400];return;}
    }
    [self.pending addObject:[object mutableCopy]];[self next];
}
- (void)next {
    if(self.closed||self.active||!self.pending.count)return;
    self.active=self.pending.firstObject;[self.pending removeObjectAtIndex:0];NSMutableDictionary *request=self.active;NSUInteger generation=self.generation;NSString *path=request[@"path"];
    if([path isEqual:@"/media/state"]){NSMutableDictionary *state=[(self.stateProvider?self.stateProvider():@{}) mutableCopy];if([state[@"url"] isKindOfClass:NSString.class])state[@"url"]=[NSURLComponents componentsWithString:state[@"url"]].path?:@"";[self response:@{@"code":@200,@"mime":@"application/json",@"data":[NSJSONSerialization dataWithJSONObject:state options:0 error:nil]} request:request generation:generation];}
    else if([path isEqual:@"/media/report"]){if(self.reportConsumer)self.reportConsumer(request[@"body"]);[self response:@{@"code":@200,@"mime":@"application/json",@"data":[@"{}" dataUsingEncoding:NSUTF8StringEncoding]} request:request generation:generation];}
    else {NSDictionary *(^provider)(NSString *,NSString *)=self.resourceProvider;dispatch_async(self.worker,^{@autoreleasepool{NSDictionary *part=provider?provider([path substringFromIndex:16],request[@"range"]):@{@"code":@503};dispatch_async(dispatch_get_main_queue(),^{[self response:part request:request generation:generation];});}});}
}
- (void)response:(NSDictionary *)part request:(NSMutableDictionary *)request generation:(NSUInteger)generation {
    if(self.closed||generation!=self.generation||request!=self.active)return;if([request[@"cancelled"] boolValue]){[self finish];return;}
    NSData *data=[part[@"data"] isKindOfClass:NSData.class]?part[@"data"]:NSData.data;NSInteger code=[part[@"code"] integerValue];if(data.length>SLResourceLimit){code=413;data=NSData.data;}
    if([part[@"mime"] containsString:@"mpegurl"]){NSString *text=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];if(text){NSRegularExpression *regex=[NSRegularExpression regularExpressionWithPattern:@"(/media/resource/[A-Fa-f0-9-]+)\\?token=[^\\\"'\\s,]+" options:0 error:nil];text=[regex stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0,text.length) withTemplate:@"$1"];data=[text dataUsingEncoding:NSUTF8StringEncoding];}}
    self.body=data;self.offset=0;self.headerSent=NO;self.metadata=@{@"type":@"response",@"id":request[@"id"],@"status":@(code?:502),@"length":@(data.length),@"mime":[part[@"mime"] isKindOfClass:NSString.class]?part[@"mime"]:@"application/octet-stream",@"range":[part[@"range"] isKindOfClass:NSString.class]?part[@"range"]:@""};request[@"deadline"]=@(NSProcessInfo.processInfo.systemUptime+25);[self pump];
}
- (void)pump {
    if(self.closed||!self.metadata)return;if(NSProcessInfo.processInfo.systemUptime>[self.active[@"deadline"] doubleValue]){[self finish];return;}
    if(!self.headerSent){if(![self json:self.metadata])return;self.headerSent=YES;}
    for(int i=0;i<8&&self.offset<self.body.length;i++){
        if(self.bufferedAmount&&self.bufferedAmount()>131072)return;
        NSUInteger count=MIN(16376,self.body.length-self.offset);uint32_t header[2]={htonl([self.active[@"id"] unsignedIntValue]),htonl((uint32_t)self.offset)};
        NSMutableData *chunk=[NSMutableData dataWithBytes:header length:8];[chunk appendBytes:(const uint8_t *)self.body.bytes+self.offset length:count];
        if(!self.send||!self.send(chunk,YES))return;self.offset+=count;self.bytesForwarded+=count;
    }
    if(self.offset==self.body.length)[self finish];
}
- (void)finish {self.body=nil;self.metadata=nil;self.active=nil;self.offset=0;[self next];}
- (void)stop {self.closed=YES;self.generation++;[self.timer invalidate];self.timer=nil;[self.pending removeAllObjects];self.active=nil;self.body=nil;self.metadata=nil;self.send=nil;self.bufferedAmount=nil;self.resourceProvider=nil;self.stateProvider=nil;self.reportConsumer=nil;}
@end
