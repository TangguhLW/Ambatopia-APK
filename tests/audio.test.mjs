import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
for(const name of ['click','jump','punch','place','break'])test(`${name} WAV has playable, non-silent PCM samples`,async()=>{
 const b=await readFile(`assets/reference/${name}_sound.wav`);assert.equal(b.toString('ascii',0,4),'RIFF');assert.equal(b.toString('ascii',8,12),'WAVE');
 let format,pcm;
 for(let at=12;at+8<=b.length;){const size=b.readUInt32LE(at+4);assert(at+8+size<=b.length);const chunk=b.toString('ascii',at,at+4);if(chunk==='fmt ')format=b.subarray(at+8,at+8+size);if(chunk==='data')pcm=b.subarray(at+8,at+8+size);at+=8+size+(size%2);}
 assert(format&&pcm);assert.equal(format.readUInt16LE(0),1);assert.equal(format.readUInt16LE(14),16);let energy=0;
 for(let at=0;at+1<pcm.length;at+=2)energy+=(pcm.readInt16LE(at)/32768)**2;
 assert(Math.sqrt(energy/(pcm.length/2))>0.001,'Sound must contain non-silent samples');
 const duration=pcm.length/format.readUInt32LE(8);assert(duration>0.01&&duration<5);
});
