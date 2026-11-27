// Build 167: "Choose your car" for the premium Home.
// Built-in cars are PNG pictures named "Car-<name>.png" that are added to the user's own app file after the
// build (they are not in this public code). The user can also add any car photo: Apple's Vision "lift the
// subject" cuts the car out (iOS 17+). The Home reads the car's color and lights the room to match.
#import <UIKit/UIKit.h>
#import <PhotosUI/PhotosUI.h>
#import <Vision/Vision.h>
#import <CoreImage/CoreImage.h>

@interface SLCarLibrary : NSObject <PHPickerViewControllerDelegate>
+ (UIImage *)currentCar;
+ (UIColor *)currentTint;
+ (NSString *)currentName;
+ (void)presentPickerFrom:(UIViewController *)controller completion:(void (^)(void))completion;
@end

static NSString *const SLCarKey=@"premiumCar";
// Build 169: paint color and room light choices.
static NSArray<NSArray *> *SLPaints(void){return @[@[@"Original",@"original"],@[@"Black",@"0.07,0.07,0.08"],@[@"White",@"0.93,0.93,0.92"],@[@"Grey",@"0.42,0.44,0.48"],@[@"Red",@"0.72,0.04,0.10"],@[@"Blue",@"0.05,0.22,0.62"],@[@"Green",@"0.10,0.42,0.28"],@[@"Purple",@"0.38,0.16,0.62"]];}
static NSArray<NSArray *> *SLLights(void){return @[@[@"Auto (follows the paint)",@"auto"],@[@"Blue",@"0.56"],@[@"Red",@"0.98"],@[@"Purple",@"0.76"],@[@"Orange",@"0.07"],@[@"Green",@"0.40"],@[@"White",@"white"]];}
static UIColor *SLRGBString(NSString *text){NSArray *p=[text componentsSeparatedByString:@","];if(p.count!=3)return nil;return [UIColor colorWithRed:[p[0] doubleValue] green:[p[1] doubleValue] blue:[p[2] doubleValue] alpha:1];}
@interface SLCarLibrary ()
@property(nonatomic,copy) void (^done)(void);
@end
@implementation SLCarLibrary
static SLCarLibrary *SLCarPicking;
+ (NSURL *)userFolder {
 NSURL *base=[NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
 NSURL *dir=[base URLByAppendingPathComponent:@"Cars" isDirectory:YES];[NSFileManager.defaultManager createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:nil];return dir;
}
/// name -> file path. Built-in first (sorted, "White 53" first), then the user's own.
+ (NSArray<NSDictionary *> *)allCars {
 NSMutableArray *cars=[NSMutableArray array];
 NSArray *paths=[[NSBundle.mainBundle pathsForResourcesOfType:@"png" inDirectory:nil] sortedArrayUsingComparator:^NSComparisonResult(NSString *a,NSString *b){
  BOOL aw=[a.lastPathComponent containsString:@"53"],bw=[b.lastPathComponent containsString:@"53"];if(aw!=bw)return aw?NSOrderedAscending:NSOrderedDescending;return [a compare:b];}];
 for(NSString *path in paths){NSString *file=path.lastPathComponent;if(![file hasPrefix:@"Car-"])continue;[cars addObject:@{@"name":[[file substringFromIndex:4] stringByDeletingPathExtension],@"path":path,@"user":@NO}];}
 for(NSURL *url in [NSFileManager.defaultManager contentsOfDirectoryAtURL:[self userFolder] includingPropertiesForKeys:nil options:0 error:nil])
  if([url.pathExtension isEqual:@"png"])[cars addObject:@{@"name":url.lastPathComponent.stringByDeletingPathExtension,@"path":url.path,@"user":@YES}];
 return cars;
}
+ (NSDictionary *)currentEntry {
 NSArray *cars=[self allCars];NSString *want=[NSUserDefaults.standardUserDefaults stringForKey:SLCarKey];
 for(NSDictionary *car in cars)if([car[@"name"] isEqual:want])return car;return cars.firstObject;
}
+ (NSString *)currentName {return [self currentEntry][@"name"]?:@"";}
+ (NSString *)paint {return [NSUserDefaults.standardUserDefaults stringForKey:@"premiumPaint"]?:@"original";}
+ (NSString *)light {return [NSUserDefaults.standardUserDefaults stringForKey:@"premiumLight"]?:@"auto";}
+ (UIImage *)originalCar {NSString *path=[self currentEntry][@"path"];return path?[UIImage imageWithContentsOfFile:path]:nil;}
+ (UIImage *)currentCar {
 UIImage *car=[self originalCar];UIColor *paint=SLRGBString([self paint]);if(!car.CGImage||!paint)return car;
 static NSCache *cache;static dispatch_once_t once;dispatch_once(&once,^{cache=[NSCache new];});NSString *key=[NSString stringWithFormat:@"%@|%@",[self currentName],[self paint]];UIImage *hit=[cache objectForKey:key];if(hit)return hit;
 UIImage *painted=[self repaint:car with:paint];if(painted)[cache setObject:painted forKey:key];return painted?:car;
}
/// Repaints the car body: the main paint (the most common bright or colored surface) gets the new color with
/// its own light and shadow kept; windows, tires, lights and stripes of another color stay as they are.
+ (UIImage *)repaint:(UIImage *)car with:(UIColor *)color {
 size_t w=CGImageGetWidth(car.CGImage),h=CGImageGetHeight(car.CGImage);uint8_t *px=calloc(w*h*4,1);if(!px)return nil;
 CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB();CGContextRef ctx=CGBitmapContextCreate(px,w,h,8,w*4,space,kCGImageAlphaPremultipliedLast);
 CGContextDrawImage(ctx,CGRectMake(0,0,w,h),car.CGImage);
 // Find the paint: a hue histogram of colored pixels, or "white paint" when most bright pixels are grey.
 double hues[36]={0};double greys=0,colored=0;
 for(size_t i=0;i<w*h;i+=7){uint8_t *p=px+i*4;if(p[3]<220)continue;double R=p[0]/255.,G=p[1]/255.,B=p[2]/255.,mx=MAX(R,MAX(G,B)),mn=MIN(R,MIN(G,B)),s=mx>0?(mx-mn)/mx:0;
  if(mx<.25)continue;if(s<.18){if(mx>.45)greys++;continue;}double hue=[self hueR:R g:G b:B];hues[(int)(hue*35.999)]+=1;colored++;}
 int best=0;for(int i=1;i<36;i++)if(hues[i]>hues[best])best=i;BOOL whitePaint=greys>hues[best]*1.4;double paintHue=(best+.5)/36.;
 // Brightness of the paint (most lit part) to keep the shading.
 double ref=0,count=0;
 for(size_t i=0;i<w*h;i+=5){uint8_t *p=px+i*4;if(p[3]<220)continue;double a=p[3]/255.,R=p[0]/255./a,G=p[1]/255./a,B=p[2]/255./a,mx=MAX(R,MAX(G,B)),mn=MIN(R,MIN(G,B)),s=mx>0?(mx-mn)/mx:0;
  BOOL paint=whitePaint?(s<.18&&mx>.35):(s>.25&&mx>.18&&fabs(fmod([self hueR:R g:G b:B]-paintHue+1.5,1)-.5)<.06);if(paint){ref+=.3*R+.59*G+.11*B;count++;}}
 ref=count>0?MAX(.2,ref/count*1.25):.8;
 CGFloat tr,tg,tb;[color getRed:&tr green:&tg blue:&tb alpha:NULL];
 for(size_t i=0;i<w*h;i++){uint8_t *p=px+i*4;if(p[3]==0)continue;double a=p[3]/255.,R=p[0]/255./a,G=p[1]/255./a,B=p[2]/255./a,mx=MAX(R,MAX(G,B)),mn=MIN(R,MIN(G,B)),s=mx>0?(mx-mn)/mx:0;
  double weight=0;
  if(whitePaint){if(s<.2&&mx>.42)weight=MIN(1,(mx-.42)/.13)*MIN(1,(.2-s)/.06);}
  else{double d=fabs(fmod([self hueR:R g:G b:B]-paintHue+1.5,1)-.5);if(s>.2&&mx>.12&&d<.08)weight=MIN(1,(.08-d)/.03)*MIN(1,(s-.2)/.1);}
  if(weight<=0)continue;double L=(.3*R+.59*G+.11*B)/ref;double light=MIN(1.25,L);
  double nr=MIN(1,tr*light+MAX(0,L-1)*.5),ng=MIN(1,tg*light+MAX(0,L-1)*.5),nb=MIN(1,tb*light+MAX(0,L-1)*.5);
  R=R+(nr-R)*weight;G=G+(ng-G)*weight;B=B+(nb-B)*weight;p[0]=(uint8_t)(MIN(1,R)*a*255);p[1]=(uint8_t)(MIN(1,G)*a*255);p[2]=(uint8_t)(MIN(1,B)*a*255);}
 CGImageRef out=CGBitmapContextCreateImage(ctx);CGContextRelease(ctx);CGColorSpaceRelease(space);free(px);
 UIImage *result=out?[UIImage imageWithCGImage:out scale:car.scale orientation:UIImageOrientationUp]:nil;if(out)CGImageRelease(out);return result;
}
+ (double)hueR:(double)r g:(double)g b:(double)b {double mx=MAX(r,MAX(g,b)),mn=MIN(r,MIN(g,b)),d=mx-mn;if(d<=0)return 0;double h=mx==r?fmod((g-b)/d,6):mx==g?(b-r)/d+2:(r-g)/d+4;h/=6;return h<0?h+1:h;}
/// The room color: the car's own color, darkened. White, grey and black cars get the cool blue room.
+ (UIColor *)currentTint {
 NSString *light=[self light];
 if([light isEqual:@"white"])return [UIColor colorWithHue:.58 saturation:.06 brightness:.40 alpha:1];
 if(![light isEqual:@"auto"])return [UIColor colorWithHue:[light doubleValue] saturation:.6 brightness:.36 alpha:1];
 UIColor *paint=SLRGBString([self paint]);
 if(paint){CGFloat h,s;[paint getHue:&h saturation:&s brightness:NULL alpha:NULL];return s>.3?[UIColor colorWithHue:h saturation:MIN(.75,s*.95) brightness:.36 alpha:1]:[UIColor colorWithHue:.56 saturation:.45 brightness:.34 alpha:1];}
 UIImage *image=[self originalCar];if(!image.CGImage)return [UIColor colorWithHue:.56 saturation:.45 brightness:.34 alpha:1];
 static NSCache *cache;static dispatch_once_t once;dispatch_once(&once,^{cache=[NSCache new];});NSString *key=[NSString stringWithFormat:@"%@|tint",[self currentName]];UIColor *hit=[cache objectForKey:key];if(hit)return hit;
 size_t w=48,h=MAX(8,(size_t)(48*image.size.height/MAX(1,image.size.width)));uint8_t *px=calloc(w*h*4,1);
 CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB();CGContextRef ctx=CGBitmapContextCreate(px,w,h,8,w*4,space,kCGImageAlphaPremultipliedLast);CGColorSpaceRelease(space);
 CGContextDrawImage(ctx,CGRectMake(0,0,w,h),image.CGImage);CGContextRelease(ctx);
 double r=0,g=0,b=0,n=0;
 for(size_t i=0;i<w*h;i++){uint8_t *p=px+i*4;if(p[3]<200)continue;double R=p[0]/255.,G=p[1]/255.,B=p[2]/255.,mx=MAX(R,MAX(G,B)),mn=MIN(R,MIN(G,B));double weight=(mx-mn)+.02;r+=R*weight;g+=G*weight;b+=B*weight;n+=weight;}
 free(px);
 UIColor *tint=[UIColor colorWithHue:.56 saturation:.45 brightness:.34 alpha:1];
 if(n>0){UIColor *avg=[UIColor colorWithRed:r/n green:g/n blue:b/n alpha:1];CGFloat hue,sat,bri;[avg getHue:&hue saturation:&sat brightness:&bri alpha:NULL];
  if(sat>.28)tint=[UIColor colorWithHue:hue saturation:MIN(.75,sat*.95) brightness:.36 alpha:1];}
 [cache setObject:tint forKey:key];return tint;
}
+ (void)choose:(NSString *)name {[NSUserDefaults.standardUserDefaults setObject:name forKey:SLCarKey];[NSNotificationCenter.defaultCenter postNotificationName:@"SLCarChanged" object:nil];}
+ (void)presentPickerFrom:(UIViewController *)controller completion:(void (^)(void))completion {
 UIAlertController *sheet=[UIAlertController alertControllerWithTitle:@"Choose your car" message:@"The room light follows the car's color." preferredStyle:UIAlertControllerStyleActionSheet];
 NSString *current=[self currentName];
 for(NSDictionary *car in [self allCars]){NSString *name=car[@"name"];
  [sheet addAction:[UIAlertAction actionWithTitle:[name isEqual:current]?[@"✓ " stringByAppendingString:name]:name style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){[self choose:name];if(completion)completion();}]];}
 [sheet addAction:[UIAlertAction actionWithTitle:@"Paint color…" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){[self pick:@"Paint color" options:SLPaints() key:@"premiumPaint" current:[self paint] from:controller completion:completion];}]];
 [sheet addAction:[UIAlertAction actionWithTitle:@"Room light…" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){[self pick:@"Room light" options:SLLights() key:@"premiumLight" current:[self light] from:controller completion:completion];}]];
 [sheet addAction:[UIAlertAction actionWithTitle:@"Add a car from Photos…" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
  PHPickerConfiguration *config=[PHPickerConfiguration new];config.filter=PHPickerFilter.imagesFilter;config.selectionLimit=1;
  PHPickerViewController *picker=[[PHPickerViewController alloc]initWithConfiguration:config];SLCarPicking=[SLCarLibrary new];SLCarPicking.done=completion;picker.delegate=SLCarPicking;[controller presentViewController:picker animated:YES completion:nil];}]];
 NSDictionary *entry=[self currentEntry];
 if([entry[@"user"] boolValue])[sheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Remove %@",entry[@"name"]] style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a){
  [NSFileManager.defaultManager removeItemAtPath:entry[@"path"] error:nil];[NSUserDefaults.standardUserDefaults removeObjectForKey:SLCarKey];[NSNotificationCenter.defaultCenter postNotificationName:@"SLCarChanged" object:nil];if(completion)completion();}]];
 [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
 sheet.popoverPresentationController.sourceView=controller.view;sheet.popoverPresentationController.sourceRect=CGRectMake(CGRectGetMidX(controller.view.bounds),CGRectGetMidY(controller.view.bounds),1,1);sheet.popoverPresentationController.permittedArrowDirections=0;
 [controller presentViewController:sheet animated:YES completion:nil];
}
+ (void)pick:(NSString *)title options:(NSArray<NSArray *> *)options key:(NSString *)key current:(NSString *)current from:(UIViewController *)controller completion:(void (^)(void))completion {
 UIAlertController *sheet=[UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleActionSheet];
 for(NSArray *o in options){NSString *value=o[1];[sheet addAction:[UIAlertAction actionWithTitle:[value isEqual:current]?[@"✓ " stringByAppendingString:o[0]]:o[0] style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
  [NSUserDefaults.standardUserDefaults setObject:value forKey:key];[NSNotificationCenter.defaultCenter postNotificationName:@"SLCarChanged" object:nil];if(completion)completion();}]];}
 [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
 sheet.popoverPresentationController.sourceView=controller.view;sheet.popoverPresentationController.sourceRect=CGRectMake(CGRectGetMidX(controller.view.bounds),CGRectGetMidY(controller.view.bounds),1,1);sheet.popoverPresentationController.permittedArrowDirections=0;
 [controller presentViewController:sheet animated:YES completion:nil];
}
- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
 [picker dismissViewControllerAnimated:YES completion:nil];
 NSItemProvider *item=results.firstObject.itemProvider;if(![item canLoadObjectOfClass:UIImage.class]){SLCarPicking=nil;return;}
 void (^done)(void)=self.done;
 [item loadObjectOfClass:UIImage.class completionHandler:^(UIImage *image,NSError *error){
  UIImage *car=image?[SLCarLibrary liftCar:image]:nil;
  dispatch_async(dispatch_get_main_queue(),^{
   if(car){NSString *name=[NSString stringWithFormat:@"My car %ld",(long)([SLCarLibrary allCars].count+1)];
    [UIImagePNGRepresentation(car) writeToURL:[[SLCarLibrary userFolder] URLByAppendingPathComponent:[name stringByAppendingPathExtension:@"png"]] atomically:YES];[SLCarLibrary choose:name];}
   if(done)done();SLCarPicking=nil;});
 }];
}
/// Cuts the car out of the photo with Apple's subject lifting, then trims the empty edges.
+ (UIImage *)liftCar:(UIImage *)photo {
 UIGraphicsImageRendererFormat *format=[UIGraphicsImageRendererFormat defaultFormat];format.scale=1;
 CGFloat scale=MIN(1,2000/MAX(photo.size.width,photo.size.height));CGSize size=CGSizeMake(round(photo.size.width*scale),round(photo.size.height*scale));
 UIImage *upright=[[[UIGraphicsImageRenderer alloc]initWithSize:size format:format] imageWithActions:^(UIGraphicsImageRendererContext *c){[photo drawInRect:CGRectMake(0,0,size.width,size.height)];}];
 CIImage *input=[CIImage imageWithCGImage:upright.CGImage];CIImage *output=nil;
 if(@available(iOS 17.0,*)){
  VNGenerateForegroundInstanceMaskRequest *request=[VNGenerateForegroundInstanceMaskRequest new];VNImageRequestHandler *handler=[[VNImageRequestHandler alloc]initWithCIImage:input options:@{}];
  if([handler performRequests:@[request] error:nil]){VNInstanceMaskObservation *mask=request.results.firstObject;
   if(mask){CVPixelBufferRef buffer=[mask generateMaskedImageOfInstances:mask.allInstances fromRequestHandler:handler croppedToInstancesExtent:YES error:nil];if(buffer){output=[CIImage imageWithCVPixelBuffer:buffer];}}}
 }
 if(!output)return upright;   // older iOS: the whole photo (the Home softens its edges)
 CGImageRef cg=[[CIContext context] createCGImage:output fromRect:output.extent];if(!cg)return upright;UIImage *result=[UIImage imageWithCGImage:cg];CGImageRelease(cg);return result;
}
@end
