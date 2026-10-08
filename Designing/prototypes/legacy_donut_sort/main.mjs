import { createGame, moveDonuts, validateMove, isWaiting, FLAVORS } from './engine.mjs';

const $ = selector => document.querySelector(selector);
const icon = (name, cls = '') => `<svg class="${cls}" aria-hidden="true" viewBox="0 0 32 32"><use href="#icon-${name}"/></svg>`;
const donut = flavor => `<svg class="donut" aria-hidden="true" viewBox="0 0 120 92"><use href="#donut-${flavor}"/></svg>`;
const icing = {
  strawberry:['#ffa3b7','#f17999','#d8557a'], chocolate:['#ad7545','#814626','#522b1d'],
  blueberry:['#b0a3ef','#9280d4','#6c5ba9'], orange:['#ffde7b','#efb642','#d58e24'], mint:['#c2dc88','#92ba58','#6c923c'],
};
const bread = 'M111 44C113 28 92 14 61 14C31 14 8 28 8 44C8 61 30 70 60 70C91 70 111 60 111 44ZM76 41C76 35 68 33 60 33C51 33 44 36 44 41C44 48 51 52 60 52C69 52 76 47 76 41Z';
const glaze = 'M110 39C110 22 88 9 60 9C33 9 10 21 10 39C10 44 13 44 14 49C15 55 21 50 25 55C30 61 35 53 41 58C47 64 51 59 57 62C64 65 68 60 74 61C80 62 81 54 88 56C96 56 94 49 101 48C107 47 111 45 110 39ZM77 38C77 29 68 26 60 26C51 26 43 31 43 38C43 46 50 49 60 49C70 49 77 45 77 38Z';
const sprinkles = [[28,27,-25],[39,17,20],[75,19,35],[91,29,-30],[101,39,60],[29,46,35],[43,53,-20],[77,51,20],[61,56,-25],[19,38,60],[88,44,-40],[52,16,-20]];
const symbols = Object.entries(icing).map(([name,colors]) => {
  const toppings = (name === 'mint' || name === 'orange')
    ? '<path d="M24 36L41 18M33 48L49 28M65 20L85 17M68 48L94 24M81 50L100 35" fill="none" stroke="#fff8d9" stroke-width="2.3" stroke-linecap="round" opacity=".9"/>'
    : sprinkles.map(([x,y,r],i) => `<rect x="${x}" y="${y}" width="3" height="6" rx="1.5" fill="${['#fff5d4','#ffcc65',name === 'chocolate' ? '#dd9a55' : '#bde3bb'][i%3]}" transform="rotate(${r} ${x} ${y})"/>`).join('');
  return `<linearGradient id="icing-${name}" x1="0" y1="0" x2=".2" y2="1"><stop stop-color="${colors[0]}"/><stop offset=".58" stop-color="${colors[1]}"/><stop offset="1" stop-color="${colors[2]}"/></linearGradient><symbol id="donut-${name}" viewBox="0 0 120 92"><path d="${bread}" fill="url(#bread)" fill-rule="evenodd"/><path d="${bread}" fill="none" stroke="#b47a34" stroke-width=".9"/><path d="${glaze}" transform="translate(0 3)" fill="${colors[2]}" fill-rule="evenodd"/><path d="${glaze}" fill="url(#icing-${name})" fill-rule="evenodd"/><path d="M18 32C24 20 42 14 57 14M73 15C85 17 92 21 97 26" fill="none" stroke="#fff8ed" stroke-width="3.5" opacity=".3" stroke-linecap="round"/>${toppings}<path d="M18 62C25 70 38 74 47 75M81 72L89 68" fill="none" stroke="#ffd98d" stroke-width="2" opacity=".6" stroke-linecap="round"/></symbol>`;
}).join('');

$('#svg-library').innerHTML = `<svg xmlns="http://www.w3.org/2000/svg"><defs>
<linearGradient id="bread" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#f7d18a"/><stop offset=".58" stop-color="#e9aa54"/><stop offset=".8" stop-color="#d58a32"/><stop offset="1" stop-color="#c47827"/></linearGradient>${symbols}
<symbol id="icon-settings" viewBox="0 0 32 32"><path fill="currentColor" d="m12 2 8 0 1 5 4 2 4-1 3 7-4 3-1 4 2 4-6 5-4-3h-5l-4 3-6-5 2-4-1-4-4-3 3-7 4 1 4-2z"/><circle cx="16" cy="16" r="6" fill="#fff6e9"/></symbol>
<symbol id="icon-lock" viewBox="0 0 32 32"><path d="M9 14V9a7 7 0 0 1 14 0v5" fill="none" stroke="currentColor" stroke-width="4"/><rect x="5" y="12" width="22" height="18" rx="5" fill="currentColor"/><path d="M16 20v4" stroke="#fff8ea" stroke-width="3" stroke-linecap="round"/></symbol>
<symbol id="icon-heart" viewBox="0 0 32 32"><path d="M16 28S2 20 2 10C2 1 13 0 16 8 20 0 30 2 30 10 30 20 16 28 16 28Z" fill="currentColor"/></symbol>
<symbol id="icon-clock" viewBox="0 0 32 32"><circle cx="16" cy="16" r="13" fill="none" stroke="currentColor" stroke-width="3"/><path d="M16 8v9l6 3" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round"/></symbol>
<symbol id="icon-check" viewBox="0 0 32 32"><path d="m6 16 7 7L27 8" fill="none" stroke="currentColor" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/></symbol>
<symbol id="icon-receipt" viewBox="0 0 32 32"><path d="M6 3h20v26l-5-3-5 3-5-3-5 3Z" fill="none" stroke="currentColor" stroke-width="2"/><path d="M11 10h10M11 16h10" stroke="currentColor" stroke-width="2"/></symbol>
<symbol id="icon-undo" viewBox="0 0 32 32"><path d="M13 4 3 13l10 8v-6h6c10 0 10 12-1 12h-4" fill="none" stroke="#fff8ed" stroke-width="5" stroke-linejoin="round" stroke-linecap="round"/></symbol>
<symbol id="icon-extra" viewBox="0 0 32 32"><path d="m5 10 4-7h13l5 7v17H5Z" fill="#f8fff3" stroke="#4c9b93" stroke-width="1.5"/><path d="M5 10h22" stroke="#4c9b93" stroke-width="2"/><circle cx="24" cy="23" r="9" fill="#faffed"/><path d="M24 18v10M19 23h10" stroke="#55af91" stroke-width="3" stroke-linecap="round"/></symbol>
<symbol id="icon-lift" viewBox="0 0 32 32"><ellipse cx="11" cy="19" rx="10" ry="9" fill="#f69aaa" stroke="#fff3dc" stroke-width="2"/><ellipse cx="11" cy="18" rx="3" ry="3" fill="#f6d685"/><path d="M23 28V9l-5 5-3-3L25 1l7 11-4 2-2-5v19Z" fill="#fff6dd" stroke="#cda456" stroke-width=".7"/></symbol>
<symbol id="icon-donut" viewBox="0 0 32 32"><circle cx="16" cy="16" r="12" fill="none" stroke="currentColor" stroke-width="8"/><path d="m9 7 1 3m12-1-2 2M7 18l3 1m10 5-1-3" stroke="#fff5e0" stroke-width="2" stroke-linecap="round"/></symbol>
</defs></svg>`;

let state = createGame(), selected = null, history = null, busy = false;
let toastTimer, comboTimer;
const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;
const theme = i => ['pink','cream','mint','pink'][i % 4];

function boxArt(box, index, current = state) {
  const waiting = isWaiting(current, box);
  return `<div class="box-art ${theme(index)}"><div class="box-back"></div><div class="donut-stack">${box.donuts.map((f,i) => donut(f).replace('class="donut"',`class="donut" style="--layer:${i}"`)).join('')}</div><div class="box-front">${waiting ? `<span class="box-waiting">${icon('clock')}等订单</span>` : `<span class="box-seal">${icon('heart')}</span>`}</div>${box.locked ? `<div class="lock-overlay">${icon('lock')}<span>周转盒</span></div>` : `<div class="fill-dots" aria-hidden="true">${Array.from({length:4},(_,i) => `<i class="${i < box.donuts.length ? 'filled' : ''}"></i>`).join('')}</div>`}</div>`;
}

function render() {
  $('#orders').innerHTML = state.orders.map((o,i) => o.locked
    ? `<button class="order locked" data-order="${i}" aria-label="第${i+1}个需求位置，未解锁，口味未知">${icon('lock','lock')}<span>待解锁</span></button>`
    : o.flavor ? `<div class="order" data-order="${i}" aria-label="${FLAVORS[o.flavor].name}订单，4颗">${donut(o.flavor)}<span class="order-name">${FLAVORS[o.flavor].name}<b>×4</b></span></div>`
    : `<div class="order done" data-order="${i}">${icon('check')}<span>已完成</span></div>`).join('');
  $('#board').innerHTML = state.board.map((box,i) => {
    const label = `第${Math.floor(i/4)+1}行第${i%4+1}列，` + (box.locked ? '周转盒，待解锁' : box.absent ? '已出餐的空盒位' : box.donuts.length ? `${box.donuts.length}颗甜甜圈，顶部${FLAVORS[box.donuts.at(-1)].name}${isWaiting(state,box) ? '，等待需求' : ''}` : '空盒');
    const canReceive = selected !== null && !validateMove(state, selected, i);
    return `<button class="box ${box.locked ? 'locked' : ''} ${box.absent ? 'absent' : ''} ${selected === i ? 'selected' : ''} ${canReceive ? 'can-receive' : ''}" data-box="${i}" aria-label="${label}" aria-pressed="${selected === i}" ${box.absent ? 'disabled' : ''}>${box.absent ? '' : boxArt(box,i)}</button>`;
  }).join('');
  $('#supply').innerHTML = state.supply.length ? state.supply.slice(0,2).map((stack,i) => `<div class="preview-box">${boxArt({donuts:stack, locked:false, absent:false}, i+2)}</div>`).join('') : `<span class="supply-empty">${icon('check')}本关备货已出完</span>`;
  $('#supply-count').textContent = `待出餐 ${state.supply.length} 盒`;
  $('#progress').innerHTML = `${state.completed} <i>/ ${state.totalOrders}</i>`;
  $('.progress').setAttribute('aria-label',`已出餐${state.completed}盒，共${state.totalOrders}盒`);
  $('#undo').disabled = !history || busy;
  $('#settings').disabled = busy;
  $('#guidance').textContent = busy ? '甜蜜出餐中…' : state.status === 'won' ? '所有订单已完成，今天也辛苦啦' : selected !== null ? `已选${FLAVORS[state.board[selected].donuts.at(-1)].name}，点选虚线框内的目标盒` : state.moves === 0 ? '先把第二盒的草莓，移到左边的草莓盒' : '点选一个盒子，再放入同口味或空的盒子';
  $('#board').setAttribute('aria-busy',String(busy));
}

function toast(message) {
  clearTimeout(toastTimer); $('#toast').textContent = message; $('#toast').classList.add('show');
  toastTimer = setTimeout(() => $('#toast').classList.remove('show'), 2700);
}

async function animate(element, frames, duration = 320, delay = 0) {
  if (!element) return;
  const animation = element.animate(frames, {duration:reducedMotion ? 1 : duration, delay:reducedMotion ? 0 : delay, easing:'cubic-bezier(.24,.7,.26,1)', fill:'both'});
  try {await animation.finished;} catch { /* 重开时动画可被取消。 */ }
  animation.cancel();
}

function floatingClone(element) {
  const rect = element.getBoundingClientRect(), clone = element.cloneNode(true);
  clone.classList.add('flying');
  Object.assign(clone.style, {left:`${rect.left}px`,top:`${rect.top}px`,width:`${rect.width}px`,height:`${rect.height}px`,margin:'0'});
  document.body.append(clone);
  return {clone,rect};
}

async function animateTransfer(event) {
  const source = $(`[data-box="${event.from}"] .donut-stack`);
  const target = $(`[data-box="${event.to}"]`).getBoundingClientRect();
  const top = source.lastElementChild, {clone,rect} = floatingClone(top);
  [...source.children].slice(-event.amount).forEach(el => el.style.opacity = '0');
  if (event.amount > 1) {
    // 一组作为一次搬运，以整组数量提示自动拆分结果。
    clone.setAttribute('aria-hidden','true');
  }
  await animate(clone,[{transform:'translate(0,0) scale(1)'},{transform:`translate(${target.x+target.width/2-rect.x-rect.width/2}px,${target.y+target.height*.25-rect.y}px) scale(1.08)`}],300);
  clone.remove();
}

async function animatePack(event) {
  const art = $(`[data-box="${event.index}"] .box-art`);
  const {clone,rect} = floatingClone(art);
  art.style.opacity = '0';
  clone.insertAdjacentHTML('beforeend','<span class="pack-label">甜蜜出餐</span>');
  const order = $(`[data-order="${event.slot}"]`).getBoundingClientRect();
  await animate(clone,[{transform:'translate(0,0) scale(1)',opacity:1},{offset:.2,transform:'translate(0,-8px) scale(1.05)',opacity:1},{transform:`translate(${order.x+order.width/2-rect.x-rect.width/2}px,${order.y-rect.y}px) scale(.3)`,opacity:0}],480);
  clone.remove();
}

async function animateEntry(index, delay = 0) {
  const art = $(`[data-box="${index}"] .box-art`);
  if (!art) return;
  const tray = $('.serving-tray').getBoundingClientRect(), rect = art.getBoundingClientRect();
  await animate(art,[{transform:`translate(${tray.x+tray.width/2-rect.x-rect.width/2}px,${tray.y-rect.y}px) scale(.35)`,opacity:0},{offset:.2,opacity:1},{transform:'translate(0,0) scale(1)',opacity:1}],430,delay);
}

async function applyMove(from,to) {
  const result = moveDonuts(state,from,to);
  if (!result.ok) {toast(result.error); await animate($(`[data-box="${to}"]`),[{transform:'translateX(0)'},{transform:'translateX(-4px)'},{transform:'translateX(4px)'},{transform:'translateX(0)'}],180); return;}
  history = structuredClone(state); selected = null; busy = true; render();
  let chain = 0;
  for (const event of result.events) {
    if (event.type === 'move') await animateTransfer(event);
    if (event.type === 'pack') await animatePack(event);
    state = event.state; render();
    if (event.type === 'refill') await animateEntry(event.index);
    if (event.type === 'pack' && ++chain > 1) {
      clearTimeout(comboTimer); $('#combo').textContent = `连续出餐 ×${chain}`; $('#combo').classList.add('show');
      comboTimer = setTimeout(() => $('#combo').classList.remove('show'),1200);
    }
  }
  state = result.state; busy = false; render();
  if (state.status === 'won') {
    $('.win-donuts').innerHTML = ['mint','strawberry','chocolate'].map(donut).join('');
    $('#win-summary').textContent = `${state.moves}次搬运，完成${state.completed}盒甜甜圈订单。`;
    $('#win-dialog').showModal();
  }
}

$('#board').addEventListener('click',async event => {
  const cell = event.target.closest('[data-box]');
  if (!cell || busy || state.status === 'won') return;
  const index = Number(cell.dataset.box), box = state.board[index];
  if (box.locked) {toast('周转盒需解锁后使用，解锁方式确定后开放'); return;}
  if (selected === index) {selected = null; render(); return;}
  if (selected !== null) {await applyMove(selected,index); return;}
  if (!box.donuts.length) {toast('先选一个有甜甜圈的来源盒'); return;}
  selected = index; render();
});
$('#orders').addEventListener('click', event => {
  if (event.target.closest('button.locked')) toast('解锁后才会揭示订单口味，解锁方式确定后开放');
});
$('#undo').addEventListener('click',() => {
  if (!history || busy) return;
  state = history; history = null; selected = null;
  clearTimeout(comboTimer); $('#combo').classList.remove('show'); render(); toast('已撤回上一次搬运及其出餐结果');
});
$('#extra').addEventListener('click',() => {
  if (busy) return;
  toast('底部两个周转盒为预留空间，解锁方式确定后开放');
  document.querySelectorAll('.box.locked').forEach(el => animate(el,[{transform:'scale(1)'},{transform:'scale(1.06)'},{transform:'scale(1)'}],350));
});
$('#lift').addEventListener('click',() => toast('置顶道具的使用规则尚未确定，当前保留入口'));
$('#settings').addEventListener('click',() => {if (!busy) $('#settings-dialog').showModal();});
document.querySelectorAll('[data-close]').forEach(button => button.addEventListener('click',() => button.closest('dialog').close()));
document.querySelectorAll('dialog').forEach(dialog => dialog.addEventListener('click',event => {if (event.target === dialog) {const r = dialog.getBoundingClientRect(); if (event.clientX < r.left || event.clientX > r.right || event.clientY < r.top || event.clientY > r.bottom) dialog.close();}}));
async function restart() {
  document.querySelectorAll('dialog[open]').forEach(dialog => dialog.close());
  clearTimeout(toastTimer); clearTimeout(comboTimer); $('#toast').classList.remove('show'); $('#combo').classList.remove('show');
  state = createGame(); selected = null; history = null; busy = true; render();
  await Promise.all(state.board.slice(0,14).map((_,i) => animateEntry(i,i*35)));
  busy = false; render();
}
$('#restart').addEventListener('click',restart);
$('#play-again').addEventListener('click',restart);
await restart();
