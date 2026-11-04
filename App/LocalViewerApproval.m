#import "LocalViewerApproval.h"
@interface LocalViewerApproval ()
@property(nonatomic,copy) NSString *nonce,*peer,*requestID,*token,*phase;
@property(nonatomic) NSTimeInterval deadline,automaticUntil;
@end
@implementation LocalViewerApproval
- (void)reset { @synchronized(self){self.nonce=nil;self.peer=nil;self.requestID=nil;self.token=nil;self.phase=nil;self.deadline=0;self.automaticUntil=0;} }
- (void)armAutomaticAt:(NSTimeInterval)now { @synchronized(self){[self reset];self.automaticUntil=now+300;} }
- (void)expireAt:(NSTimeInterval)now {if(self.deadline && now>=self.deadline)[self reset];}
- (NSDictionary *)statusAt:(NSTimeInterval)now { @synchronized(self){[self expireAt:now];return @{ @"phase":self.phase?:@"idle",@"requestID":self.requestID?:@"",@"peer":self.peer?:@"",@"automatic":@(self.automaticUntil>now) };} }
- (NSDictionary *)request:(NSString *)nonce peer:(NSString *)peer now:(NSTimeInterval)now {return [self request:nonce peer:peer previousToken:nil now:now];}
- (NSDictionary *)request:(NSString *)nonce peer:(NSString *)peer previousToken:(NSString *)previousToken now:(NSTimeInterval)now { @synchronized(self){
    [self expireAt:now];
    if(![nonce isKindOfClass:NSString.class] || nonce.length!=32 || [nonce rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"] invertedSet]].location!=NSNotFound || !peer.length)return @{@"phase":@"invalid"};
    // A changed hotspot peer must prove possession of the existing session.
    if([self.phase isEqual:@"approved"] && [self.nonce isEqual:nonce] && ![self.peer isEqual:peer] && [previousToken isKindOfClass:NSString.class] && previousToken.length && [previousToken isEqual:self.token]){self.peer=peer;self.token=NSUUID.UUID.UUIDString;self.deadline=now+14400;}
    if(self.nonce && (![self.nonce isEqual:nonce] || ![self.peer isEqual:peer]))return @{@"phase":@"busy"};
    if(!self.nonce){self.nonce=nonce;self.peer=peer;self.requestID=NSUUID.UUID.UUIDString;self.phase=@"pending";self.deadline=now+120;if(self.automaticUntil>now){self.phase=@"approved";self.token=NSUUID.UUID.UUIDString;self.deadline=now+14400;self.automaticUntil=0;}}
    if([self.phase isEqual:@"approved"])return @{@"phase":@"approved",@"token":self.token};
    return @{@"phase":self.phase};
} }
- (BOOL)decide:(BOOL)approve requestID:(NSString *)requestID now:(NSTimeInterval)now { @synchronized(self){
    [self expireAt:now];if(![self.phase isEqual:@"pending"] || ![self.requestID isEqual:requestID])return NO;
    self.phase=approve?@"approved":@"rejected";self.token=approve?NSUUID.UUID.UUIDString:nil;self.deadline=now+(approve?14400:120);return YES;
} }
- (BOOL)allowsToken:(NSString *)token peer:(NSString *)peer now:(NSTimeInterval)now { @synchronized(self){
    [self expireAt:now];return [self.phase isEqual:@"approved"] && token.length && [token isEqual:self.token] && [peer isEqual:self.peer];
} }
@end
