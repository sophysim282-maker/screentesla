#import "ScreenLinkHomeView.h"
#import <AVFoundation/AVFoundation.h>

@interface SLAmbientCarView : UIView
@property(nonatomic,strong) UIImageView *poster;
@property(nonatomic,strong) AVPlayerLayer *videoLayer;
@end
@implementation SLAmbientCarView
- (instancetype)initWithFrame:(CGRect)frame {if((self=[super initWithFrame:frame])){self.clipsToBounds=YES;self.layer.cornerRadius=28;self.backgroundColor=UIColor.blackColor;self.poster=[[UIImageView alloc]initWithImage:[UIImage imageNamed:@"CarPoster.jpg"]];self.poster.contentMode=UIViewContentModeScaleAspectFill;[self addSubview:self.poster];self.videoLayer=[AVPlayerLayer layer];self.videoLayer.videoGravity=AVLayerVideoGravityResizeAspectFill;[self.layer addSublayer:self.videoLayer];self.isAccessibilityElement=YES;self.accessibilityLabel=@"Silver sports car beneath a starry sky";}return self;}
- (void)layoutSubviews {[super layoutSubviews];self.poster.frame=self.bounds;self.videoLayer.frame=self.bounds;}
@end

@interface ScreenLinkHomeView ()
@property(nonatomic,strong,readwrite) UIView *previewHost;
@property(nonatomic,strong) UILabel *statusLabel,*detailLabel;
@property(nonatomic,strong) UIButton *startButton,*disconnectButton,*themeButton;
@property(nonatomic,strong) SLAmbientCarView *car;
@property(nonatomic,strong) AVQueuePlayer *ambientPlayer;
@property(nonatomic,strong) AVPlayerLooper *ambientLooper;
@property(nonatomic) BOOL idleAllowed;
@property(nonatomic,strong) UISegmentedControl *playerQuality,*playerEQ;
@property(nonatomic,strong) UISlider *playerVolume,*playerSeek;
@property(nonatomic,strong) UIButton *playerPause,*playerBack,*playerForward;
@property(nonatomic,strong) UILabel *playerPosition,*playerHint;
@property(nonatomic,copy) NSDictionary *playerState;
@end
@implementation ScreenLinkHomeView
- (UILabel *)label:(NSString *)text style:(UIFontTextStyle)style {
 UILabel *label=[UILabel new];label.text=text;label.font=[UIFont preferredFontForTextStyle:style];label.adjustsFontForContentSizeCategory=YES;label.numberOfLines=0;return label;
}
- (UIButton *)button:(NSString *)title symbol:(NSString *)symbol action:(SEL)action filled:(BOOL)filled {
 UIButtonConfiguration *config=filled?UIButtonConfiguration.filledButtonConfiguration:UIButtonConfiguration.tintedButtonConfiguration;
 config.title=title;config.image=[UIImage systemImageNamed:symbol];config.imagePadding=10;config.cornerStyle=UIButtonConfigurationCornerStyleCapsule;config.contentInsets=NSDirectionalEdgeInsetsMake(16,18,16,18);
 config.baseBackgroundColor=filled?[UIColor colorWithRed:.08 green:.52 blue:.47 alpha:1]:UIColor.secondarySystemFillColor;config.baseForegroundColor=filled?UIColor.whiteColor:UIColor.labelColor;
 UIButton *button=[UIButton buttonWithConfiguration:config primaryAction:nil];button.titleLabel.adjustsFontForContentSizeCategory=YES;[button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];return button;
}
- (instancetype)initWithFrame:(CGRect)frame {
 if((self=[super initWithFrame:frame])){
  NSInteger theme=[NSUserDefaults.standardUserDefaults integerForKey:@"ScreenLinkAppearance"];self.overrideUserInterfaceStyle=theme==1?UIUserInterfaceStyleLight:theme==2?UIUserInterfaceStyleDark:UIUserInterfaceStyleUnspecified;
  self.backgroundColor=UIColor.systemGroupedBackgroundColor;self.idleAllowed=YES;
  UIScrollView *scroll=[UIScrollView new];scroll.translatesAutoresizingMaskIntoConstraints=NO;scroll.alwaysBounceVertical=YES;scroll.accessibilityIdentifier=@"home.scroll";[self addSubview:scroll];
  UIStackView *stack=[UIStackView new];stack.axis=UILayoutConstraintAxisVertical;stack.spacing=16;stack.translatesAutoresizingMaskIntoConstraints=NO;[scroll addSubview:stack];
  NSLayoutConstraint *width=[stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-40];width.priority=999;
  [NSLayoutConstraint activateConstraints:@[[scroll.topAnchor constraintEqualToAnchor:self.topAnchor],[scroll.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],[scroll.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],[scroll.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],[scroll.contentLayoutGuide.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor],[stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:16],[stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-24],[stack.centerXAnchor constraintEqualToAnchor:scroll.centerXAnchor],width,[stack.widthAnchor constraintLessThanOrEqualToConstant:720],[stack.leadingAnchor constraintGreaterThanOrEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:20],[stack.trailingAnchor constraintLessThanOrEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-20]]];
  UIStackView *nav=[UIStackView new];nav.alignment=UIStackViewAlignmentCenter;nav.spacing=12;
  UIImageView *mark=[[UIImageView alloc]initWithImage:[UIImage systemImageNamed:@"airplayvideo"]];mark.tintColor=UIColor.labelColor;mark.contentMode=UIViewContentModeScaleAspectFit;[mark.widthAnchor constraintEqualToConstant:28].active=YES;[nav addArrangedSubview:mark];
  UILabel *name=[self label:@"ScreenLink" style:UIFontTextStyleTitle2];name.font=[UIFontMetrics.defaultMetrics scaledFontForFont:[UIFont systemFontOfSize:25 weight:UIFontWeightBold]];[nav addArrangedSubview:name];[nav addArrangedSubview:[UIView new]];
  self.themeButton=[self button:@"" symbol:@"circle.lefthalf.filled" action:@selector(themeTapped) filled:NO];self.themeButton.accessibilityLabel=@"Switch light or dark appearance";self.themeButton.accessibilityIdentifier=@"home.theme";[nav addArrangedSubview:self.themeButton];[stack addArrangedSubview:nav];
  self.car=[SLAmbientCarView new];[self.car.heightAnchor constraintEqualToAnchor:self.car.widthAnchor multiplier:.5625].active=YES;[stack addArrangedSubview:self.car];
  UIStackView *intro=[UIStackView new];intro.axis=UILayoutConstraintAxisVertical;intro.spacing=5;
  UILabel *headline=[self label:@"Ready when you are" style:UIFontTextStyleTitle1];headline.font=[UIFontMetrics.defaultMetrics scaledFontForFont:[UIFont systemFontOfSize:29 weight:UIFontWeightBold]];[intro addArrangedSubview:headline];
  UILabel *subtitle=[self label:@"Your video. A bigger view." style:UIFontTextStyleSubheadline];subtitle.textColor=UIColor.secondaryLabelColor;[intro addArrangedSubview:subtitle];[stack addArrangedSubview:intro];
  UIVisualEffectView *card=[[UIVisualEffectView alloc]initWithEffect:UIAccessibilityIsReduceTransparencyEnabled()?nil:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial]];card.backgroundColor=UIColor.secondarySystemGroupedBackgroundColor;card.layer.cornerRadius=24;card.clipsToBounds=YES;card.layer.borderWidth=.5;card.layer.borderColor=[UIColor.separatorColor colorWithAlphaComponent:.25].CGColor;
  UIStackView *status=[UIStackView new];status.axis=UILayoutConstraintAxisVertical;status.spacing=6;status.translatesAutoresizingMaskIntoConstraints=NO;[card.contentView addSubview:status];
  [NSLayoutConstraint activateConstraints:@[[status.topAnchor constraintEqualToAnchor:card.contentView.topAnchor constant:16],[status.bottomAnchor constraintEqualToAnchor:card.contentView.bottomAnchor constant:-16],[status.leadingAnchor constraintEqualToAnchor:card.contentView.leadingAnchor constant:18],[status.trailingAnchor constraintEqualToAnchor:card.contentView.trailingAnchor constant:-18]]];
  self.statusLabel=[self label:@"Ready to connect" style:UIFontTextStyleHeadline];self.statusLabel.accessibilityIdentifier=@"home.status";[status addArrangedSubview:self.statusLabel];
  self.detailLabel=[self label:@"Turn on Personal Hotspot, then tap Start." style:UIFontTextStyleSubheadline];self.detailLabel.textColor=UIColor.secondaryLabelColor;self.detailLabel.accessibilityIdentifier=@"home.detail";[status addArrangedSubview:self.detailLabel];[stack addArrangedSubview:card];
  self.startButton=[self button:@"Start YouTube + PiP" symbol:@"play.fill" action:@selector(startTapped) filled:YES];self.startButton.accessibilityIdentifier=@"home.start";[stack addArrangedSubview:self.startButton];
  UILabel *recording=[self label:@"No screen recording" style:UIFontTextStyleFootnote];recording.textAlignment=NSTextAlignmentCenter;recording.textColor=UIColor.secondaryLabelColor;[stack addArrangedSubview:recording];
  self.disconnectButton=[self button:@"Disconnect All" symbol:@"power" action:@selector(disconnectTapped) filled:NO];self.disconnectButton.accessibilityIdentifier=@"home.disconnect";[stack addArrangedSubview:self.disconnectButton];
  UIStackView *controls=[UIStackView new];controls.axis=UILayoutConstraintAxisVertical;controls.spacing=12;controls.layoutMargins=UIEdgeInsetsMake(18,18,18,18);controls.layoutMarginsRelativeArrangement=YES;controls.backgroundColor=UIColor.secondarySystemGroupedBackgroundColor;controls.layer.cornerRadius=24;
  [controls addArrangedSubview:[self label:@"Car player controls" style:UIFontTextStyleHeadline]];
  self.playerHint=[self label:@"Choose videos in YouTube. These controls change the car player, not your phone’s YouTube quality. Quality depends on the source; tap the car once if sound needs permission." style:UIFontTextStyleFootnote];self.playerHint.textColor=UIColor.secondaryLabelColor;[controls addArrangedSubview:self.playerHint];
  [controls addArrangedSubview:[self label:@"Video quality" style:UIFontTextStyleSubheadline]];
  self.playerQuality=[[UISegmentedControl alloc]initWithItems:@[@"Auto",@"720p",@"1080p"]];self.playerQuality.selectedSegmentIndex=0;self.playerQuality.accessibilityIdentifier=@"player.quality";[self.playerQuality addTarget:self action:@selector(playerQualityChanged) forControlEvents:UIControlEventValueChanged];[self.playerQuality.heightAnchor constraintGreaterThanOrEqualToConstant:44].active=YES;[controls addArrangedSubview:self.playerQuality];
  UIStackView *playback=[UIStackView new];playback.spacing=8;playback.distribution=UIStackViewDistributionFillEqually;
  self.playerBack=[self button:@"10s" symbol:@"gobackward.10" action:@selector(playerBackTapped) filled:NO];self.playerBack.accessibilityLabel=@"Rewind car video ten seconds";
  self.playerPause=[self button:@"Play" symbol:@"playpause.fill" action:@selector(playerPauseTapped) filled:YES];self.playerPause.accessibilityIdentifier=@"player.pause";
  self.playerForward=[self button:@"10s" symbol:@"goforward.10" action:@selector(playerForwardTapped) filled:NO];self.playerForward.accessibilityLabel=@"Forward car video ten seconds";
  for(UIButton *button in @[self.playerBack,self.playerPause,self.playerForward]){UIButtonConfiguration *configuration=button.configuration;configuration.contentInsets=NSDirectionalEdgeInsetsMake(12,8,12,8);button.configuration=configuration;[playback addArrangedSubview:button];}[controls addArrangedSubview:playback];
  self.playerPosition=[self label:@"Waiting for video" style:UIFontTextStyleFootnote];[controls addArrangedSubview:self.playerPosition];
  self.playerSeek=[UISlider new];self.playerSeek.minimumValue=0;self.playerSeek.maximumValue=1;self.playerSeek.continuous=NO;self.playerSeek.accessibilityLabel=@"Car video position";self.playerSeek.accessibilityIdentifier=@"player.seek";[self.playerSeek addTarget:self action:@selector(playerSeekChanged) forControlEvents:UIControlEventValueChanged];[controls addArrangedSubview:self.playerSeek];
  [controls addArrangedSubview:[self label:@"Car volume" style:UIFontTextStyleSubheadline]];
  self.playerVolume=[UISlider new];self.playerVolume.minimumValue=0;self.playerVolume.maximumValue=1;self.playerVolume.value=1;self.playerVolume.continuous=NO;self.playerVolume.accessibilityLabel=@"Car player volume";self.playerVolume.accessibilityIdentifier=@"player.volume";[self.playerVolume addTarget:self action:@selector(playerVolumeChanged) forControlEvents:UIControlEventValueChanged];[controls addArrangedSubview:self.playerVolume];
  self.playerEQ=[[UISegmentedControl alloc]initWithItems:@[@"Normal sound",@"Music"]];self.playerEQ.selectedSegmentIndex=0;self.playerEQ.accessibilityLabel=@"Car sound preset";[self.playerEQ addTarget:self action:@selector(playerEQChanged) forControlEvents:UIControlEventValueChanged];[self.playerEQ.heightAnchor constraintGreaterThanOrEqualToConstant:44].active=YES;[controls addArrangedSubview:self.playerEQ];
  [stack addArrangedSubview:controls];[self showPlayerState:@{}];
  self.previewHost=[UIView new];self.previewHost.backgroundColor=UIColor.blackColor;self.previewHost.layer.cornerRadius=20;self.previewHost.clipsToBounds=YES;self.previewHost.hidden=YES;
  NSLayoutConstraint *previewHeight=[self.previewHost.heightAnchor constraintEqualToConstant:160];previewHeight.priority=750;previewHeight.active=YES;[stack addArrangedSubview:self.previewHost];
  UIButton *copy=[self button:@"Website link" symbol:@"link" action:@selector(copyTapped) filled:NO];copy.accessibilityIdentifier=@"home.copy";[stack addArrangedSubview:copy];
  UIButton *developer=[UIButton buttonWithType:UIButtonTypeSystem];[developer setTitle:@"Developer" forState:UIControlStateNormal];developer.tintColor=UIColor.secondaryLabelColor;developer.accessibilityIdentifier=@"home.developer";[developer addTarget:self action:@selector(developerTapped) forControlEvents:UIControlEventTouchUpInside];[developer.heightAnchor constraintGreaterThanOrEqualToConstant:44].active=YES;[stack addArrangedSubview:developer];
  UIStackView *steps=[UIStackView new];steps.axis=UILayoutConstraintAxisVertical;steps.spacing=7;[steps addArrangedSubview:[self label:@"Connect in three steps" style:UIFontTextStyleHeadline]];
  for(NSString *line in @[@"1   Connect the viewer to your phone’s hotspot.",@"2   Choose ScreenLink in YouTube’s AirPlay menu.",@"3   Return here once to prepare the floating video."]){UILabel *label=[self label:line style:UIFontTextStyleSubheadline];label.textColor=UIColor.secondaryLabelColor;[steps addArrangedSubview:label];}[stack addArrangedSubview:steps];
  UILabel *footer=[self label:@"iOS manages background availability." style:UIFontTextStyleFootnote];footer.textColor=UIColor.secondaryLabelColor;[stack addArrangedSubview:footer];
  NSNotificationCenter *notifications=NSNotificationCenter.defaultCenter;
  for(NSString *event in @[UIApplicationDidBecomeActiveNotification,UIApplicationWillResignActiveNotification,UIApplicationDidEnterBackgroundNotification,UIAccessibilityReduceMotionStatusDidChangeNotification])[notifications addObserver:self selector:@selector(ambientStateChanged:) name:event object:nil];
 }
 return self;
}
- (void)dealloc {[NSNotificationCenter.defaultCenter removeObserver:self];[self stopAmbient];}
- (void)didMoveToWindow {[super didMoveToWindow];[self updateAmbient];}
- (void)setHidden:(BOOL)hidden {[super setHidden:hidden];[self updateAmbient];}
- (void)ambientStateChanged:(NSNotification *)note {if([note.name isEqual:UIApplicationWillResignActiveNotification]||[note.name isEqual:UIApplicationDidEnterBackgroundNotification])[self stopAmbient];else [self updateAmbient];}
- (void)stopAmbient {[self.ambientPlayer pause];self.car.videoLayer.player=nil;[self.ambientLooper disableLooping];self.ambientLooper=nil;[self.ambientPlayer removeAllItems];self.ambientPlayer=nil;}
- (void)updateAmbient {
 BOOL allowed=self.idleAllowed&&self.window&&!self.hidden&&!UIAccessibilityIsReduceMotionEnabled()&&UIApplication.sharedApplication.applicationState==UIApplicationStateActive;
 if(!allowed){[self stopAmbient];return;}if(self.ambientPlayer)return;
 NSURL *url=[NSBundle.mainBundle URLForResource:@"CarAmbient" withExtension:@"mp4"];if(!url)return;
 // Bundled clip has no audio track. Never configure the audio session or PiP here.
 self.ambientPlayer=[AVQueuePlayer queuePlayerWithItems:@[]];self.ambientPlayer.muted=YES;self.ambientPlayer.volume=0;
 self.ambientLooper=[AVPlayerLooper playerLooperWithPlayer:self.ambientPlayer templateItem:[AVPlayerItem playerItemWithURL:url]];
 self.car.videoLayer.player=self.ambientPlayer;[self.ambientPlayer play];
}
- (void)showStatus:(NSString *)status detail:(NSString *)detail busy:(BOOL)busy sharing:(BOOL)sharing disconnecting:(BOOL)disconnecting attention:(BOOL)attention {
 self.statusLabel.text=status;self.statusLabel.textColor=attention?UIColor.systemRedColor:UIColor.labelColor;self.detailLabel.text=detail;self.startButton.enabled=!busy;self.disconnectButton.enabled=!disconnecting;self.previewHost.hidden=!sharing;
 UIButtonConfiguration *c=self.startButton.configuration;c.showsActivityIndicator=busy;self.startButton.configuration=c;
 self.idleAllowed=!busy&&!sharing;[self updateAmbient];
}
- (void)themeTapped {BOOL dark=self.traitCollection.userInterfaceStyle!=UIUserInterfaceStyleDark;self.overrideUserInterfaceStyle=dark?UIUserInterfaceStyleDark:UIUserInterfaceStyleLight;[NSUserDefaults.standardUserDefaults setInteger:dark?2:1 forKey:@"ScreenLinkAppearance"];UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification,dark?@"Dark appearance":@"Light appearance");}
- (void)startTapped {self.idleAllowed=NO;[self stopAmbient];if(self.startAction)self.startAction();}
- (void)disconnectTapped {if(self.disconnectAction)self.disconnectAction();}
- (void)developerTapped {[self stopAmbient];if(self.developerAction)self.developerAction();}
- (void)copyTapped {if(self.copyAction)self.copyAction();UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification,@"Website link copied");}
- (void)sendPlayer:(NSDictionary *)request {if(self.playerAction)self.playerAction(request);}
- (void)playerQualityChanged {[self sendPlayer:@{@"quality":@[@"auto",@"720",@"1080"][self.playerQuality.selectedSegmentIndex]}];}
- (void)playerVolumeChanged {[self sendPlayer:@{@"volume":@(self.playerVolume.value)}];}
- (void)playerEQChanged {[self sendPlayer:@{@"eq":self.playerEQ.selectedSegmentIndex==1?@"music":@"normal"}];}
- (void)playerPauseTapped {[self sendPlayer:@{@"paused":@(![self.playerState[@"paused"] boolValue])}];}
- (void)playerBackTapped {[self sendPlayer:@{@"seek":@(MAX(0,[self.playerState[@"position"] doubleValue]-10))}];}
- (void)playerForwardTapped {[self sendPlayer:@{@"seek":@(MIN([self.playerState[@"duration"] doubleValue],[self.playerState[@"position"] doubleValue]+10))}];}
- (void)playerSeekChanged {[self sendPlayer:@{@"seek":@(self.playerSeek.value*[self.playerState[@"duration"] doubleValue])}];}
- (void)showPlayerState:(NSDictionary *)state {
 NSMutableDictionary *display=[state mutableCopy]?:[NSMutableDictionary dictionary];NSDictionary *pending=state[@"viewerControls"][@"playback"];if([pending[@"epoch"] isEqual:state[@"epoch"]])for(NSString *key in @[@"paused",@"seek"])if(pending[key])display[[key isEqual:@"seek"]?@"position":key]=pending[key];self.playerState=display;state=display;NSDictionary *settings=[state[@"viewerControls"] isKindOfClass:NSDictionary.class]?state[@"viewerControls"]:@{};
 BOOL enabled=[state[@"receiverRunning"] boolValue],active=[state[@"active"] boolValue];
 self.playerQuality.enabled=enabled;self.playerVolume.enabled=enabled;self.playerEQ.enabled=enabled;
 self.playerPause.enabled=enabled&&active;self.playerBack.enabled=enabled&&active;self.playerForward.enabled=enabled&&active;
 double duration=[state[@"duration"] doubleValue],position=[state[@"position"] doubleValue];self.playerSeek.enabled=enabled&&active&&duration>0;
 if(!self.playerSeek.tracking)self.playerSeek.value=duration>0?position/duration:0;
 if(!self.playerVolume.tracking&&settings[@"volume"])self.playerVolume.value=[settings[@"volume"] floatValue];
 NSUInteger quality=[@[@"auto",@"720",@"1080"] indexOfObject:settings[@"quality"]?:@"auto"];self.playerQuality.selectedSegmentIndex=quality==NSNotFound?0:quality;
 self.playerEQ.selectedSegmentIndex=[settings[@"eq"] isEqual:@"music"]?1:0;
 UIButtonConfiguration *config=self.playerPause.configuration;config.title=[state[@"paused"] boolValue]?@"Play":@"Pause";self.playerPause.configuration=config;
 self.playerPosition.text=active?[NSString stringWithFormat:@"%ld:%02ld / %ld:%02ld · %@",(long)(position/60),(long)position%60,(long)(duration/60),(long)duration%60,[state[@"ready"] boolValue]?@"Car playback reported":@"Waiting for car player"]:@"Choose a video in YouTube after connecting AirPlay.";
}
@end


