// Build 170: "Outside screen" test for the iPhone Duo.
// The user picks a photo or video. If iOS gives the app a second screen (the outside screen, or any other
// screen) while the app is open on the big inside screen, SLOuterSceneDelegate shows that photo or video there.
// The page also writes a report of what this iPhone offers (screens, scene kinds and any new UIKit names about
// outer/cover screens), so the next build can use the real Apple feature.
#import <UIKit/UIKit.h>
#import <PhotosUI/PhotosUI.h>
#import <AVFoundation/AVFoundation.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <objc/runtime.h>
#import <dlfcn.h>

static NSString *const SLOuterChanged=@"SLOuterMediaChanged";
static NSString *const SLOuterKindKey=@"outerMediaKind"; // "photo" or "video"
static NSMutableArray<NSString *> *SLOuterEvents(void){static NSMutableArray *list;static dispatch_once_t once;dispatch_once(&once,^{list=[NSMutableArray array];});return list;}
static void SLOuterNote(NSString *text){
 NSDateFormatter *f=[NSDateFormatter new];f.dateFormat=@"HH:mm:ss";
 @synchronized(SLOuterEvents()){[SLOuterEvents() addObject:[NSString stringWithFormat:@"%@ %@",[f stringFromDate:NSDate.date],text]];if(SLOuterEvents().count>60)[SLOuterEvents() removeObjectAtIndex:0];}
}
static NSURL *SLOuterFolder(void){
 NSURL *base=[NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
 NSURL *dir=[base URLByAppendingPathComponent:@"Outer" isDirectory:YES];[NSFileManager.defaultManager createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:nil];return dir;
}
static NSString *SLOuterKind(void){return [NSUserDefaults.standardUserDefaults stringForKey:SLOuterKindKey];}
static NSURL *SLOuterFile(void){NSString *k=SLOuterKind();if(!k)return nil;return [SLOuterFolder() URLByAppendingPathComponent:[k isEqual:@"video"]?@"media.mov":@"media.jpg"];}
static UIImage *SLOuterThumb(void){
 NSURL *u=SLOuterFile();if(!u||![NSFileManager.defaultManager fileExistsAtPath:u.path])return nil;
 if([SLOuterKind() isEqual:@"photo"])return [UIImage imageWithContentsOfFile:u.path];
 AVAssetImageGenerator *g=[AVAssetImageGenerator assetImageGeneratorWithAsset:[AVURLAsset URLAssetWithURL:u options:nil]];g.appliesPreferredTrackTransform=YES;
 CGImageRef cg=[g copyCGImageAtTime:CMTimeMake(1,2) actualTime:NULL error:nil];if(!cg)return nil;UIImage *i=[UIImage imageWithCGImage:cg];CGImageRelease(cg);return i;
}

#pragma mark - What shows on the outside screen
@interface SLOuterMediaController : UIViewController
@property(nonatomic,strong) UIImageView *photo;
@property(nonatomic,strong) AVQueuePlayer *player;
@property(nonatomic,strong) AVPlayerLooper *looper;
@property(nonatomic,strong) AVPlayerLayer *videoLayer;
@property(nonatomic,strong) UILabel *empty;
@end
@implementation SLOuterMediaController
- (void)viewDidLoad {
 [super viewDidLoad];self.view.backgroundColor=UIColor.blackColor;
 self.photo=[UIImageView new];self.photo.contentMode=UIViewContentModeScaleAspectFill;self.photo.clipsToBounds=YES;[self.view addSubview:self.photo];
 self.empty=[UILabel new];self.empty.text=@"ScreenLink";self.empty.textColor=[UIColor colorWithWhite:1 alpha:.6];self.empty.font=[UIFont systemFontOfSize:28 weight:UIFontWeightSemibold];self.empty.textAlignment=NSTextAlignmentCenter;[self.view addSubview:self.empty];
 [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(reload) name:SLOuterChanged object:nil];[self reload];
}
- (void)viewDidLayoutSubviews {[super viewDidLayoutSubviews];self.photo.frame=self.view.bounds;self.videoLayer.frame=self.view.bounds;self.empty.frame=self.view.bounds;}
- (void)reload {
 [self.player pause];self.looper=nil;self.player=nil;[self.videoLayer removeFromSuperlayer];self.videoLayer=nil;self.photo.image=nil;
 NSURL *u=SLOuterFile();BOOL has=u&&[NSFileManager.defaultManager fileExistsAtPath:u.path];self.empty.hidden=has;if(!has)return;
 if([SLOuterKind() isEqual:@"video"]){
  AVPlayerItem *item=[AVPlayerItem playerItemWithURL:u];self.player=[AVQueuePlayer new];self.player.muted=YES;self.looper=[AVPlayerLooper playerLooperWithPlayer:self.player templateItem:item];
  self.videoLayer=[AVPlayerLayer playerLayerWithPlayer:self.player];self.videoLayer.videoGravity=AVLayerVideoGravityResizeAspectFill;self.videoLayer.frame=self.view.bounds;[self.view.layer addSublayer:self.videoLayer];[self.player play];
 } else self.photo.image=[UIImage imageWithContentsOfFile:u.path];
}
@end

#pragma mark - Any extra screen iOS gives the app
@interface SLOuterSceneDelegate : UIResponder <UIWindowSceneDelegate>
@property(nonatomic,strong) UIWindow *window;
@end
@implementation SLOuterSceneDelegate
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {
 UIWindowScene *ws=[scene isKindOfClass:UIWindowScene.class]?(UIWindowScene *)scene:nil;
 SLOuterNote([NSString stringWithFormat:@"EXTRA SCREEN CONNECTED: kind=%@ size=%@",session.role,ws?NSStringFromCGSize(ws.coordinateSpace.bounds.size):@"?"]);
 if(!ws)return;UIWindow *w=[[UIWindow alloc]initWithWindowScene:ws];w.rootViewController=[SLOuterMediaController new];self.window=w;w.hidden=NO;
}
- (void)sceneDidDisconnect:(UIScene *)scene {SLOuterNote([NSString stringWithFormat:@"Extra screen gone: %@",scene.session.role]);self.window=nil;}
@end

#pragma mark - The report
static NSString *SLOuterReport(void){
 NSMutableString *r=[NSMutableString string];UIDevice *d=UIDevice.currentDevice;
 [r appendFormat:@"ScreenLink outside-screen report (build %@)\niOS %@ · %@\n",[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"],d.systemVersion,d.model];
 [r appendFormat:@"Duo version (scenes): %@\n",[NSBundle.mainBundle objectForInfoDictionaryKey:@"UIApplicationSceneManifest"]?@"yes":@"no — install the DUO file for this test"];
 [r appendString:@"\nSCREENS\n"];
 #pragma clang diagnostic push
 #pragma clang diagnostic ignored "-Wdeprecated-declarations"
 for(UIScreen *s in UIScreen.screens)[r appendFormat:@"- %@ pt, scale %.1f%@\n",NSStringFromCGSize(s.bounds.size),s.scale,s==UIScreen.mainScreen?@" (main)":@""];
 #pragma clang diagnostic pop
 [r appendString:@"\nOPEN SCENES\n"];
 for(UIScene *s in UIApplication.sharedApplication.connectedScenes){UIWindowScene *w=[s isKindOfClass:UIWindowScene.class]?(UIWindowScene *)s:nil;
  [r appendFormat:@"- %@ · state %ld · size %@\n",s.session.role,(long)s.activationState,w?NSStringFromCGSize(w.coordinateSpace.bounds.size):@"?"];}
 [r appendString:@"\nSCENE KINDS IOS KNOWS\n"];
 NSArray *guess=@[@"UIWindowSceneSessionRoleApplication",@"UIWindowSceneSessionRoleExternalDisplay",@"UIWindowSceneSessionRoleExternalDisplayNonInteractive",@"UIWindowSceneSessionRoleOuterDisplay",@"UIWindowSceneSessionRoleCoverDisplay",@"UIWindowSceneSessionRoleExteriorDisplay",@"UIWindowSceneSessionRoleSecondaryDisplay",@"UIWindowSceneSessionRoleOuterDisplayNonInteractive",@"UIWindowSceneSessionRoleCoverDisplayNonInteractive",@"UIWindowSceneSessionRoleAmbient",@"UIWindowSceneSessionRoleAccessory",@"UIWindowSceneSessionRoleCameraAccessory",@"UIWindowSceneSessionRoleRearDisplay"];
 for(NSString *name in guess){void *p=dlsym(RTLD_DEFAULT,name.UTF8String);if(p)[r appendFormat:@"- %@ = %@\n",name,*(__unsafe_unretained NSString **)p];}
 [r appendString:@"\nNEW UIKIT NAMES (outer / cover / fold)\n"];
 NSArray *words=@[@"outer",@"cover",@"exterior",@"secondarydisplay",@"foldable",@"unfold",@"folded",@"foldstate",@"hinge",@"duo",@"reservedregion",@"posture",@"innerdisplay",@"reardisplay",@"subdisplay"];
 BOOL (^hit)(NSString *)=^BOOL(NSString *n){NSString *l=n.lowercaseString;for(NSString *w in words)if([l containsString:w])return YES;return NO;};
 unsigned int count=0;Class *classes=objc_copyClassList(&count);NSMutableArray *found=[NSMutableArray array];
 for(unsigned int i=0;i<count;i++){NSString *n=NSStringFromClass(classes[i]);if(([n hasPrefix:@"UI"]||[n hasPrefix:@"_UI"])&&hit(n))[found addObject:n];}
 free(classes);[found sortUsingSelector:@selector(compare:)];
 for(NSString *n in [found subarrayWithRange:NSMakeRange(0,MIN(found.count,80u))])[r appendFormat:@"- class %@\n",n];
 for(NSString *cn in @[@"UIScreen",@"UIWindowScene",@"UIWindow",@"UIApplication",@"UIScene",@"UISceneSession",@"UIWindowSceneGeometry",@"UITraitCollection",@"UIView",@"UISceneSessionActivationRequest",@"UIWindowSceneGeometryPreferencesIOS"]){
  Class c=NSClassFromString(cn);if(!c)continue;
  for(int meta=0;meta<2;meta++){Class k=meta?object_getClass(c):c;unsigned int mc=0;Method *ms=class_copyMethodList(k,&mc);
   for(unsigned int i=0;i<mc;i++){NSString *s=NSStringFromSelector(method_getName(ms[i]));if(hit(s)&&![s hasPrefix:@"_"])[r appendFormat:@"- %@%@ %@\n",meta?@"+":@"-",cn,s];}
   free(ms);}
 }
 [r appendString:@"\nEVENTS\n"];
 @synchronized(SLOuterEvents()){for(NSString *e in SLOuterEvents())[r appendFormat:@"%@\n",e];if(!SLOuterEvents().count)[r appendString:@"(no extra screen has connected yet)\n"];}
 return r;
}

#pragma mark - The "Outside screen" page
@interface SLOuterScreen : UIViewController <PHPickerViewControllerDelegate>
@property(nonatomic,strong) UIImageView *preview;
@property(nonatomic,strong) UILabel *status;
@property(nonatomic,strong) UITextView *report;
+ (void)presentFrom:(UIViewController *)controller;
@end
@implementation SLOuterScreen
+ (void)load {
 [NSNotificationCenter.defaultCenter addObserverForName:UISceneWillConnectNotification object:nil queue:nil usingBlock:^(NSNotification *n){SLOuterNote([NSString stringWithFormat:@"Scene connecting: %@",((UIScene *)n.object).session.role]);}];
 #pragma clang diagnostic push
 #pragma clang diagnostic ignored "-Wdeprecated-declarations"
 [NSNotificationCenter.defaultCenter addObserverForName:UIScreenDidConnectNotification object:nil queue:nil usingBlock:^(NSNotification *n){SLOuterNote([NSString stringWithFormat:@"Screen connected: %@",NSStringFromCGSize(((UIScreen *)n.object).bounds.size)]);}];
 #pragma clang diagnostic pop
}
+ (void)presentFrom:(UIViewController *)controller {
 UINavigationController *nav=[[UINavigationController alloc]initWithRootViewController:[SLOuterScreen new]];nav.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;[controller presentViewController:nav animated:YES completion:nil];
}
- (UIButton *)button:(NSString *)title symbol:(NSString *)symbol action:(SEL)action filled:(BOOL)filled {
 UIButtonConfiguration *c=filled?UIButtonConfiguration.filledButtonConfiguration:UIButtonConfiguration.tintedButtonConfiguration;c.title=title;c.image=[UIImage systemImageNamed:symbol];c.imagePadding=8;c.cornerStyle=UIButtonConfigurationCornerStyleLarge;c.contentInsets=NSDirectionalEdgeInsetsMake(14,16,14,16);
 UIButton *b=[UIButton buttonWithConfiguration:c primaryAction:nil];[b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];return b;
}
- (void)viewDidLoad {
 [super viewDidLoad];self.title=@"Outside screen";self.view.backgroundColor=[UIColor colorWithWhite:.06 alpha:1];
 self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done)];
 UIScrollView *scroll=[UIScrollView new];scroll.translatesAutoresizingMaskIntoConstraints=NO;[self.view addSubview:scroll];
 UILabel *intro=[UILabel new];intro.numberOfLines=0;intro.textColor=[UIColor colorWithWhite:.75 alpha:1];intro.font=[UIFont systemFontOfSize:15];
 intro.text=@"Pick a photo or video. When your iPhone Duo is open, ScreenLink tries to show it on the outside screen. This is a test: if it does not show, tap Copy report and send it to Claude.";
 self.preview=[UIImageView new];self.preview.contentMode=UIViewContentModeScaleAspectFill;self.preview.clipsToBounds=YES;self.preview.layer.cornerRadius=18;self.preview.backgroundColor=[UIColor colorWithWhite:.14 alpha:1];[self.preview.heightAnchor constraintEqualToConstant:220].active=YES;
 self.status=[UILabel new];self.status.numberOfLines=0;self.status.font=[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];self.status.textColor=UIColor.whiteColor;
 UIButton *pick=[self button:@"Choose photo or video" symbol:@"photo.on.rectangle" action:@selector(pick) filled:YES];
 UIButton *show=[self button:@"Show on outside screen now" symbol:@"rectangle.portrait.on.rectangle.portrait" action:@selector(tryShow) filled:NO];
 UIButton *remove=[self button:@"Remove" symbol:@"trash" action:@selector(removeMedia) filled:NO];
 UIButton *copy=[self button:@"Copy report" symbol:@"doc.on.doc" action:@selector(copyReport) filled:NO];
 self.report=[UITextView new];self.report.editable=NO;self.report.scrollEnabled=NO;self.report.backgroundColor=[UIColor colorWithWhite:.1 alpha:1];self.report.layer.cornerRadius=12;self.report.textColor=[UIColor colorWithWhite:.8 alpha:1];self.report.font=[UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
 UIStackView *stack=[[UIStackView alloc]initWithArrangedSubviews:@[intro,self.preview,self.status,pick,show,remove,copy,self.report]];stack.axis=UILayoutConstraintAxisVertical;stack.spacing=14;stack.translatesAutoresizingMaskIntoConstraints=NO;[scroll addSubview:stack];
 UILayoutGuide *g=self.view.safeAreaLayoutGuide;
 [NSLayoutConstraint activateConstraints:@[[scroll.topAnchor constraintEqualToAnchor:self.view.topAnchor],[scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],[scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],[scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
  [stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:16],[stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-24],
  [stack.centerXAnchor constraintEqualToAnchor:g.centerXAnchor],[stack.widthAnchor constraintEqualToAnchor:g.widthAnchor constant:-32],[stack.widthAnchor constraintLessThanOrEqualToConstant:560]]];
 [self refresh];
}
- (void)done {[self dismissViewControllerAnimated:YES completion:nil];}
- (NSArray<UIScene *> *)extraScenes {
 NSMutableArray *a=[NSMutableArray array];for(UIScene *s in UIApplication.sharedApplication.connectedScenes)if(![s.session.role isEqual:UIWindowSceneSessionRoleApplication])[a addObject:s];return a;
}
- (void)refresh {
 self.preview.image=SLOuterThumb();
 NSArray *extra=[self extraScenes];NSString *k=SLOuterKind();
 self.status.text=extra.count?[NSString stringWithFormat:@"✅ Outside screen connected — showing your %@.",k?:@"ScreenLink logo"]:[NSString stringWithFormat:@"%@\nOutside screen: iOS has not given it to the app yet.",k?[NSString stringWithFormat:@"Your %@ is ready.",k]:@"No photo or video yet."];
 self.report.text=SLOuterReport();
}
- (void)pick {
 PHPickerConfiguration *c=[PHPickerConfiguration new];c.filter=[PHPickerFilter anyFilterMatchingSubfilters:@[PHPickerFilter.imagesFilter,PHPickerFilter.videosFilter]];c.selectionLimit=1;c.preferredAssetRepresentationMode=PHPickerConfigurationAssetRepresentationModeCompatible;
 PHPickerViewController *p=[[PHPickerViewController alloc]initWithConfiguration:c];p.delegate=self;[self presentViewController:p animated:YES completion:nil];
}
- (void)saved:(NSString *)kind {
 dispatch_async(dispatch_get_main_queue(),^{
  if(kind){NSString *other=[kind isEqual:@"video"]?@"media.jpg":@"media.mov";[NSFileManager.defaultManager removeItemAtURL:[SLOuterFolder() URLByAppendingPathComponent:other] error:nil];[NSUserDefaults.standardUserDefaults setObject:kind forKey:SLOuterKindKey];SLOuterNote([@"Saved a " stringByAppendingString:kind]);}
  else SLOuterNote(@"Could not read that photo or video");
  [NSNotificationCenter.defaultCenter postNotificationName:SLOuterChanged object:nil];[self refresh];});
}
- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
 [picker dismissViewControllerAnimated:YES completion:nil];NSItemProvider *item=results.firstObject.itemProvider;if(!item)return;
 if([item hasItemConformingToTypeIdentifier:UTTypeMovie.identifier]){
  [item loadFileRepresentationForTypeIdentifier:UTTypeMovie.identifier completionHandler:^(NSURL *url,NSError *error){
   NSURL *dest=[SLOuterFolder() URLByAppendingPathComponent:@"media.mov"];[NSFileManager.defaultManager removeItemAtURL:dest error:nil];
   BOOL ok=url&&[NSFileManager.defaultManager copyItemAtURL:url toURL:dest error:nil];[self saved:ok?@"video":nil];}];
 } else if([item canLoadObjectOfClass:UIImage.class]){
  [item loadObjectOfClass:UIImage.class completionHandler:^(id<NSItemProviderReading> object,NSError *error){
   NSData *jpg=[object isKindOfClass:UIImage.class]?UIImageJPEGRepresentation((UIImage *)object,.9):nil;
   BOOL ok=jpg&&[jpg writeToURL:[SLOuterFolder() URLByAppendingPathComponent:@"media.jpg"] atomically:YES];[self saved:ok?@"photo":nil];}];
 }
}
- (void)tryShow {
 // Ask iOS for a second window. On a normal iPhone this does nothing; on iPhone Duo it tells us what iOS allows.
 SLOuterNote(@"Asked iOS for the outside screen");
 if(![NSBundle.mainBundle objectForInfoDictionaryKey:@"UIApplicationSceneManifest"]){SLOuterNote(@"This is the NORMAL version: install the DUO file for this test");[self refresh];return;}
 NSArray *roles=@[@"UIWindowSceneSessionRoleOuterDisplay",@"UIWindowSceneSessionRoleCoverDisplay",@"UIWindowSceneSessionRoleExteriorDisplay",@"UIWindowSceneSessionRoleSecondaryDisplay",@"UIWindowSceneSessionRoleOuterDisplayNonInteractive",@"UIWindowSceneSessionRoleCoverDisplayNonInteractive"];
 BOOL asked=NO;
 if(@available(iOS 17.0,*)){
  for(NSString *name in roles){void *p=dlsym(RTLD_DEFAULT,name.UTF8String);if(!p)continue;NSString *role=*(__unsafe_unretained NSString **)p;asked=YES;
   UISceneSessionActivationRequest *req=[UISceneSessionActivationRequest requestWithRole:role];
   [UIApplication.sharedApplication activateSceneSessionForRequest:req errorHandler:^(NSError *e){SLOuterNote([NSString stringWithFormat:@"%@ refused: %@",role,e.localizedDescription]);dispatch_async(dispatch_get_main_queue(),^{[self refresh];});}];
   SLOuterNote([@"Asked for scene kind " stringByAppendingString:role]);}
 }
 if(!asked)SLOuterNote(@"This iOS has no outside-screen scene kind that apps can ask for");
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(1.5*NSEC_PER_SEC)),dispatch_get_main_queue(),^{[self refresh];});
}
- (void)removeMedia {
 for(NSString *n in @[@"media.jpg",@"media.mov"])[NSFileManager.defaultManager removeItemAtURL:[SLOuterFolder() URLByAppendingPathComponent:n] error:nil];
 [NSUserDefaults.standardUserDefaults removeObjectForKey:SLOuterKindKey];[NSNotificationCenter.defaultCenter postNotificationName:SLOuterChanged object:nil];[self refresh];
}
- (void)copyReport {[self refresh];UIPasteboard.generalPasteboard.string=self.report.text;self.status.text=@"Report copied. Paste it to Claude.";}
@end

// The Duo version is scene based. Any screen that is not the app's own main window goes to SLOuterSceneDelegate.
UISceneConfiguration *SLOuterConfiguration(UISceneSession *session){
 if([session.role isEqual:UIWindowSceneSessionRoleApplication]){UISceneConfiguration *c=[UISceneConfiguration configurationWithName:@"Default" sessionRole:session.role];c.delegateClass=NSClassFromString(@"SLSceneDelegate");return c;}
 SLOuterNote([@"iOS offered a screen of kind " stringByAppendingString:session.role]);
 UISceneConfiguration *c=[UISceneConfiguration configurationWithName:@"Outside" sessionRole:session.role];c.delegateClass=SLOuterSceneDelegate.class;return c;
}
