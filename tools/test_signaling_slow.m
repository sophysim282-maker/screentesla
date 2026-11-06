#import <Foundation/Foundation.h>
#import "SLSignaling.h"
// A real delayed loopback HTTP response: the former 8-second request budget fails it.
int main(void){@autoreleasepool{
 NSTask *server=[NSTask new];server.executableURL=[NSURL fileURLWithPath:@"/usr/bin/env"];server.arguments=@[@"python3",@"-u",@"-c",@"import http.server,time\nclass H(http.server.BaseHTTPRequestHandler):\n def do_GET(self):\n  time.sleep(9)\n  self.send_response(200);self.send_header('Content-Type','application/json');self.end_headers();self.wfile.write(b'{\"status\":\"ready\"}')\n def log_message(self,*args): pass\ns=http.server.HTTPServer(('127.0.0.1',0),H);print(s.server_port,flush=True);s.serve_forever()"];
 NSPipe *output=[NSPipe pipe];server.standardOutput=output;server.standardError=[NSFileHandle fileHandleWithNullDevice];NSError *launch=nil;if(![server launchAndReturnError:&launch]){fprintf(stderr,"Slow signaling fixture failed to start\n");return 1;}
 NSMutableData *portBytes=[NSMutableData data];for(NSUInteger i=0;i<8;i++){NSData *byte=[output.fileHandleForReading readDataOfLength:1];if(!byte.length)break;if(((const char *)byte.bytes)[0]=='\n')break;[portBytes appendData:byte];}NSInteger port=[[[NSString alloc]initWithData:portBytes encoding:NSUTF8StringEncoding] integerValue];if(port<=0){[server terminate];return 1;}
 SLSignaling *api=[[SLSignaling alloc]initWithBaseURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://127.0.0.1:%ld",(long)port]]];__block BOOL done=NO,passed=NO;NSTimeInterval began=NSProcessInfo.processInfo.systemUptime;
 [api call:@"GET" path:@"/delayed" authorization:nil body:nil completion:^(NSInteger code,NSDictionary *body,NSError *error){passed=!error&&code==200&&[body[@"status"] isEqual:@"ready"];done=YES;}];
 while(!done&&NSProcessInfo.processInfo.systemUptime-began<24)[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
 NSTimeInterval elapsed=NSProcessInfo.processInfo.systemUptime-began;[api close];[server terminate];[server waitUntilExit];if(!done||!passed||elapsed<8.5){fprintf(stderr,"Slow signaling regression failed\n");return 1;}
 puts("Slow signaling passed: real 9-second HTTP response accepted within the bounded request budget. No cellular/Tesla network tested.");return 0;
}}
