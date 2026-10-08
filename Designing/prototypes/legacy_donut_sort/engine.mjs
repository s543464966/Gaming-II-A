// 数组从底部到顶部排列。演示关配置用于界面验收，不代表正式关卡难度。
export const FLAVORS = {
  strawberry: { name: '草莓', color: '#f27d98' },
  chocolate: { name: '巧克力', color: '#925130' },
  blueberry: { name: '蓝莓', color: '#8492d9' },
  orange: { name: '香橙', color: '#f4b954' },
  mint: { name: '抹茶', color: '#9abd79' },
};
const copy = value => structuredClone(value);

export function createGame() {
  const s = 'strawberry', c = 'chocolate', b = 'blueberry', o = 'orange', m = 'mint';
  const stacks = [[s,s,s], [c,s], [b,b,b,b], [o,o,o,o],
    [c,c,c], [m,m,m], [s,m], [b,b], [o,o], [s,s], [b,b], [o,o], [c,c], [c,c]];
  return {
    board: Array.from({length:16}, (_, i) => ({ id:i, donuts:stacks[i] ?? [], locked:i >= 14, absent:false, buffer:i >= 14 })),
    orders: [
      { flavor:s, queue:[b,o,m,s,b], locked:false },
      { flavor:c, queue:[o,c,s], locked:false },
      { flavor:null, queue:[], locked:true }, { flavor:null, queue:[], locked:true },
    ],
    supply:[[s], [s,s], [s,s]], completed:0, totalOrders:10, moves:0, status:'playing',
  };
}

export function isWaiting(state, box) {
  return !box.absent && !box.locked && box.donuts.length === 4 &&
    box.donuts.every(f => f === box.donuts[0]) &&
    !state.orders.some(o => !o.locked && o.flavor === box.donuts[0]);
}

export function validateMove(state, from, to) {
  const source = state.board[from], target = state.board[to];
  if (state.status !== 'playing') return '本关已完成';
  if (!source || !target || from === to) return '请选择另一个盒子';
  if (source.locked || target.locked) return '这个周转盒还未解锁';
  if (source.absent || target.absent) return '这里的盒子已经出餐';
  if (!source.donuts.length) return '这个盒子是空的';
  if (target.donuts.length === 4) return '这个盒子已经装满了';
  if (target.donuts.length && target.donuts.at(-1) !== source.donuts.at(-1)) return '需要放到顶部同口味或空的盒子里';
  return null;
}

export function moveDonuts(original, from, to) {
  const error = validateMove(original, from, to);
  if (error) return { ok:false, error };
  const state = copy(original), events = [];
  const source = state.board[from], target = state.board[to], flavor = source.donuts.at(-1);
  let run = 0;
  for (let i = source.donuts.length - 1; i >= 0 && source.donuts[i] === flavor; i--) run++;
  const amount = Math.min(run, 4 - target.donuts.length);
  target.donuts.push(...source.donuts.splice(source.donuts.length - amount));
  state.moves++;
  events.push({ type:'move', from, to, flavor, amount, state:copy(state) });

  // 回收、需求更新、补位逐次结算，确保新盒子不接受过去的回收事件。
  while (true) {
    let match = null;
    for (let slot = 0; slot < state.orders.length && !match; slot++) {
      const order = state.orders[slot];
      if (order.locked || !order.flavor) continue;
      const index = state.board.findIndex(box => !box.locked && !box.absent &&
        box.donuts.length === 4 && box.donuts.every(f => f === order.flavor));
      if (index !== -1) match = { index, slot, flavor:order.flavor };
    }
    if (!match) break;
    const { index, slot, flavor:packedFlavor } = match;
    state.board[index].donuts = [];
    state.board[index].absent = true;
    state.orders[slot].flavor = state.orders[slot].queue.shift() ?? null;
    state.completed++;
    events.push({ type:'pack', index, slot, flavor:packedFlavor, state:copy(state) });
    if (state.supply.length) {
      state.board[index].donuts = state.supply.shift();
      state.board[index].absent = false;
      events.push({ type:'refill', index, state:copy(state) });
    }
  }
  if (state.completed === state.totalOrders && !state.supply.length && state.board.every(box => !box.donuts.length)) state.status = 'won';
  return { ok:true, state, events };
}
