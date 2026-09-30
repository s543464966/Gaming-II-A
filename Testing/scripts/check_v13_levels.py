"""核对实际层序、来源装量、四种广告条件和已绑定配置的首归纳下限；不把可行路线称为最短解。"""
from pathlib import Path
from collections import Counter
import hashlib, json, sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'Tooling/data'))
from build_hundred_levels import read, Rules, make_box
from rebalance_hundred_levels import KINDS, first_group_gate
from build_r2_levels import midgame_metrics


def verify(content, fixtures):
    plans = read(content/'level_plan.json')['levels']
    stats = []
    for plan in plans:
        name=f'level_{plan["id"]:02}'
        d=read(content/'levels'/f'{name}.json')
        f=read(fixtures/f'{name}_solution.json')
        digest=hashlib.sha256(json.dumps(d,ensure_ascii=False,sort_keys=True,separators=(',',':')).encode()).hexdigest()
        assert f['definition_sha256']==digest, name
        expected=Counter()
        for g in plan['effective_groups']:
            if g['kind']=='广告锁定周转盒':continue
            expected[(g['phase'],g['id'],KINDS[g['kind']],g['capacity'],g['fill'],g['number'])]+=1
        actual=Counter(('开局',s['group_id'],s['box']['kind'],1 if s['kind']=='single' else 4,len(s['box']['items']),s['box']['lid']) for s in d['slots'] if s['box'])
        for g,box in zip([g for g in plan['effective_groups'] if g['phase']=='备货'],d['stock']):
            actual[('备货',g['id'],box['kind'],4,len(box['items']),box['lid'])]+=1
        assert expected==actual,(name,'group amounts',expected-actual,actual-expected)
        boxes=[s['box'] for s in d['slots'] if s['box']]
        items=[item for box in boxes+d['stock'] for item in box['items']]
        supply=Counter(item['flavor'] for item in items)
        demand=Counter(flavor for order in d['demands'] for flavor in order['sequence'])
        assert supply==Counter({key:value*4 for key,value in demand.items()}),name
        assert len(supply)==plan['flavors'] and sum(supply.values())==plan['donuts'],name
        assert all(not o['sequence'] for o in d['demands'][2:]) and all(o['initially_open'] for o in d['demands'][:2]),name
        assert d['tools']=={'undo':1,'add_box':1,'top':1} and not d['combo_rewards'],name
        assert sum(bool(item.get('hidden',False)) for item in items)==round(plan['hidden_ratio']*plan['donuts']),name
        initial_four=[s['box'] for s in d['slots'] if s['kind']!='single' and s['box'] and s['box']['items']]
        adjacent=sum(a['flavor']==b['flavor'] for box in boxes for a,b in zip(box['items'],box['items'][1:]))
        pairs=sum(max(0,len(box['items'])-1) for box in boxes)
        aabb=sum(len(b['items'])==4 and b['items'][0]['flavor']==b['items'][1]['flavor'] and b['items'][2]['flavor']==b['items'][3]['flavor'] and b['items'][0]['flavor']!=b['items'][2]['flavor'] for b in initial_four)
        assert aabb<=int(plan['aabb_max']*len(initial_four)+1e-8),name
        assert not pairs or adjacent/pairs<=plan['adjacent_max']+1e-8,name
        all_pairs=pairs+sum(max(0,len(box['items'])-1) for box in d['stock'])
        all_adjacent=adjacent+sum(a['flavor']==b['flavor'] for box in d['stock'] for a,b in zip(box['items'],box['items'][1:]))
        assert not all_pairs or all_adjacent/all_pairs<=plan['adjacent_max']+1e-8,(name,'stock adjacent pairs')
        normal=[b for b in boxes if b['kind']=='normal' and len(b['items'])>0 and any(s['box'] is b and s['kind']=='regular' for s in d['slots'])]
        assert abs(sum(len(b['items']) for b in normal)/(len(normal)*4)-plan['normal_fill_ratio'])<1e-8,name
        gate=first_group_gate(d,plan['first_group_min'],plan['one_step_max'])
        assert gate is not None,(name,'first-group lower bound')
        midgame = midgame_metrics(d, f['steps']) if 'midgame_space_min' in plan else None
        if midgame is not None:
            assert midgame['count'] >= plan['midgame_space_min'], (name, 'midgame space target', midgame)
            assert midgame == f['midgame_metrics'], (name, 'stale midgame metrics')
        for mode in range(4):
            rules=Rules(d);boxes=list(rules.initial[0])
            for j in range(2):
                if mode & (1<<j):boxes[-2+j]=make_box({'items':[]})
            state=(tuple(boxes),0,0,0)
            steps=f['steps'] if not mode else f['assist'][str(mode)]
            for step in steps:
                choices=[n for m,n in rules.moves(state) if list(m)==list(step)]
                assert choices,(name,mode,step)
                state=choices[0]
            assert rules.won(state),(name,mode)
        stats.append({'level':plan['id'],'baseline_moves':len(f['steps']),
                      'A_moves':len(f['assist']['1']),'B_moves':len(f['assist']['2']),'AB_moves':len(f['assist']['3']),
                      'first_group_lower_bound':gate['first_group_lower_bound'],'adjacent_ratio':adjacent/pairs if pairs else None,
                      'aabb_ratio':aabb/len(initial_four),'midgame':midgame,'optimal':False,'playtest':'pending'})
    assert sum(p['stock']>0 for p in plans)==30
    print('PASS: 100 source-group expansions, flavor/hidden conservation, opening/midgame thresholds and 400 offline replays')
    return stats


if __name__=='__main__':
    stage=Path(sys.argv[1]) if len(sys.argv)>1 else ROOT/'Coding/godot/game_content/donuts'
    fixtures=stage/'fixtures' if (stage/'fixtures').exists() else ROOT/'Testing/fixtures/donut_sort'
    verify(stage,fixtures)
