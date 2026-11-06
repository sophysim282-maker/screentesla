#import <Foundation/Foundation.h>
/* MediaCast keeps its original token; only alias response copies are retokened. */
static inline NSData *SLRetokenLocalMediaData(NSData *data,NSString *mime,NSString *original,NSString *viewer) {
    if(!original.length || !viewer.length || (![mime isEqual:@"application/json"] && ![mime isEqual:@"application/vnd.apple.mpegurl"]))return data;
    NSString *text=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];if(!text)return data;
    for(NSString *prefix in @[@"?token=",@"&token="])text=[text stringByReplacingOccurrencesOfString:[prefix stringByAppendingString:original] withString:[prefix stringByAppendingString:viewer]];
    return [text dataUsingEncoding:NSUTF8StringEncoding];
}
