#import <Foundation/Foundation.h>
// Build 71: the website certificate can live in the app's own storage, imported
// once from the user's earlier ScreenLink IPA (or its certificate files), so new
// builds no longer need the identity added to every IPA. A certificate inside
// the IPA (PrivateTLS) still takes priority. Nothing is uploaded anywhere.
@interface SLIdentityStore : NSObject
+ (NSString *)activeDirectory;
+ (BOOL)hasIdentity;
+ (NSString *)importFromURLs:(NSArray<NSURL *> *)urls success:(BOOL *)success;
@end
