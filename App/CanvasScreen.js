/* Live screen: bounded fMP4 over WSS -> WebCodecs -> Canvas. */
(()=>{'use strict';
class CanvasScreen {
 constructor(canvas,{onstate=()=>{},onerror=()=>{}}={}){this.canvas=canvas;this.ctx=canvas.getContext('2d',{alpha:false});if(!this.ctx)throw Error('Canvas unavailable');this.onstate=onstate;this.onerror=onerror;this.hold=true;this.minRevision=0;this.serial=0;this.framesDrawn=0;this.closed=false;this.clear();}
 clear(){this.serial++;if(this.decoder?.state!=='closed')this.decoder?.close();this.decoder=null;this.config='';this.init=null;this.epoch='';this.frame?.close();this.frame=null;cancelAnimationFrame(this.raf);this.raf=0;this.ctx.fillStyle='#000';this.ctx.fillRect(0,0,this.canvas.width,this.canvas.height);}
 hide(){this.hold=true;this.clear();}
 privacy(meta,show=false){this.minRevision=Math.max(this.minRevision,Number(meta.privacyRevision)||0);if(meta.hidden){this.hide();this.onstate({...meta,confirmed:true});}else if(show){this.clear();this.hold=false;}}
 state(meta){const revision=Number(meta.privacyRevision)||0;if(revision<this.minRevision)return false;this.minRevision=revision;this.meta=meta;if(meta.hidden){this.hide();this.onstate({...meta,confirmed:true});return false;}if(this.hold){this.onstate({...meta,localHidden:true});return false;}if(this.epoch&&meta.epoch!==this.epoch)this.clear();this.onstate(meta);return true;}
 async packet(meta,buffer){if(!this.state(meta))return;const bytes=new Uint8Array(buffer);if(bytes.byteLength>2*1024*1024)throw Error('Screen packet too large');
  if(meta.kind==='init'){this.clear();this.epoch=meta.epoch;this.init=bytes;return;}
  if(meta.kind!=='data'||!this.init||this.epoch!==meta.epoch)return;
  const serial=this.serial,samples=ScreenLinkCanvas.demux(bytes,this.init).filter(s=>s.track?.video);
  for(const sample of samples){if(this.closed||serial!==this.serial||this.hold)return;const t=sample.track;let config={codec:t.codec,codedWidth:t.video.width,codedHeight:t.video.height,description:t.description,hardwareAcceleration:'prefer-hardware'};
   const key=JSON.stringify({...config,description:Array.from(t.description||[])});
   if(this.config!==key){let support=await VideoDecoder.isConfigSupported(config);if(!support.supported){delete config.hardwareAcceleration;support=await VideoDecoder.isConfigSupported(config);}if(serial!==this.serial||this.hold||this.closed)return;if(!support.supported)throw Error('Screen codec unsupported: '+t.codec);this.decoder?.close();this.decoder=new VideoDecoder({output:frame=>{if(serial!==this.serial||this.closed||this.hold){frame.close();return;}this.frame?.close();this.frame=frame;if(!this.raf)this.raf=requestAnimationFrame(()=>this.paint());},error:e=>this.onerror(e)});this.decoder.configure(config);this.config=key;this.needKey=true;}
   if(this.needKey&&!sample.is_sync)continue;if(sample.is_sync)this.needKey=false;
   while(this.decoder.decodeQueueSize>6){await new Promise(r=>setTimeout(r,5));if(serial!==this.serial||this.hold||this.closed)return;}
   this.decoder.decode(new EncodedVideoChunk({type:sample.is_sync?'key':'delta',timestamp:Math.round(sample.cts/sample.timescale*1e6),duration:Math.max(1,Math.round(sample.duration/sample.timescale*1e6)),data:sample.data}));
  }
 }
 paint(){this.raf=0;const frame=this.frame;this.frame=null;if(!frame)return;try{if(this.closed||this.hold)return;const orientation=Number(this.meta?.orientation)||1,side=orientation===6||orientation===8,angle=orientation===6?Math.PI/2:orientation===8?-Math.PI/2:orientation===3?Math.PI:0;const w=side?frame.displayHeight:frame.displayWidth,h=side?frame.displayWidth:frame.displayHeight;if(this.canvas.width!==w||this.canvas.height!==h){this.canvas.width=w;this.canvas.height=h;}this.ctx.save();this.ctx.translate(w/2,h/2);this.ctx.rotate(angle);this.ctx.drawImage(frame,-frame.displayWidth/2,-frame.displayHeight/2);this.ctx.restore();this.framesDrawn++;this.onstate({...this.meta,frameReady:true,framesDrawn:this.framesDrawn});}finally{frame.close();}}
 destroy(){this.closed=true;this.hide();}
}
self.ScreenLinkScreen={CanvasScreen};})();
