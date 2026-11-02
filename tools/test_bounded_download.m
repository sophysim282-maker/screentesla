#import <Foundation/Foundation.h>
#import "BoundedDownload.h"
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>
#include <signal.h>
#include <assert.h>
int main(void){@autoreleasepool{
 signal(SIGPIPE,SIG_IGN);int server=socket(AF_INET,SOCK_STREAM,0);assert(server>=0);struct sockaddr_in address={0};address.sin_len=sizeof address;address.sin_family=AF_INET;address.sin_addr.s_addr=htonl(INADDR_LOOPBACK);assert(!bind(server,(void *)&address,sizeof address));assert(!listen(server,2));socklen_t len=sizeof address;assert(!getsockname(server,(void *)&address,&len));
 [NSThread detachNewThreadWithBlock:^{@autoreleasepool{for(int i=0;i<2;i++){int client=accept(server,NULL,NULL);assert(client>=0);char input[2048];recv(client,input,sizeof input,0);const char *header="HTTP/1.1 200 OK\r\nContent-Length: 8192\r\nContent-Type: video/mp2t\r\nConnection: close\r\n\r\n";send(client,header,strlen(header),0);char body[8192];memset(body,'v',sizeof body);send(client,body,sizeof body,0);close(client);}close(server);}}];
 NSURLRequest *request=[NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://127.0.0.1:%d/",ntohs(address.sin_port)]]];NSDictionary *small=SLBoundedDownload(request,4096);assert([small[@"code"] intValue]==413);assert(![small[@"data"] length]);NSDictionary *large=SLBoundedDownload(request,16384);assert([large[@"code"] intValue]==200);assert([large[@"data"] length]==8192);puts("Bounded resource download passed: oversized response cancelled, allowed media retained.");
}return 0;}
