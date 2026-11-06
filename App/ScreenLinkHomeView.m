#import "ScreenLinkHomeView.h"
@interface ScreenLinkHomeView ()
@property(nonatomic,strong,readwrite) UIView *previewHost;
@property(nonatomic,strong) UILabel *statusLabel,*detailLabel,*dot;
@property(nonatomic,strong) UIButton *startButton,*disconnectButton;
@end
@implementation ScreenLinkHomeView
- (UILabel *)label:(NSString *)text style:(UIFontTextStyle)style {
 UILabel *label=[UILabel new];label.text=text;label.font=[UIFont preferredFontForTextStyle:style];label.adjustsFontForContentSizeCategory=YES;label.numberOfLines=0;return label;
}
- (UIButton *)button:(NSString *)title symbol:(NSString *)symbol action:(SEL)action filled:(BOOL)filled {
 UIButtonConfiguration *config=filled?UIButtonConfiguration.filledButtonConfiguration:UIButtonConfiguration.tintedButtonConfiguration;
 config.title=title;config.image=[UIImage systemImageNamed:symbol];config.imagePadding=10;config.cornerStyle=UIButtonConfigurationCornerStyleLarge;
 config.contentInsets=NSDirectionalEdgeInsetsMake(16,18,16,18);
 if(filled){config.baseBackgroundColor=[UIColor colorWithRed:.05 green:.43 blue:.47 alpha:1];config.baseForegroundColor=UIColor.whiteColor;}
 UIButton *button=[UIButton buttonWithConfiguration:config primaryAction:nil];[button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];return button;
}
- (instancetype)initWithFrame:(CGRect)frame {
 if((self=[super initWithFrame:frame])){
  self.backgroundColor=UIColor.systemGroupedBackgroundColor;
  UIScrollView *scroll=[UIScrollView new];scroll.translatesAutoresizingMaskIntoConstraints=NO;scroll.alwaysBounceVertical=YES;scroll.accessibilityIdentifier=@"home.scroll";[self addSubview:scroll];
  UIStackView *stack=[UIStackView new];stack.axis=UILayoutConstraintAxisVertical;stack.spacing=20;stack.translatesAutoresizingMaskIntoConstraints=NO;[scroll addSubview:stack];
  NSLayoutConstraint *width=[stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-40];width.priority=999;
  [NSLayoutConstraint activateConstraints:@[[scroll.topAnchor constraintEqualToAnchor:self.topAnchor],[scroll.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],[scroll.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],[scroll.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],[stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:20],[stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-28],[stack.centerXAnchor constraintEqualToAnchor:scroll.centerXAnchor],width,[stack.widthAnchor constraintLessThanOrEqualToConstant:720],[stack.leadingAnchor constraintGreaterThanOrEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:20],[stack.trailingAnchor constraintLessThanOrEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-20]]];
  UIStackView *nav=[UIStackView new];nav.alignment=UIStackViewAlignmentCenter;nav.spacing=12;
  UILabel *name=[self label:@"ScreenLink" style:UIFontTextStyleTitle2];name.font=[UIFontMetrics.defaultMetrics scaledFontForFont:[UIFont systemFontOfSize:25 weight:UIFontWeightBold]];[nav addArrangedSubview:name];UIView *spacer=[UIView new];[nav addArrangedSubview:spacer];
  UIButton *developer=[UIButton buttonWithType:UIButtonTypeSystem];[developer setTitle:@"Developer" forState:UIControlStateNormal];developer.accessibilityIdentifier=@"home.developer";[developer addTarget:self action:@selector(developerTapped) forControlEvents:UIControlEventTouchUpInside];[developer.heightAnchor constraintGreaterThanOrEqualToConstant:44].active=YES;[nav addArrangedSubview:developer];[stack addArrangedSubview:nav];
  UIImageView *cover=[[UIImageView alloc]initWithImage:[UIImage imageNamed:@"ScreenLinkCover"]];cover.contentMode=UIViewContentModeScaleAspectFill;cover.clipsToBounds=YES;cover.layer.cornerRadius=26;cover.accessibilityLabel=@"A phone sending a bright video scene to a nearby screen";cover.isAccessibilityElement=YES;[cover.heightAnchor constraintEqualToAnchor:cover.widthAnchor multiplier:.5].active=YES;[stack addArrangedSubview:cover];
  UIStackView *intro=[UIStackView new];intro.axis=UILayoutConstraintAxisVertical;intro.spacing=7;
  UILabel *headline=[self label:@"Your video. A bigger view." style:UIFontTextStyleTitle1];headline.font=[UIFontMetrics.defaultMetrics scaledFontForFont:[UIFont systemFontOfSize:30 weight:UIFontWeightBold]];[intro addArrangedSubview:headline];
  UILabel *subtitle=[self label:@"Share YouTube over your hotspot. Keep your phone screen private." style:UIFontTextStyleSubheadline];subtitle.textColor=UIColor.secondaryLabelColor;[intro addArrangedSubview:subtitle];[stack addArrangedSubview:intro];
  UIView *card=[UIView new];card.backgroundColor=UIColor.secondarySystemGroupedBackgroundColor;card.layer.cornerRadius=22;
  UIStackView *status=[UIStackView new];status.axis=UILayoutConstraintAxisVertical;status.spacing=8;status.translatesAutoresizingMaskIntoConstraints=NO;[card addSubview:status];
  [NSLayoutConstraint activateConstraints:@[[status.topAnchor constraintEqualToAnchor:card.topAnchor constant:18],[status.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-18],[status.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18],[status.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18]]];
  self.statusLabel=[self label:@"Ready to connect" style:UIFontTextStyleHeadline];self.statusLabel.accessibilityIdentifier=@"home.status";[status addArrangedSubview:self.statusLabel];
  self.detailLabel=[self label:@"Turn on Personal Hotspot, then tap Start." style:UIFontTextStyleSubheadline];self.detailLabel.textColor=UIColor.secondaryLabelColor;self.detailLabel.accessibilityIdentifier=@"home.detail";[status addArrangedSubview:self.detailLabel];[stack addArrangedSubview:card];
  self.startButton=[self button:@"Start YouTube + PiP" symbol:@"play.fill" action:@selector(startTapped) filled:YES];self.startButton.accessibilityIdentifier=@"home.start";[stack addArrangedSubview:self.startButton];
  self.disconnectButton=[self button:@"Disconnect All" symbol:@"power" action:@selector(disconnectTapped) filled:NO];UIButtonConfiguration *disconnectConfig=self.disconnectButton.configuration;disconnectConfig.baseForegroundColor=UIColor.systemRedColor;self.disconnectButton.configuration=disconnectConfig;self.disconnectButton.accessibilityIdentifier=@"home.disconnect";[stack addArrangedSubview:self.disconnectButton];
  self.previewHost=[UIView new];self.previewHost.backgroundColor=UIColor.blackColor;self.previewHost.layer.cornerRadius=18;self.previewHost.clipsToBounds=YES;self.previewHost.hidden=YES;
  NSLayoutConstraint *previewHeight=[self.previewHost.heightAnchor constraintEqualToConstant:160];previewHeight.priority=750;previewHeight.active=YES;[stack addArrangedSubview:self.previewHost];
  UIStackView *steps=[UIStackView new];steps.axis=UILayoutConstraintAxisVertical;steps.spacing=10;[steps addArrangedSubview:[self label:@"A quick start" style:UIFontTextStyleHeadline]];
  for(NSString *line in @[@"1   Connect your viewer to this phone’s hotspot.",@"2   In YouTube, choose ScreenLink from AirPlay.",@"3   Return here once to prepare the floating video."]){UILabel *label=[self label:line style:UIFontTextStyleSubheadline];label.textColor=UIColor.secondaryLabelColor;[steps addArrangedSubview:label];}
  [stack addArrangedSubview:steps];
  UIButton *copy=[self button:@"Copy website link" symbol:@"link" action:@selector(copyTapped) filled:NO];copy.accessibilityIdentifier=@"home.copy";[stack addArrangedSubview:copy];
  UILabel *footer=[self label:@"YouTube uses real video without screen recording. iOS manages background availability." style:UIFontTextStyleFootnote];footer.textColor=UIColor.secondaryLabelColor;[stack addArrangedSubview:footer];
 }
 return self;
}
- (void)showStatus:(NSString *)status detail:(NSString *)detail busy:(BOOL)busy sharing:(BOOL)sharing disconnecting:(BOOL)disconnecting attention:(BOOL)attention {
 self.statusLabel.text=status;self.statusLabel.textColor=attention?UIColor.systemRedColor:UIColor.labelColor;self.detailLabel.text=detail;self.startButton.enabled=!busy;self.disconnectButton.enabled=!disconnecting;self.previewHost.hidden=!sharing;
 UIButtonConfiguration *c=self.startButton.configuration;c.showsActivityIndicator=busy;self.startButton.configuration=c;
}
- (void)startTapped {if(self.startAction)self.startAction();}
- (void)disconnectTapped {if(self.disconnectAction)self.disconnectAction();}
- (void)developerTapped {if(self.developerAction)self.developerAction();}
- (void)copyTapped {if(self.copyAction)self.copyAction();UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification,@"Website link copied");}
@end
