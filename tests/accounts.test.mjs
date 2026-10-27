import {test} from 'node:test';
import assert from 'node:assert/strict';
import {identity,password,alias,reserved,createBroker} from '../server/accounts.mjs';
test('AmbaID canonicalization and reserved identity',()=>{assert.equal(alias('Player_1'),'player_1@players.ambatopia.invalid');assert(reserved('ThAnEy'));for(const bad of ['../x','@Thaney','x','a@b.com','a b'])assert.throws(()=>identity(bad));});
test('password bounds and dedicated project guard',()=>{assert.throws(()=>password('short'));assert.throws(()=>password('a'.repeat(73)));assert.equal(password('test-password-123'),'test-password-123');assert.throws(()=>createBroker({SUPABASE_URL:'https://other.supabase.co'}));});
