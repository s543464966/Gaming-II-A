"""用最短首归纳反例调整逐颗口味；保留装量和口味总数，验收仍用完整规则回放。"""
from pathlib import Path
from collections import deque
import argparse, copy, hashlib, json, random, time
from rebalance_hundred_levels import candidate, opening_metrics, first_group_gate
from build_hundred_levels import Rules, read, write, finalize


def short_route(definition, minimum):
    visible = copy.deepcopy(definition)
    for slot in visible['slots']:
        if slot['box']:
            for item in slot['box']['items']:item.pop('hidden',None)
    rules = Rules(visible)
    queue = deque([(rules.initial,[])])
    seen = {rules.initial}
    while queue:
        state,path = queue.popleft()
        for move,nxt in rules.moves(state):
            if nxt[1]+nxt[2]>0 or any(b and b[3] for b in nxt[0]):
                return len(path)+1,path+[move]
            if len(path)+1 < minimum-1 and nxt not in seen:
                seen.add(nxt)
                if len(seen)>120000:return 0,[]
                queue.append((nxt,path+[move]))
    return minimum,[]


def tune(plan, output):
    rng = random.Random(130000+plan['id'])
    started = time.monotonic()
    for restart in range(1000):
        seed = 131000000+plan['id']*100000+restart
        d = candidate(plan,seed)
        if not d:continue
        score,path = short_route(d,plan['first_group_min'])
        for iteration in range(120):
            m = opening_metrics(d)
            if score>=plan['first_group_min'] and m['aabb_ratio']<=plan['aabb_max'] and m['adjacent_ratio']<=plan['adjacent_max']:
                solution,visits = Rules(d).solve(20000)
                if solution:
                    gate = first_group_gate(d,plan['first_group_min'],plan['one_step_max'])
                    if gate:
                        fixture = finalize(d,solution,visits)
                        m.update(gate);fixture['opening_metrics']=m;fixture['requirements']='V1.3'
                        d['design']['tuning_iterations']=[restart,iteration]
                        fixture['definition_sha256']=hashlib.sha256(json.dumps(d,ensure_ascii=False,sort_keys=True,separators=(',',':')).encode()).hexdigest()
                        name=f'level_{plan["id"]:02}'
                        write(output/'levels'/f'{name}.json',d);write(output/'fixtures'/f'{name}_solution.json',fixture)
                        print('TUNED',name,score,len(solution),restart,iteration,flush=True);return
            positions = [(i,j) for i,s in enumerate(d['slots']) if s['box'] for j in range(len(s['box']['items']))]
            sources = [(i,j) for i,j in positions if not path or i in {x for move in path for x in move}]
            a,b = rng.choice(sources),rng.choice(positions)
            x=d['slots'][a[0]]['box']['items'][a[1]];y=d['slots'][b[0]]['box']['items'][b[1]]
            if x['flavor']==y['flavor']:continue
            x['flavor'],y['flavor']=y['flavor'],x['flavor']
            metrics=opening_metrics(d)
            if metrics['aabb_ratio']>plan['aabb_max'] or metrics['adjacent_ratio']>plan['adjacent_max'] or any(s['box'] and len(s['box']['items'])==4 and len({i['flavor'] for i in s['box']['items']})==1 for s in d['slots']):
                x['flavor'],y['flavor']=y['flavor'],x['flavor'];continue
            new_score,new_path=short_route(d,plan['first_group_min'])
            if new_score>=score or rng.random()<.035:
                score,path=new_score,new_path
            else:x['flavor'],y['flavor']=y['flavor'],x['flavor']
        print('TUNE',plan['id'],restart,score,f'{time.monotonic()-started:.1f}s',flush=True)
    raise RuntimeError('No verified layers found')


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('output',type=Path);parser.add_argument('level',type=int)
    args=parser.parse_args();tune(read(args.output/'level_plan.json')['levels'][args.level-1],args.output)
