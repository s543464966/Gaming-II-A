class_name DonutCoinBalance
extends Control
## 在顶部常驻显示本关会话的真实金币余额。


## 按阅读习惯加入千位分隔符，奖励与撤回均由会话快照驱动。
func present(amount: int) -> void:
	var digits: String = str(maxi(amount, 0))
	var formatted: String = ""
	while digits.length() > 3:
		formatted = "," + digits.substr(digits.length() - 3, 3) + formatted
		digits = digits.substr(0, digits.length() - 3)
	$Amount.text = digits + formatted
