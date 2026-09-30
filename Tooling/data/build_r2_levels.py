"""按 R2 装量制作层序，检查开局与中段腾位；候选全部通过后才安装。"""
from pathlib import Path
from collections import Counter
from concurrent.futures import ProcessPoolExecutor, as_completed
import argparse, copy, hashlib, json, random, time
from build_hundred_levels import Rules, read, write, finalize, assign_bomb_timing
from rebalance_hundred_levels import candidate, opening_metrics, first_group_gate


def groups_on_move(rules, state, move):
    """辨认一次玩家搬运带来的首次四颗归纳，不把连锁回收算作新搬运。"""
    src, dst = move
    source, target = state[0][src], state[0][dst]
    if target[3] or rules.caps[dst] != 4:
        return False
    flavor = source[0][0] // 2
    count = 0
    for item in source[0]:
        if item // 2 != flavor or item % 2 == 0:
            break
        count += 1
    count = min(count, rules.caps[dst] - len(target[0]))
    return len(target[0]) + count == 4 and all(x // 2 == flavor for x in target[0])


def midgame_metrics(definition, steps):
    """在实际无辅助路线每段归纳前检查全部合法一步选择，记录需要先腾位的段。"""
    rules = Rules(definition)
    state = rules.initial
    total = sum(map(len, rules.demands))
    intervals, began, pending = [], 0, None
    split_grouped = False
    for index, step in enumerate(steps):
        # 验证一步选择不套用求解器的等价空盒与整摞换位剪枝。
        choices = list(rules.moves(state, prune=False))
        if pending is None:
            pending = {'from_step': index + 1, 'recovered': state[1] + state[2],
                       'one_step_targets': sorted({m[1] for m, _ in choices if groups_on_move(rules, state, m)})}
            began = index
            split_grouped = False
        split_grouped = split_grouped or state[0][step[0]][3]
        grouped = groups_on_move(rules, state, step)
        selected = [nxt for move, nxt in choices if list(move) == list(step)]
        if not selected:
            raise ValueError((definition['id'], index, step))
        state = selected[0]
        if grouped:
            if .3 <= pending['recovered'] / total <= .7 and index > began and not pending['one_step_targets'] and not split_grouped:
                intervals.append(dict(pending, to_step=index+1, moves=index-began+1))
            pending = None
    return {'count':len(intervals), 'intervals':intervals, 'scope':'verified_baseline_route_not_all_paths'}


def generate_r2(plan, output, start=0, attempts=20000):
    path = output/'levels'/f'level_{plan["id"]:02}.json'
    if path.exists():
        definition = read(path)
        fixture_path = output/'fixtures'/f'level_{plan["id"]:02}_solution.json'
        fixture = read(fixture_path)
        midgame = midgame_metrics(definition, fixture['steps'])
        if midgame['count'] >= plan['midgame_space_min']:
            definition['design']['bomb_multiplier'] = plan.get('bomb_multiplier')
            if plan.get('bomb_multiplier'):
                assign_bomb_timing(definition, fixture)
            fixture['midgame_metrics'] = midgame
            fixture['definition_sha256'] = hashlib.sha256(json.dumps(definition,ensure_ascii=False,sort_keys=True,separators=(',',':')).encode()).hexdigest()
            write(path, definition)
            write(fixture_path, fixture)
            return f'CHECKED {plan["id"]}'
    started = time.monotonic()
    rejected = Counter()
    for trial in range(start, start + attempts):
        seed = 230000000 + plan['id']*100000 + trial
        definition = candidate(plan, seed)
        if definition is None:
            rejected['candidate'] += 1
            continue
        metrics = opening_metrics(definition)
        if metrics['aabb_ratio'] > plan['aabb_max']+1e-9 or max(metrics['adjacent_ratio'], metrics['all_adjacent_ratio']) > plan['adjacent_max']+1e-9:
            rejected['layers'] += 1
            continue
        gate = first_group_gate(definition, plan['first_group_min'], plan['one_step_max'])
        if gate is None:
            rejected['first'] += 1
            continue
        solution, visits = Rules(definition).solve(5000)
        if not solution:
            rejected['solve'] += 1
        else:
            midgame = midgame_metrics(definition, solution)
            if midgame['count'] < plan['midgame_space_min']:
                rejected['midgame'] += 1
            else:
                fixture = finalize(definition, solution, visits)
                fixture['requirements'] = 'R2'
                fixture['opening_metrics'] = dict(metrics, **gate)
                fixture['midgame_metrics'] = midgame
                fixture['definition_sha256'] = hashlib.sha256(json.dumps(definition,ensure_ascii=False,sort_keys=True,separators=(',',':')).encode()).hexdigest()
                write(path,definition)
                write(output/'fixtures'/f'level_{plan["id"]:02}_solution.json',fixture)
                return f"BUILT {plan['id']}: trial {trial}, {len(solution)} moves, mid {midgame['count']}, {time.monotonic()-started:.1f}s"
        if trial % 100 == 0:
            print(f"SEARCH {plan['id']} trial {trial} {dict(rejected)} {time.monotonic()-started:.1f}s",flush=True)
    raise RuntimeError(f"Level {plan['id']} not solved: {dict(rejected)}")


def tune_r2(plan, output):
    """针对开局短解逐颗交换口味，数量与装量固定，中段指标仍由完整路线检查。"""
    from tune_level_layers import short_route
    rng = random.Random(240000 + plan['id'])
    started = time.monotonic()
    for restart in range(200):
        seed = 240000000 + plan['id']*10000 + restart
        d = candidate(plan, seed)
        if d is None:
            continue
        score, path = short_route(d, plan['first_group_min'])
        positions = [(i,j) for i,s in enumerate(d['slots']) if s['box'] for j in range(len(s['box']['items']))]
        for iteration in range(500):
            metrics = opening_metrics(d)
            layers_ok = metrics['aabb_ratio']<=plan['aabb_max'] and max(metrics['adjacent_ratio'],metrics['all_adjacent_ratio'])<=plan['adjacent_max']
            if score >= plan['first_group_min'] and layers_ok:
                solution,visits = Rules(d).solve(15000)
                if solution:
                    midgame = midgame_metrics(d,solution)
                    gate = first_group_gate(d,plan['first_group_min'],plan['one_step_max'])
                    if midgame['count']>=plan['midgame_space_min'] and gate:
                        d['design']['tuning_iterations'] = [restart,iteration]
                        fixture = finalize(d,solution,visits)
                        fixture.update(requirements='R2', opening_metrics=dict(metrics,**gate),midgame_metrics=midgame)
                        fixture['definition_sha256'] = hashlib.sha256(json.dumps(d,ensure_ascii=False,sort_keys=True,separators=(',',':')).encode()).hexdigest()
                        name = f'level_{plan["id"]:02}'
                        write(output/'levels'/(name+'.json'),d)
                        write(output/'fixtures'/(name+'_solution.json'),fixture)
                        return f'TUNED {plan["id"]}: {len(solution)} moves, mid {midgame["count"]}, {restart}/{iteration}, {time.monotonic()-started:.1f}s'
            involved = {x for move in path for x in move}
            sources = [p for p in positions if not involved or p[0] in involved]
            a,b = rng.choice(sources),rng.choice(positions)
            x=d['slots'][a[0]]['box']['items'][a[1]]
            y=d['slots'][b[0]]['box']['items'][b[1]]
            if x['flavor']==y['flavor']:
                continue
            x['flavor'],y['flavor']=y['flavor'],x['flavor']
            m=opening_metrics(d)
            invalid=m['aabb_ratio']>plan['aabb_max'] or max(m['adjacent_ratio'],m['all_adjacent_ratio'])>plan['adjacent_max'] or any(s['box'] and len(s['box']['items'])==4 and len({i['flavor'] for i in s['box']['items']})==1 for s in d['slots'])
            if not invalid:
                new_score,new_path=short_route(d,plan['first_group_min'])
                if new_score>=score or rng.random()<.015:
                    score,path=new_score,new_path
                    continue
            x['flavor'],y['flavor']=y['flavor'],x['flavor']
        print(f'TUNE {plan["id"]}: restart {restart}, score {score}, {time.monotonic()-started:.1f}s',flush=True)
    raise RuntimeError(f'No tuned R2 candidate for {plan["id"]}')


def tune_demands(plan, output):
    """保留已达标层序，重排同量需求以消除中段待回收整盒造成的顺接捷径。"""
    name = f'level_{plan["id"]:02}'
    base = read(output/'levels'/(name+'.json'))
    old_fixture = read(output/'fixtures'/(name+'_solution.json'))
    original = [f for order in base['demands'] for f in order['sequence']]
    remaining = Counter(original)
    grouped_order = []
    rules = Rules(base)
    state = rules.initial
    for move in old_fixture['steps']:
        if groups_on_move(rules,state,move):
            flavor = state[0][move[0]][0][0]//2
            if remaining[flavor] > 0:
                grouped_order.append(flavor)
                remaining[flavor] -= 1
        state = next(n for m,n in rules.moves(state) if list(m)==list(move))
    grouped_order += list(remaining.elements())
    rng = random.Random(250000+plan['id'])
    started=time.monotonic()
    for trial in range(3000):
        sequence = list(grouped_order if trial==0 else original)
        if trial:
            rng.shuffle(sequence)
        d=copy.deepcopy(base)
        for index in range(2):
            d['demands'][index]['sequence']=sequence[index::2]
        solution,visits=Rules(d).solve(6000)
        if solution:
            midgame=midgame_metrics(d,solution)
            if midgame['count']>=plan['midgame_space_min']:
                gate=first_group_gate(d,plan['first_group_min'],plan['one_step_max'])
                if gate:
                    d['design']['demand_tuning_trial']=trial
                    fixture=finalize(d,solution,visits)
                    fixture.update(requirements='R2',opening_metrics=dict(opening_metrics(d),**gate),midgame_metrics=midgame)
                    fixture['definition_sha256']=hashlib.sha256(json.dumps(d,ensure_ascii=False,sort_keys=True,separators=(',',':')).encode()).hexdigest()
                    write(output/'levels'/(name+'.json'),d)
                    write(output/'fixtures'/(name+'_solution.json'),fixture)
                    return f'DEMANDS {plan["id"]}: trial {trial}, {len(solution)} moves, mid {midgame["count"]}, {time.monotonic()-started:.1f}s'
        if trial%100==0:
            print(f'DEMANDS {plan["id"]}: trial {trial}, {time.monotonic()-started:.1f}s',flush=True)
    raise RuntimeError(f'No verified demand order for {plan["id"]}')


if __name__ == '__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('output',type=Path)
    parser.add_argument('--start',type=int,default=1)
    parser.add_argument('--end',type=int,default=100)
    parser.add_argument('--workers',type=int,default=4)
    parser.add_argument('--trial',type=int,default=0)
    parser.add_argument('--tune',action='store_true')
    parser.add_argument('--demands',action='store_true')
    args=parser.parse_args()
    plans=read(args.output/'level_plan.json')['levels'][args.start-1:args.end]
    with ProcessPoolExecutor(max_workers=args.workers) as pool:
        tasks=[pool.submit(tune_demands,p,args.output) if args.demands else pool.submit(tune_r2,p,args.output) if args.tune else pool.submit(generate_r2,p,args.output,args.trial) for p in plans]
        for task in as_completed(tasks):
            print(task.result(),flush=True)
