import test from 'node:test';
import assert from 'node:assert/strict';
import {toNative,toRuntime,toWebSnapshot,appearanceToEquipment,equipmentToAppearance} from '../src/mapping.mjs';
test('maps server IDs to exact simulator IDs without confusing bedrock and dirt',()=>{
 assert.equal(toNative(1),2);assert.equal(toNative(2),8);assert.equal(toNative(4),6);assert.equal(toRuntime(200242),5);assert.throws(()=>toNative(20015416));assert.equal(toNative(215416),15416);
});
test('converts server pixel spawn and full native tile IDs to web snapshot',()=>{
 const world={foreground:Array(6000).fill(1),background:Array(6000).fill(0),main_door:[50,23]};world.foreground[2350]=4;
 const snapshot=toWebSnapshot(world);assert.equal(snapshot.foreground[2350],15);assert.equal(snapshot.spawn.x,50);assert.equal(snapshot.spawn.y,23);
});
test('preserves wardrobe slot identity across the native outfit bridge',()=>{
 const outfit=appearanceToEquipment({outfit:[46,36,48,40,34,92,362,68]});assert.equal(outfit.hat,46);assert.equal(outfit.back,362);
 assert.deepEqual(equipmentToAppearance(outfit).outfit,[46,36,48,40,34,92,362,68]);
});

