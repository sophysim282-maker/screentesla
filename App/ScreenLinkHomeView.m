#import "ScreenLinkHomeView.h"
#import <AVFoundation/AVFoundation.h>

@interface SLAmbientCarView : UIView
@property(nonatomic,strong) UIImageView *poster;
@property(nonatomic,strong) AVPlayerLayer *videoLayer;
@property(nonatomic,strong) CAGradientLayer *sheen;
@end
@implementation SLAmbientCarView
- (instancetype)initWithFrame:(CGRect)frame {if((self=[super initWithFrame:frame])){self.clipsToBounds=YES;self.layer.cornerRadius=28;self.backgroundColor=UIColor.blackColor;self.poster=[[UIImageView alloc]initWithImage:[UIImage imageNamed:@"CarPoster.jpg"]];self.poster.contentMode=UIViewContentModeScaleAspectFill;[self addSubview:self.poster];self.videoLayer=[AVPlayerLayer layer];self.videoLayer.videoGravity=AVLayerVideoGravityResizeAspectFill;[self.layer addSublayer:self.videoLayer];self.isAccessibilityElement=YES;self.accessibilityLabel=@"Silver sports car beneath a starry sky";
  self.sheen=[CAGradientLayer layer];self.sheen.startPoint=CGPointMake(0,.2);self.sheen.endPoint=CGPointMake(1,.8);self.sheen.colors=@[(id)[UIColor colorWithWhite:1 alpha:0].CGColor,(id)[UIColor colorWithWhite:1 alpha:.28].CGColor,(id)[UIColor colorWithWhite:1 alpha:0].CGColor];self.sheen.locations=@[@-.4,@-.25,@-.1];[self.layer addSublayer:self.sheen];
  self.layer.borderWidth=1;self.layer.borderColor=[UIColor colorWithRed:.4 green:1 blue:.85 alpha:.35].CGColor;}return self;}
- (void)layoutSubviews {[super layoutSubviews];self.poster.frame=self.bounds;self.videoLayer.frame=self.bounds;[CATransaction begin];[CATransaction setDisableActions:YES];self.sheen.frame=self.bounds;[CATransaction commit];}
@end

// Build 86 "Cosmic Glass" Home: animated space background, 3D tilting car stage,
// glass cards and lively buttons. Home only; Developer and video playback unchanged.
// Every animation is skipped when Reduce Motion is on.
static BOOL SLMotionAllowed(void){return !UIAccessibilityIsReduceMotionEnabled();}
static UIColor *SLRGB(CGFloat r,CGFloat g,CGFloat b){return [UIColor colorWithRed:r/255. green:g/255. blue:b/255. alpha:1];}

@interface SLCosmicView : UIView
@property(nonatomic,strong) CAGradientLayer *sky,*aurora;
@property(nonatomic,strong) CAEmitterLayer *stars;
@end
@implementation SLCosmicView
- (instancetype)initWithFrame:(CGRect)frame {
 if((self=[super initWithFrame:frame])){
  self.userInteractionEnabled=NO;
  self.sky=[CAGradientLayer layer];self.sky.startPoint=CGPointMake(0,0);self.sky.endPoint=CGPointMake(1,1);[self.layer addSublayer:self.sky];
  self.aurora=[CAGradientLayer layer];self.aurora.type=kCAGradientLayerRadial;self.aurora.startPoint=CGPointMake(.5,.5);self.aurora.endPoint=CGPointMake(1,1);self.aurora.opacity=.55;[self.layer addSublayer:self.aurora];
  self.stars=[CAEmitterLayer layer];self.stars.emitterShape=kCAEmitterLayerRectangle;self.stars.renderMode=kCAEmitterLayerAdditive;
  UIGraphicsImageRenderer *renderer=[[UIGraphicsImageRenderer alloc]initWithSize:CGSizeMake(8,8)];
  UIImage *dot=[renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx){[[UIColor whiteColor] setFill];[[UIBezierPath bezierPathWithOvalInRect:CGRectMake(0,0,8,8)] fill];}];
  CAEmitterCell *dust=[CAEmitterCell emitterCell];dust.contents=(id)dot.CGImage;dust.birthRate=7;dust.lifetime=18;dust.velocity=5;dust.velocityRange=4;dust.emissionRange=M_PI*2;dust.scale=.18;dust.scaleRange=.14;dust.alphaRange=.6;dust.alphaSpeed=-.04;dust.color=[UIColor colorWithWhite:1 alpha:.8].CGColor;
  CAEmitterCell *twinkle=[CAEmitterCell emitterCell];twinkle.contents=(id)dot.CGImage;twinkle.birthRate=.9;twinkle.lifetime=4;twinkle.velocity=1;twinkle.scale=.32;twinkle.scaleSpeed=-.06;twinkle.alphaSpeed=-.25;twinkle.color=SLRGB(170,255,236).CGColor;
  self.stars.emitterCells=@[dust,twinkle];[self.layer addSublayer:self.stars];
  [self applyPalette];
 }
 return self;
}
- (void)traitCollectionDidChange:(UITraitCollection *)previous {[super traitCollectionDidChange:previous];[self applyPalette];}
- (void)applyPalette {
 BOOL dark=self.traitCollection.userInterfaceStyle!=UIUserInterfaceStyleLight;
 NSArray *a=dark?@[(id)SLRGB(4,7,20).CGColor,(id)SLRGB(10,26,52).CGColor,(id)SLRGB(9,40,44).CGColor]:@[(id)SLRGB(236,245,255).CGColor,(id)SLRGB(222,234,255).CGColor,(id)SLRGB(242,232,255).CGColor];
 NSArray *b=dark?@[(id)SLRGB(10,6,28).CGColor,(id)SLRGB(26,14,56).CGColor,(id)SLRGB(6,34,52).CGColor]:@[(id)SLRGB(230,250,246).CGColor,(id)SLRGB(236,230,255).CGColor,(id)SLRGB(222,240,255).CGColor];
 self.sky.colors=a;[self.sky removeAllAnimations];
 self.aurora.colors=dark?@[(id)[SLRGB(54,220,190) colorWithAlphaComponent:.55].CGColor,(id)[SLRGB(120,90,255) colorWithAlphaComponent:.0].CGColor]:@[(id)[SLRGB(120,210,255) colorWithAlphaComponent:.45].CGColor,(id)[UIColor colorWithWhite:1 alpha:0].CGColor];
 self.stars.hidden=!dark;
 if(SLMotionAllowed()){
  CABasicAnimation *shift=[CABasicAnimation animationWithKeyPath:@"colors"];shift.fromValue=a;shift.toValue=b;shift.duration=14;shift.autoreverses=YES;shift.repeatCount=HUGE_VALF;shift.timingFunction=[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];[self.sky addAnimation:shift forKey:@"shift"];
  CABasicAnimation *drift=[CABasicAnimation animationWithKeyPath:@"position"];drift.byValue=[NSValue valueWithCGPoint:CGPointMake(70,140)];drift.duration=11;drift.autoreverses=YES;drift.repeatCount=HUGE_VALF;drift.timingFunction=[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];[self.aurora removeAllAnimations];[self.aurora addAnimation:drift forKey:@"drift"];
  self.stars.birthRate=1;
 }else{[self.aurora removeAllAnimations];self.stars.birthRate=0;}
}
- (void)layoutSubviews {
 [super layoutSubviews];[CATransaction begin];[CATransaction setDisableActions:YES];
 self.sky.frame=self.bounds;CGFloat side=MAX(self.bounds.size.width,self.bounds.size.height)*.9;self.aurora.frame=CGRectMake(-side*.25,-side*.2,side,side);
 self.stars.frame=self.bounds;self.stars.emitterPosition=CGPointMake(CGRectGetMidX(self.bounds),CGRectGetMidY(self.bounds));self.stars.emitterSize=self.bounds.size;[CATransaction commit];
}
@end

// A glowing border that rotates around a card while ScreenLink is sharing.
@interface SLGlowBorder : UIView
@property(nonatomic,strong) CAGradientLayer *ring;
@property(nonatomic,strong) CAShapeLayer *mask;
@end
@implementation SLGlowBorder
- (instancetype)initWithFrame:(CGRect)frame {
 if((self=[super initWithFrame:frame])){
  self.userInteractionEnabled=NO;self.ring=[CAGradientLayer layer];self.ring.type=kCAGradientLayerConic;self.ring.startPoint=CGPointMake(.5,.5);self.ring.endPoint=CGPointMake(.5,0);
  self.ring.colors=@[(id)SLRGB(64,240,200).CGColor,(id)SLRGB(90,140,255).CGColor,(id)SLRGB(190,110,255).CGColor,(id)[SLRGB(64,240,200) colorWithAlphaComponent:.1].CGColor,(id)SLRGB(64,240,200).CGColor];
  self.mask=[CAShapeLayer layer];self.mask.fillColor=UIColor.clearColor.CGColor;self.mask.strokeColor=UIColor.blackColor.CGColor;self.mask.lineWidth=2.2;
  [self.layer addSublayer:self.ring];self.layer.mask=self.mask;self.alpha=0;
 }
 return self;
}
- (void)layoutSubviews {
 [super layoutSubviews];[CATransaction begin];[CATransaction setDisableActions:YES];
 CGFloat side=hypot(self.bounds.size.width,self.bounds.size.height);self.ring.bounds=CGRectMake(0,0,side,side);self.ring.position=CGPointMake(CGRectGetMidX(self.bounds),CGRectGetMidY(self.bounds));
 self.mask.frame=self.bounds;self.mask.path=[UIBezierPath bezierPathWithRoundedRect:CGRectInset(self.bounds,1.1,1.1) cornerRadius:24].CGPath;[CATransaction commit];
}
- (void)setGlowing:(BOOL)glowing {
 [UIView animateWithDuration:.5 animations:^{self.alpha=glowing?1:0;}];
 if(glowing&&SLMotionAllowed()&&![self.ring animationForKey:@"spin"]){CABasicAnimation *spin=[CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];spin.fromValue=@0;spin.toValue=@(M_PI*2);spin.duration=5;spin.repeatCount=HUGE_VALF;[self.ring addAnimation:spin forKey:@"spin"];}
 if(!glowing)[self.ring removeAnimationForKey:@"spin"];
}
@end

// Build 117: soft dark edge on the entrance pictures, so they melt into the black screen.
@interface SLFadeView : UIView
@end
@implementation SLFadeView
+ (Class)layerClass {return CAGradientLayer.class;}
@end
static CGFloat SLStep(CGFloat a,CGFloat b,CGFloat x){CGFloat t=MAX(0,MIN(1,(x-a)/(b-a)));return t*t*(3-2*t);}
static CGFloat SLMix(CGFloat a,CGFloat b,CGFloat t){return a+(b-a)*MAX(0,MIN(1,t));}

@interface ScreenLinkHomeView () <UIScrollViewDelegate>
@property(nonatomic,strong) UIView *entrance,*entranceBack,*entranceStatus;
@property(nonatomic,strong) UIScrollView *entranceScroll;
@property(nonatomic,strong) NSArray<UIImageView *> *entranceImages;
@property(nonatomic,strong) NSMutableArray<UIView *> *entranceFades;
@property(nonatomic,strong) UILabel *entranceTitle,*entranceStatusText;
@property(nonatomic,strong) UIView *entranceHint;
@property(nonatomic,strong) CADisplayLink *entranceLink;
@property(nonatomic) CFTimeInterval entranceStart;
@property(nonatomic) CGFloat entranceFrom,entranceNow;
@property(nonatomic) BOOL entranceLeaving;
@property(nonatomic,strong) UIImage *heroDefault;
@property(nonatomic,strong,readwrite) UIView *previewHost;
@property(nonatomic,strong) UILabel *statusLabel,*detailLabel;
@property(nonatomic,strong) UIButton *startButton,*disconnectButton;
@property(nonatomic,strong) SLAmbientCarView *car;
@property(nonatomic,strong) AVQueuePlayer *ambientPlayer;
@property(nonatomic,strong) AVPlayerLooper *ambientLooper;
@property(nonatomic) BOOL idleAllowed;
@property(nonatomic,strong) UISegmentedControl *playerQuality,*playerEQ;
@property(nonatomic,strong) UISlider *playerVolume,*playerSeek;
@property(nonatomic,strong) UIButton *playerPause,*playerBack,*playerForward;
@property(nonatomic,strong) UILabel *playerPosition,*playerHint;
@property(nonatomic,copy) NSDictionary *playerState;
@property(nonatomic,strong) SLCosmicView *cosmic;
@property(nonatomic,strong) SLGlowBorder *statusGlow;
@property(nonatomic,strong) UIView *statusDot,*liveBadge;
@property(nonatomic,strong) UIStackView *mainStack;
@property(nonatomic) BOOL entranceDone;
@property(nonatomic,strong) CAGradientLayer *startShine;
@property(nonatomic,strong) NSMutableDictionary<NSString *,UILabel *> *rowDetails;
@property(nonatomic,strong) UIView *controlsCard,*helpCard;
@property(nonatomic,strong) UIImageView *heroImage;
@end
static UIColor *SLHomeGrey(void){return [UIColor colorWithRed:.49 green:.51 blue:.55 alpha:1];}
@implementation ScreenLinkHomeView
- (UILabel *)label:(NSString *)text style:(UIFontTextStyle)style {
 UILabel *label=[UILabel new];label.text=text;label.font=[UIFont preferredFontForTextStyle:style];label.adjustsFontForContentSizeCategory=YES;label.numberOfLines=0;return label;
}
// Build 116: a round icon button for the quick row and the top bar.
- (UIButton *)roundButton:(NSString *)symbol label:(NSString *)label action:(SEL)action {
 UIButtonConfiguration *config=UIButtonConfiguration.plainButtonConfiguration;
 config.image=[UIImage systemImageNamed:symbol withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:21 weight:UIImageSymbolWeightSemibold]];config.baseForegroundColor=SLHomeGrey();config.contentInsets=NSDirectionalEdgeInsetsMake(12,12,12,12);
 UIButton *button=[UIButton buttonWithConfiguration:config primaryAction:nil];button.accessibilityLabel=label;[button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
 [button.widthAnchor constraintGreaterThanOrEqualToConstant:48].active=YES;[button.heightAnchor constraintGreaterThanOrEqualToConstant:48].active=YES;return button;
}
// Build 116: one line of the list: grey icon, name, grey line of detail, arrow.
- (UIControl *)rowWithSymbol:(NSString *)symbol title:(NSString *)title subtitle:(NSString *)subtitle key:(NSString *)key {
 UIControl *row=[UIControl new];row.accessibilityIdentifier=[@"home.row." stringByAppendingString:key];row.isAccessibilityElement=YES;row.accessibilityTraits=UIAccessibilityTraitButton;row.accessibilityLabel=title;row.accessibilityValue=subtitle;
 UIImageView *icon=[[UIImageView alloc]initWithImage:[UIImage systemImageNamed:symbol withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:21 weight:UIImageSymbolWeightMedium]]];icon.tintColor=SLHomeGrey();icon.contentMode=UIViewContentModeCenter;[icon.widthAnchor constraintEqualToConstant:32].active=YES;
 UILabel *name=[UILabel new];name.text=title;name.font=[UIFontMetrics.defaultMetrics scaledFontForFont:[UIFont systemFontOfSize:23 weight:UIFontWeightSemibold]];name.adjustsFontForContentSizeCategory=YES;name.textColor=UIColor.whiteColor;name.numberOfLines=0;
 UILabel *detail=[UILabel new];detail.text=subtitle;detail.font=[UIFontMetrics.defaultMetrics scaledFontForFont:[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold]];detail.adjustsFontForContentSizeCategory=YES;detail.textColor=SLHomeGrey();detail.numberOfLines=0;self.rowDetails[key]=detail;
 UIStackView *words=[[UIStackView alloc]initWithArrangedSubviews:@[name,detail]];words.axis=UILayoutConstraintAxisVertical;words.spacing=2;
 UIImageView *arrow=[[UIImageView alloc]initWithImage:[UIImage systemImageNamed:@"chevron.right" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightSemibold]]];arrow.tintColor=[UIColor colorWithWhite:.36 alpha:1];[arrow setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];[arrow setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
 UIStackView *line=[[UIStackView alloc]initWithArrangedSubviews:@[icon,words,arrow]];line.spacing=18;line.alignment=UIStackViewAlignmentCenter;line.userInteractionEnabled=NO;line.translatesAutoresizingMaskIntoConstraints=NO;[row addSubview:line];
 [NSLayoutConstraint activateConstraints:@[[line.topAnchor constraintEqualToAnchor:row.topAnchor constant:13],[line.bottomAnchor constraintEqualToAnchor:row.bottomAnchor constant:-13],[line.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:2],[line.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-2]]];
 [row addTarget:self action:@selector(rowTapped:) forControlEvents:UIControlEventTouchUpInside];return row;
}
- (void)rowTapped:(UIControl *)row {
 NSString *key=[row.accessibilityIdentifier isEqual:@"home.maps"]?@"maps":[row.accessibilityIdentifier stringByReplacingOccurrencesOfString:@"home.row." withString:@""];
 [[[UISelectionFeedbackGenerator alloc]init] selectionChanged];
 if([key isEqual:@"video"]){[self videoRowTapped];return;}
 if([key isEqual:@"help"]){[UIView animateWithDuration:.25 animations:^{self.helpCard.hidden=!self.helpCard.hidden;self.helpCard.alpha=self.helpCard.hidden?0:1;}];return;}
 if([key isEqual:@"maps"]){[self mapTapped];return;}
 if(self.moreAction)self.moreAction(key);
}
- (void)videoRowTapped {[UIView animateWithDuration:.25 animations:^{self.controlsCard.hidden=!self.controlsCard.hidden;self.controlsCard.alpha=self.controlsCard.hidden?0:1;}];}
- (void)waitingQuickTapped {if(self.moreAction)self.moreAction(@"waiting");}
- (void)setSubtitle:(NSString *)text forRow:(NSString *)key {UILabel *label=self.rowDetails[key];if(label&&text.length&&![label.text isEqual:text])label.text=text;}
- (void)showHeroImage:(UIImage *)image {if(self.heroDefault)image=self.heroDefault;self.heroImage.image=image;self.heroImage.hidden=image==nil;}
- (UIButton *)button:(NSString *)title symbol:(NSString *)symbol action:(SEL)action filled:(BOOL)filled {
 UIButtonConfiguration *config=filled?UIButtonConfiguration.filledButtonConfiguration:UIButtonConfiguration.tintedButtonConfiguration;
 config.title=title;config.image=[UIImage systemImageNamed:symbol];config.imagePadding=10;config.cornerStyle=UIButtonConfigurationCornerStyleCapsule;config.contentInsets=NSDirectionalEdgeInsetsMake(16,18,16,18);
 config.baseBackgroundColor=filled?[UIColor colorWithRed:.08 green:.52 blue:.47 alpha:1]:UIColor.secondarySystemFillColor;config.baseForegroundColor=filled?UIColor.whiteColor:UIColor.labelColor;
 UIButton *button=[UIButton buttonWithConfiguration:config primaryAction:nil];button.titleLabel.adjustsFontForContentSizeCategory=YES;[button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];return button;
}
- (instancetype)initWithFrame:(CGRect)frame {
 if((self=[super initWithFrame:frame])){
  self.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;
  self.backgroundColor=[UIColor colorWithRed:.086 green:.094 blue:.11 alpha:1];self.idleAllowed=YES;
  self.cosmic=[SLCosmicView new];self.cosmic.translatesAutoresizingMaskIntoConstraints=NO;[self addSubview:self.cosmic];self.cosmic.alpha=.22;
  [NSLayoutConstraint activateConstraints:@[[self.cosmic.topAnchor constraintEqualToAnchor:self.topAnchor],[self.cosmic.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],[self.cosmic.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],[self.cosmic.trailingAnchor constraintEqualToAnchor:self.trailingAnchor]]];
  UIScrollView *scroll=[UIScrollView new];scroll.translatesAutoresizingMaskIntoConstraints=NO;scroll.alwaysBounceVertical=YES;scroll.accessibilityIdentifier=@"home.scroll";scroll.backgroundColor=UIColor.clearColor;[self addSubview:scroll];
  UIStackView *stack=[UIStackView new];self.mainStack=stack;stack.axis=UILayoutConstraintAxisVertical;stack.spacing=18;stack.translatesAutoresizingMaskIntoConstraints=NO;[scroll addSubview:stack];
  NSLayoutConstraint *width=[stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-40];width.priority=999;
  [NSLayoutConstraint activateConstraints:@[[scroll.topAnchor constraintEqualToAnchor:self.topAnchor],[scroll.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],[scroll.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],[scroll.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],[scroll.contentLayoutGuide.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor],[stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:16],[stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-24],[stack.centerXAnchor constraintEqualToAnchor:scroll.centerXAnchor],width,[stack.widthAnchor constraintLessThanOrEqualToConstant:720],[stack.leadingAnchor constraintGreaterThanOrEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:20],[stack.trailingAnchor constraintLessThanOrEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-20]]];
  // Build 116: new Home. Dark and calm: big name, the status right under it, one big picture, a row of
  // round quick buttons, then a plain list with a grey line under each name and an arrow. Every control
  // keeps its old action and its old test name (home.start, home.disconnect, home.developer, …).
  UIStackView *nav=[UIStackView new];nav.alignment=UIStackViewAlignmentCenter;nav.spacing=6;
  UILabel *name=[self label:@"ScreenLink" style:UIFontTextStyleLargeTitle];name.font=[UIFontMetrics.defaultMetrics scaledFontForFont:[UIFont systemFontOfSize:36 weight:UIFontWeightBold]];name.textColor=UIColor.whiteColor;name.numberOfLines=1;name.adjustsFontSizeToFitWidth=YES;name.minimumScaleFactor=.6;[nav addArrangedSubview:name];[nav addArrangedSubview:[UIView new]];
  UIButton *copy=[self roundButton:@"link" label:@"Copy the car website link" action:@selector(copyTapped)];copy.accessibilityIdentifier=@"home.copy";{UIButtonConfiguration *c=copy.configuration;c.baseForegroundColor=UIColor.whiteColor;copy.configuration=c;}[nav addArrangedSubview:copy];
  UIButton *developer=[self roundButton:@"line.3.horizontal" label:@"Developer controls and test log" action:@selector(developerTapped)];developer.accessibilityIdentifier=@"home.developer";{UIButtonConfiguration *c=developer.configuration;c.baseForegroundColor=UIColor.whiteColor;developer.configuration=c;}[nav addArrangedSubview:developer];[stack addArrangedSubview:nav];
  UIStackView *status=[UIStackView new];status.axis=UILayoutConstraintAxisVertical;status.spacing=4;
  self.statusLabel=[self label:@"Ready to connect" style:UIFontTextStyleHeadline];self.statusLabel.font=[UIFontMetrics.defaultMetrics scaledFontForFont:[UIFont systemFontOfSize:19 weight:UIFontWeightSemibold]];self.statusLabel.accessibilityIdentifier=@"home.status";
  UIStackView *statusRow=[UIStackView new];statusRow.spacing=10;statusRow.alignment=UIStackViewAlignmentCenter;self.statusDot=[UIView new];self.statusDot.layer.cornerRadius=6;self.statusDot.backgroundColor=UIColor.systemGrayColor;[self.statusDot.widthAnchor constraintEqualToConstant:12].active=YES;[self.statusDot.heightAnchor constraintEqualToConstant:12].active=YES;[statusRow addArrangedSubview:self.statusDot];[statusRow addArrangedSubview:self.statusLabel];[status addArrangedSubview:statusRow];
  self.detailLabel=[self label:@"Turn on Personal Hotspot, then tap Start." style:UIFontTextStyleSubheadline];self.detailLabel.font=[UIFontMetrics.defaultMetrics scaledFontForFont:[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold]];self.detailLabel.textColor=SLHomeGrey();self.detailLabel.accessibilityIdentifier=@"home.detail";[status addArrangedSubview:self.detailLabel];[stack addArrangedSubview:status];
  self.car=[SLAmbientCarView new];[self.car.heightAnchor constraintEqualToAnchor:self.car.widthAnchor multiplier:.5625].active=YES;[stack addArrangedSubview:self.car];[self makeStage3D];
  // The user's own waiting screen picture, when there is one, covers the car clip.
  self.heroImage=[UIImageView new];self.heroImage.contentMode=UIViewContentModeScaleAspectFill;self.heroImage.clipsToBounds=YES;self.heroImage.layer.cornerRadius=28;self.heroImage.hidden=YES;self.heroImage.translatesAutoresizingMaskIntoConstraints=NO;[self.car insertSubview:self.heroImage belowSubview:self.liveBadge];
  [NSLayoutConstraint activateConstraints:@[[self.heroImage.topAnchor constraintEqualToAnchor:self.car.topAnchor],[self.heroImage.bottomAnchor constraintEqualToAnchor:self.car.bottomAnchor],[self.heroImage.leadingAnchor constraintEqualToAnchor:self.car.leadingAnchor],[self.heroImage.trailingAnchor constraintEqualToAnchor:self.car.trailingAnchor]]];
  // Build 117: the user's own car picture (added to the app when it is packaged) is the Home picture.
  {NSString *path=[NSBundle.mainBundle pathForResource:@"entrance-4" ofType:@"jpg"];self.heroDefault=path?[UIImage imageWithContentsOfFile:path]:nil;if(self.heroDefault)[self showHeroImage:nil];}
  self.statusGlow=[SLGlowBorder new];self.statusGlow.userInteractionEnabled=NO;self.statusGlow.translatesAutoresizingMaskIntoConstraints=NO;[self.car addSubview:self.statusGlow];[NSLayoutConstraint activateConstraints:@[[self.statusGlow.topAnchor constraintEqualToAnchor:self.car.topAnchor],[self.statusGlow.bottomAnchor constraintEqualToAnchor:self.car.bottomAnchor],[self.statusGlow.leadingAnchor constraintEqualToAnchor:self.car.leadingAnchor],[self.statusGlow.trailingAnchor constraintEqualToAnchor:self.car.trailingAnchor]]];
  self.previewHost=[UIView new];self.previewHost.backgroundColor=UIColor.blackColor;self.previewHost.layer.cornerRadius=20;self.previewHost.clipsToBounds=YES;self.previewHost.hidden=YES;
  NSLayoutConstraint *previewHeight=[self.previewHost.heightAnchor constraintEqualToConstant:160];previewHeight.priority=750;previewHeight.active=YES;[stack addArrangedSubview:self.previewHost];
  // Quick buttons: Start, pause the car video, video settings, waiting screen, Disconnect all.
  self.startButton=[self button:@"" symbol:@"play.fill" action:@selector(startTapped) filled:YES];self.startButton.accessibilityIdentifier=@"home.start";self.startButton.accessibilityLabel=@"Start";{UIButtonConfiguration *c=self.startButton.configuration;c.contentInsets=NSDirectionalEdgeInsetsMake(14,14,14,14);c.imagePadding=0;self.startButton.configuration=c;}[self.startButton.widthAnchor constraintEqualToConstant:58].active=YES;[self.startButton.heightAnchor constraintEqualToConstant:58].active=YES;[self makeStartButtonAlive];
  UIButton *quickPause=[self roundButton:@"playpause.fill" label:@"Pause or play the car video" action:@selector(playerPauseTapped)];
  UIButton *quickVideo=[self roundButton:@"slider.horizontal.3" label:@"Video quality and sound" action:@selector(videoRowTapped)];
  UIButton *quickWaiting=[self roundButton:@"photo.on.rectangle" label:@"Waiting screen" action:@selector(waitingQuickTapped)];
  self.disconnectButton=[self roundButton:@"power" label:@"Disconnect all" action:@selector(disconnectTapped)];self.disconnectButton.accessibilityIdentifier=@"home.disconnect";{UIButtonConfiguration *c=self.disconnectButton.configuration;c.baseForegroundColor=[UIColor colorWithRed:1 green:.42 blue:.4 alpha:1];self.disconnectButton.configuration=c;}
  UIStackView *quick=[[UIStackView alloc]initWithArrangedSubviews:@[self.startButton,quickPause,quickVideo,quickWaiting,self.disconnectButton]];quick.distribution=UIStackViewDistributionEqualSpacing;quick.alignment=UIStackViewAlignmentCenter;[stack addArrangedSubview:quick];
  // The list.
  self.rowDetails=[NSMutableDictionary dictionary];UIStackView *list=[UIStackView new];list.axis=UILayoutConstraintAxisVertical;list.spacing=0;
  [list addArrangedSubview:[self rowWithSymbol:@"video.fill" title:@"Video" subtitle:@"YouTube · quality, sound and position" key:@"video"]];
  UIStackView *controls=[UIStackView new];controls.axis=UILayoutConstraintAxisVertical;controls.spacing=12;controls.layoutMargins=UIEdgeInsetsMake(18,18,18,18);controls.layoutMarginsRelativeArrangement=YES;controls.backgroundColor=[UIColor colorWithRed:.12 green:.13 blue:.16 alpha:1];controls.layer.cornerRadius=26;controls.layer.borderWidth=.5;controls.layer.borderColor=[UIColor colorWithWhite:1 alpha:.14].CGColor;self.playerQuality.selectedSegmentTintColor=nil;
  [controls addArrangedSubview:[self label:@"Car player controls" style:UIFontTextStyleHeadline]];
  self.playerHint=[self label:@"Choose videos in YouTube. These controls change the car player, not your phone’s YouTube quality. Quality depends on the source; tap the car once if sound needs permission." style:UIFontTextStyleFootnote];self.playerHint.textColor=UIColor.secondaryLabelColor;[controls addArrangedSubview:self.playerHint];
  [controls addArrangedSubview:[self label:@"Video quality" style:UIFontTextStyleSubheadline]];
  self.playerQuality=[[UISegmentedControl alloc]initWithItems:@[@"Auto",@"720p",@"1080p",@"1440p",@"4K"]];self.playerQuality.selectedSegmentIndex=0;self.playerQuality.accessibilityIdentifier=@"player.quality";[self.playerQuality addTarget:self action:@selector(playerQualityChanged) forControlEvents:UIControlEventValueChanged];[self.playerQuality.heightAnchor constraintGreaterThanOrEqualToConstant:44].active=YES;[controls addArrangedSubview:self.playerQuality];
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
  controls.hidden=YES;self.controlsCard=controls;[list addArrangedSubview:controls];[self showPlayerState:@{}];
  [list addArrangedSubview:[self rowWithSymbol:@"speaker.wave.2" title:@"Phone sound" subtitle:@"On" key:@"phonesound"]];
  [list addArrangedSubview:[self rowWithSymbol:@"play.circle" title:@"Keep playing" subtitle:@"On" key:@"keep"]];
  [list addArrangedSubview:[self rowWithSymbol:@"music.note" title:@"TikTok" subtitle:@"Inside ScreenLink · no screen recording" key:@"tiktok"]];
  [list addArrangedSubview:[self rowWithSymbol:@"photo.on.rectangle" title:@"Waiting screen" subtitle:@"Your pictures, GIFs and videos" key:@"waiting"]];
  UIControl *maps=[self rowWithSymbol:@"map" title:@"Maps" subtitle:@"Closed" key:@"maps"];maps.accessibilityIdentifier=@"home.maps";[list addArrangedSubview:maps];
  [list addArrangedSubview:[self rowWithSymbol:@"cube" title:@"Orbit Cube" subtitle:@"Needs Maps" key:@"cube"]];
  [list addArrangedSubview:[self rowWithSymbol:@"questionmark.circle" title:@"Help" subtitle:@"How to connect · no screen recording" key:@"help"]];
  UIStackView *steps=[UIStackView new];steps.axis=UILayoutConstraintAxisVertical;steps.spacing=7;[steps addArrangedSubview:[self label:@"Connect in three steps" style:UIFontTextStyleHeadline]];
  for(NSString *line in @[@"1   Connect the viewer to your phone’s hotspot.",@"2   Choose ScreenLink in YouTube’s AirPlay menu.",@"3   Return here once to prepare the floating video."]){UILabel *label=[self label:line style:UIFontTextStyleSubheadline];label.textColor=SLHomeGrey();[steps addArrangedSubview:label];}  UILabel *footer=[self label:@"No screen recording is used. iOS manages background availability." style:UIFontTextStyleFootnote];footer.textColor=SLHomeGrey();[steps addArrangedSubview:footer];
  if([steps.arrangedSubviews.firstObject isKindOfClass:UILabel.class])((UILabel *)steps.arrangedSubviews.firstObject).textColor=UIColor.whiteColor;
  steps.layoutMargins=UIEdgeInsetsMake(4,50,14,4);steps.layoutMarginsRelativeArrangement=YES;steps.hidden=YES;self.helpCard=steps;[list addArrangedSubview:steps];[stack addArrangedSubview:list];
  NSNotificationCenter *notifications=NSNotificationCenter.defaultCenter;
  for(NSString *event in @[UIApplicationDidBecomeActiveNotification,UIApplicationWillResignActiveNotification,UIApplicationDidEnterBackgroundNotification,UIAccessibilityReduceMotionStatusDidChangeNotification])[notifications addObserver:self selector:@selector(ambientStateChanged:) name:event object:nil];
 }
 return self;
}
- (void)dealloc {[NSNotificationCenter.defaultCenter removeObserver:self];[self stopAmbient];}
- (void)didMoveToWindow {[super didMoveToWindow];[self updateAmbient];dispatch_async(dispatch_get_main_queue(),^{[self playEntrance];});}
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
 UIColor *dot=attention?UIColor.systemOrangeColor:sharing?[UIColor colorWithRed:.25 green:.95 blue:.72 alpha:1]:busy?UIColor.systemBlueColor:UIColor.systemGrayColor;
 if(!attention&&!busy&&self.healthLevel>0)dot=self.healthLevel==1?UIColor.systemGreenColor:self.healthLevel==2?UIColor.systemYellowColor:UIColor.systemRedColor;self.statusDot.backgroundColor=dot;
 [self.statusDot.layer removeAnimationForKey:@"pulse"];if((sharing||busy||attention)&&SLMotionAllowed()){CABasicAnimation *pulse=[CABasicAnimation animationWithKeyPath:@"transform.scale"];pulse.fromValue=@1;pulse.toValue=@1.6;pulse.duration=.9;pulse.autoreverses=YES;pulse.repeatCount=HUGE_VALF;[self.statusDot.layer addAnimation:pulse forKey:@"pulse"];}
 [self.statusGlow setGlowing:sharing];self.liveBadge.hidden=!sharing;
}
- (void)themeTapped {BOOL dark=self.traitCollection.userInterfaceStyle!=UIUserInterfaceStyleDark;self.overrideUserInterfaceStyle=dark?UIUserInterfaceStyleDark:UIUserInterfaceStyleLight;[NSUserDefaults.standardUserDefaults setInteger:dark?2:1 forKey:@"ScreenLinkAppearance"];UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification,dark?@"Dark appearance":@"Light appearance");}
- (void)startTapped {self.idleAllowed=NO;[self stopAmbient];if(self.startAction)self.startAction();}
- (void)mapTapped {if(self.mapAction)self.mapAction();}
- (void)disconnectTapped {if(self.disconnectAction)self.disconnectAction();}
- (void)developerTapped {[self stopAmbient];if(self.developerAction)self.developerAction();}
- (void)copyTapped {if(self.copyAction)self.copyAction();UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification,@"Website link copied");}
- (void)sendPlayer:(NSDictionary *)request {if(self.playerAction)self.playerAction(request);}
- (void)playerQualityChanged {[self sendPlayer:@{@"quality":@[@"auto",@"720",@"1080",@"1440",@"2160"][self.playerQuality.selectedSegmentIndex]}];}
- (void)playerVolumeChanged {[self sendPlayer:@{@"volume":@(self.playerVolume.value)}];}
- (void)playerEQChanged {[self sendPlayer:@{@"eq":self.playerEQ.selectedSegmentIndex==1?@"music":@"normal"}];}
- (void)playerPauseTapped {[self sendPlayer:@{@"paused":[NSNumber numberWithBool:![self.playerState[@"paused"] boolValue]]}];}
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
 NSUInteger quality=[@[@"auto",@"720",@"1080",@"1440",@"2160"] indexOfObject:settings[@"quality"]?:@"auto"];self.playerQuality.selectedSegmentIndex=quality==NSNotFound?0:quality;
 self.playerEQ.selectedSegmentIndex=[settings[@"eq"] isEqual:@"music"]?1:0;
 UIButtonConfiguration *config=self.playerPause.configuration;config.title=[state[@"paused"] boolValue]?@"Play":@"Pause";self.playerPause.configuration=config;
 self.playerPosition.text=active?[NSString stringWithFormat:@"%ld:%02ld / %ld:%02ld · %@",(long)(position/60),(long)position%60,(long)(duration/60),(long)duration%60,[state[@"ready"] boolValue]?@"Car playback reported":@"Waiting for car player"]:@"Choose a video in YouTube after connecting AirPlay.";
}
// Build 86: the car stage tilts in 3D with the phone and the finger, floats and shines.
- (void)makeStage3D {
 SLAmbientCarView *car=self.car;
 CATransform3D perspective=CATransform3DIdentity;perspective.m34=-1.0/700;car.layer.transform=perspective;
 UILabel *live=[UILabel new];self.liveBadge=live;live.text=@"  ● LIVE  ";live.font=[UIFont systemFontOfSize:12 weight:UIFontWeightHeavy];live.textColor=UIColor.whiteColor;live.backgroundColor=[UIColor colorWithRed:.9 green:.15 blue:.3 alpha:.9];live.layer.cornerRadius=11;live.clipsToBounds=YES;live.hidden=YES;live.translatesAutoresizingMaskIntoConstraints=NO;[car addSubview:live];
 [NSLayoutConstraint activateConstraints:@[[live.topAnchor constraintEqualToAnchor:car.topAnchor constant:14],[live.leadingAnchor constraintEqualToAnchor:car.leadingAnchor constant:14],[live.heightAnchor constraintEqualToConstant:22]]];
 if(!SLMotionAllowed())return;
 CABasicAnimation *blink=[CABasicAnimation animationWithKeyPath:@"opacity"];blink.fromValue=@1;blink.toValue=@.45;blink.duration=.8;blink.autoreverses=YES;blink.repeatCount=HUGE_VALF;[live.layer addAnimation:blink forKey:@"blink"];
 UIInterpolatingMotionEffect *tiltX=[[UIInterpolatingMotionEffect alloc]initWithKeyPath:@"layer.transform" type:UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis];
 tiltX.minimumRelativeValue=[NSValue valueWithCATransform3D:CATransform3DRotate(perspective,-.16,0,1,0)];tiltX.maximumRelativeValue=[NSValue valueWithCATransform3D:CATransform3DRotate(perspective,.16,0,1,0)];
 UIInterpolatingMotionEffect *tiltY=[[UIInterpolatingMotionEffect alloc]initWithKeyPath:@"layer.transform" type:UIInterpolatingMotionEffectTypeTiltAlongVerticalAxis];
 tiltY.minimumRelativeValue=[NSValue valueWithCATransform3D:CATransform3DRotate(perspective,.12,1,0,0)];tiltY.maximumRelativeValue=[NSValue valueWithCATransform3D:CATransform3DRotate(perspective,-.12,1,0,0)];
 UIMotionEffectGroup *group=[UIMotionEffectGroup new];group.motionEffects=@[tiltX,tiltY];[car addMotionEffect:group];
 CABasicAnimation *bob=[CABasicAnimation animationWithKeyPath:@"transform.translation.y"];bob.fromValue=@-4;bob.toValue=@4;bob.additive=YES;bob.duration=3.2;bob.autoreverses=YES;bob.repeatCount=HUGE_VALF;bob.timingFunction=[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];[car.layer addAnimation:bob forKey:@"float"];
 CABasicAnimation *sweep=[CABasicAnimation animationWithKeyPath:@"locations"];sweep.fromValue=@[@-.4,@-.25,@-.1];sweep.toValue=@[@1.1,@1.25,@1.4];sweep.duration=1.6;sweep.timingFunction=[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
 CAAnimationGroup *shine=[CAAnimationGroup animation];shine.animations=@[sweep];shine.duration=5.5;shine.repeatCount=HUGE_VALF;[car.sheen addAnimation:shine forKey:@"shine"];
 car.userInteractionEnabled=YES;[car addGestureRecognizer:[[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(stagePanned:)]];
}
- (void)stagePanned:(UIPanGestureRecognizer *)pan {
 CATransform3D base=CATransform3DIdentity;base.m34=-1.0/700;
 if(pan.state==UIGestureRecognizerStateBegan||pan.state==UIGestureRecognizerStateChanged){
  CGPoint t=[pan translationInView:self.car];CGFloat w=MAX(1,self.car.bounds.size.width),h=MAX(1,self.car.bounds.size.height);
  CGFloat ry=MAX(-.45,MIN(.45,t.x/w*.9)),rx=MAX(-.35,MIN(.35,-t.y/h*.7));
  self.car.transform3D=CATransform3DRotate(CATransform3DRotate(base,ry,0,1,0),rx,1,0,0);
 }else{
  [UIView animateWithDuration:.9 delay:0 usingSpringWithDamping:.45 initialSpringVelocity:.6 options:UIViewAnimationOptionAllowUserInteraction animations:^{self.car.transform3D=base;} completion:nil];
 }
}
// Start button: flowing gradient, moving shine, press bounce and a haptic tap.
- (void)makeStartButtonAlive {
 UIButtonConfiguration *config=self.startButton.configuration;
 UIView *fill=[UIView new];fill.userInteractionEnabled=NO;fill.clipsToBounds=YES;
 CAGradientLayer *gradient=[CAGradientLayer layer];gradient.colors=@[(id)[UIColor colorWithRed:.12 green:.78 blue:.62 alpha:1].CGColor,(id)[UIColor colorWithRed:.15 green:.55 blue:.95 alpha:1].CGColor,(id)[UIColor colorWithRed:.55 green:.35 blue:.98 alpha:1].CGColor];gradient.startPoint=CGPointMake(0,.5);gradient.endPoint=CGPointMake(1,.5);gradient.frame=CGRectMake(0,0,800,90);[fill.layer addSublayer:gradient];
 self.startShine=[CAGradientLayer layer];self.startShine.colors=@[(id)[UIColor colorWithWhite:1 alpha:0].CGColor,(id)[UIColor colorWithWhite:1 alpha:.45].CGColor,(id)[UIColor colorWithWhite:1 alpha:0].CGColor];self.startShine.startPoint=CGPointMake(0,.5);self.startShine.endPoint=CGPointMake(1,.5);self.startShine.locations=@[@-.3,@-.15,@0];self.startShine.frame=CGRectMake(0,0,800,90);[fill.layer addSublayer:self.startShine];
 config.background.customView=fill;config.baseForegroundColor=UIColor.whiteColor;self.startButton.configuration=config;
 self.startButton.layer.shadowColor=[UIColor colorWithRed:.2 green:.9 blue:.75 alpha:1].CGColor;self.startButton.layer.shadowOpacity=.45;self.startButton.layer.shadowRadius=16;self.startButton.layer.shadowOffset=CGSizeMake(0,6);
 [self.startButton addTarget:self action:@selector(startPressed) forControlEvents:UIControlEventTouchDown|UIControlEventTouchDragEnter];
 [self.startButton addTarget:self action:@selector(startReleased) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside|UIControlEventTouchCancel|UIControlEventTouchDragExit];
 if(!SLMotionAllowed())return;
 CABasicAnimation *flow=[CABasicAnimation animationWithKeyPath:@"startPoint"];flow.fromValue=[NSValue valueWithCGPoint:CGPointMake(0,.5)];flow.toValue=[NSValue valueWithCGPoint:CGPointMake(-.6,.5)];flow.duration=3.5;flow.autoreverses=YES;flow.repeatCount=HUGE_VALF;[gradient addAnimation:flow forKey:@"flow"];
 CABasicAnimation *sweep=[CABasicAnimation animationWithKeyPath:@"locations"];sweep.fromValue=@[@-.3,@-.15,@0];sweep.toValue=@[@.5,@.65,@.8];sweep.duration=1.2;
 CAAnimationGroup *shine=[CAAnimationGroup animation];shine.animations=@[sweep];shine.duration=3.8;shine.repeatCount=HUGE_VALF;[self.startShine addAnimation:shine forKey:@"shine"];
}
- (void)startPressed {[[[UIImpactFeedbackGenerator alloc]initWithStyle:UIImpactFeedbackStyleMedium] impactOccurred];[UIView animateWithDuration:.12 animations:^{self.startButton.transform=CGAffineTransformMakeScale(.95,.95);}];}
- (void)startReleased {[UIView animateWithDuration:.5 delay:0 usingSpringWithDamping:.45 initialSpringVelocity:.8 options:UIViewAnimationOptionAllowUserInteraction animations:^{self.startButton.transform=CGAffineTransformIdentity;} completion:nil];}
// Sections rise in one after another the first time Home appears.
- (void)playEntrance {
 if(self.entranceDone||!self.window)return;self.entranceDone=YES;if(!SLMotionAllowed())return;
 [self.window layoutIfNeeded];
 if([self startCinematicEntrance])return;
 [self revealHomeParts:.05];
}
- (void)revealHomeParts:(NSTimeInterval)delay {
 NSArray<UIView *> *views=self.mainStack.arrangedSubviews;
 [views enumerateObjectsUsingBlock:^(UIView *view,NSUInteger index,BOOL *stop){
  view.alpha=0;if(view!=self.car)view.transform=CGAffineTransformMakeTranslation(0,28);
  [UIView animateWithDuration:.75 delay:delay+index*.055 usingSpringWithDamping:.8 initialSpringVelocity:.4 options:UIViewAnimationOptionAllowUserInteraction animations:^{view.alpha=1;if(view!=self.car)view.transform=CGAffineTransformIdentity;} completion:nil];
 }];
}
// Build 117: cinematic entrance. Four car pictures (entrance-1…4.jpg, added to the app when it is packaged;
// without them this is skipped). The finger scrolls the camera: back of the car, along the side, the
// three-quarter view, then the lights come on and the picture flies into its place on Home.
- (BOOL)startCinematicEntrance {
 if(self.bounds.size.height<300||UIApplication.sharedApplication.applicationState==UIApplicationStateBackground)return NO;
 NSMutableArray<UIImage *> *pictures=[NSMutableArray array];
 for(int i=1;i<=4;i++){NSString *path=[NSBundle.mainBundle pathForResource:[NSString stringWithFormat:@"entrance-%d",i] ofType:@"jpg"];UIImage *image=path?[UIImage imageWithContentsOfFile:path]:nil;if(!image)return NO;[pictures addObject:image];}
 UIView *cover=[[UIView alloc]initWithFrame:self.bounds];cover.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;cover.clipsToBounds=YES;cover.accessibilityIdentifier=@"home.entrance";[self addSubview:cover];self.entrance=cover;
 self.entranceBack=[[UIView alloc]initWithFrame:cover.bounds];self.entranceBack.autoresizingMask=cover.autoresizingMask;self.entranceBack.backgroundColor=UIColor.blackColor;[cover addSubview:self.entranceBack];
 NSMutableArray *views=[NSMutableArray array];self.entranceFades=[NSMutableArray array];
 for(UIImage *picture in pictures){
  UIImageView *view=[[UIImageView alloc]initWithFrame:CGRectMake(0,0,160,90)];view.image=picture;view.contentMode=UIViewContentModeScaleAspectFill;view.clipsToBounds=YES;view.alpha=0;[cover addSubview:view];[views addObject:view];
  for(int edge=0;edge<2;edge++){SLFadeView *fade=[[SLFadeView alloc]initWithFrame:CGRectMake(0,edge?66:0,160,24)];fade.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight|(edge?UIViewAutoresizingFlexibleTopMargin:UIViewAutoresizingFlexibleBottomMargin);
   CAGradientLayer *gradient=(CAGradientLayer *)fade.layer;gradient.colors=edge?@[(id)UIColor.clearColor.CGColor,(id)UIColor.blackColor.CGColor]:@[(id)UIColor.blackColor.CGColor,(id)UIColor.clearColor.CGColor];[view addSubview:fade];[self.entranceFades addObject:fade];}
 }
 self.entranceImages=views;
 CGFloat top=self.safeAreaInsets.top,bottom=self.safeAreaInsets.bottom,W=cover.bounds.size.width,H=cover.bounds.size.height;
 UILabel *title=[[UILabel alloc]initWithFrame:CGRectMake(0,top+18,W,34)];title.autoresizingMask=UIViewAutoresizingFlexibleWidth;title.text=@"ScreenLink";title.textAlignment=NSTextAlignmentCenter;title.textColor=UIColor.whiteColor;title.font=[UIFont systemFontOfSize:26 weight:UIFontWeightSemibold];[cover addSubview:title];self.entranceTitle=title;
 UIView *status=[[UIView alloc]initWithFrame:CGRectMake(0,top+58,W,24)];status.autoresizingMask=UIViewAutoresizingFlexibleWidth;status.alpha=0;[cover addSubview:status];self.entranceStatus=status;
 UILabel *text=[[UILabel alloc]initWithFrame:status.bounds];text.autoresizingMask=UIViewAutoresizingFlexibleWidth;text.textAlignment=NSTextAlignmentCenter;text.textColor=UIColor.whiteColor;text.font=[UIFont systemFontOfSize:16 weight:UIFontWeightMedium];[status addSubview:text];self.entranceStatusText=text;
 UIView *hint=[[UIView alloc]initWithFrame:CGRectMake(0,H-bottom-92,W,60)];hint.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleTopMargin;[cover addSubview:hint];self.entranceHint=hint;
 UIImageView *arrow=[[UIImageView alloc]initWithImage:[UIImage systemImageNamed:@"chevron.down" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightMedium]]];arrow.tintColor=UIColor.whiteColor;arrow.contentMode=UIViewContentModeCenter;arrow.frame=CGRectMake(0,0,W,26);arrow.autoresizingMask=UIViewAutoresizingFlexibleWidth;[hint addSubview:arrow];
 UILabel *explore=[[UILabel alloc]initWithFrame:CGRectMake(0,30,W,24)];explore.autoresizingMask=UIViewAutoresizingFlexibleWidth;explore.text=@"Scroll to explore";explore.textAlignment=NSTextAlignmentCenter;explore.textColor=[UIColor colorWithWhite:1 alpha:.85];explore.font=[UIFont systemFontOfSize:16 weight:UIFontWeightMedium];[hint addSubview:explore];
 CABasicAnimation *bob=[CABasicAnimation animationWithKeyPath:@"transform.translation.y"];bob.fromValue=@0;bob.toValue=@7;bob.duration=.9;bob.autoreverses=YES;bob.repeatCount=HUGE_VALF;bob.timingFunction=[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];[arrow.layer addAnimation:bob forKey:@"bob"];
 UIScrollView *scroll=[[UIScrollView alloc]initWithFrame:cover.bounds];scroll.autoresizingMask=cover.autoresizingMask;scroll.contentSize=CGSizeMake(W,H*3.4);scroll.showsVerticalScrollIndicator=NO;scroll.bounces=NO;scroll.contentInsetAdjustmentBehavior=UIScrollViewContentInsetAdjustmentNever;scroll.decelerationRate=UIScrollViewDecelerationRateNormal;scroll.delegate=self;scroll.backgroundColor=UIColor.clearColor;[cover addSubview:scroll];self.entranceScroll=scroll;
 [scroll addGestureRecognizer:[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(entranceTapped)]];
 for(UIView *part in self.mainStack.arrangedSubviews)part.alpha=0;
 [self entranceProgress:0];cover.alpha=0;[UIView animateWithDuration:.6 animations:^{cover.alpha=1;}];
 return YES;
}
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
 if(scrollView!=self.entranceScroll||self.entranceLeaving||self.entranceLink)return;
 CGFloat range=scrollView.contentSize.height-scrollView.bounds.size.height;if(range>1)[self entranceProgress:scrollView.contentOffset.y/range];
}
// A tap plays the rest alone.
- (void)entranceTapped {
 if(self.entranceLeaving||self.entranceLink)return;self.entranceScroll.scrollEnabled=NO;self.entranceFrom=self.entranceNow;self.entranceStart=CACurrentMediaTime();
 self.entranceLink=[CADisplayLink displayLinkWithTarget:self selector:@selector(entranceFrame:)];[self.entranceLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
}
- (void)entranceFrame:(CADisplayLink *)link {
 CGFloat length=.5+2.6*(1-self.entranceFrom),t=MIN(1,(CACurrentMediaTime()-self.entranceStart)/length),eased=t*t*(3-2*t);
 [self entranceProgress:self.entranceFrom+(1-self.entranceFrom)*eased];
}
- (void)entranceProgress:(CGFloat)p {
 if(self.entranceLeaving||!self.entrance)return;p=MAX(0,MIN(1,p));self.entranceNow=p;
 CGFloat W=self.entrance.bounds.size.width,H=self.entrance.bounds.size.height;
 // from, to, zoom at start, zoom at end, focus x at start, focus x at end, focus y, place on screen (y)
 static const CGFloat k[4][8]={{0,.36,3.4,2.3,.518,.518,.51,.50},{.25,.68,2.6,2.6,.32,.68,.49,.48},{.56,.92,2.4,1.9,.50,.50,.50,.48},{.82,1,1.5,1.2,.52,.52,.52,.47}};
 CGFloat alpha[4]={1-SLStep(.25,.36,p),SLStep(.25,.36,p)*(1-SLStep(.56,.68,p)),SLStep(.56,.68,p)*(1-SLStep(.82,.92,p)),SLStep(.82,.92,p)};
 for(NSUInteger i=0;i<4&&i<self.entranceImages.count;i++){
  CGFloat t=(p-k[i][0])/(k[i][1]-k[i][0]),w=SLMix(k[i][2],k[i][3],t)*W,h=w*.5625,fx=SLMix(k[i][4],k[i][5],t);
  UIImageView *view=self.entranceImages[i];view.frame=CGRectMake(W/2-fx*w,k[i][7]*H-k[i][6]*h,w,h);view.alpha=alpha[i];
 }
 self.entranceHint.alpha=1-SLStep(0,.08,p);self.entranceStatus.alpha=SLStep(.86,.96,p);
 self.entranceStatusText.text=[NSString stringWithFormat:@"●  %@",self.statusLabel.text?:@""];
 if(p>=.995)[self finishEntrance];
}
- (void)finishEntrance {
 if(self.entranceLeaving)return;self.entranceLeaving=YES;[self.entranceLink invalidate];self.entranceLink=nil;self.entranceScroll.userInteractionEnabled=NO;
 [self layoutIfNeeded];UIImageView *last=self.entranceImages.lastObject;CGRect target=[self.car convertRect:self.car.bounds toView:self.entrance];
 [self revealHomeParts:.2];
 UIView *cover=self.entrance;
 [UIView animateWithDuration:.85 delay:0 usingSpringWithDamping:.88 initialSpringVelocity:0 options:0 animations:^{
  last.frame=target;last.layer.cornerRadius=28;self.entranceBack.alpha=0;self.entranceTitle.alpha=0;self.entranceStatus.alpha=0;for(UIView *fade in self.entranceFades)fade.alpha=0;
 } completion:^(BOOL finished){
  [UIView animateWithDuration:.25 animations:^{cover.alpha=0;} completion:^(BOOL done){[cover removeFromSuperview];self.entrance=nil;self.entranceImages=nil;self.entranceFades=nil;self.entranceScroll=nil;}];
 }];
}
@end


