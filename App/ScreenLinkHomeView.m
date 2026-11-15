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
@property(nonatomic,strong) UISwitch *mapsSwitch;
@property(nonatomic,strong) NSMutableDictionary<NSString *,NSDictionary *> *tileParts;
@property(nonatomic,strong) NSMutableDictionary<NSString *,NSNumber *> *tileOn;
@property(nonatomic,strong) UIScrollView *homePage,*videoPage;
@property(nonatomic,strong) UIVisualEffectView *videoBlur;
@property(nonatomic,strong) UIImageView *avatar;
@property(nonatomic,strong) UILabel *bigTime,*bigTimeSub,*videoTime,*linkText;
@property(nonatomic,strong) UIButton *barPause;
@property(nonatomic,strong) NSArray<UIButton *> *tabButtons;
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
// Build 148: glass Home chosen by the user (from the Dribbble style they sent): the car photo fills the
// screen, a black status card at the top (like the Dynamic Island) with Open YouTube, the car video time in
// big numbers, a glass bar with Pause, glass tiles with their name and a green ON / grey OFF badge, Start /
// Stop ScreenLink, and a bottom bar with names: Home · Video · Map · Menu. Every old action and test name
// is kept (home.start, home.disconnect, home.developer, home.copy, home.maps, home.scroll, player.*).
static UIColor *SLGlassFill(void){return [UIColor colorWithRed:.43 green:.45 blue:.49 alpha:.34];}
- (UIVisualEffectView *)glassBox:(CGFloat)radius {
 UIVisualEffectView *box=[[UIVisualEffectView alloc]initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark]];
 box.layer.cornerRadius=radius;box.layer.cornerCurve=kCACornerCurveContinuous;box.clipsToBounds=YES;box.layer.borderWidth=1;box.layer.borderColor=[UIColor colorWithWhite:1 alpha:.15].CGColor;
 box.contentView.backgroundColor=SLGlassFill();return box;
}
- (void)fill:(UIView *)child in:(UIView *)parent inset:(UIEdgeInsets)inset {
 child.translatesAutoresizingMaskIntoConstraints=NO;[parent addSubview:child];
 [NSLayoutConstraint activateConstraints:@[[child.topAnchor constraintEqualToAnchor:parent.topAnchor constant:inset.top],[child.bottomAnchor constraintEqualToAnchor:parent.bottomAnchor constant:-inset.bottom],[child.leadingAnchor constraintEqualToAnchor:parent.leadingAnchor constant:inset.left],[child.trailingAnchor constraintEqualToAnchor:parent.trailingAnchor constant:-inset.right]]];
}
- (UIImage *)symbol:(NSString *)name size:(CGFloat)size {return [UIImage systemImageNamed:name withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:size weight:UIImageSymbolWeightSemibold]];}
- (UIButton *)pill:(NSString *)title symbol:(NSString *)symbol background:(UIColor *)background foreground:(UIColor *)foreground action:(SEL)action {
 UIButtonConfiguration *c=UIButtonConfiguration.filledButtonConfiguration;c.title=title;c.image=symbol?[self symbol:symbol size:14]:nil;c.imagePadding=7;c.baseBackgroundColor=background;c.baseForegroundColor=foreground;c.background.cornerRadius=14;c.contentInsets=NSDirectionalEdgeInsetsMake(9,14,9,14);
 c.titleTextAttributesTransformer=^NSDictionary *(NSDictionary *a){NSMutableDictionary *m=[a mutableCopy];m[NSFontAttributeName]=[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];return m;};
 UIButton *button=[UIButton buttonWithConfiguration:c primaryAction:nil];[button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];return button;
}
// A glass tile: icon, name (big), ON / OFF badge. Tap = switch.
- (UIControl *)tile:(NSString *)title symbol:(NSString *)symbol key:(NSString *)key {
 UIControl *tile=[UIControl new];tile.accessibilityIdentifier=[@"home.tile." stringByAppendingString:key];tile.isAccessibilityElement=YES;tile.accessibilityTraits=UIAccessibilityTraitButton;tile.accessibilityLabel=title;
 UIVisualEffectView *glass=[self glassBox:18];glass.userInteractionEnabled=NO;[self fill:glass in:tile inset:UIEdgeInsetsZero];
 [tile.heightAnchor constraintGreaterThanOrEqualToConstant:104].active=YES;
 UIImageView *icon=[[UIImageView alloc]initWithImage:[self symbol:symbol size:20]];icon.tintColor=UIColor.whiteColor;icon.contentMode=UIViewContentModeLeft;
 UILabel *name=[UILabel new];name.text=title;name.textColor=UIColor.whiteColor;name.font=[UIFontMetrics.defaultMetrics scaledFontForFont:[UIFont systemFontOfSize:16 weight:UIFontWeightBold]];name.adjustsFontForContentSizeCategory=YES;name.numberOfLines=2;name.adjustsFontSizeToFitWidth=YES;name.minimumScaleFactor=.75;
 UILabel *badge=[UILabel new];badge.font=[UIFont systemFontOfSize:13 weight:UIFontWeightHeavy];badge.textAlignment=NSTextAlignmentCenter;badge.layer.cornerRadius=8;badge.layer.masksToBounds=YES;[badge.heightAnchor constraintEqualToConstant:22].active=YES;[badge.widthAnchor constraintGreaterThanOrEqualToConstant:44].active=YES;
 UIStackView *words=[[UIStackView alloc]initWithArrangedSubviews:@[icon,[UIView new],name,badge]];words.axis=UILayoutConstraintAxisVertical;words.alignment=UIStackViewAlignmentLeading;words.spacing=4;words.userInteractionEnabled=NO;[self fill:words in:tile inset:UIEdgeInsetsMake(12,12,12,10)];
 self.tileParts[key]=@{@"tile":tile,@"badge":badge,@"glass":glass};
 [tile addTarget:self action:@selector(tileTapped:) forControlEvents:UIControlEventTouchUpInside];
 [tile addTarget:self action:@selector(tileDown:) forControlEvents:UIControlEventTouchDown|UIControlEventTouchDragEnter];[tile addTarget:self action:@selector(tileUp:) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside|UIControlEventTouchCancel|UIControlEventTouchDragExit];
 [self setTile:key on:NO text:@"OFF"];return tile;
}
- (void)tileDown:(UIControl *)tile {[UIView animateWithDuration:.12 animations:^{tile.transform=CGAffineTransformMakeScale(.95,.95);}];}
- (void)tileUp:(UIControl *)tile {[UIView animateWithDuration:.4 delay:0 usingSpringWithDamping:.6 initialSpringVelocity:.5 options:UIViewAnimationOptionAllowUserInteraction animations:^{tile.transform=CGAffineTransformIdentity;} completion:nil];}
- (void)setTile:(NSString *)key on:(BOOL)on text:(NSString *)text {
 NSDictionary *p=self.tileParts[key];if(!p)return;self.tileOn[key]=@(on);UILabel *badge=p[@"badge"];UIView *glass=p[@"glass"];
 badge.text=[NSString stringWithFormat:@" %@ ",text];badge.backgroundColor=on?[UIColor colorWithRed:.19 green:.82 blue:.35 alpha:1]:[UIColor colorWithWhite:1 alpha:.2];badge.textColor=on?[UIColor colorWithRed:.01 green:.13 blue:.05 alpha:1]:UIColor.whiteColor;
 glass.layer.borderColor=on?[UIColor colorWithRed:.47 green:1 blue:.78 alpha:.55].CGColor:[UIColor colorWithWhite:1 alpha:.15].CGColor;((UIControl *)p[@"tile"]).accessibilityValue=text;
}
- (void)tileTapped:(UIControl *)tile {
 NSString *key=[tile.accessibilityIdentifier stringByReplacingOccurrencesOfString:@"home.tile." withString:@""];
 [[[UIImpactFeedbackGenerator alloc]initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];
 if([key isEqual:@"tiktok"]||[key isEqual:@"waiting"]){if(self.moreAction)self.moreAction(key);return;}
 BOOL on=![self.tileOn[key] boolValue];[self setTile:key on:on text:on?@"ON":@"OFF"];
 if([key isEqual:@"maps"]){if(self.moreAction)self.moreAction(on?@"mapsOn":@"mapsOff");return;}
 if(self.moreAction)self.moreAction(key);
}
- (void)rowTapped:(UIControl *)row {if(self.moreAction)self.moreAction([row.accessibilityIdentifier stringByReplacingOccurrencesOfString:@"home.row." withString:@""]);}
- (void)videoRowTapped {[self showPage:1];}
- (void)waitingQuickTapped {if(self.moreAction)self.moreAction(@"waiting");}
// Old list lines are now tiles; their text says On / Open or Off.
- (void)setSubtitle:(NSString *)text forRow:(NSString *)key {
 if(!text.length)return;BOOL on=[text hasPrefix:@"On"]||[text hasPrefix:@"Open"];
 if([key isEqual:@"maps"]||[key isEqual:@"phonesound"]||[key isEqual:@"keep"]||[key isEqual:@"pip"])[self setTile:key on:on text:on?@"ON":@"OFF"];
}
- (void)setMapsSwitch:(BOOL)on {[self setTile:@"maps" on:on text:on?@"ON":@"OFF"];}
- (void)mapsSwitchChanged:(UISwitch *)toggle {if(self.moreAction)self.moreAction(toggle.on?@"mapsOn":@"mapsOff");}
- (void)showHeroImage:(UIImage *)image {if(self.heroDefault)image=self.heroDefault;self.heroImage.image=image;self.heroImage.hidden=image==nil;self.avatar.image=image?:[UIImage imageNamed:@"CarPoster.jpg"];}
- (UIButton *)button:(NSString *)title symbol:(NSString *)symbol action:(SEL)action filled:(BOOL)filled {
 UIButtonConfiguration *config=filled?UIButtonConfiguration.filledButtonConfiguration:UIButtonConfiguration.tintedButtonConfiguration;
 config.title=title.length?title:nil;config.image=[self symbol:symbol size:filled?30:22];config.imagePadding=8;config.cornerStyle=UIButtonConfigurationCornerStyleCapsule;config.contentInsets=NSDirectionalEdgeInsetsMake(16,16,16,16);
 config.baseBackgroundColor=filled?[UIColor colorWithWhite:.95 alpha:1]:[UIColor colorWithWhite:1 alpha:.16];config.baseForegroundColor=filled?UIColor.blackColor:UIColor.whiteColor;
 UIButton *button=[UIButton buttonWithConfiguration:config primaryAction:nil];[button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];return button;
}
- (UILabel *)white:(NSString *)text size:(CGFloat)size weight:(UIFontWeight)weight {UILabel *l=[UILabel new];l.text=text;l.textColor=UIColor.whiteColor;l.font=[UIFontMetrics.defaultMetrics scaledFontForFont:[UIFont systemFontOfSize:size weight:weight]];l.adjustsFontForContentSizeCategory=YES;l.numberOfLines=0;return l;}
- (UIScrollView *)pageScroll:(UIStackView *)stack identifier:(NSString *)identifier {
 UIScrollView *scroll=[UIScrollView new];scroll.alwaysBounceVertical=YES;scroll.showsVerticalScrollIndicator=NO;scroll.accessibilityIdentifier=identifier;scroll.backgroundColor=UIColor.clearColor;
 stack.axis=UILayoutConstraintAxisVertical;stack.translatesAutoresizingMaskIntoConstraints=NO;[scroll addSubview:stack];
 NSLayoutConstraint *width=[stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-28];width.priority=999;
 [NSLayoutConstraint activateConstraints:@[[scroll.contentLayoutGuide.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor],[stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:6],[stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-110],[stack.centerXAnchor constraintEqualToAnchor:scroll.centerXAnchor],width,[stack.widthAnchor constraintLessThanOrEqualToConstant:620]]];
 return scroll;
}
- (instancetype)initWithFrame:(CGRect)frame {
 if((self=[super initWithFrame:frame])){
  self.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;self.backgroundColor=UIColor.blackColor;self.idleAllowed=YES;self.clipsToBounds=YES;
  self.rowDetails=[NSMutableDictionary dictionary];self.tileParts=[NSMutableDictionary dictionary];self.tileOn=[NSMutableDictionary dictionary];
  // The car photo fills the screen (the user's own picture when there is one), darker at the top and bottom.
  self.car=[SLAmbientCarView new];self.car.layer.cornerRadius=0;self.car.layer.borderWidth=0;self.car.sheen.hidden=YES;self.car.isAccessibilityElement=NO;[self fill:self.car in:self inset:UIEdgeInsetsZero];
  self.heroImage=[UIImageView new];self.heroImage.contentMode=UIViewContentModeScaleAspectFill;self.heroImage.clipsToBounds=YES;self.heroImage.hidden=YES;[self fill:self.heroImage in:self.car inset:UIEdgeInsetsZero];
  SLFadeView *shade=[SLFadeView new];shade.userInteractionEnabled=NO;((CAGradientLayer *)shade.layer).colors=@[(id)[UIColor colorWithWhite:0 alpha:.45].CGColor,(id)[UIColor colorWithWhite:0 alpha:.1].CGColor,(id)[UIColor colorWithWhite:0 alpha:.35].CGColor,(id)[UIColor colorWithWhite:0 alpha:.85].CGColor];((CAGradientLayer *)shade.layer).locations=@[@0,@.3,@.55,@1];[self fill:shade in:self.car inset:UIEdgeInsetsZero];
  self.videoBlur=[[UIVisualEffectView alloc]initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];self.videoBlur.alpha=0;self.videoBlur.userInteractionEnabled=NO;[self fill:self.videoBlur in:self.car inset:UIEdgeInsetsZero];
  self.avatar=[UIImageView new];
  {NSString *path=[NSBundle.mainBundle pathForResource:@"entrance-4" ofType:@"jpg"];self.heroDefault=path?[UIImage imageWithContentsOfFile:path]:nil;[self showHeroImage:nil];}

  // ---------- Home page ----------
  UIStackView *stack=[UIStackView new];self.mainStack=stack;stack.spacing=12;
  UIScrollView *home=[self pageScroll:stack identifier:@"home.scroll"];[self fill:home in:self inset:UIEdgeInsetsZero];self.homePage=home;
  // Black status card (like the Dynamic Island).
  UIView *island=[UIView new];island.backgroundColor=UIColor.blackColor;island.layer.cornerRadius=32;island.layer.cornerCurve=kCACornerCurveContinuous;
  UIImageView *carIcon=[[UIImageView alloc]initWithImage:[self symbol:@"car.fill" size:11]];carIcon.tintColor=UIColor.whiteColor;carIcon.contentMode=UIViewContentModeCenter;carIcon.backgroundColor=[UIColor colorWithRed:.12 green:.5 blue:.42 alpha:1];carIcon.layer.cornerRadius=11;carIcon.clipsToBounds=YES;[carIcon.widthAnchor constraintEqualToConstant:22].active=YES;[carIcon.heightAnchor constraintEqualToConstant:22].active=YES;
  UILabel *carStatus=[self white:@"Car Status" size:14 weight:UIFontWeightBold];
  UIButton *help=[self roundButton:@"questionmark.circle" label:@"Help" action:@selector(helpTapped)];help.accessibilityIdentifier=@"home.help";
  UIButton *copy=[self roundButton:@"link" label:@"Copy the car website link" action:@selector(copyTapped)];copy.accessibilityIdentifier=@"home.copy";
  for(UIButton *b in @[help,copy]){UIButtonConfiguration *c=b.configuration;c.baseForegroundColor=[UIColor colorWithWhite:1 alpha:.85];c.image=[self symbol:(b==help?@"questionmark.circle":@"link") size:17];c.contentInsets=NSDirectionalEdgeInsetsMake(6,6,6,6);b.configuration=c;}
  UILabel *live=[UILabel new];self.liveBadge=live;live.text=@"  ● LIVE  ";live.font=[UIFont systemFontOfSize:12 weight:UIFontWeightHeavy];live.textColor=UIColor.whiteColor;live.backgroundColor=[UIColor colorWithWhite:.17 alpha:1];live.layer.cornerRadius=9;live.clipsToBounds=YES;live.hidden=YES;[live.heightAnchor constraintEqualToConstant:22].active=YES;
  UIStackView *head=[[UIStackView alloc]initWithArrangedSubviews:@[carIcon,carStatus,[UIView new],live,help,copy]];head.spacing=7;head.alignment=UIStackViewAlignmentCenter;
  self.avatar.contentMode=UIViewContentModeScaleAspectFill;self.avatar.clipsToBounds=YES;self.avatar.layer.cornerRadius=36;self.avatar.layer.borderWidth=3;self.avatar.layer.borderColor=UIColor.whiteColor.CGColor;[self.avatar.widthAnchor constraintEqualToConstant:72].active=YES;[self.avatar.heightAnchor constraintEqualToConstant:72].active=YES;[self showHeroImage:nil];
  self.statusDot=[UIView new];self.statusDot.layer.cornerRadius=5;self.statusDot.backgroundColor=UIColor.systemGrayColor;[self.statusDot.widthAnchor constraintEqualToConstant:10].active=YES;[self.statusDot.heightAnchor constraintEqualToConstant:10].active=YES;
  self.statusLabel=[self white:@"Ready to connect" size:17 weight:UIFontWeightSemibold];self.statusLabel.numberOfLines=2;self.statusLabel.accessibilityIdentifier=@"home.status";
  UIStackView *statusRow=[[UIStackView alloc]initWithArrangedSubviews:@[self.statusDot,self.statusLabel]];statusRow.spacing=7;statusRow.alignment=UIStackViewAlignmentCenter;
  self.detailLabel=[self white:@"Turn on Personal Hotspot, then tap Start." size:13 weight:UIFontWeightRegular];self.detailLabel.textColor=[UIColor colorWithWhite:.64 alpha:1];self.detailLabel.numberOfLines=3;self.detailLabel.accessibilityIdentifier=@"home.detail";
  UIButton *youtube=[self pill:@"Open YouTube" symbol:@"play.rectangle" background:[UIColor colorWithWhite:.11 alpha:1] foreground:[UIColor colorWithWhite:.85 alpha:1] action:@selector(openYouTubeTapped)];youtube.accessibilityIdentifier=@"home.youtube";
  UIStackView *words=[[UIStackView alloc]initWithArrangedSubviews:@[statusRow,self.detailLabel,youtube]];words.axis=UILayoutConstraintAxisVertical;words.spacing=5;[words setCustomSpacing:10 afterView:self.detailLabel];
  UIStackView *body=[[UIStackView alloc]initWithArrangedSubviews:@[self.avatar,words]];body.spacing=14;body.alignment=UIStackViewAlignmentCenter;
  UIStackView *islandStack=[[UIStackView alloc]initWithArrangedSubviews:@[head,body]];islandStack.axis=UILayoutConstraintAxisVertical;islandStack.spacing=10;[self fill:islandStack in:island inset:UIEdgeInsetsMake(14,16,16,14)];
  [stack addArrangedSubview:island];
  UIStackView *steps=[UIStackView new];steps.axis=UILayoutConstraintAxisVertical;steps.spacing=6;steps.layoutMargins=UIEdgeInsetsMake(14,16,14,16);steps.layoutMarginsRelativeArrangement=YES;steps.backgroundColor=[UIColor colorWithWhite:0 alpha:.72];steps.layer.cornerRadius=18;
  [steps addArrangedSubview:[self white:@"Connect in three steps" size:16 weight:UIFontWeightBold]];
  for(NSString *line in @[@"1   Turn on Personal Hotspot and let the car join it.",@"2   In YouTube tap the TV icon → ScreenLink VPN Phone.",@"3   Open car.tesla4khmer.com/video in the car."]){UILabel *l=[self white:line size:14 weight:UIFontWeightRegular];l.textColor=[UIColor colorWithWhite:.8 alpha:1];[steps addArrangedSubview:l];}
  steps.hidden=YES;self.helpCard=steps;[stack addArrangedSubview:steps];
  // Big time of the car video.
  self.bigTime=[self white:@"Ready" size:46 weight:UIFontWeightBold];self.bigTime.numberOfLines=1;self.bigTime.adjustsFontSizeToFitWidth=YES;self.bigTime.minimumScaleFactor=.5;
  self.bigTimeSub=[self white:@"Choose a video in YouTube" size:14 weight:UIFontWeightSemibold];
  UIStackView *time=[[UIStackView alloc]initWithArrangedSubviews:@[self.bigTime,self.bigTimeSub]];time.axis=UILayoutConstraintAxisVertical;time.spacing=0;time.layoutMargins=UIEdgeInsetsMake(0,8,0,8);time.layoutMarginsRelativeArrangement=YES;
  UIView *gap=[UIView new];[gap.heightAnchor constraintGreaterThanOrEqualToConstant:150].active=YES;
  [stack setCustomSpacing:26 afterView:steps];[stack addArrangedSubview:time];[stack addArrangedSubview:gap];
  self.previewHost=[UIView new];self.previewHost.backgroundColor=UIColor.blackColor;self.previewHost.layer.cornerRadius=18;self.previewHost.clipsToBounds=YES;self.previewHost.hidden=YES;
  NSLayoutConstraint *previewHeight=[self.previewHost.heightAnchor constraintEqualToConstant:160];previewHeight.priority=750;previewHeight.active=YES;[stack addArrangedSubview:self.previewHost];
  // Glass bar: connection in words + Pause / Play.
  UIView *bar=[UIView new];UIVisualEffectView *barGlass=[self glassBox:16];[self fill:barGlass in:bar inset:UIEdgeInsetsZero];
  self.linkText=[self white:@"Waiting for the car" size:15 weight:UIFontWeightMedium];self.linkText.numberOfLines=1;self.linkText.adjustsFontSizeToFitWidth=YES;self.linkText.minimumScaleFactor=.7;
  self.barPause=[self pill:@"Pause" symbol:@"pause.fill" background:[UIColor colorWithWhite:1 alpha:.2] foreground:UIColor.whiteColor action:@selector(playerPauseTapped)];self.barPause.hidden=YES;
  UIStackView *barLine=[[UIStackView alloc]initWithArrangedSubviews:@[self.linkText,self.barPause]];barLine.spacing=8;barLine.alignment=UIStackViewAlignmentCenter;[self fill:barLine in:bar inset:UIEdgeInsetsMake(6,16,6,6)];[bar.heightAnchor constraintGreaterThanOrEqualToConstant:50].active=YES;
  [stack addArrangedSubview:bar];
  // Glass tiles.
  UIStackView *row1=[[UIStackView alloc]initWithArrangedSubviews:@[[self tile:@"Phone sound" symbol:@"speaker.wave.2.fill" key:@"phonesound"],[self tile:@"Keep playing" symbol:@"repeat" key:@"keep"],[self tile:@"Maps" symbol:@"map.fill" key:@"maps"]]];
  UIStackView *row2=[[UIStackView alloc]initWithArrangedSubviews:@[[self tile:@"Small window" symbol:@"pip.fill" key:@"pip"],[self tile:@"Waiting screen" symbol:@"photo.on.rectangle" key:@"waiting"],[self tile:@"TikTok" symbol:@"music.note" key:@"tiktok"]]];
  for(UIStackView *r in @[row1,row2]){r.spacing=10;r.distribution=UIStackViewDistributionFillEqually;}
  [self setTile:@"waiting" on:NO text:@"OPEN"];[self setTile:@"tiktok" on:NO text:@"OPEN"];
  UIStackView *tiles=[[UIStackView alloc]initWithArrangedSubviews:@[row1,row2]];tiles.axis=UILayoutConstraintAxisVertical;tiles.spacing=10;[stack addArrangedSubview:tiles];
  // Start / Stop ScreenLink.
  self.startButton=[self wideButton:@"Start ScreenLink" symbol:@"play.fill" color:[UIColor colorWithRed:.19 green:.82 blue:.35 alpha:1] action:@selector(startTapped)];self.startButton.accessibilityIdentifier=@"home.start";self.startButton.accessibilityLabel=@"Start";
  self.disconnectButton=[self wideButton:@"Stop ScreenLink" symbol:@"power" color:[UIColor colorWithRed:1 green:.42 blue:.4 alpha:1] action:@selector(disconnectTapped)];self.disconnectButton.accessibilityIdentifier=@"home.disconnect";self.disconnectButton.accessibilityLabel=@"Disconnect all";self.disconnectButton.hidden=YES;
  [stack addArrangedSubview:self.startButton];[stack addArrangedSubview:self.disconnectButton];

  // ---------- Video page ----------
  UIStackView *vstack=[UIStackView new];vstack.spacing=14;vstack.alignment=UIStackViewAlignmentFill;
  UIScrollView *video=[self pageScroll:vstack identifier:@"video.scroll"];[self fill:video in:self inset:UIEdgeInsetsZero];video.hidden=YES;self.videoPage=video;
  UIButton *playerTab=[self pill:@"Player" symbol:nil background:[UIColor colorWithWhite:.92 alpha:1] foreground:UIColor.blackColor action:@selector(noop)];
  UIButton *waitingTab=[self pill:@"Waiting screen" symbol:nil background:[UIColor colorWithWhite:1 alpha:.16] foreground:UIColor.whiteColor action:@selector(waitingQuickTapped)];
  for(UIButton *b in @[playerTab,waitingTab]){UIButtonConfiguration *c=b.configuration;c.background.cornerRadius=20;c.contentInsets=NSDirectionalEdgeInsetsMake(10,18,10,18);b.configuration=c;}
  UIStackView *vtabs=[[UIStackView alloc]initWithArrangedSubviews:@[playerTab,waitingTab,[UIView new]]];vtabs.spacing=8;[vstack addArrangedSubview:vtabs];
  UILabel *onCar=[self white:@"ON THE CAR" size:12 weight:UIFontWeightSemibold];onCar.textAlignment=NSTextAlignmentCenter;onCar.textColor=[UIColor colorWithWhite:1 alpha:.8];
  self.videoTime=[self white:@"0:00" size:60 weight:UIFontWeightBold];self.videoTime.textAlignment=NSTextAlignmentCenter;self.videoTime.numberOfLines=1;self.videoTime.adjustsFontSizeToFitWidth=YES;self.videoTime.minimumScaleFactor=.5;
  self.playerPosition=[self white:@"Waiting for video" size:14 weight:UIFontWeightSemibold];self.playerPosition.textAlignment=NSTextAlignmentCenter;
  UIStackView *vt=[[UIStackView alloc]initWithArrangedSubviews:@[onCar,self.videoTime,self.playerPosition]];vt.axis=UILayoutConstraintAxisVertical;vt.spacing=0;[vstack setCustomSpacing:30 afterView:vtabs];[vstack addArrangedSubview:vt];
  self.playerBack=[self button:@"" symbol:@"gobackward.10" action:@selector(playerBackTapped) filled:NO];self.playerBack.accessibilityLabel=@"Rewind car video ten seconds";
  self.playerPause=[self button:@"" symbol:@"pause.fill" action:@selector(playerPauseTapped) filled:YES];self.playerPause.accessibilityIdentifier=@"player.pause";self.playerPause.accessibilityLabel=@"Pause";
  self.playerForward=[self button:@"" symbol:@"goforward.10" action:@selector(playerForwardTapped) filled:NO];self.playerForward.accessibilityLabel=@"Forward car video ten seconds";
  for(UIButton *b in @[self.playerBack,self.playerForward]){[b.widthAnchor constraintEqualToConstant:64].active=YES;[b.heightAnchor constraintEqualToConstant:64].active=YES;}
  [self.playerPause.widthAnchor constraintEqualToConstant:88].active=YES;[self.playerPause.heightAnchor constraintEqualToConstant:88].active=YES;
  UIStackView *pb=[[UIStackView alloc]initWithArrangedSubviews:@[self.playerBack,self.playerPause,self.playerForward]];pb.spacing=26;pb.alignment=UIStackViewAlignmentCenter;
  UIStackView *pbWrap=[[UIStackView alloc]initWithArrangedSubviews:@[pb]];pbWrap.axis=UILayoutConstraintAxisVertical;pbWrap.alignment=UIStackViewAlignmentCenter;[vstack setCustomSpacing:40 afterView:vt];[vstack addArrangedSubview:pbWrap];
  self.playerSeek=[UISlider new];self.playerSeek.minimumValue=0;self.playerSeek.maximumValue=1;self.playerSeek.continuous=NO;self.playerSeek.minimumTrackTintColor=UIColor.whiteColor;self.playerSeek.accessibilityLabel=@"Car video position";self.playerSeek.accessibilityIdentifier=@"player.seek";[self.playerSeek addTarget:self action:@selector(playerSeekChanged) forControlEvents:UIControlEventValueChanged];
  [vstack setCustomSpacing:30 afterView:pbWrap];[vstack addArrangedSubview:self.playerSeek];
  UIView *opts=[UIView new];UIVisualEffectView *optsGlass=[self glassBox:22];[self fill:optsGlass in:opts inset:UIEdgeInsetsZero];
  UIStackView *o=[UIStackView new];o.axis=UILayoutConstraintAxisVertical;o.spacing=8;[self fill:o in:opts inset:UIEdgeInsetsMake(16,16,18,16)];
  [o addArrangedSubview:[self white:@"Quality" size:16 weight:UIFontWeightBold]];
  self.playerQuality=[[UISegmentedControl alloc]initWithItems:@[@"Auto",@"720p",@"1080p",@"1440p",@"4K"]];self.playerQuality.selectedSegmentIndex=0;self.playerQuality.accessibilityIdentifier=@"player.quality";[self.playerQuality addTarget:self action:@selector(playerQualityChanged) forControlEvents:UIControlEventValueChanged];[self.playerQuality.heightAnchor constraintGreaterThanOrEqualToConstant:40].active=YES;[o addArrangedSubview:self.playerQuality];
  [o setCustomSpacing:16 afterView:self.playerQuality];[o addArrangedSubview:[self white:@"Sound" size:16 weight:UIFontWeightBold]];
  self.playerEQ=[[UISegmentedControl alloc]initWithItems:@[@"Normal",@"Music"]];self.playerEQ.selectedSegmentIndex=0;self.playerEQ.accessibilityLabel=@"Car sound preset";[self.playerEQ addTarget:self action:@selector(playerEQChanged) forControlEvents:UIControlEventValueChanged];[self.playerEQ.heightAnchor constraintGreaterThanOrEqualToConstant:40].active=YES;[o addArrangedSubview:self.playerEQ];
  [o setCustomSpacing:16 afterView:self.playerEQ];[o addArrangedSubview:[self white:@"Car volume" size:16 weight:UIFontWeightBold]];
  UIImageView *quiet=[[UIImageView alloc]initWithImage:[UIImage systemImageNamed:@"speaker.fill"]],*loud=[[UIImageView alloc]initWithImage:[UIImage systemImageNamed:@"speaker.wave.3.fill"]];quiet.tintColor=loud.tintColor=[UIColor colorWithWhite:1 alpha:.8];
  self.playerVolume=[UISlider new];self.playerVolume.minimumValue=0;self.playerVolume.maximumValue=1;self.playerVolume.value=1;self.playerVolume.continuous=NO;self.playerVolume.minimumTrackTintColor=UIColor.whiteColor;self.playerVolume.accessibilityLabel=@"Car player volume";self.playerVolume.accessibilityIdentifier=@"player.volume";[self.playerVolume addTarget:self action:@selector(playerVolumeChanged) forControlEvents:UIControlEventValueChanged];
  UIStackView *vol=[[UIStackView alloc]initWithArrangedSubviews:@[quiet,self.playerVolume,loud]];vol.spacing=10;vol.alignment=UIStackViewAlignmentCenter;[o addArrangedSubview:vol];
  self.playerHint=[self white:@"Choose videos in YouTube. These buttons control the car player." size:12 weight:UIFontWeightRegular];self.playerHint.textColor=[UIColor colorWithWhite:1 alpha:.6];[o addArrangedSubview:self.playerHint];
  [vstack addArrangedSubview:opts];self.controlsCard=opts;

  // ---------- Bottom bar: Home · Video · Map · Menu ----------
  UIView *tabBar=[UIView new];UIVisualEffectView *tabGlass=[[UIVisualEffectView alloc]initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterialDark]];tabGlass.layer.cornerRadius=26;tabGlass.layer.cornerCurve=kCACornerCurveContinuous;tabGlass.clipsToBounds=YES;tabGlass.layer.borderWidth=1;tabGlass.layer.borderColor=[UIColor colorWithWhite:1 alpha:.12].CGColor;[self fill:tabGlass in:tabBar inset:UIEdgeInsetsZero];
  NSMutableArray *tabs=[NSMutableArray array];NSArray *names=@[@"Home",@"Video",@"Map",@"Menu"],*symbols=@[@"house",@"video",@"map",@"line.3.horizontal"],*ids=@[@"home.tab.home",@"home.tab.video",@"home.maps",@"home.developer"];
  for(NSUInteger i=0;i<4;i++){UIButtonConfiguration *c=UIButtonConfiguration.plainButtonConfiguration;c.title=names[i];c.image=[self symbol:symbols[i] size:20];c.imagePlacement=NSDirectionalRectEdgeTop;c.imagePadding=4;c.baseForegroundColor=UIColor.whiteColor;c.background.cornerRadius=18;c.contentInsets=NSDirectionalEdgeInsetsMake(8,4,8,4);
   c.titleTextAttributesTransformer=^NSDictionary *(NSDictionary *a){NSMutableDictionary *m=[a mutableCopy];m[NSFontAttributeName]=[UIFont systemFontOfSize:12 weight:UIFontWeightBold];return m;};
   UIButton *t=[UIButton buttonWithConfiguration:c primaryAction:nil];t.tag=(NSInteger)i;t.accessibilityIdentifier=ids[i];[t addTarget:self action:@selector(tabTapped:) forControlEvents:UIControlEventTouchUpInside];[tabs addObject:t];}
  self.tabButtons=tabs;UIStackView *tabLine=[[UIStackView alloc]initWithArrangedSubviews:tabs];tabLine.distribution=UIStackViewDistributionFillEqually;tabLine.spacing=4;[self fill:tabLine in:tabBar inset:UIEdgeInsetsMake(6,6,6,6)];
  tabBar.translatesAutoresizingMaskIntoConstraints=NO;[self addSubview:tabBar];
  [NSLayoutConstraint activateConstraints:@[[tabBar.leadingAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.leadingAnchor constant:14],[tabBar.trailingAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.trailingAnchor constant:-14],[tabBar.bottomAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.bottomAnchor constant:-6]]];
  [self showPage:0];[self showPlayerState:@{}];
  NSNotificationCenter *notifications=NSNotificationCenter.defaultCenter;
  for(NSString *event in @[UIApplicationDidBecomeActiveNotification,UIApplicationWillResignActiveNotification,UIApplicationDidEnterBackgroundNotification,UIAccessibilityReduceMotionStatusDidChangeNotification])[notifications addObserver:self selector:@selector(ambientStateChanged:) name:event object:nil];
 }
 return self;
}
- (void)noop {}
- (UIButton *)wideButton:(NSString *)title symbol:(NSString *)symbol color:(UIColor *)color action:(SEL)action {
 UIButtonConfiguration *c=UIButtonConfiguration.filledButtonConfiguration;c.title=title;c.image=[self symbol:symbol size:16];c.imagePadding=9;c.baseForegroundColor=color;c.baseBackgroundColor=[UIColor colorWithWhite:.12 alpha:.78];c.background.cornerRadius=18;c.background.strokeColor=[color colorWithAlphaComponent:.5];c.background.strokeWidth=1;c.contentInsets=NSDirectionalEdgeInsetsMake(16,16,16,16);
 c.titleTextAttributesTransformer=^NSDictionary *(NSDictionary *a){NSMutableDictionary *m=[a mutableCopy];m[NSFontAttributeName]=[UIFont systemFontOfSize:18 weight:UIFontWeightBold];return m;};
 UIButton *b=[UIButton buttonWithConfiguration:c primaryAction:nil];[b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];[b.heightAnchor constraintGreaterThanOrEqualToConstant:56].active=YES;return b;
}
- (void)tabTapped:(UIButton *)tab {
 [[[UISelectionFeedbackGenerator alloc]init] selectionChanged];
 if(tab.tag==0)[self showPage:0];else if(tab.tag==1)[self showPage:1];else if(tab.tag==2)[self mapTapped];else [self developerTapped];
}
- (void)showPage:(NSInteger)page {
 self.homePage.hidden=page!=0;self.videoPage.hidden=page!=1;
 [UIView animateWithDuration:.3 animations:^{self.videoBlur.alpha=page==1?1:0;}];
 for(UIButton *t in self.tabButtons){UIButtonConfiguration *c=t.configuration;BOOL on=t.tag==page;c.background.backgroundColor=on?[UIColor colorWithWhite:1 alpha:.16]:UIColor.clearColor;c.baseForegroundColor=on?UIColor.whiteColor:[UIColor colorWithWhite:1 alpha:.7];t.configuration=c;}
}
- (void)helpTapped {[UIView animateWithDuration:.25 animations:^{self.helpCard.hidden=!self.helpCard.hidden;self.helpCard.alpha=self.helpCard.hidden?0:1;}];}
- (void)openYouTubeTapped {
 [[[UIImpactFeedbackGenerator alloc]initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];
 [UIApplication.sharedApplication openURL:[NSURL URLWithString:@"youtube://"] options:@{} completionHandler:^(BOOL ok){if(!ok)[UIApplication.sharedApplication openURL:[NSURL URLWithString:@"https://m.youtube.com"] options:@{} completionHandler:nil];}];
}
- (void)dealloc {[NSNotificationCenter.defaultCenter removeObserver:self];[self stopAmbient];}
- (void)didMoveToWindow {[super didMoveToWindow];[self updateAmbient];dispatch_async(dispatch_get_main_queue(),^{[self playEntrance];});}
- (void)setHidden:(BOOL)hidden {[super setHidden:hidden];[self updateAmbient];}
- (void)ambientStateChanged:(NSNotification *)note {if([note.name isEqual:UIApplicationWillResignActiveNotification]||[note.name isEqual:UIApplicationDidEnterBackgroundNotification])[self stopAmbient];else [self updateAmbient];}
- (void)stopAmbient {[self.ambientPlayer pause];self.car.videoLayer.player=nil;[self.ambientLooper disableLooping];self.ambientLooper=nil;[self.ambientPlayer removeAllItems];self.ambientPlayer=nil;}
- (void)updateAmbient {
 BOOL allowed=self.idleAllowed&&self.window&&!self.hidden&&!UIAccessibilityIsReduceMotionEnabled()&&UIApplication.sharedApplication.applicationState==UIApplicationStateActive&&self.heroImage.hidden;
 if(!allowed){[self stopAmbient];return;}if(self.ambientPlayer)return;
 NSURL *url=[NSBundle.mainBundle URLForResource:@"CarAmbient" withExtension:@"mp4"];if(!url)return;
 // Bundled clip has no audio track. Never configure the audio session or PiP here.
 self.ambientPlayer=[AVQueuePlayer queuePlayerWithItems:@[]];self.ambientPlayer.muted=YES;self.ambientPlayer.volume=0;
 self.ambientLooper=[AVPlayerLooper playerLooperWithPlayer:self.ambientPlayer templateItem:[AVPlayerItem playerItemWithURL:url]];
 self.car.videoLayer.player=self.ambientPlayer;[self.ambientPlayer play];
}
- (void)showStatus:(NSString *)status detail:(NSString *)detail busy:(BOOL)busy sharing:(BOOL)sharing disconnecting:(BOOL)disconnecting attention:(BOOL)attention {
 self.statusLabel.text=status;self.detailLabel.text=detail;self.startButton.enabled=!busy;self.disconnectButton.enabled=!disconnecting;self.previewHost.hidden=!(sharing&&self.screenPreview);
 self.startButton.hidden=sharing&&!busy;self.disconnectButton.hidden=!sharing&&!busy;
 UIButtonConfiguration *c=self.startButton.configuration;c.showsActivityIndicator=busy;self.startButton.configuration=c;
 self.idleAllowed=!busy&&!sharing;[self updateAmbient];
 UIColor *dot=attention?UIColor.systemOrangeColor:sharing?[UIColor colorWithRed:.25 green:.95 blue:.72 alpha:1]:busy?UIColor.systemBlueColor:UIColor.systemGrayColor;
 if(!attention&&!busy&&self.healthLevel>0)dot=self.healthLevel==1?UIColor.systemGreenColor:self.healthLevel==2?UIColor.systemYellowColor:UIColor.systemRedColor;self.statusDot.backgroundColor=dot;
 [self.statusDot.layer removeAnimationForKey:@"pulse"];if((sharing||busy||attention)&&SLMotionAllowed()){CABasicAnimation *pulse=[CABasicAnimation animationWithKeyPath:@"transform.scale"];pulse.fromValue=@1;pulse.toValue=@1.6;pulse.duration=.9;pulse.autoreverses=YES;pulse.repeatCount=HUGE_VALF;[self.statusDot.layer addAnimation:pulse forKey:@"pulse"];}
 self.liveBadge.hidden=!sharing;
 self.linkText.text=!sharing?(busy?@"Starting…":@"ScreenLink is off"):attention?@"Needs attention · see the card":self.healthLevel==1?@"Car connected":self.healthLevel==2?@"Waiting for the car":self.healthLevel==3?@"Car not answering":@"ScreenLink is on";
}
- (void)themeTapped {}
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
static NSString *SLClock(double seconds){long s=(long)MAX(0,seconds);return s>=3600?[NSString stringWithFormat:@"%ld:%02ld:%02ld",s/3600,(s%3600)/60,s%60]:[NSString stringWithFormat:@"%ld:%02ld",s/60,s%60];}
- (void)showPlayerState:(NSDictionary *)state {
 NSMutableDictionary *display=[state mutableCopy]?:[NSMutableDictionary dictionary];NSDictionary *pending=state[@"viewerControls"][@"playback"];if([pending[@"epoch"] isEqual:state[@"epoch"]])for(NSString *key in @[@"paused",@"seek"])if(pending[key])display[[key isEqual:@"seek"]?@"position":key]=pending[key];self.playerState=display;state=display;NSDictionary *settings=[state[@"viewerControls"] isKindOfClass:NSDictionary.class]?state[@"viewerControls"]:@{};
 BOOL enabled=[state[@"receiverRunning"] boolValue],active=[state[@"active"] boolValue],paused=[state[@"paused"] boolValue];
 self.playerQuality.enabled=enabled;self.playerVolume.enabled=enabled;self.playerEQ.enabled=enabled;
 self.playerPause.enabled=enabled&&active;self.playerBack.enabled=enabled&&active;self.playerForward.enabled=enabled&&active;
 double duration=[state[@"duration"] doubleValue],position=[state[@"position"] doubleValue];self.playerSeek.enabled=enabled&&active&&duration>0;
 if(!self.playerSeek.tracking)self.playerSeek.value=duration>0?position/duration:0;
 if(!self.playerVolume.tracking&&settings[@"volume"])self.playerVolume.value=[settings[@"volume"] floatValue];
 NSUInteger quality=[@[@"auto",@"720",@"1080",@"1440",@"2160"] indexOfObject:settings[@"quality"]?:@"auto"];self.playerQuality.selectedSegmentIndex=quality==NSNotFound?0:quality;
 self.playerEQ.selectedSegmentIndex=[settings[@"eq"] isEqual:@"music"]?1:0;
 UIButtonConfiguration *config=self.playerPause.configuration;config.title=nil;config.image=[self symbol:paused?@"play.fill":@"pause.fill" size:30];self.playerPause.configuration=config;self.playerPause.accessibilityLabel=paused?@"Play":@"Pause";
 UIButtonConfiguration *bar=self.barPause.configuration;bar.title=paused?@"Play":@"Pause";bar.image=[self symbol:paused?@"play.fill":@"pause.fill" size:14];self.barPause.configuration=bar;self.barPause.hidden=!active;
 NSString *quality2=@[@"Auto",@"720p",@"1080p",@"1440p",@"4K"][self.playerQuality.selectedSegmentIndex];
 self.bigTime.text=active?SLClock(position):@"Ready";self.videoTime.text=active?SLClock(position):@"0:00";
 self.bigTimeSub.text=active?[NSString stringWithFormat:@"on the car · %@ total%@",SLClock(duration),paused?@" · paused":@""]:@"Choose a video in YouTube";
 self.playerPosition.text=active?[NSString stringWithFormat:@"%@ of %@ · %@ · %@",SLClock(position),SLClock(duration),quality2,[state[@"ready"] boolValue]?@"playing on the car":@"waiting for the car"]:@"Choose a video in YouTube after connecting AirPlay.";
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


