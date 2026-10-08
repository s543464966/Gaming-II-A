"""按 V1.3 装量分组生成实际局面、验证层序门槛，并在隔离目录保存四条件可行路线。"""
from pathlib import Path
from collections import deque, Counter
import argparse, copy, hashlib, json, math, random, time
from build_hundred_levels import Rules, make_box, read, write, finalize

KINDS = {'普通盒':'normal', '数字盖盒':'lid', '普通冰冻盒':'frozen',
         '数字冰冻盒':'number_frozen', '固定颜色盒':'fixed', '单向收纳盒':'in_only',
         '底部置顶盒':'cycle', '炸弹盒':'bomb', '单颗暂存盒':'normal'}


def candidate(plan, seed):
    if 'authored_opening' in plan:
        return authored_candidate(plan)
    rng = random.Random(seed)
    flavors = list(range(plan['flavors']))
    demands = flavors + [rng.choice(flavors) for _ in range(plan['orders']-len(flavors))]
    rng.shuffle(demands)
    pool = [f for f in demands for _ in range(4)]
    rng.shuffle(pool)
    entries, stock_entries = [], []
    for g in plan['groups']:
        if g['kind'] == '广告锁定周转盒':
            continue
        for i in range(g['count']):
            box = {'kind': KINDS[g['kind']], 'lid': g['number'], 'items': []}
            if box['kind'] == 'fixed':
                box['fixed_flavor'] = rng.choice(flavors)
            if box['kind'] == 'bomb':
                box['bomb_seconds'] = 300
            entry = {'kind': 'single' if g['capacity']==1 else 'regular', 'unlock_after':0,
                     'box':box, 'group_id':g['id'], 'fill':g['fill']}
            (entries if g['phase']=='开局' else stock_entries).append(entry)
    for adjustment in plan.get('approved_adjustments', []):
        if 'group' in adjustment:
            entry = next(e for e in entries if e['group_id'] == adjustment['group'])
            entry['kind'] = 'regular' if adjustment['capacity']==4 else 'single'
            entry['box']['kind'] = KINDS[adjustment['kind']]
            continue
        source = next(e for e in entries if e['group_id'] == adjustment['from_group'])
        target = next(e for e in entries if e['group_id'] == adjustment['to_group'])
        source['fill'] -= adjustment['amount']
        target['fill'] += adjustment['amount']
    filled = [e for e in entries if e['fill']]
    empty = [e for e in entries if not e['fill']]
    rng.shuffle(filled)
    rng.shuffle(empty)
    entries = filled + empty
    for e in entries + stock_entries:
        e['box']['items'] = [{'flavor':pool.pop()} for _ in range(e.pop('fill'))]
    assert not pool
    # 初始与备货均不靠自动满盒跳过玩家操作。
    if any(len(e['box']['items'])==4 and len({x['flavor'] for x in e['box']['items']})==1 for e in entries+stock_entries):
        return None
    hidden_count = round(plan['hidden_ratio']*plan['donuts'])
    hideable = [item for e in entries+stock_entries if e['box']['kind'] not in ('lid','in_only') for item in e['box']['items'][1:]]
    if hidden_count > len(hideable):
        return None
    for item in rng.sample(hideable, hidden_count):
        item['hidden'] = True
    for i,e in enumerate(entries):
        e['id'] = f'slot_{i:02}'
    entries += [{'kind':'turnover', 'id':x, 'unlock_after':-1, 'box':None} for x in ('A','B')]
    definition = {'id':plan['id'], 'title':f'甜甜圈小铺 · {plan["id"]}', 'layout_id':f'level_{plan["id"]:02}',
                  'slots':entries, 'stock':[e['box'] for e in stock_entries],
                  'demands':[{'initially_open':True,'sequence':demands[i::2]} for i in range(2)] +
                            [{'initially_open':False,'sequence':[]} for _ in range(2)],
                  'tools':{'undo':1,'add_box':1,'top':1}, 'combo_rewards':[],
                  'design':{'version':'R2' if 'midgame_space_min' in plan else '1.3','seed':seed,'source_row':plan['source_row'],
                            'assist_boxes':plan['assist'],'hidden_donuts':hidden_count,
                            'layer_order':'top_to_bottom', 'playtest_status':'pending',
                            'approved_adjustments':plan.get('approved_adjustments', [])}}
    if 'bomb_multiplier' in plan:
        definition['design']['bomb_multiplier'] = plan['bomb_multiplier']
    return definition


def authored_candidate(plan):
    """复用工作簿固定层序、逐颗隐藏及备货，校验装量与逐味订单守恒。"""
    spec = plan['authored_opening']
    remaining = Counter({g['id']:g['count'] for g in plan['groups'] if g['kind']!='广告锁定周转盒'})
    groups = {g['id']:g for g in plan['groups']}
    def box_for(source, phase):
        group = groups[source['group_id']]
        assert group['phase']==phase and group['kind'] in ('普通盒','数字冰冻盒','数字盖盒','普通冰冻盒','单颗暂存盒'), group
        assert group['capacity']==(1 if group['kind']=='单颗暂存盒' else 4), group
        assert phase=='开局' or group['kind']=='普通盒', group
        assert len(source['layers'])==group['fill'] and remaining[group['id']]>0, source
        remaining[group['id']] -= 1
        hidden = source.get('hidden', [])
        assert len(hidden)==len(set(hidden)) and all(0<i<len(source['layers']) for i in hidden), source
        return {'kind':KINDS[group['kind']], 'lid':group['number'],
                'items':[dict(flavor=f, **({'hidden':True} if i in hidden else {})) for i,f in enumerate(source['layers'])]}
    slots = []
    for index, source in enumerate(spec['slots']):
        slots.append({'kind':'single' if groups[source['group_id']]['capacity']==1 else 'regular','unlock_after':0,'id':f'slot_{index:02}',
                      'group_id':source['group_id'],'box':box_for(source,'开局')})
    stock = [box_for(source,'备货') for source in spec.get('stock', [])]
    assert not any(remaining.values()) and len(stock)==plan['stock'], plan['id']
    items = [item for box in [s['box'] for s in slots]+stock for item in box['items']]
    supply = Counter(item['flavor'] for item in items)
    hidden_count = sum(bool(item.get('hidden',False)) for item in items)
    assert hidden_count==round(plan['hidden_ratio']*plan['donuts']), plan['id']
    sequences = spec['demand_sequences']
    demand = Counter(f for seq in sequences for f in seq)
    assert len(sequences)==2 and all(sequences) and len(supply)==plan['flavors'], plan['id']
    assert supply==Counter({f:count*4 for f,count in demand.items()}), plan['id']
    assert sum(supply.values())==plan['donuts'] and all(0<=f<15 for f in supply), plan['id']
    slots += [{'kind':'turnover','id':name,'unlock_after':-1,'box':None} for name in ('A','B')]
    assert len(slots)==plan['slots'], plan['id']
    return {'id':plan['id'],'title':f'甜甜圈小铺 · {plan["id"]}','layout_id':f'level_{plan["id"]:02}',
            'slots':slots,'stock':stock,
            'demands':[{'initially_open':True,'sequence':seq} for seq in sequences]+
                      [{'initially_open':False,'sequence':[]} for _ in range(2)],
            'tools':{'undo':1,'add_box':1,'top':1},'combo_rewards':[],
            'design':{'version':'R2','source_row':plan['source_row'],'assist_boxes':plan['assist'],
                      'hidden_donuts':hidden_count,'layer_order':'top_to_bottom','playtest_status':'pending',
                      'approved_adjustments':[],'bomb_multiplier':None,'authored_opening':True,
                      'reference':spec['reference']}}


def opening_metrics(definition):
    boxes = [s['box'] for s in definition['slots'] if s['box'] is not None]
    filled = [s['box'] for s in definition['slots'] if s['kind']!='single' and s['box'] and s['box']['items']]
    aabb = 0
    same = pairs = 0
    for b in boxes:
        values = [x['flavor'] for x in b['items']]
        pairs += max(len(values)-1,0)
        same += sum(a==b for a,b in zip(values, values[1:]))
        aabb += int(len(values)==4 and values[0]==values[1] and values[2]==values[3] and values[0]!=values[2])
    stock_same = sum(a['flavor']==b['flavor'] for box in definition['stock'] for a,b in zip(box['items'],box['items'][1:]))
    stock_pairs = sum(max(0,len(box['items'])-1) for box in definition['stock'])
    return {'aabb_count':aabb, 'aabb_ratio':aabb/len(filled), 'adjacent_pairs':same,
            'total_pairs':pairs, 'adjacent_ratio':same/pairs if pairs else None,
            'all_adjacent_ratio':(same+stock_same)/(pairs+stock_pairs) if pairs+stock_pairs else None}


def first_group_gate(definition, minimum, one_step_max, limit=120000):
    # 隐藏全部视作已知仍须达标，避免利用未知标记虚增首归纳难度。
    visible = copy.deepcopy(definition)
    for s in visible['slots']:
        if s['box']:
            s['box']['hidden_layers']=False
            for item in s['box']['items']:item.pop('hidden',None)
    rules = Rules(visible)
    queue = deque([(rules.initial,0)])
    seen = {rules.initial}
    targets = set()
    while queue:
        state, depth = queue.popleft()
        for move,nxt in rules.moves(state):
            grouped = nxt[1]+nxt[2] > 0 or any(b and b[3] for b in nxt[0])
            if grouped:
                if depth==0:targets.add(move[1])
                if depth+1<minimum or len(targets)>one_step_max:
                    return None
            elif depth+1<max(minimum-1,1) and nxt not in seen:
                seen.add(nxt)
                if len(seen)>limit:return None
                queue.append((nxt,depth+1))
    return {'first_group_lower_bound':minimum, 'lower_bound_states':len(seen),
            'lower_bound_hidden_relaxed':True, 'one_step_targets':len(targets)}


def generate(plan, output, start_trial=0, attempts=30000, replace_existing=False):
    destination=output/'levels'/f'level_{plan["id"]:02}.json'
    if destination.exists() and not replace_existing:
        print(f'KEEP {plan["id"]}',flush=True);return
    began=time.monotonic(); rejected=Counter()
    for trial in range(start_trial,start_trial+attempts):
        if trial % 200 == 0: print(f'CHECK {plan["id"]} trial {trial} {dict(rejected)} {time.monotonic()-began:.1f}s',flush=True)
        seed=130000000+plan['id']*100000+trial
        d=candidate(plan,seed)
        if d is None:rejected['candidate']+=1;continue
        metrics=opening_metrics(d)
        if metrics['aabb_ratio']>plan['aabb_max']+1e-9 or max(metrics['adjacent_ratio'], metrics['all_adjacent_ratio'])>plan['adjacent_max']+1e-9:
            rejected['layers']+=1;continue
        gate=first_group_gate(d,plan['first_group_min'],plan['one_step_max'])
        if gate is None:rejected['first']+=1;continue
        solution,visits=Rules(d).solve(3500)
        if not solution:
            rejected['solve']+=1
            if rejected['solve']%2000==0:print(f'PROGRESS {plan["id"]} trial {trial} {dict(rejected)} {time.monotonic()-began:.1f}s',flush=True)
            continue
        fixture=finalize(d,solution,visits)
        metrics.update(gate)
        fixture['opening_metrics']=metrics
        fixture['requirements']='V1.3'
        fixture['definition_sha256']=hashlib.sha256(json.dumps(d,ensure_ascii=False,sort_keys=True,separators=(',',':')).encode()).hexdigest()
        write(destination,d)
        write(output/'fixtures'/f'level_{plan["id"]:02}_solution.json',fixture)
        print(f'BUILT {plan["id"]}: trial {trial}, {len(solution)} moves, first >= {gate["first_group_lower_bound"]}, {time.monotonic()-began:.1f}s',flush=True)
        return
    raise RuntimeError(f'Unfinished level {plan["id"]}: {dict(rejected)}')


def install(output):
    """完整候选齐备后一次发布到唯一内容目录；逐关坐标保留连续摆放，不挖中央空洞。"""
    root = Path(__file__).resolve().parents[2]
    content = root/'Coding/godot/game_content/donuts'
    plans = read(output/'level_plan.json')
    catalog = []
    layout = read(content/'layouts/board_layouts.json')
    layout['levels'] = [f'level_{i:02}' for i in range(1,101)]
    definitions = []
    for p in plans['levels']:
        filename = f'level_{p["id"]:02}'
        d = read(output/'levels'/f'{filename}.json')
        fixture = read(output/'fixtures'/f'{filename}_solution.json')
        digest = hashlib.sha256(json.dumps(d,ensure_ascii=False,sort_keys=True,separators=(',',':')).encode()).hexdigest()
        assert digest == fixture['definition_sha256'], filename
        definitions.append((p,d,fixture,filename))
    for p,d,fixture,filename in definitions:
        count = len(d['slots'])
        # 每排最多五盒，余数均摊；16–20 盒形成四排，少盒关不强凑四排。
        rows = math.ceil(count/5)
        sizes = [count//rows+(row<count%rows) for row in range(rows)]
        # 五排关避免末排只有空托或低堆叠而拉大可见间隙；调换行宽，不改盒序及数量。
        if rows >= 5 and sizes[-1] < max(sizes) and not any(s.get('box') and len(s['box']['items']) >= 3 for s in d['slots'][-sizes[-1]:]):
            donor = max(i for i,n in enumerate(sizes[:-1]) if n == max(sizes))
            sizes[donor],sizes[-1] = sizes[-1],sizes[donor]
        kind = {'整齐':'grid','错落':'staggered','自由':'free'}[p['layout']]
        positions = []
        for row,number in enumerate(sizes):
            for col in range(number):
                idx = len(positions)
                offset = (18 if row%2 else -18) if kind!='grid' else 0
                yoffset = (4 if (row+col)%2 else -4) if kind=='free' else 0
                positions.append({'id':d['slots'][idx]['id'],'order':idx,'layer':row,
                                  'x':550+(col-(number-1)/2)*220+offset,'y':180+row*330+yoffset})
        layout['templates'][filename] = {'type':kind,'composition':'每排优先四至五盒，连续居中，盒数足够时四排','source_composition':p['composition'],'slots':positions}
        write(content/'levels'/f'{filename}.json',d)
        write(root/'Testing/fixtures/donut_sort'/f'{filename}_solution.json',fixture)
        catalog.append({'path':f'res://game_content/donuts/levels/{filename}.json','title':d['title']})
    write(content/'level_plan.json',plans)
    write(content/'levels/catalog.json',{'levels':catalog})
    write(content/'layouts/board_layouts.json',layout)
    print(f"INSTALLED: 100 {plans['requirements']} definitions, corresponding fixtures and stable layouts")


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('output',type=Path)
    parser.add_argument('--start',type=int,default=1)
    parser.add_argument('--end',type=int,default=100)
    parser.add_argument('--trial',type=int,default=0)
    parser.add_argument('--install',action='store_true')
    args=parser.parse_args()
    if args.install:
        install(args.output)
    else:
        for p in read(args.output/'level_plan.json')['levels'][args.start-1:args.end]:
            generate(p,args.output,args.trial)
