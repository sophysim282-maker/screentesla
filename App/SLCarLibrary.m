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
+ (UIImage *)currentCar {NSString *path=[self currentEntry][@"path"];return path?[UIImage imageWithContentsOfFile:path]:nil;}
/// The room color: the car's own color, darkened. White, grey and black cars get the cool blue room.
+ (UIColor *)currentTint {
 UIImage *image=[self currentCar];if(!image.CGImage)return [UIColor colorWithHue:.56 saturation:.45 brightness:.34 alpha:1];
 static NSCache *cache;static dispatch_once_t once;dispatch_once(&once,^{cache=[NSCache new];});NSString *key=[self currentName];UIColor *hit=[cache objectForKey:key];if(hit)return hit;
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
