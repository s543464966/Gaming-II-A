class_name DonutDispatchView
extends Control
## 常驻底部出餐纸盒，为首批与补位动画提供唯一入场位置。


## 返回纸盒图像中心在设计画布中的位置。
func center_in_stage() -> Vector2:
	var art: TextureRect = $Back
	return position + art.position + art.size * 0.5
