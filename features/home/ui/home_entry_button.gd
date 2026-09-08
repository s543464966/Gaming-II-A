@tool
extends "res://ui/components/icon_button.gd"
## 首页入口沿牌面轮廓命中，透明斜角不抢占相邻入口或触发提亮。

## 顶点使用按钮局部设计像素，随画布等比缩放。
@export var hit_polygon: PackedVector2Array = PackedVector2Array()
## 头像的椭圆区域可与姓名牌多边形合并；空矩形表示未启用。
@export var hit_ellipse: Rect2 = Rect2()

## 原生命中判断同时约束鼠标悬停、按下、释放和移出取消。
func _has_point(point: Vector2) -> bool:
	if hit_polygon.is_empty() and not hit_ellipse.has_area():
		return Rect2(Vector2.ZERO, size).has_point(point)
	if not hit_polygon.is_empty() and Geometry2D.is_point_in_polygon(point, hit_polygon):
		return true
	if hit_ellipse.has_area():
		var normalized: Vector2 = (point - hit_ellipse.get_center()) / (hit_ellipse.size * 0.5)
		return normalized.length_squared() <= 1.0
	return false
