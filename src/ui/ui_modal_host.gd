class_name UiModalHost
extends Node
## 模态栈的唯一权威。
##
## 只维护“谁开着”和 [SceneTree.paused] 的真值，不打开具体界面、不处理具体输入：
## 具体界面的参数由 [UiRoot] 路由，具体界面的清理由各自的 [UiModal.close] 完成。
##
## 熔断约定：模态节点可以失败 / 不可见；宿主只对“确实发过 closed”的节点出栈，
## 绝不让暂停状态依赖某个具体界面是否记得隐藏自己。

## 暂停状态变化（由栈是否为空决定）。
signal pause_changed(paused: bool)

## 当前栈。只保存 [UiModal]，不按具体类型分支。
var _stack: Array[UiModal] = []
## 上一次广播给外部的暂停状态，避免无变化的场景切换重复播音效。
var _paused: bool = false
## 每个模态的 closed 回调；重开同一个模态时避免重复连接。
var _callbacks: Dictionary = {}


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS


## 入栈。重复入栈是幂等的。
func open(modal: UiModal) -> void:
    if modal == null:
        return
    if _stack.has(modal):
        return
    _stack.append(modal)
    var callback := _on_modal_closed.bind(modal)
    _callbacks[modal] = callback
    modal.closed.connect(callback)
    _sync_pause()


## 请求关闭一个已在栈中的模态。真正的清理和 closed 广播由 [UiModal] 决定。
func close(modal: UiModal) -> void:
    if modal == null or not _stack.has(modal):
        return
    modal.close()


## 关闭所有模态。
func close_all() -> void:
    for modal: UiModal in _stack.duplicate():
        modal.close()
    # 子类若拒绝关闭（正常不会），这里兜底清空，保证暂停不泄漏。
    for modal: UiModal in _callbacks.keys():
        var callback = _callbacks[modal]
        if callback != null and modal.closed.is_connected(callback):
            modal.closed.disconnect(callback)
    _callbacks.clear()
    _stack.clear()
    _sync_pause()


## 当前顶层模态；没有则为 null。
func top() -> UiModal:
    return _stack.back() if not _stack.is_empty() else null


func has_modal() -> bool:
    return not _stack.is_empty()


func _on_modal_closed(modal: UiModal) -> void:
    var callback = _callbacks.get(modal)
    if callback != null and modal.closed.is_connected(callback):
        modal.closed.disconnect(callback)
    _callbacks.erase(modal)
    _stack.erase(modal)
    _sync_pause()


func _sync_pause() -> void:
    # 独立测试 / 装配阶段的宿主可能还没进树；此时不碰 SceneTree。
    if not is_inside_tree():
        return
    var paused := not _stack.is_empty()
    if paused == _paused:
        return
    _paused = paused
    var tree := get_tree()
    if tree != null:
        tree.paused = paused
    pause_changed.emit(paused)
