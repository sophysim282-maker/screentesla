#import "HLSPlaylist.h"
static NSString *attribute(NSString *line,NSString *name){
    NSRegularExpression *re=[NSRegularExpression regularExpressionWithPattern:[NSString stringWithFormat:@"(?:^|[:,])%@=\"([^\"]*)\"",name] options:0 error:NULL];
    NSTextCheckingResult *match=[re firstMatchInString:line options:0 range:NSMakeRange(0,line.length)];
    return match?[line substringWithRange:[match rangeAtIndex:1]]:nil;
}
static void fail(NSError **error,NSString *message){if(error)*error=[NSError errorWithDomain:@"ScreenLink.HLS" code:1 userInfo:@{NSLocalizedDescriptionKey:message}];}
NSString *SLExpandYouTubePlaylist(NSString *text,NSError **error){
    NSArray *lines=[[text stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"] componentsSeparatedByString:@"\n"];
    if(![lines.firstObject isEqual:@"#EXTM3U"]){fail(error,@"The sender did not supply an HLS playlist.");return nil;}
    NSString *base=nil,*prefix=nil;NSArray *params=nil;NSMutableArray *out=[NSMutableArray array];
    for(NSString *line in lines){
        if([line hasPrefix:@"#YT-EXT-CONDENSED-URL:"]){
            base=attribute(line,@"BASE-URI");prefix=attribute(line,@"PREFIX");NSString *names=attribute(line,@"PARAMS");params=[names componentsSeparatedByString:@","];
            if(!base.length || !prefix.length || !names.length || [params containsObject:@""]){fail(error,@"Invalid YouTube condensed playlist header.");return nil;}
            continue;
        }
        if(prefix && [line hasPrefix:prefix]){
            NSArray *values=[[line substringFromIndex:prefix.length] componentsSeparatedByString:@"/"];
            if(values.count!=params.count){fail(error,@"YouTube segment parameter count does not match its playlist header.");return nil;}
            NSMutableString *url=[base mutableCopy];
            for(NSUInteger i=0;i<params.count;i++)[url appendFormat:@"/%@/%@",params[i],values[i]];
            [out addObject:url];
        }else [out addObject:line];
    }
    return [[out componentsJoinedByString:@"\n"] stringByAppendingString:[out.lastObject length]?@"\n":@""];
}
NSString *SLRewritePlaylist(NSString *text,NSString *(^map)(NSString *uri),NSError **error){
    NSString *expanded=SLExpandYouTubePlaylist(text,error);if(!expanded)return nil;
    NSMutableArray *out=[NSMutableArray array];
    NSRegularExpression *re=[NSRegularExpression regularExpressionWithPattern:@"URI=\"([^\"]+)\"" options:0 error:NULL];
    for(NSString *line in [expanded componentsSeparatedByString:@"\n"]){
        if([line hasPrefix:@"#EXT-X-KEY:"] && ([line containsString:@"SAMPLE-AES"] || [line containsString:@"com.apple.streamingkeydelivery"])){fail(error,@"Protected AirPlay media is not supported.");return nil;}
        if(line.length && ![line hasPrefix:@"#"]){NSString *mapped=map(line);if(!mapped){fail(error,@"Unsupported media URL.");return nil;}[out addObject:mapped];continue;}
        NSMutableString *mapped=[line mutableCopy];NSArray *matches=[re matchesInString:line options:0 range:NSMakeRange(0,line.length)];
        for(NSTextCheckingResult *match in matches.reverseObjectEnumerator){NSString *uri=map([line substringWithRange:[match rangeAtIndex:1]]);if(!uri){fail(error,@"Unsupported playlist URL.");return nil;}[mapped replaceCharactersInRange:[match rangeAtIndex:1] withString:uri];}
        [out addObject:mapped];
    }
    return [out componentsJoinedByString:@"\n"];
}

NSInteger SLFCUPPlaylistStatus(NSInteger status,NSData *data){
    if(status!=0)return status;
    if(!data.length)return 502;
    NSString *text=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    return text && SLExpandYouTubePlaylist(text,NULL)?200:502;
}
