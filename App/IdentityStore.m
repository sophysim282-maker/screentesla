#import "IdentityStore.h"
#import "ZipEntry.h"
#import "LocalTLS.h"
static int mainAppChain(const char *n){return !strncmp(n,"Payload/",8)&&strstr(n,".app/PrivateTLS/fullchain.pem")&&!strstr(n,"/PlugIns/");}
static int mainAppKey(const char *n){return !strncmp(n,"Payload/",8)&&strstr(n,".app/PrivateTLS/private.key")&&!strstr(n,"/PlugIns/");}
@implementation SLIdentityStore
+ (NSString *)bundleDirectory {return [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"PrivateTLS"];}
+ (NSString *)storeDirectory {
    NSURL *support=[NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
    return [support.path stringByAppendingPathComponent:@"ScreenLinkWebsiteCertificate"];
}
+ (BOOL)complete:(NSString *)directory {NSFileManager *m=NSFileManager.defaultManager;return [m fileExistsAtPath:[directory stringByAppendingPathComponent:@"fullchain.pem"]]&&[m fileExistsAtPath:[directory stringByAppendingPathComponent:@"private.key"]];}
+ (NSString *)activeDirectory {NSString *bundle=[self bundleDirectory];if([self complete:bundle])return bundle;NSString *store=[self storeDirectory];return [self complete:store]?store:bundle;}
+ (BOOL)hasIdentity {return [self complete:[self activeDirectory]];}
+ (NSData *)zipEntry:(NSURL *)url match:(sl_zip_match)match error:(NSString **)message {
    unsigned char *bytes=NULL;size_t size=0;char error[160]={0};
    if(!sl_zip_extract(url.fileSystemRepresentation,match,&bytes,&size,error,sizeof error)){*message=[NSString stringWithUTF8String:error];return nil;}
    return [NSData dataWithBytesNoCopy:bytes length:size freeWhenDone:YES];
}
+ (NSString *)importFromURLs:(NSArray<NSURL *> *)urls success:(BOOL *)success {
    *success=NO;NSData *chain=nil,*key=nil;NSMutableArray *leaf=[NSMutableArray array],*authorities=[NSMutableArray array];NSString *problem=nil;
    for(NSURL *url in urls){
        BOOL scoped=[url startAccessingSecurityScopedResource];
        NSString *ext=url.pathExtension.lowercaseString;
        if([@[@"ipa",@"zip"] containsObject:ext]){
            NSString *error=nil;NSData *c=[self zipEntry:url match:mainAppChain error:&error],*k=c?[self zipEntry:url match:mainAppKey error:&error]:nil;
            if(c&&k){chain=c;key=k;}else problem=[NSString stringWithFormat:@"%@: %@",url.lastPathComponent,error?:@"No website certificate found in this file."];
        }else{
            NSData *data=[NSData dataWithContentsOfURL:url];NSString *text=data?[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding]:nil;NSString *name=url.lastPathComponent.lowercaseString;
            if([text containsString:@"PRIVATE KEY-----"])key=data;
            else if([text containsString:@"BEGIN CERTIFICATE"]){
                if([name containsString:@"fullchain"])chain=data;
                else if([name containsString:@"ca_bundle"]||[name containsString:@"cabundle"]||[name containsString:@"chain"]||[name hasPrefix:@"ca"])[authorities addObject:data];
                else [leaf addObject:data];
            }else problem=[NSString stringWithFormat:@"%@ is not a certificate, key or ScreenLink IPA.",url.lastPathComponent];
        }
        if(scoped)[url stopAccessingSecurityScopedResource];
    }
    if(!chain&&(leaf.count||authorities.count)){
        NSMutableData *joined=[NSMutableData data];
        for(NSData *part in [leaf arrayByAddingObjectsFromArray:authorities]){[joined appendData:part];[joined appendBytes:"\n" length:1];}
        chain=joined;
    }
    if(!chain||!key)return problem?:@"Pick your earlier ScreenLink IPA that had the website working, or the certificate and private key files together.";
    NSFileManager *m=NSFileManager.defaultManager;NSString *store=[self storeDirectory],*staging=[store stringByAppendingString:@".new"];
    [m removeItemAtPath:staging error:nil];
    NSDictionary *protection=@{NSFileProtectionKey:NSFileProtectionCompleteUntilFirstUserAuthentication,NSFilePosixPermissions:@0600};
    if(![m createDirectoryAtPath:staging withIntermediateDirectories:YES attributes:@{NSFileProtectionKey:NSFileProtectionCompleteUntilFirstUserAuthentication} error:nil]||
       ![m createFileAtPath:[staging stringByAppendingPathComponent:@"fullchain.pem"] contents:chain attributes:protection]||
       ![m createFileAtPath:[staging stringByAppendingPathComponent:@"private.key"] contents:key attributes:protection]){[m removeItemAtPath:staging error:nil];return @"The certificate could not be saved on this iPhone.";}
    char detail[200]={0};
    BOOL valid=sl_tls_identity_check([[staging stringByAppendingPathComponent:@"fullchain.pem"] fileSystemRepresentation],[[staging stringByAppendingPathComponent:@"private.key"] fileSystemRepresentation],detail,sizeof detail);
    if(!valid){[m removeItemAtPath:staging error:nil];return [NSString stringWithUTF8String:detail];}
    [m removeItemAtPath:store error:nil];
    if(![m moveItemAtPath:staging toPath:store error:nil]){[m removeItemAtPath:staging error:nil];return @"The certificate could not be saved on this iPhone.";}
    NSURL *storeURL=[NSURL fileURLWithPath:store isDirectory:YES];[storeURL setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:nil];
    *success=YES;return [NSString stringWithFormat:@"WEBSITE CERTIFICATE SAVED: %s It stays in ScreenLink for future builds.",detail];
}
@end
