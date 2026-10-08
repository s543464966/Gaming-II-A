"""只读复核前 30 关路线节奏，以及锁定四同味等待盒的兼容性。"""
from pathlib import Path
from collections import Counter, deque
import hashlib
import json
import sys
import argparse

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'Tooling/data'))
from build_hundred_levels import Rules, full, make_box


def audit_reference():
    """复核手工录入的第六关实玩记录；不将模型回放冒充桌面操作。"""
    record = json.loads((Path(__file__).with_name('reference_screw_level_06.json')).read_text(encoding='utf-8'))
    board = list(record['opening_stacks'])
    orders = list(record['observed_orders'].values())
    assert Counter(''.join(board)) == Counter(''.join(''.join(row) for row in orders) * 4)
    cursors = [0, 0]
    deliveries = []
    first_group = None
    peak_waiting = 0
    for step, (source, target, expected_count) in enumerate(record['actual_moves'], 1):
        origin, destination = board[source], board[target]
        assert origin and destination is not None and source != target, (step, 'missing container')
        assert not (len(origin) == 4 and len(set(origin)) == 1), (step, 'completed source')
        assert not destination or destination[0] == origin[0], (step, 'wrong color')
        count = next((index for index, color in enumerate(origin) if color != origin[0]), len(origin))
        count = min(count, 4 - len(destination))
        assert count > 0 and count == expected_count, (step, 'transfer size')
        board[source], board[target] = origin[count:], origin[:count] + destination
        if len(board[target]) == 4 and len(set(board[target])) == 1 and first_group is None:
            first_group = step
        delivered = []
        while True:
            match = None
            for index, stack in enumerate(board):
                if stack is None or len(stack) != 4 or len(set(stack)) != 1:
                    continue
                for side in range(2):
                    if cursors[side] < len(orders[side]) and orders[side][cursors[side]] == stack[0]:
                        match = index, side
                        break
                if match:
                    break
            if match is None:
                break
            index, side = match
            delivered.append({'side': side, 'color': board[index][0]})
            board[index] = None
            cursors[side] += 1
        if delivered:
            deliveries.append({'step': step, 'groups': delivered})
        peak_waiting = max(peak_waiting, sum(bool(stack) and len(stack) == 4 and len(set(stack)) == 1 for stack in board))
        assert sum(len(stack or '') for stack in board) + 4 * sum(cursors) == 68
    assert all(not stack for stack in board) and cursors == list(map(len, orders))
    # 参考色到现有甜甜圈的一一映射是候选设计，不改运行关卡或源表。
    flavor_map = {'P': 0, 'D': 3, 'O': 4, 'Y': 5, 'V': 6, 'R': 8, 'C': 10}
    definition = {
        'slots': [{'kind': 'regular', 'id': f'reference_{index:02}',
                   'box': {'kind': 'normal', 'items': [{'flavor': flavor_map[color]} for color in stack]}}
                  for index, stack in enumerate(record['opening_stacks'])]
                 + [{'kind': 'turnover', 'id': name, 'box': None} for name in ('A', 'B')],
        'stock': [],
        'demands': [{'sequence': [flavor_map[color] for color in row]} for row in orders],
    }
    candidate_rules = Rules(definition)
    for mode in range(4):
        boxes = list(candidate_rules.initial[0])
        for bit, index in ((1, 19), (2, 20)):
            if mode & bit:
                boxes[index] = make_box({'kind': 'normal', 'items': []})
        state = candidate_rules.settle(boxes, *candidate_rules.initial[1:])
        for origin, target, _count in record['actual_moves']:
            assert not full(state[0][origin])
            state = dict(candidate_rules.moves(state, prune=False))[(origin, target)]
        assert candidate_rules.won(state)
    delivery_steps = [0] + [event['step'] for event in deliveries]
    return {'scope': 'consistency_check_of_manually_transcribed_live_play', 'won': True,
            'suggested_flavor_map': flavor_map, 'candidate_offline_route_modes_passed': 4,
            'moves': len(record['actual_moves']), 'first_group': first_group,
            'peak_waiting_boxes': peak_waiting,
            'maximum_delivery_gap': max(b - a for a, b in zip(delivery_steps, delivery_steps[1:])),
            'deliveries': deliveries}


def probe_first_delivery(number, limit=10000, depth_limit=6):
    """按完整合法搬运广搜首交付；未找到时只报告已检查范围。"""
    source = ROOT / f'Coding/godot/game_content/donuts/levels/level_{number:02}.json'
    rules = Rules(json.loads(source.read_text(encoding='utf-8-sig')))
    start = rules.settle(list(rules.initial[0]), *rules.initial[1:])
    queue = deque([(start, [])])
    seen = {start}
    visited = 0
    while queue and visited < limit:
        state, path = queue.popleft()
        if len(path) >= depth_limit:
            continue
        visited += 1
        for move, following in rules.moves(state, prune=False):
            if following[1] + following[2] > 0:
                return {'level': number, 'minimum_first_delivery_in_model': len(path) + 1,
                        'path': path + [move], 'expanded': visited,
                        'scope': 'full_legal_move_bfs_no_ads_no_tools_existing_offline_model'}
            if following not in seen:
                seen.add(following)
                queue.append((following, path + [move]))
    return {'level': number, 'minimum_first_delivery_in_model': None,
            'expanded': visited, 'state_limit': limit, 'depth_limit': depth_limit,
            'status': 'search_limit' if queue else 'no_delivery_within_depth'}


def audit_level(number):
    source = ROOT / f'Coding/godot/game_content/donuts/levels/level_{number:02}.json'
    definition = json.loads(source.read_text(encoding='utf-8-sig'))
    fixture = json.loads((ROOT / f'Testing/fixtures/donut_sort/level_{number:02}_solution.json').read_text(encoding='utf-8-sig'))
    rules = Rules(definition)
    modes = []
    baseline = {}
    for mode in range(4):
        boxes = list(rules.initial[0])
        for index, slot in enumerate(definition['slots']):
            bit = {'A': 1, 'B': 2}.get(slot.get('id'), 0)
            if bit and mode & bit:
                boxes[index] = make_box({'kind': 'normal', 'items': []})
        state = rules.settle(boxes, *rules.initial[1:])
        path = fixture['steps'] if mode == 0 else fixture['assist'][str(mode)]
        peak = sum(full(box) for box in state[0])
        first_delivery = 0 if state[1] + state[2] else None
        dismantled = []
        for step, (origin, target) in enumerate(path, 1):
            if full(state[0][origin]):
                dismantled.append(step)
            successors = dict(rules.moves(state, prune=False))
            if (origin, target) not in successors:
                raise AssertionError((number, mode, step, 'illegal move'))
            before = state[1] + state[2]
            state = successors[(origin, target)]
            if first_delivery is None and state[1] + state[2] > before:
                first_delivery = step
            peak = max(peak, sum(full(box) for box in state[0]))
        if not rules.won(state):
            raise AssertionError((number, mode, 'not won'))
        modes.append({'mode': mode, 'steps': len(path), 'waiting_box_source_steps': dismantled,
                      'won_under_existing_model': True, 'compatible_with_waiting_lock': not dismantled})
        if mode == 0:
            baseline = {'first_delivery_step': first_delivery, 'peak_waiting_boxes': peak, 'steps': len(path)}
    normal = [slot['box'] for slot in definition['slots']
              if slot['kind'] == 'regular' and slot['box'] and slot['box']['kind'] == 'normal']
    flavors = {item['flavor'] for slot in definition['slots'] if slot['box'] for item in slot['box']['items']}
    flavors.update(item['flavor'] for box in definition['stock'] for item in box['items'])
    return {'level': number, 'definition_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
            'flavors': len(flavors), 'slots': len(definition['slots']),
            'opening_items': sum(len(slot['box']['items']) for slot in definition['slots'] if slot['box']),
            'mechanisms': {kind: sum(bool(slot['box']) and slot['box']['kind'] == kind for slot in definition['slots'])
                           for kind in sorted({slot['box']['kind'] for slot in definition['slots'] if slot['box']}) if kind != 'normal'},
            'hidden_items': sum(sum(item.get('hidden', slot['box'].get('hidden_layers', False)) and index > 0
                                   for index, item in enumerate(slot['box']['items']))
                                for slot in definition['slots'] if slot['box']),
            'orders': sum(len(demand['sequence']) for demand in definition['demands'][:2]),
            'stock_boxes': len(definition['stock']),
            'normal_empty': sum(not box['items'] for box in normal),
            'normal_partial': sum(0 < len(box['items']) < 4 for box in normal),
            'baseline': baseline, 'modes': modes}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--probe', type=int, nargs='+', help='仅广搜指定关卡的首交付')
    parser.add_argument('--limit', type=int, default=10000)
    parser.add_argument('--depth', type=int, default=6)
    parser.add_argument('--reference', action='store_true', help='核对第六关实玩转录')
    args = parser.parse_args()
    if args.reference:
        print(json.dumps(audit_reference(), ensure_ascii=False, indent=2))
        raise SystemExit(0)
    if args.probe:
        for number in args.probe:
            print(json.dumps(probe_first_delivery(number, args.limit, args.depth), ensure_ascii=False), flush=True)
        raise SystemExit(0)
    levels = [audit_level(number) for number in range(1, 31)]
    print(json.dumps({'scope': 'offline_saved_routes_not_minimum_difficulty_or_engine_acceptance',
                      'route_count': 120,
                      'waiting_lock_compatible_routes': sum(mode['compatible_with_waiting_lock'] for level in levels for mode in level['modes']),
                      'levels': levels}, ensure_ascii=False, indent=2))
