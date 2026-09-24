class_name UiModal
extends Control
## 模态界面统一契约。
##
## 只负责“生命周期 + 取消协议”，不负责具体内容，也不直接改 [SceneTree.paused]：
## [UiModalHost] 才是模态栈与暂停真值的唯一持有者。
##
## 子类约定：
## - [method _ready] 第一行调用 [code]super._ready()[/code]；
## - 需要清理的关闭逻辑覆写 [method close]，并在末尾调用 [code]super.close()[/code]；
## - 普通模态可取消；对话等不可打断界面覆写 [method can_cancel] 返回 false。

## 界面已关闭。宿主据此出栈并同步暂停。
signal closed


func _ready() -> void:
    visible = false


## 关闭模态：先隐藏自己，再通知宿主。
##
## 子类清理完自己的状态后调用 [code]super.close()[/code]。
func close() -> void:
    visible = false
    closed.emit()


## 请求取消（Esc / 触控 B / 宿主 close_all）。返回 true 表示确实关闭了。
func request_cancel() -> bool:
    if not can_cancel():
        return false
    close()
    return true


## 当前上下文是否允许被取消键关闭。对话返回 false。
func can_cancel() -> bool:
    return true
