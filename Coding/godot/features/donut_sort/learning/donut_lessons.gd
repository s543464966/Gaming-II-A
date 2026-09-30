class_name DonutLessons
extends RefCounted
## 根据当前实际在场内容选择首次机制说明，记录由页面注入的进度服务保存。

const TEXT: Dictionary = {
	"basic": ["整理甜甜圈", "把顶层同口味甜甜圈搬到空纸托或同口味上方。凑齐四颗并符合顶部需求，就会自动收餐。"],
	"hidden": ["隐藏的口味", "灰色甜甜圈露到最上方后才揭示口味。已经揭示的口味会一直保留。"],
	"stock": ["原位补货", "本关有备货。完成当前连续收餐后，新餐盒按回收顺序补入原位；备货用完就停止。"],
	"lid": ["数字盖盒", "首次归纳出四颗同味，会让按盒位顺序选中的一只数字盒减一。归零开盖；同一个盒子重复凑满不再减数。"],
	"frozen": ["冰冻餐盒", "冰冻时不能拿取或放入。每成功回收一盒，按盒位顺序解冻一只普通冰冻盒。"],
	"single": ["单颗暂存", "这个小纸托只能放一颗。它不会收餐或补货，最后要把甜甜圈移回普通纸托凑齐四颗。"],
	"number_frozen": ["数字冰冻", "首次归纳四颗同味，让按盒位顺序选中的一只数字盒减一；归零破冰。回收不会直接解开数字冰。"],
	"fixed": ["固定口味", "彩色纸托只接收它指定的口味，即使空着也一样。取出和收餐仍按普通规则。"],
	"in_only": ["单向收纳盒", "指定纸托只能放入，预放的甜甜圈也不能取出。凑齐四颗同味后，按顶部需求回收。"],
	"cycle": ["底部置顶", "从带紫色双箭头的纸托成功搬出后，剩下最底部的一颗会移到顶部。整组搬出也只触发一次。"],
	"bomb": ["限时餐盒", "倒计时结束前，在炸弹盒中凑齐四颗同味即可解除炸弹，标识和倒计时一起消失；没有对应需求时留在原位等待。搬空不能解除。设置、教学和后台会暂停计时。"]
}


## 按学习顺序列出已经入场的机制，尚未补入的特殊盒不会提前触发教学。
static func available(state: Dictionary) -> Array[String]:
	var found: Dictionary = {"basic": true}
	if int(state.get("remaining_stock", 0)) > 0:
		found.stock = true
	for slot: Dictionary in state.slots:
		if slot.box == null or not slot.open:
			continue
		if slot.kind == "single":
			found.single = true
		if TEXT.has(slot.box.kind):
			found[slot.box.kind] = true
		if slot.box.items.any(func(item: Dictionary) -> bool: return not item.revealed):
			found.hidden = true
	var result: Array[String] = []
	for key: String in TEXT:
		if found.has(key):
			result.append(key)
	return result
