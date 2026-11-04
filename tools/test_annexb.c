#include <assert.h>
#include "../App/AnnexB.h"
int main(void) {
 size_t s[8],n[8];
 unsigned char p[]={0,0,0,1,0x67,0x42,0,0,1,0x68,0xce,0,0,0,1,0x65,0x88};
 assert(sl_nals(p,sizeof p,s,n,8)==3);
 assert(s[0]==4&&n[0]==2&&s[1]==9&&n[1]==2&&s[2]==15&&n[2]==2);
 assert(sl_nals(p,sizeof p,s,n,1)==2);
 assert(sl_nals(p,0,s,n,8)==0);
 unsigned char adjacent[]={0,0,1,0,0,0,1,0x65};
 assert(sl_nals(adjacent,sizeof adjacent,s,n,8)==1&&n[0]==1);
 unsigned char plain[]={0x65,0x88};assert(sl_nals(plain,2,s,n,8)==0);
 unsigned char truncated[]={0,0,0,1};assert(sl_nals(truncated,4,s,n,8)==0);
 return 0;
}
