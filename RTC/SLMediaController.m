#import "SLMediaController.h"
#import <ReplayKit/ReplayKit.h>
@interface SLMediaController ()
@property(nonatomic,strong) UILabel *state;
@property(nonatomic,strong) UITextView *details;
@property(nonatomic,strong) UIButton *start,*approve,*reject;
@property(nonatomic,strong) NSTimer *timer;
@property(nonatomic,strong) NSDictionary *last;
@property(nonatomic) BOOL busy,disconnectRequested;
@property(nonatomic) NSUInteger generation;
@property(nonatomic,strong) NSURLSession *controlSession;
@end
@implementation SLMediaController
- (UIButton *)button:(NSString *)title action:(SEL)action {UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];[button setTitle:title forState:UIControlStateNormal];[button.heightAnchor constraintEqualToConstant:40].active=YES;[button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];return button;}
- (void)viewDidLoad {
    [super viewDidLoad];self.controlSession=[NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.ephemeralSessionConfiguration];self.view.backgroundColor=UIColor.systemBackgroundColor;UIStackView *stack=[UIStackView new];stack.axis=UILayoutConstraintAxisVertical;stack.spacing=10;stack.translatesAutoresizingMaskIntoConstraints=NO;[self.view addSubview:stack];[NSLayoutConstraint activateConstraints:@[[stack.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:12],[stack.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-12],[stack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:18],[stack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-18]]];
    UILabel *title=[UILabel new];title.text=self.youtubeOnly?@"YouTube only → website":@"Maps + YouTube → website";title.font=[UIFont boldSystemFontOfSize:21];title.numberOfLines=0;[stack addArrangedSubview:title];
    UILabel *help=[UILabel new];help.numberOfLines=0;help.font=[UIFont systemFontOfSize:14];help.text=self.youtubeOnly?@"Connect built-in VPN and Personal Hotspot. Tap the round system button and Start Broadcast. On your Mac or parked Tesla, open https://car.tesla4khmer.com/video, press Connect phone, and approve the local viewer on this phone. Open YouTube → AirPlay → ScreenLink VPN Phone, then press Play with sound on the website. YouTube fills the viewer; no Maps pane or screen stream is requested in this mode. Keep the VPN and system broadcast active. You can switch back to Maps + YouTube in the website View menu.":@"Connect built-in VPN and Personal Hotspot first. Allow Local Network access when asked before leaving this app. 1. Tap the round button below and Start Broadcast. 2. Start the website session, press Connect phone at https://car.tesla4khmer.com/ and approve here. No number to enter. 3. Open YouTube → AirPlay → ScreenLink VPN Phone. Press Play with sound on the website. Phone-screen capture starts hidden. Open Google Maps, then press Show screen in the website Maps pane. Before switching apps, press Hide screen and wait for confirmation. YouTube uses a separate media channel.";[stack addArrangedSubview:help];[stack addArrangedSubview:[self button:@"Copy viewer link" action:@selector(copyViewerLink)]];
    RPSystemBroadcastPickerView *picker=[[RPSystemBroadcastPickerView alloc]initWithFrame:CGRectMake(0,0,60,60)];picker.preferredExtension=self.broadcastExtensionIdentifier;picker.showsMicrophoneButton=NO;[picker.heightAnchor constraintEqualToConstant:60].active=YES;[stack addArrangedSubview:picker];
    self.state=[UILabel new];self.state.numberOfLines=0;self.state.text=@"Start the system broadcast first.";[stack addArrangedSubview:self.state];
    self.start=[self button:@"Start website session" action:@selector(startPair)];[stack addArrangedSubview:self.start];UIStackView *approval=[UIStackView new];approval.distribution=UIStackViewDistributionFillEqually;self.approve=[self button:@"Approve viewer" action:@selector(approvePair)];self.reject=[self button:@"Reject" action:@selector(rejectPair)];[approval addArrangedSubview:self.approve];[approval addArrangedSubview:self.reject];[stack addArrangedSubview:approval];
    UIStackView *actions=[UIStackView new];actions.distribution=UIStackViewDistributionFillEqually;[actions addArrangedSubview:[self button:@"Stop website" action:@selector(stopPair)]];[actions addArrangedSubview:[self button:@"Copy diagnostics" action:@selector(copyReport)]];[actions addArrangedSubview:[self button:@"Done" action:@selector(done)]];[stack addArrangedSubview:actions];
    self.details=[UITextView new];self.details.editable=NO;self.details.font=[UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];[stack addArrangedSubview:self.details];__weak SLMediaController *weak=self;self.timer=[NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer *timer){[weak query:@"status"];}];[self query:@"status"];
}
- (void)query:(NSString *)command {
    if(self.busy||self.disconnectRequested)return;NSUInteger generation=self.generation;self.busy=YES;NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:[@"http://127.0.0.1:8080/local/rtc/" stringByAppendingString:command]]];request.HTTPMethod=[command isEqual:@"status"]?@"GET":@"POST";[request setValue:@"app" forHTTPHeaderField:@"X-ScreenLink-Control"];request.timeoutInterval=3;request.cachePolicy=NSURLRequestReloadIgnoringLocalCacheData;
    [[self.controlSession dataTaskWithRequest:request completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){dispatch_async(dispatch_get_main_queue(),^{if(generation!=self.generation||self.disconnectRequested)return;self.busy=NO;id result=data?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil;BOOL valid=!error&&[(NSHTTPURLResponse *)response statusCode]==200&&[result isKindOfClass:NSDictionary.class];self.start.enabled=valid;self.approve.enabled=valid&&[result[@"approvalRequested"] boolValue];self.reject.enabled=self.approve.enabled;
        if(!valid){self.state.text=@"Waiting for ScreenLink Screen broadcast. Tap the round system button and Start Broadcast.";return;}
        self.last=result;NSString *phase=result[@"phase"]?:@"idle";
        if([phase isEqual:@"connected"])self.state.text=[NSString stringWithFormat:@"WEBSITE CONNECTED · %@ · %.1f MB forwarded",[result[@"mediaActive"] boolValue]?@"YouTube media active":@"open YouTube and select ScreenLink AirPlay",[result[@"bytesForwarded"] doubleValue]/1048576];else self.state.text=[NSString stringWithFormat:@"%@%@",phase,[result[@"error"] length]?[@" · " stringByAppendingString:result[@"error"]]:@""];
        self.start.enabled=[@[@"idle",@"failed"] containsObject:phase]||(![result[@"mediaChannelOpen"] boolValue]&&[result[@"error"] length]>0);
        self.details.text=[([result[@"events"] isKindOfClass:NSArray.class]?result[@"events"]:@[]) componentsJoinedByString:@"\n"];
    });}] resume];
}
- (void)stopForDisconnectAll {
 self.disconnectRequested=YES;self.generation++;self.busy=NO;[self.timer invalidate];self.timer=nil;[self.controlSession invalidateAndCancel];self.controlSession=nil;
 NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://127.0.0.1:8080/local/rtc/stop"]];request.HTTPMethod=@"POST";request.timeoutInterval=2;[request setValue:@"app" forHTTPHeaderField:@"X-ScreenLink-Control"];
 NSURLSession *stopSession=[NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.ephemeralSessionConfiguration];
 [[stopSession dataTaskWithRequest:request completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){[stopSession finishTasksAndInvalidate];}] resume];
}
- (void)dealloc {[self.controlSession invalidateAndCancel];}
- (void)copyViewerLink {UIPasteboard.generalPasteboard.string=self.youtubeOnly?@"https://car.tesla4khmer.com/video":@"https://car.tesla4khmer.com/split";}
- (void)startPair {[self query:@"start"];}
- (void)approvePair {[self query:@"approve"];}
- (void)rejectPair {[self query:@"reject"];}
- (void)stopPair {[self query:@"stop"];}
- (void)copyReport {NSMutableDictionary *safe=[self.last mutableCopy]?:[NSMutableDictionary dictionary];[safe removeObjectForKey:@"pairingCode"];safe[@"version"]=@"0.19.0";safe[@"mode"]=@"youtube-media-over-webrtc";NSData *data=[NSJSONSerialization dataWithJSONObject:safe options:NSJSONWritingPrettyPrinted error:nil];UIPasteboard.generalPasteboard.string=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];}
- (void)done {[self.timer invalidate];self.timer=nil;[self dismissViewControllerAnimated:YES completion:nil];}
- (void)viewDidDisappear:(BOOL)animated {[super viewDidDisappear:animated];if(self.isBeingDismissed){[self.timer invalidate];self.timer=nil;}}
@end
