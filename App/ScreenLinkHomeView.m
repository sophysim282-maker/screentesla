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
@property(nonatomic,strong) UISwitch *mapsSwitch,*pipSwitch;
@property(nonatomic,strong) NSMutableDictionary<NSString *,NSDictionary *> *tileParts;
@property(nonatomic,strong) NSMutableDictionary<NSString *,NSNumber *> *tileOn;
@property(nonatomic,strong) UIView *playerSection;
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
 NSString *key=[row.accessibilityIdentifier isEqual:@"home.maps"]?@"openmap":[row.accessibilityIdentifier isEqual:@"home.developer"]?@"more":[row.accessibilityIdentifier stringByReplacingOccurrencesOfString:@"home.row." withString:@""];
 [[[UISelectionFeedbackGenerator alloc]init] selectionChanged];
 if([key isEqual:@"video"]){[self videoRowTapped];return;}
 if([key isEqual:@"help"]){[UIView animateWithDuration:.25 animations:^{self.helpCard.hidden=!self.helpCard.hidden;self.helpCard.alpha=self.helpCard.hidden?0:1;}];return;}
 if([key isEqual:@"openmap"]||[key isEqual:@"maps"]){[self mapTapped];return;}
 if([key isEqual:@"more"]){[self developerTapped];return;}
 if(self.moreAction)self.moreAction(key);
}
- (void)videoRowTapped {[UIView animateWithDuration:.25 animations:^{self.controlsCard.hidden=!self.controlsCard.hidden;self.controlsCard.alpha=self.controlsCard.hidden?0:1;}];}
- (void)waitingQuickTapped {if(self.moreAction)self.moreAction(@"waiting");}
// Build 147: the old list lines are now tiles and switches; their text says On/Open or Off.
- (void)setSubtitle:(NSString *)text forRow:(NSString *)key {
 if(!text.length)return;BOOL on=[text hasPrefix:@"On"]||[text hasPrefix:@"Open"];
 if([key isEqual:@"maps"]||[key isEqual:@"phonesound"]||[key isEqual:@"keep"]){[self setTile:key on:on text:on?@"On":@"Off"];return;}
 if([key isEqual:@"pip"]){if(self.pipSwitch.on!=on)[self.pipSwitch setOn:on animated:YES];return;}
}
- (void)setMapsSwitch:(BOOL)on {[self setTile:@"maps" on:on text:on?@"On":@"Off"];}
- (void)mapsSwitchChanged:(UISwitch *)toggle {[[[UIImpactFeedbackGenerator alloc]initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];if(self.moreAction)self.moreAction(toggle.on?@"mapsOn":@"mapsOff");}
- (void)showHeroImage:(UIImage *)image {if(self.heroDefault)image=self.heroDefault;self.heroImage.image=image;self.heroImage.hidden=image==nil;}
- (UIButton *)button:(NSString *)title symbol:(NSString *)symbol action:(SEL)action filled:(BOOL)filled {
 UIButtonConfiguration *config=filled?UIButtonConfiguration.filledButtonConfiguration:UIButtonConfiguration.tintedButtonConfiguration;
 config.title=title;config.image=[UIImage systemImageNamed:symbol];config.imagePadding=10;config.cornerStyle=UIButtonConfigurationCornerStyleCapsule;config.contentInsets=NSDirectionalEdgeInsetsMake(16,18,16,18);
 config.baseBackgroundColor=filled?UIColor.systemBlueColor:UIColor.tertiarySystemFillColor;config.baseForegroundColor=filled?UIColor.whiteColor:UIColor.labelColor;
 UIButton *button=[UIButton buttonWithConfiguration:config primaryAction:nil];button.titleLabel.adjustsFontForContentSizeCategory=YES;[button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];return button;
}
// Build 147: Apple-style Home, like iPhone Settings and the Home app. Follows the iPhone's light or dark mode.
// Large title, a car card with the status and an Open YouTube button, four big tiles you tap once for On/Off,
// grouped lists with coloured square icons, and Start / Stop ScreenLink at the bottom. Every control keeps
// its old action and its old test name (home.start, home.disconnect, home.developer, player.*).
static UIColor *SLDyn(UIColor *light,UIColor *dark){return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t){return t.userInterfaceStyle==UIUserInterfaceStyleDark?dark:light;}];}
- (UIView *)squareIcon:(NSString *)symbol color:(UIColor *)color {
 UIView *box=[UIView new];box.backgroundColor=color;box.layer.cornerRadius=7;box.layer.cornerCurve=kCACornerCurveContinuous;box.translatesAutoresizingMaskIntoConstraints=NO;[box.widthAnchor constraintEqualToConstant:30].active=YES;[box.heightAnchor constraintEqualToConstant:30].active=YES;
 UIImageView *image=[[UIImageView alloc]initWithImage:[UIImage systemImageNamed:symbol withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightSemibold]]];image.tintColor=UIColor.whiteColor;image.translatesAutoresizingMaskIntoConstraints=NO;[box addSubview:image];
 [NSLayoutConstraint activateConstraints:@[[image.centerXAnchor constraintEqualToAnchor:box.centerXAnchor],[image.centerYAnchor constraintEqualToAnchor:box.centerYAnchor]]];return box;
}
// One line of a grouped list: coloured square icon, name, optional value, optional switch or arrow.
- (UIControl *)cell:(NSString *)title symbol:(NSString *)symbol color:(UIColor *)color key:(NSString *)key value:(NSString *)value accessory:(NSInteger)accessory {
 UIControl *row=[UIControl new];row.accessibilityIdentifier=[@"home.row." stringByAppendingString:key];row.isAccessibilityElement=accessory!=2;row.accessibilityTraits=UIAccessibilityTraitButton;row.accessibilityLabel=title;
 [row.heightAnchor constraintGreaterThanOrEqualToConstant:52].active=YES;
 UILabel *name=[UILabel new];name.text=title;name.font=[UIFont preferredFontForTextStyle:UIFontTextStyleBody];name.adjustsFontForContentSizeCategory=YES;name.textColor=UIColor.labelColor;name.numberOfLines=0;
 UILabel *detail=[UILabel new];detail.text=value;detail.font=[UIFont preferredFontForTextStyle:UIFontTextStyleBody];detail.adjustsFontForContentSizeCategory=YES;detail.textColor=UIColor.secondaryLabelColor;detail.textAlignment=NSTextAlignmentRight;[detail setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];self.rowDetails[key]=detail;
 NSMutableArray *parts=[NSMutableArray arrayWithObjects:[self squareIcon:symbol color:color],name,[UIView new],detail,nil];
 if(accessory==1){UIImageView *arrow=[[UIImageView alloc]initWithImage:[UIImage systemImageNamed:@"chevron.right" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightSemibold]]];arrow.tintColor=UIColor.tertiaryLabelColor;[arrow setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];[parts addObject:arrow];}
 UIStackView *line=[[UIStackView alloc]initWithArrangedSubviews:parts];line.spacing=13;line.alignment=UIStackViewAlignmentCenter;line.userInteractionEnabled=accessory==2;line.translatesAutoresizingMaskIntoConstraints=NO;[row addSubview:line];
 [NSLayoutConstraint activateConstraints:@[[line.topAnchor constraintEqualToAnchor:row.topAnchor constant:10],[line.bottomAnchor constraintEqualToAnchor:row.bottomAnchor constant:-10],[line.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:16],[line.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-16]]];
 if(accessory!=2)[row addTarget:self action:@selector(rowTapped:) forControlEvents:UIControlEventTouchUpInside];
 [row addTarget:self action:@selector(cellDown:) forControlEvents:UIControlEventTouchDown|UIControlEventTouchDragEnter];[row addTarget:self action:@selector(cellUp:) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside|UIControlEventTouchCancel|UIControlEventTouchDragExit];
 return row;
}
- (void)cellDown:(UIControl *)row {row.backgroundColor=UIColor.systemFillColor;}
- (void)cellUp:(UIControl *)row {[UIView animateWithDuration:.25 animations:^{row.backgroundColor=UIColor.clearColor;}];}
// A rounded group of cells with thin lines between them, like iPhone Settings.
- (UIView *)group:(NSArray<UIView *> *)cells {
 UIStackView *box=[UIStackView new];box.axis=UILayoutConstraintAxisVertical;box.backgroundColor=UIColor.secondarySystemGroupedBackgroundColor;box.layer.cornerRadius=12;box.layer.cornerCurve=kCACornerCurveContinuous;box.clipsToBounds=YES;
 [cells enumerateObjectsUsingBlock:^(UIView *cell,NSUInteger i,BOOL *stop){[box addArrangedSubview:cell];if(i+1<cells.count){UIView *sep=[UIView new];sep.backgroundColor=UIColor.separatorColor;[sep.heightAnchor constraintEqualToConstant:1/UIScreen.mainScreen.scale].active=YES;UIView *inset=[UIView new];[inset addSubview:sep];sep.translatesAutoresizingMaskIntoConstraints=NO;[NSLayoutConstraint activateConstraints:@[[sep.topAnchor constraintEqualToAnchor:inset.topAnchor],[sep.bottomAnchor constraintEqualToAnchor:inset.bottomAnchor],[sep.leadingAnchor constraintEqualToAnchor:inset.leadingAnchor constant:59],[sep.trailingAnchor constraintEqualToAnchor:inset.trailingAnchor]]];[box addArrangedSubview:inset];}}];
 return box;
}
- (UIView *)sectionHeader:(NSString *)text {UILabel *label=[UILabel new];label.text=text.uppercaseString;label.font=[UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];label.adjustsFontForContentSizeCategory=YES;label.textColor=UIColor.secondaryLabelColor;label.numberOfLines=0;
 UIStackView *pad=[[UIStackView alloc]initWithArrangedSubviews:@[label]];pad.layoutMargins=UIEdgeInsetsMake(0,16,0,16);pad.layoutMarginsRelativeArrangement=YES;return pad;}
// A big tile like the Home app: round coloured icon, name, On/Off. Tap once to switch.
- (UIControl *)tile:(NSString *)title symbol:(NSString *)symbol color:(UIColor *)color key:(NSString *)key {
 UIControl *tile=[UIControl new];tile.accessibilityIdentifier=[@"home.tile." stringByAppendingString:key];tile.isAccessibilityElement=YES;tile.accessibilityTraits=UIAccessibilityTraitButton;tile.accessibilityLabel=title;tile.layer.cornerRadius=18;tile.layer.cornerCurve=kCACornerCurveContinuous;
 [tile.heightAnchor constraintEqualToConstant:96].active=YES;
 UIView *circle=[UIView new];circle.layer.cornerRadius=18;circle.translatesAutoresizingMaskIntoConstraints=NO;circle.userInteractionEnabled=NO;[circle.widthAnchor constraintEqualToConstant:36].active=YES;[circle.heightAnchor constraintEqualToConstant:36].active=YES;
 UIImageView *image=[[UIImageView alloc]initWithImage:[UIImage systemImageNamed:symbol withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightSemibold]]];image.tintColor=UIColor.whiteColor;image.translatesAutoresizingMaskIntoConstraints=NO;[circle addSubview:image];[NSLayoutConstraint activateConstraints:@[[image.centerXAnchor constraintEqualToAnchor:circle.centerXAnchor],[image.centerYAnchor constraintEqualToAnchor:circle.centerYAnchor]]];
 UILabel *name=[UILabel new];name.text=title;name.font=[UIFontMetrics.defaultMetrics scaledFontForFont:[UIFont systemFontOfSize:16 weight:UIFontWeightSemibold]];name.adjustsFontForContentSizeCategory=YES;name.adjustsFontSizeToFitWidth=YES;name.minimumScaleFactor=.7;
 UILabel *state=[UILabel new];state.text=@"Off";state.font=[UIFontMetrics.defaultMetrics scaledFontForFont:[UIFont systemFontOfSize:14 weight:UIFontWeightRegular]];state.adjustsFontForContentSizeCategory=YES;
 UIStackView *words=[[UIStackView alloc]initWithArrangedSubviews:@[circle,[UIView new],name,state]];words.axis=UILayoutConstraintAxisVertical;words.alignment=UIStackViewAlignmentLeading;words.userInteractionEnabled=NO;words.translatesAutoresizingMaskIntoConstraints=NO;[tile addSubview:words];
 [NSLayoutConstraint activateConstraints:@[[words.topAnchor constraintEqualToAnchor:tile.topAnchor constant:12],[words.bottomAnchor constraintEqualToAnchor:tile.bottomAnchor constant:-10],[words.leadingAnchor constraintEqualToAnchor:tile.leadingAnchor constant:14],[words.trailingAnchor constraintEqualToAnchor:tile.trailingAnchor constant:-10]]];
 self.tileParts[key]=@{@"tile":tile,@"circle":circle,@"name":name,@"state":state,@"color":color};
 [tile addTarget:self action:@selector(tileTapped:) forControlEvents:UIControlEventTouchUpInside];
 [tile addTarget:self action:@selector(tileDown:) forControlEvents:UIControlEventTouchDown|UIControlEventTouchDragEnter];[tile addTarget:self action:@selector(tileUp:) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside|UIControlEventTouchCancel|UIControlEventTouchDragExit];
 [self setTile:key on:NO text:@"Off"];return tile;
}
- (void)tileDown:(UIControl *)tile {[UIView animateWithDuration:.12 animations:^{tile.transform=CGAffineTransformMakeScale(.96,.96);}];}
- (void)tileUp:(UIControl *)tile {[UIView animateWithDuration:.4 delay:0 usingSpringWithDamping:.6 initialSpringVelocity:.5 options:UIViewAnimationOptionAllowUserInteraction animations:^{tile.transform=CGAffineTransformIdentity;} completion:nil];}
- (void)setTile:(NSString *)key on:(BOOL)on text:(NSString *)text {
 NSDictionary *p=self.tileParts[key];if(!p)return;self.tileOn[key]=@(on);
 UIControl *tile=p[@"tile"];UIView *circle=p[@"circle"];UILabel *name=p[@"name"],*state=p[@"state"];
 tile.backgroundColor=on?SLDyn(UIColor.whiteColor,[UIColor colorWithWhite:.95 alpha:1]):SLDyn([UIColor colorWithWhite:.9 alpha:1],[UIColor colorWithWhite:.11 alpha:1]);
 circle.backgroundColor=on?p[@"color"]:SLDyn([UIColor colorWithWhite:.78 alpha:1],[UIColor colorWithWhite:.23 alpha:1]);
 name.textColor=on?UIColor.blackColor:UIColor.labelColor;state.textColor=on?[UIColor colorWithWhite:.42 alpha:1]:UIColor.secondaryLabelColor;state.text=text;
 tile.accessibilityValue=text;
}
- (void)tileTapped:(UIControl *)tile {
 NSString *key=[tile.accessibilityIdentifier stringByReplacingOccurrencesOfString:@"home.tile." withString:@""];
 [[[UIImpactFeedbackGenerator alloc]initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];
 if([key isEqual:@"tiktok"]){if(self.moreAction)self.moreAction(@"tiktok");return;}
 BOOL on=![self.tileOn[key] boolValue];[self setTile:key on:on text:on?@"On":@"Off"];
 if([key isEqual:@"maps"]){if(self.moreAction)self.moreAction(on?@"mapsOn":@"mapsOff");return;}
 if(self.moreAction)self.moreAction(key);
}
- (void)pipSwitchChanged:(UISwitch *)toggle {[[[UISelectionFeedbackGenerator alloc]init] selectionChanged];if(self.moreAction)self.moreAction(@"pip");}
- (void)openYouTubeTapped {
 [[[UIImpactFeedbackGenerator alloc]initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];
 NSURL *app=[NSURL URLWithString:@"youtube://"];
 [UIApplication.sharedApplication openURL:app options:@{} completionHandler:^(BOOL ok){if(!ok)[UIApplication.sharedApplication openURL:[NSURL URLWithString:@"https://m.youtube.com"] options:@{} completionHandler:nil];}];
}
- (UIMenu *)qualityMenu {
 NSMutableArray *items=[NSMutableArray array];NSArray *names=@[@"Auto",@"720p",@"1080p",@"1440p",@"4K"],*values=@[@"auto",@"720",@"1080",@"1440",@"2160"];
 for(NSUInteger i=0;i<names.count;i++){UIAction *action=[UIAction actionWithTitle:names[i] image:nil identifier:nil handler:^(UIAction *a){self.playerQuality.selectedSegmentIndex=(NSInteger)i;[self playerQualityChanged];self.rowDetails[@"quality"].text=names[i];}];action.state=self.playerQuality.selectedSegmentIndex==(NSInteger)i?UIMenuElementStateOn:UIMenuElementStateOff;[items addObject:action];}
 return [UIMenu menuWithTitle:@"Video Quality" children:items];
}
- (instancetype)initWithFrame:(CGRect)frame {
 if((self=[super initWithFrame:frame])){
  self.backgroundColor=UIColor.systemGroupedBackgroundColor;self.idleAllowed=YES;self.rowDetails=[NSMutableDictionary dictionary];self.tileParts=[NSMutableDictionary dictionary];self.tileOn=[NSMutableDictionary dictionary];
  {NSInteger saved=[NSUserDefaults.standardUserDefaults integerForKey:@"ScreenLinkAppearance"];if(saved==1)self.overrideUserInterfaceStyle=UIUserInterfaceStyleLight;else if(saved==2)self.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;}
  UIScrollView *scroll=[UIScrollView new];scroll.translatesAutoresizingMaskIntoConstraints=NO;scroll.alwaysBounceVertical=YES;scroll.accessibilityIdentifier=@"home.scroll";scroll.backgroundColor=UIColor.clearColor;[self addSubview:scroll];
  UIStackView *stack=[UIStackView new];self.mainStack=stack;stack.axis=UILayoutConstraintAxisVertical;stack.spacing=14;stack.translatesAutoresizingMaskIntoConstraints=NO;[scroll addSubview:stack];
  NSLayoutConstraint *width=[stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-32];width.priority=999;
  [NSLayoutConstraint activateConstraints:@[[scroll.topAnchor constraintEqualToAnchor:self.topAnchor],[scroll.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],[scroll.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],[scroll.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],[scroll.contentLayoutGuide.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor],[stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:8],[stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-28],[stack.centerXAnchor constraintEqualToAnchor:scroll.centerXAnchor],width,[stack.widthAnchor constraintLessThanOrEqualToConstant:640]]];
  // Large title with the link button (copy the car website link) on the right.
  UIStackView *nav=[UIStackView new];nav.alignment=UIStackViewAlignmentCenter;nav.spacing=6;nav.layoutMargins=UIEdgeInsetsMake(0,4,0,0);nav.layoutMarginsRelativeArrangement=YES;
  UILabel *name=[UILabel new];name.text=@"ScreenLink";name.font=[[UIFontMetrics metricsForTextStyle:UIFontTextStyleLargeTitle] scaledFontForFont:[UIFont systemFontOfSize:34 weight:UIFontWeightBold]];name.adjustsFontForContentSizeCategory=YES;name.textColor=UIColor.labelColor;name.numberOfLines=1;name.adjustsFontSizeToFitWidth=YES;name.minimumScaleFactor=.6;[nav addArrangedSubview:name];[nav addArrangedSubview:[UIView new]];
  UIButton *copy=[self roundButton:@"link" label:@"Copy the car website link" action:@selector(copyTapped)];copy.accessibilityIdentifier=@"home.copy";{UIButtonConfiguration *c=copy.configuration;c.baseForegroundColor=UIColor.systemBlueColor;copy.configuration=c;}[nav addArrangedSubview:copy];[stack addArrangedSubview:nav];
  // The car card: picture, status at the bottom, Open YouTube at the top right.
  self.car=[SLAmbientCarView new];self.car.layer.cornerRadius=22;self.car.layer.cornerCurve=kCACornerCurveContinuous;self.car.layer.borderWidth=0;self.car.sheen.hidden=YES;[self.car.heightAnchor constraintEqualToAnchor:self.car.widthAnchor multiplier:.56].active=YES;[stack addArrangedSubview:self.car];
  self.heroImage=[UIImageView new];self.heroImage.contentMode=UIViewContentModeScaleAspectFill;self.heroImage.clipsToBounds=YES;self.heroImage.hidden=YES;self.heroImage.translatesAutoresizingMaskIntoConstraints=NO;[self.car addSubview:self.heroImage];
  [NSLayoutConstraint activateConstraints:@[[self.heroImage.topAnchor constraintEqualToAnchor:self.car.topAnchor],[self.heroImage.bottomAnchor constraintEqualToAnchor:self.car.bottomAnchor],[self.heroImage.leadingAnchor constraintEqualToAnchor:self.car.leadingAnchor],[self.heroImage.trailingAnchor constraintEqualToAnchor:self.car.trailingAnchor]]];
  {NSString *path=[NSBundle.mainBundle pathForResource:@"entrance-4" ofType:@"jpg"];self.heroDefault=path?[UIImage imageWithContentsOfFile:path]:nil;if(self.heroDefault)[self showHeroImage:nil];}
  SLFadeView *shade=[SLFadeView new];shade.userInteractionEnabled=NO;shade.translatesAutoresizingMaskIntoConstraints=NO;((CAGradientLayer *)shade.layer).colors=@[(id)[UIColor colorWithWhite:0 alpha:0].CGColor,(id)[UIColor colorWithWhite:0 alpha:.82].CGColor];((CAGradientLayer *)shade.layer).locations=@[@.3,@1];[self.car addSubview:shade];
  [NSLayoutConstraint activateConstraints:@[[shade.topAnchor constraintEqualToAnchor:self.car.topAnchor],[shade.bottomAnchor constraintEqualToAnchor:self.car.bottomAnchor],[shade.leadingAnchor constraintEqualToAnchor:self.car.leadingAnchor],[shade.trailingAnchor constraintEqualToAnchor:self.car.trailingAnchor]]];
  self.statusLabel=[UILabel new];self.statusLabel.text=@"Ready to connect";self.statusLabel.font=[UIFontMetrics.defaultMetrics scaledFontForFont:[UIFont systemFontOfSize:22 weight:UIFontWeightBold]];self.statusLabel.adjustsFontForContentSizeCategory=YES;self.statusLabel.textColor=UIColor.whiteColor;self.statusLabel.numberOfLines=2;self.statusLabel.accessibilityIdentifier=@"home.status";
  self.statusDot=[UIView new];self.statusDot.layer.cornerRadius=5;self.statusDot.backgroundColor=UIColor.systemGrayColor;[self.statusDot.widthAnchor constraintEqualToConstant:10].active=YES;[self.statusDot.heightAnchor constraintEqualToConstant:10].active=YES;
  UIStackView *statusRow=[[UIStackView alloc]initWithArrangedSubviews:@[self.statusDot,self.statusLabel]];statusRow.spacing=8;statusRow.alignment=UIStackViewAlignmentCenter;
  self.detailLabel=[UILabel new];self.detailLabel.text=@"Turn on Personal Hotspot, then tap Start.";self.detailLabel.font=[UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];self.detailLabel.adjustsFontForContentSizeCategory=YES;self.detailLabel.textColor=[UIColor colorWithWhite:1 alpha:.85];self.detailLabel.numberOfLines=3;self.detailLabel.accessibilityIdentifier=@"home.detail";
  UIStackView *status=[[UIStackView alloc]initWithArrangedSubviews:@[statusRow,self.detailLabel]];status.axis=UILayoutConstraintAxisVertical;status.spacing=2;status.translatesAutoresizingMaskIntoConstraints=NO;[self.car addSubview:status];
  [NSLayoutConstraint activateConstraints:@[[status.leadingAnchor constraintEqualToAnchor:self.car.leadingAnchor constant:16],[status.trailingAnchor constraintEqualToAnchor:self.car.trailingAnchor constant:-16],[status.bottomAnchor constraintEqualToAnchor:self.car.bottomAnchor constant:-14]]];
  UIButtonConfiguration *yt=UIButtonConfiguration.filledButtonConfiguration;yt.title=@"YouTube";yt.image=[UIImage systemImageNamed:@"airplayvideo" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightSemibold]];yt.imagePadding=6;yt.cornerStyle=UIButtonConfigurationCornerStyleCapsule;yt.baseBackgroundColor=[UIColor colorWithWhite:1 alpha:.24];yt.baseForegroundColor=UIColor.whiteColor;yt.contentInsets=NSDirectionalEdgeInsetsMake(8,13,8,13);
  yt.titleTextAttributesTransformer=^NSDictionary *(NSDictionary *a){NSMutableDictionary *m=[a mutableCopy];m[NSFontAttributeName]=[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];return m;};
  UIButton *youtube=[UIButton buttonWithConfiguration:yt primaryAction:nil];youtube.accessibilityIdentifier=@"home.youtube";youtube.accessibilityLabel=@"Open YouTube";youtube.translatesAutoresizingMaskIntoConstraints=NO;[youtube addTarget:self action:@selector(openYouTubeTapped) forControlEvents:UIControlEventTouchUpInside];[self.car addSubview:youtube];
  [NSLayoutConstraint activateConstraints:@[[youtube.topAnchor constraintEqualToAnchor:self.car.topAnchor constant:12],[youtube.trailingAnchor constraintEqualToAnchor:self.car.trailingAnchor constant:-12]]];
  [self makeLiveBadge];
  self.previewHost=[UIView new];self.previewHost.backgroundColor=UIColor.blackColor;self.previewHost.layer.cornerRadius=16;self.previewHost.clipsToBounds=YES;self.previewHost.hidden=YES;
  NSLayoutConstraint *previewHeight=[self.previewHost.heightAnchor constraintEqualToConstant:160];previewHeight.priority=750;previewHeight.active=YES;[stack addArrangedSubview:self.previewHost];
  // Four big tiles.
  UIStackView *row1=[[UIStackView alloc]initWithArrangedSubviews:@[[self tile:@"Maps" symbol:@"map.fill" color:UIColor.systemGreenColor key:@"maps"],[self tile:@"Phone Sound" symbol:@"speaker.wave.2.fill" color:UIColor.systemOrangeColor key:@"phonesound"]]];
  UIStackView *row2=[[UIStackView alloc]initWithArrangedSubviews:@[[self tile:@"Keep Playing" symbol:@"play.fill" color:UIColor.systemBlueColor key:@"keep"],[self tile:@"TikTok" symbol:@"music.note" color:UIColor.systemPinkColor key:@"tiktok"]]];
  for(UIStackView *r in @[row1,row2]){r.spacing=10;r.distribution=UIStackViewDistributionFillEqually;}
  UIStackView *tiles=[[UIStackView alloc]initWithArrangedSubviews:@[row1,row2]];tiles.axis=UILayoutConstraintAxisVertical;tiles.spacing=10;[stack addArrangedSubview:tiles];[self setTile:@"tiktok" on:NO text:@"Open"];
  // Car player controls: shown by themselves while a video plays. Big buttons.
  UIStackView *controls=[UIStackView new];controls.axis=UILayoutConstraintAxisVertical;controls.spacing=12;controls.layoutMargins=UIEdgeInsetsMake(16,16,16,16);controls.layoutMarginsRelativeArrangement=YES;controls.backgroundColor=UIColor.secondarySystemGroupedBackgroundColor;controls.layer.cornerRadius=12;controls.layer.cornerCurve=kCACornerCurveContinuous;
  self.playerPosition=[self label:@"Waiting for video" style:UIFontTextStyleSubheadline];self.playerPosition.textColor=UIColor.secondaryLabelColor;[controls addArrangedSubview:self.playerPosition];
  self.playerSeek=[UISlider new];self.playerSeek.minimumValue=0;self.playerSeek.maximumValue=1;self.playerSeek.continuous=NO;self.playerSeek.accessibilityLabel=@"Car video position";self.playerSeek.accessibilityIdentifier=@"player.seek";[self.playerSeek addTarget:self action:@selector(playerSeekChanged) forControlEvents:UIControlEventValueChanged];[controls addArrangedSubview:self.playerSeek];
  UIStackView *playback=[UIStackView new];playback.spacing=10;playback.distribution=UIStackViewDistributionFillEqually;
  self.playerBack=[self button:@"10" symbol:@"gobackward.10" action:@selector(playerBackTapped) filled:NO];self.playerBack.accessibilityLabel=@"Rewind car video ten seconds";
  self.playerPause=[self button:@"Pause" symbol:@"playpause.fill" action:@selector(playerPauseTapped) filled:YES];self.playerPause.accessibilityIdentifier=@"player.pause";
  self.playerForward=[self button:@"10" symbol:@"goforward.10" action:@selector(playerForwardTapped) filled:NO];self.playerForward.accessibilityLabel=@"Forward car video ten seconds";
  for(UIButton *button in @[self.playerBack,self.playerPause,self.playerForward]){[button.heightAnchor constraintGreaterThanOrEqualToConstant:52].active=YES;[playback addArrangedSubview:button];}[controls addArrangedSubview:playback];
  UIImageView *quiet=[[UIImageView alloc]initWithImage:[UIImage systemImageNamed:@"speaker.fill"]],*loud=[[UIImageView alloc]initWithImage:[UIImage systemImageNamed:@"speaker.wave.3.fill"]];quiet.tintColor=loud.tintColor=UIColor.secondaryLabelColor;
  self.playerVolume=[UISlider new];self.playerVolume.minimumValue=0;self.playerVolume.maximumValue=1;self.playerVolume.value=1;self.playerVolume.continuous=NO;self.playerVolume.accessibilityLabel=@"Car player volume";self.playerVolume.accessibilityIdentifier=@"player.volume";[self.playerVolume addTarget:self action:@selector(playerVolumeChanged) forControlEvents:UIControlEventValueChanged];
  UIStackView *volume=[[UIStackView alloc]initWithArrangedSubviews:@[quiet,self.playerVolume,loud]];volume.spacing=10;volume.alignment=UIStackViewAlignmentCenter;[controls addArrangedSubview:volume];
  self.playerQuality=[[UISegmentedControl alloc]initWithItems:@[@"Auto",@"720p",@"1080p",@"1440p",@"4K"]];self.playerQuality.selectedSegmentIndex=0;self.playerQuality.accessibilityIdentifier=@"player.quality";[self.playerQuality addTarget:self action:@selector(playerQualityChanged) forControlEvents:UIControlEventValueChanged];[self.playerQuality.heightAnchor constraintGreaterThanOrEqualToConstant:36].active=YES;[controls addArrangedSubview:self.playerQuality];
  self.playerEQ=[[UISegmentedControl alloc]initWithItems:@[@"Normal Sound",@"Music"]];self.playerEQ.selectedSegmentIndex=0;self.playerEQ.accessibilityLabel=@"Car sound preset";[self.playerEQ addTarget:self action:@selector(playerEQChanged) forControlEvents:UIControlEventValueChanged];[self.playerEQ.heightAnchor constraintGreaterThanOrEqualToConstant:36].active=YES;[controls addArrangedSubview:self.playerEQ];
  self.playerHint=[self label:@"Choose videos in YouTube. These buttons control the car player." style:UIFontTextStyleFootnote];self.playerHint.textColor=UIColor.secondaryLabelColor;[controls addArrangedSubview:self.playerHint];
  controls.hidden=YES;self.controlsCard=controls;
  UIView *playerHeader=[self sectionHeader:@"Car Player"];
  UIStackView *playerSection=[[UIStackView alloc]initWithArrangedSubviews:@[playerHeader,controls]];playerSection.axis=UILayoutConstraintAxisVertical;playerSection.spacing=7;playerSection.layoutMargins=UIEdgeInsetsMake(0,0,0,0);playerSection.hidden=YES;self.playerSection=playerSection;[stack setCustomSpacing:22 afterView:tiles];[stack addArrangedSubview:playerSection];
  // Settings-style list.
  UIControl *quality=[self cell:@"Video Quality" symbol:@"sparkles.tv" color:UIColor.systemIndigoColor key:@"quality" value:@"Auto" accessory:1];
  {UIButton *menu=[UIButton buttonWithType:UIButtonTypeSystem];menu.translatesAutoresizingMaskIntoConstraints=NO;menu.showsMenuAsPrimaryAction=YES;menu.accessibilityLabel=@"Video Quality";__weak typeof(self) weak=self;menu.menu=[UIMenu menuWithChildren:@[[UIDeferredMenuElement elementWithUncachedProvider:^(void (^completion)(NSArray<UIMenuElement *> *)){completion(weak?weak.qualityMenu.children:@[]);}]]];[quality addSubview:menu];
   [NSLayoutConstraint activateConstraints:@[[menu.topAnchor constraintEqualToAnchor:quality.topAnchor],[menu.bottomAnchor constraintEqualToAnchor:quality.bottomAnchor],[menu.leadingAnchor constraintEqualToAnchor:quality.leadingAnchor],[menu.trailingAnchor constraintEqualToAnchor:quality.trailingAnchor]]];}
  UIControl *pip=[self cell:@"Small Window" symbol:@"pip.fill" color:UIColor.systemTealColor key:@"pip" value:@"" accessory:2];
  {UISwitch *toggle=[UISwitch new];toggle.accessibilityIdentifier=@"home.pipSwitch";toggle.accessibilityLabel=@"Small window (PiP)";[toggle addTarget:self action:@selector(pipSwitchChanged:) forControlEvents:UIControlEventValueChanged];UIStackView *line=(UIStackView *)pip.subviews.firstObject;[line addArrangedSubview:toggle];self.pipSwitch=toggle;}
  UIControl *waiting=[self cell:@"Waiting Screen" symbol:@"photo.fill" color:UIColor.systemPinkColor key:@"waiting" value:@"" accessory:1];
  UIControl *maps=[self cell:@"Open Map" symbol:@"location.fill" color:UIColor.systemGreenColor key:@"openmap" value:@"" accessory:1];maps.accessibilityIdentifier=@"home.maps";
  [stack addArrangedSubview:[self sectionHeader:@"Car Player Settings"]];
  UIView *settings=[self group:@[quality,pip,waiting,maps]];[stack addArrangedSubview:settings];[stack setCustomSpacing:7 afterView:stack.arrangedSubviews[stack.arrangedSubviews.count-2]];[stack setCustomSpacing:22 afterView:settings];
  UIControl *help=[self cell:@"Help" symbol:@"questionmark" color:UIColor.systemGreenColor key:@"help" value:@"Khmer" accessory:1];
  UIControl *more=[self cell:@"More" symbol:@"gearshape.fill" color:UIColor.systemGrayColor key:@"more" value:@"" accessory:1];more.accessibilityIdentifier=@"home.developer";
  UIView *second=[self group:@[help,more]];[stack addArrangedSubview:second];
  UIStackView *steps=[UIStackView new];steps.axis=UILayoutConstraintAxisVertical;steps.spacing=7;steps.layoutMargins=UIEdgeInsetsMake(14,16,14,16);steps.layoutMarginsRelativeArrangement=YES;steps.backgroundColor=UIColor.secondarySystemGroupedBackgroundColor;steps.layer.cornerRadius=12;
  [steps addArrangedSubview:[self label:@"Connect in three steps" style:UIFontTextStyleHeadline]];
  for(NSString *line in @[@"1   Turn on Personal Hotspot and let the car join it.",@"2   In YouTube tap the TV icon and choose ScreenLink VPN Phone.",@"3   Open car.tesla4khmer.com/video in the car."]){UILabel *label=[self label:line style:UIFontTextStyleSubheadline];label.textColor=UIColor.secondaryLabelColor;[steps addArrangedSubview:label];}
  steps.hidden=YES;self.helpCard=steps;[stack addArrangedSubview:steps];
  // Start / Stop ScreenLink, like the red line at the bottom of an Apple settings page.
  self.startButton=[self bottomButton:@"Start ScreenLink" color:UIColor.systemBlueColor action:@selector(startTapped)];self.startButton.accessibilityIdentifier=@"home.start";self.startButton.accessibilityLabel=@"Start";
  self.disconnectButton=[self bottomButton:@"Stop ScreenLink" color:UIColor.systemRedColor action:@selector(disconnectTapped)];self.disconnectButton.accessibilityIdentifier=@"home.disconnect";self.disconnectButton.accessibilityLabel=@"Disconnect all";
  [stack setCustomSpacing:22 afterView:steps];[stack setCustomSpacing:22 afterView:second];[stack addArrangedSubview:self.startButton];[stack addArrangedSubview:self.disconnectButton];[stack setCustomSpacing:10 afterView:self.startButton];
  [self showPlayerState:@{}];
  NSNotificationCenter *notifications=NSNotificationCenter.defaultCenter;
  for(NSString *event in @[UIApplicationDidBecomeActiveNotification,UIApplicationWillResignActiveNotification,UIApplicationDidEnterBackgroundNotification,UIAccessibilityReduceMotionStatusDidChangeNotification])[notifications addObserver:self selector:@selector(ambientStateChanged:) name:event object:nil];
 }
 return self;
}
- (UIButton *)bottomButton:(NSString *)title color:(UIColor *)color action:(SEL)action {
 UIButtonConfiguration *config=UIButtonConfiguration.plainButtonConfiguration;config.title=title;config.baseForegroundColor=color;config.background.backgroundColor=UIColor.secondarySystemGroupedBackgroundColor;config.background.cornerRadius=12;config.contentInsets=NSDirectionalEdgeInsetsMake(15,16,15,16);
 config.titleTextAttributesTransformer=^NSDictionary *(NSDictionary *a){NSMutableDictionary *m=[a mutableCopy];m[NSFontAttributeName]=[UIFont preferredFontForTextStyle:UIFontTextStyleBody];return m;};
 UIButton *button=[UIButton buttonWithConfiguration:config primaryAction:nil];[button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];[button.heightAnchor constraintGreaterThanOrEqualToConstant:52].active=YES;return button;
}
- (void)makeLiveBadge {
 UILabel *live=[UILabel new];self.liveBadge=live;live.text=@"  ● LIVE  ";live.font=[UIFont systemFontOfSize:12 weight:UIFontWeightHeavy];live.textColor=UIColor.whiteColor;live.backgroundColor=[UIColor colorWithRed:.95 green:.2 blue:.25 alpha:.92];live.layer.cornerRadius=11;live.clipsToBounds=YES;live.hidden=YES;live.translatesAutoresizingMaskIntoConstraints=NO;[self.car addSubview:live];
 [NSLayoutConstraint activateConstraints:@[[live.topAnchor constraintEqualToAnchor:self.car.topAnchor constant:16],[live.leadingAnchor constraintEqualToAnchor:self.car.leadingAnchor constant:14],[live.heightAnchor constraintEqualToConstant:22]]];
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
 self.statusLabel.text=status;self.statusLabel.textColor=UIColor.whiteColor;self.startButton.hidden=sharing&&!busy;self.disconnectButton.hidden=!sharing&&!busy;self.detailLabel.text=detail;self.startButton.enabled=!busy;self.disconnectButton.enabled=!disconnecting;self.previewHost.hidden=!sharing;
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
 self.playerSection.hidden=!active;self.controlsCard.hidden=!active;{NSInteger q=self.playerQuality.selectedSegmentIndex;NSArray *names=@[@"Auto",@"720p",@"1080p",@"1440p",@"4K"];if(q>=0&&q<(NSInteger)names.count)self.rowDetails[@"quality"].text=names[q];}
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


