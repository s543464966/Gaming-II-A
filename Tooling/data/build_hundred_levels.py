"""从已提取策划参数制作关卡候选及解回放；运行工程不依赖此工具。"""
from pathlib import Path
import json, random, heapq, itertools, sys, hashlib, re, math

ROOT = Path(__file__).resolve().parents[2]
CONTENT = ROOT / 'Coding/godot/game_content/donuts'
FIXTURES = ROOT / 'Testing/fixtures/donut_sort'
KINDS = {'数字盖盒':'lid','普通冰冻盒':'frozen','数字冰冻盒':'number_frozen',
         '固定颜色盒':'fixed','空订单盒':'in_only','底部置顶盒':'cycle','炸弹盒':'bomb'}
CHAPTER_TITLES = ('午后茶会','礼盒惊喜','冰糖时光','一口香甜','冰雪礼盒',
                  '缤纷拼盘','甜蜜归位','转转甜圈','限时派对')
BOMB_TARGET_SECONDS = {91:120, 92:75, 93:50, 94:165, 95:140,
                       96:125, 97:135, 98:170, 99:120, 100:95}

def player_title(level):
    """玩家关卡名不直接暴露策划表中的教学／回落等角色标签。"""
    return f'{CHAPTER_TITLES[(level-11)//10]} · {(level-1)%10+1}'

def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))

def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')

def make_box(definition):
    items = tuple(2*int(x['flavor']) + (not x.get('hidden', definition.get('hidden_layers',False)) or i==0)
                  for i,x in enumerate(definition['items']))
    return (items, definition.get('kind','normal'), definition.get('lid',0),
            len(items)==4 and len({x//2 for x in items})==1, definition.get('fixed_flavor',-1))

def handle(box):
    return box is not None and box[2]==0 and box[1] not in ('frozen','number_frozen')

def full(box):
    return handle(box) and len(box[0])==4 and len({x//2 for x in box[0]})==1

def replace(box, **kw):
    b=list(box)
    for key,value in kw.items(): b[{'items':0,'kind':1,'lid':2,'grouped':3,'fixed':4}[key]]=value
    return tuple(b)

class Rules:
    def __init__(self, definition):
        self.definition=definition
        self.caps=tuple(1 if s['kind']=='single' else 4 for s in definition['slots'])
        self.demands=tuple(tuple(s['sequence']) for s in definition['demands'][:2])
        self.stock=tuple(make_box(b) for b in definition['stock'])
        self.initial=(tuple(make_box(s['box']) if s['box'] is not None else None for s in definition['slots']),0,0,0)

    def settle(self, boxes, c0,c1,cursor):
        cursors=[c0,c1]
        while True:
            refill=[]
            while True:
                found=False
                for i,b in enumerate(boxes):
                    if self.caps[i]==1 or not full(b):continue
                    f=b[0][0]//2
                    for d in range(2):
                        if cursors[d]<len(self.demands[d]) and self.demands[d][cursors[d]]==f:
                            boxes[i]=None; cursors[d]+=1; refill.append(i); found=True
                            for j,other in enumerate(boxes):
                                if other is not None and other[1]=='frozen':
                                    boxes[j]=replace(other,kind='normal'); break
                            break
                    if found:break
                if not found:break
            if not refill or cursor==len(self.stock):break
            for i in refill:
                if cursor==len(self.stock):break
                boxes[i]=self.stock[cursor]; cursor+=1
        return (tuple(boxes),*cursors,cursor)

    def moves(self,state, prune=True):
        boxes=state[0]
        for i,b in enumerate(boxes):
            if not handle(b) or not b[0] or b[1]=='in_only':continue
            items=b[0]; f=items[0]//2
            count=0
            for x in items:
                if x//2!=f or x%2==0:break
                count+=1
            seen_empty=set()
            for j,d in enumerate(boxes):
                if i==j or not handle(d) or len(d[0])>=self.caps[j] or d[4]>=0 and d[4]!=f:continue
                if d[0] and (d[0][0]//2!=f or not d[0][0]%2):continue
                if not d[0]:
                    signature=(d[1:],self.caps[j])
                    if prune and signature in seen_empty:continue
                    seen_empty.add(signature)
                    # 整摞同味换空盒通常无益；特殊源与限制目标仍保留。
                    if prune and count==len(items) and b[1]=='normal' and d[1]=='normal' and self.caps[i]==self.caps[j]:continue
                n=min(count,self.caps[j]-len(d[0]))
                if n<=0:continue
                result=list(boxes)
                rest=items[n:]
                if b[1]=='cycle' and len(rest)>1:rest=rest[-1:]+rest[:-1]
                if rest:rest=(rest[0]|1,)+rest[1:]
                result[i]=replace(b,items=rest)
                target=replace(d,items=items[:n]+d[0])
                if self.caps[j]==4 and not d[3] and full(target):
                    target=replace(target,grouped=True,kind='normal' if target[1]=='bomb' else target[1])
                    result[j]=target
                    for k,other in enumerate(result):
                        if other is not None and other[2]>0:
                            lid=other[2]-1
                            result[k]=replace(other,lid=lid,kind='normal' if lid==0 and other[1]=='number_frozen' else other[1]);break
                else:result[j]=target
                yield (i,j), self.settle(result,*state[1:])

    def won(self,state):
        return state[1]+state[2]==sum(map(len,self.demands)) and state[3]==len(self.stock) and all(b is None or not b[0] and b[1]!='bomb' for b in state[0])

    def score(self,state):
        value=5*(len(self.stock)-state[3])
        for b in state[0]:
            if b is None:continue
            items=b[0]
            value+=sum(i==0 or x//2!=items[i-1]//2 for i,x in enumerate(items))
            value+=len(items)*.13+b[2]*.3
            if b[1] in ('frozen','number_frozen'):value+=.5
            if b[1]=='bomb':value+=4
        return value

    def solve(self,limit=10000):
        start=self.settle(list(self.initial[0]),*self.initial[1:])
        queue=[]; serial=itertools.count(); records=[(start,-1,None,0)]
        heapq.heappush(queue,(self.score(start),next(serial),0))
        seen={start:0}; visits=0
        while queue and visits<limit:
            _,_,rid=heapq.heappop(queue)
            state,_,_,depth=records[rid]
            if self.won(state):
                path=[]
                while records[rid][1]>=0:
                    path.append(records[rid][2]);rid=records[rid][1]
                return list(reversed(path)), visits
            if depth>=180:continue
            visits+=1
            for move,nxt in self.moves(state):
                if seen.get(nxt,999)<=depth+1:continue
                seen[nxt]=depth+1
                nid=len(records);records.append((nxt,rid,move,depth+1))
                heapq.heappush(queue,(self.score(nxt)+.14*(depth+1),next(serial),nid))
        return None, visits

def candidate(plan,seed):
    rng=random.Random(seed); level=plan['id']; n=plan['filled']; k=plan['orders']; stock_count=plan['stock']
    flavor_ids=list(range(plan['flavors']))
    order_flavors=flavor_ids+[rng.choice(flavor_ids) for _ in range(k-len(flavor_ids))]
    rng.shuffle(order_flavors)
    pool=[f for f in order_flavors for _ in range(4)];rng.shuffle(pool)
    mechanisms=[]
    main=KINDS.get(plan['main'])
    amount=2 if str(plan['parameters']).startswith('2只') else 1
    if main:mechanisms.extend([main]*amount)
    secondary=KINDS.get(plan['secondary'])
    if secondary:mechanisms.append(secondary)
    chosen=rng.sample(range(n),len(mechanisms))
    specs=dict(zip(chosen,mechanisms))
    sizes=[1]*n
    for i,kind in specs.items():
        if kind in ('lid','number_frozen'):sizes[i]=4
    left=4*(k-stock_count)-sum(sizes)
    if left<0:return None
    for _ in range(left):
        possible=[i for i in range(n) if sizes[i]<4 and not(specs.get(i)=='in_only' and sizes[i]>=2)]
        if not possible:return None
        sizes[rng.choice(possible)]+=1
    arrays=[[] for _ in range(n)]
    # 只进不出盒初始同味且未满，确保没有不可移出的混味死盒。
    for i,kind in specs.items():
        if kind=='in_only':
            options=[f for f in flavor_ids if pool.count(f)>=sizes[i]]
            f=rng.choice(options)
            for _ in range(sizes[i]):pool.remove(f);arrays[i].append(f)
    rng.shuffle(pool)
    for i in range(n):
        if arrays[i]:continue
        arrays[i]=[pool.pop() for _ in range(sizes[i])]
    stocks=[]
    for _ in range(stock_count):stocks.append([pool.pop() for _ in range(4)])
    if any(len(a)==4 and len(set(a))==1 for a in arrays):return None
    boxes=[{'kind':specs.get(i,'normal'),'lid':0,'items':[{'flavor':f} for f in a]} for i,a in enumerate(arrays)]
    numbered=0
    for i,b in enumerate(boxes):
        if b['kind'] in ('lid','number_frozen'):
            numbered+=1;b['lid']=min(numbered,2)
        if b['kind']=='fixed':b['fixed_flavor']=arrays[i][-1]
        if b['kind']=='bomb':b['bomb_seconds']=300 # 首轮可玩时限，最终须按熟练试玩定标。
    stock=[{'kind':'normal','lid':0,'items':[{'flavor':f} for f in a]} for a in stocks]
    hidden_target=round(plan['hidden_ratio']*4*k)
    choices=[b for b in boxes+stock if len(b['items'])>1 and b['kind'] not in ('lid','frozen','number_frozen','in_only')]
    rng.shuffle(choices);reachable={0:[]}
    for b in choices:
        for count,selected in list(reachable.items()):
            new=count+len(b['items'])-1
            if new<=hidden_target and new not in reachable:reachable[new]=selected+[b]
    if hidden_target not in reachable:return None
    for b in reachable[hidden_target]:b['hidden_layers']=True
    slots=[{'kind':'regular','unlock_after':0,'box':b} for b in boxes]
    slots += [{'kind':'regular','unlock_after':0,'box':{'kind':'normal','lid':0,'items':[]}} for _ in range(plan['empty'])]
    slots += [{'kind':'single','unlock_after':0,'box':{'kind':'normal','lid':0,'items':[]}} for _ in range(plan['single'])]
    slots += [{'kind':'turnover','id':name,'unlock_after':-1,'box':None} for name in ('A','B')]
    demands=[{'initially_open':True,'sequence':order_flavors[i::2]} for i in range(2)]
    demands += [{'initially_open':False,'sequence':[]} for _ in range(2)]
    return {'id':level,'title':player_title(level),'layout_id':f'level_{level:02}', 'slots':slots,'demands':demands,'stock':stock,
            'tools':{'undo':0,'add_box':0,'top':0},'combo_rewards':[],
            'design':{'seed':seed,'source_row':level+5,'assist_boxes':plan['assist'],'hidden_donuts':hidden_target,
                      'bomb_timing':'provisional_playtest_required' if main=='bomb' else 'none'}}

def finalize(definition, solution, visits):
    fixture={'moves':len(solution),'steps':solution,'optimal':False,'search_nodes':visits,'assist':{}}
    for mode in range(1,4):
        rules=Rules(definition); boxes=list(rules.initial[0])
        for offset in range(2):
            if mode & (1<<offset):boxes[len(boxes)-2+offset]=make_box({'items':[]})
        rules.initial=(tuple(boxes),*rules.initial[1:])
        path,_=rules.solve(1000)
        fixture['assist'][str(mode)]=path if path and len(path)<len(solution) else solution
    if any(s.get('box') and s['box']['kind']=='bomb' for s in definition['slots']):
        assign_bomb_timing(definition, fixture)
    return fixture

def assign_bomb_timing(definition, fixture, min_seconds=0):
    """按四种条件下首次归纳解除炸弹的步数预留操作时间；修订规则时可保留已有时限。"""
    disarm_steps={}
    for mode in range(4):
        rules=Rules(definition); boxes=list(rules.initial[0])
        for offset in range(2):
            if mode & (1<<offset):boxes[len(boxes)-2+offset]=make_box({'items':[]})
        state=(tuple(boxes),*rules.initial[1:])
        steps=fixture['steps'] if mode==0 else fixture['assist'][str(mode)]
        for index, step in enumerate(steps,1):
            state=next(result for move,result in rules.moves(state) if list(move)==list(step))
            if not any(box and box[1]=='bomb' for box in state[0]):
                disarm_steps[str(mode)]=index
                break
        if str(mode) not in disarm_steps:raise ValueError('Solution leaves an armed bomb')
    worst=max(disarm_steps.values())
    multiplier = definition['design'].get('bomb_multiplier')
    seconds=max(min_seconds, math.ceil((worst*3+8)*multiplier/5)*5) if multiplier else max(min_seconds,BOMB_TARGET_SECONDS.get(definition['id'], 90),math.ceil((worst*3+8)/5)*5)
    fixture.pop('bomb_dispatch_moves',None)
    fixture['bomb_disarm_moves']=disarm_steps
    definition['design']['bomb_timing']={'status':'provisional_playtest_required',
        'profile':'short' if seconds<100 else 'long', 'estimated_seconds_per_move':3,
        'max_disarm_moves':worst,'seconds':seconds,'multiplier':multiplier,
        'basis':'estimated_disarm_operation_budget_not_measured_player_time'}
    for slot in definition['slots']:
        if slot['box'] and slot['box']['kind']=='bomb':slot['box']['bomb_seconds']=seconds

def layouts(plans):
    path=CONTENT/'layouts/board_layouts.json'; data=read(path)
    data['levels']=[f'level_{i:02}' for i in range(1,101)]
    for p in plans[10:]:
        count=p['filled']+p['empty']+p['single']+2
        cols=4 if count<=16 else (5 if count<=20 else 6)
        rows=(count+cols-1)//cols
        # 各行连续居中，余数均匀分配，不挖中间洞。
        sizes=[count//rows+(r<count%rows) for r in range(rows)]
        slots=[]
        for row,num in enumerate(sizes):
            for col in range(num):
                idx=len(slots)
                slots.append({'id':f'slot_{idx:02}','order':idx,'layer':row,'x':550+(col-(num-1)/2)*220,'y':180+row*310})
        data['templates'][f"level_{p['id']:02}"]={'type':'grid','composition':'连续居中','slots':slots}
    write(path,data)

def main():
    plans=read(CONTENT/'level_plan.json')['levels']
    start=int(sys.argv[1]) if len(sys.argv)>1 else 11
    end=int(sys.argv[2]) if len(sys.argv)>2 else 100
    for p in plans[start-1:end]:
        level=p['id']; destination=CONTENT/f'levels/level_{level:02}.json'
        if destination.exists() and level>10:
            print(f'KEEP {level}',flush=True);continue
        for trial in range(300):
            definition=candidate(p,level*10000+trial)
            if definition is None:continue
            rules=Rules(definition); solution,visits=rules.solve(6000 if trial<20 else 18000)
            if not solution:continue
            # 数字机关、隐藏与需求均参加搜索；正式验收仍由Godot会话独立重放。
            fixture=finalize(definition,solution,visits)
            write(destination,definition)
            write(FIXTURES/f'level_{level:02}_solution.json',fixture)
            print(f'BUILT {level}: seed {definition["design"]["seed"]}, {len(solution)} moves, {visits} nodes',flush=True)
            break
        else:raise RuntimeError(f'No valid candidate for level {level}')
    if end==100 and all((CONTENT/f'levels/level_{i:02}.json').exists() for i in range(1,101)):
        write(CONTENT/'levels/catalog.json',{'levels':[{'path':f'res://game_content/donuts/levels/level_{i:02}.json','title':read(CONTENT/f'levels/level_{i:02}.json')['title']} for i in range(1,101)]})
        layouts(plans)

if __name__=='__main__':main()
