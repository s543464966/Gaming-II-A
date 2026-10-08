import test from 'node:test';
import assert from 'node:assert/strict';
import { createGame, moveDonuts, isWaiting } from '../../Designing/prototypes/legacy_donut_sort/engine.mjs';

test('凑齐未匹配需求的盒子等待；一次搬运引发草莓、蓝莓、香橙三次回收', () => {
  const initial = createGame();
  assert.equal(isWaiting(initial, initial.board[2]), true);
  const result = moveDonuts(initial, 1, 0);
  assert.equal(result.ok, true);
  assert.deepEqual(result.events.filter(e => e.type === 'pack').map(e => e.flavor), ['strawberry','blueberry','orange']);
  assert.equal(result.state.completed, 3);
  assert.equal(result.state.orders[1].flavor, 'chocolate');
  assert.equal(result.state.orders[0].flavor, 'mint');
  assert.equal(result.state.supply.length, 0);
  assert.equal(result.state.board[14].locked, true);
  assert.equal(initial.completed, 0, '操作不能修改历史状态，撤回才能可靠恢复');
});

test('容量不足自动拆分；不匹配需求的满盒不回收、不补货', () => {
  const state = createGame();
  state.board[0].donuts = ['mint','mint','mint'];
  state.board[1].donuts = ['mint','mint'];
  const result = moveDonuts(state, 1, 0);
  assert.equal(result.events[0].amount, 1);
  assert.deepEqual(result.state.board[1].donuts, ['mint']);
  assert.equal(result.state.board[0].donuts.length, 4);
  assert.equal(result.state.completed, 0);
  assert.equal(result.state.supply.length, 3);
});

test('搬空来源盒保留盒子；错误口味、满盒、锁定盒拒绝操作', () => {
  const state = createGame();
  state.board[0].donuts = [];
  const result = moveDonuts(state, 9, 0);
  assert.equal(result.state.board[9].absent, false);
  assert.equal(result.state.board[9].donuts.length, 0);
  assert.equal(result.state.supply.length, 3);
  for (const [a,b] of [[1,4], [1,2], [1,14]]) assert.equal(moveDonuts(state,a,b).ok, false);
});

test('演示关可以通关：全部需求、场上甜甜圈与备货均清空，空盒保留', () => {
  let state = createGame();
  const solution = [[1,0],[1,4],[6,5],[6,0],[9,0],[10,7],[11,8],[13,12],[3,2]];
  for (const [from,to] of solution) {
    const result = moveDonuts(state,from,to);
    assert.equal(result.ok, true, `搬运 ${from} → ${to}`);
    state = result.state;
  }
  assert.equal(state.status, 'won');
  assert.equal(state.completed, 10);
  assert.equal(state.board.filter(b => !b.absent && !b.locked).length > 0, true);
});
