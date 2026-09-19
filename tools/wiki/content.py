#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""tools/wiki/content.py — wiki 生成器的数据层。

把 [code].tmp/wiki/data.json[/code]（由 [code]tools/wiki_dump.tscn[/code] 导出）
和 [code]assets/i18n/*.csv[/code] 组合成一个查询上下文：
按 id 取资源、按翻译键取中英文、把 id 引用渲染成可点击的卡片链接，
并预先算好「谁引用了谁」的反查索引。渲染层（render.py）只依赖这里。
"""
from __future__ import annotations

import csv
import html
import json
import os
import shutil

# ---------------------------------------------------------------- 常量

## 全部数据种类：类名 → (锚点前缀, 中文名)。
KINDS: dict[str, tuple[str, str]] = {
    "ItemData": ("items", "物品"),
    "CropData": ("crops", "作物"),
    "FishData": ("fish", "鱼"),
    "AnimalData": ("animals", "动物"),
    "BuildingData": ("buildings", "畜舍"),
    "FloraData": ("flora", "野生植被"),
    "ToolData": ("tools", "工具"),
    "NpcData": ("npcs", "NPC"),
    "DialogueData": ("dialogues", "对白"),
    "ShopData": ("shops", "商店"),
    "CommissionData": ("commissions", "委托"),
    "FestivalData": ("festivals", "节日"),
    "EventData": ("events", "事件"),
}

## 字段名 →（被引用资源的类名）。用于把裸 id 渲染成链接、以及反查索引。
REF_FIELDS: dict[str, str] = {
    "tool_id": "ToolData",
    "crop_id": "CropData",
    "animal_id": "AnimalData",
    "shop_id": "ShopData",
    "required_npc": "NpcData",
    "seed_item_id": "ItemData",
    "harvest_item_id": "ItemData",
    "product_item_id": "ItemData",
    "feed_item_id": "ItemData",
    "drop_item_id": "ItemData",
    "item_id": "ItemData",
}

## 字段名 → 被引用资源列表的类名。
REF_LIST_FIELDS: dict[str, str] = {
    "npc_ids": "NpcData",
    "loved_gifts": "ItemData",
    "liked_gifts": "ItemData",
    "disliked_gifts": "ItemData",
}

## 枚举名 → 中文取值表（这些值没有进 i18n，直接给中文）。
ENUMS: dict[str, list[str]] = {
    "ItemCategory": ["种子", "收获物", "工具", "素材", "食物", "礼物", "牲畜"],
    "FloraKind": ["树", "杂草", "石头", "野花", "蘑菇"],
    "ToolKind": ["锄头", "洒水壶", "种子", "斧头", "镐", "镰刀", "钓竿"],
    "Emotion": ["平静", "开心", "难过", "生气", "惊讶"],
    "Facing": ["下", "上", "左", "右"],
    "WaterKind": ["池塘 / 河沟", "海"],
}

## 季节 / 天气用 i18n 的键，保证双语都能显示。
SEASON_KEYS = ["SEASON_SPRING", "SEASON_SUMMER", "SEASON_FALL", "SEASON_WINTER"]
WEATHER_KEYS = ["WEATHER_SUNNY", "WEATHER_CLOUDY", "WEATHER_RAINY", "WEATHER_STORMY", "WEATHER_SNOWY"]


def esc(text: object) -> str:
    return html.escape(str(text), quote=True)


# ---------------------------------------------------------------- 贴图仓库

class Assets:
    """把 [code]res://assets/...[/code] 的贴图复制到输出目录，返回相对 URL。"""

    def __init__(self, root: str, out_dir: str) -> None:
        self.root = root
        self.out_dir = out_dir
        self._urls: dict[str, str] = {}
        self._sizes: dict[str, tuple[int, int]] = {}

    def url(self, res_path: object) -> str | None:
        if not isinstance(res_path, str) or not res_path.startswith("res://assets/"):
            return None
        if res_path in self._urls:
            return self._urls[res_path]
        rel = res_path[len("res://assets/"):]
        source = os.path.join(self.root, "assets", rel)
        if not os.path.isfile(source):
            return None
        target_rel = rel
        target = os.path.join(self.out_dir, target_rel)
        os.makedirs(os.path.dirname(target), exist_ok=True)
        shutil.copyfile(source, target)
        self._urls[res_path] = target_rel.replace(os.sep, "/")
        return self._urls[res_path]

    def size(self, res_path: str) -> tuple[int, int]:
        if res_path not in self._sizes:
            from PIL import Image

            url = self.url(res_path)
            path = os.path.join(self.out_dir, url) if url else ""
            self._sizes[res_path] = Image.open(path).size if url else (0, 0)
        return self._sizes[res_path]

    def texture(self, value: object) -> str | None:
        if isinstance(value, dict):
            return self.url(value.get("$texture"))
        return None


# ---------------------------------------------------------------- 上下文

class Context:
    """渲染层的数据入口：翻译、引用链接、反查。"""

    def __init__(self, root: str, out_dir: str) -> None:
        with open(os.path.join(out_dir, "data.json"), encoding="utf-8") as handle:
            payload = json.load(handle)
        self.version: str = payload.get("version", "")
        self.layout: dict = payload["layout"]
        self.resources: dict[str, dict] = payload["resources"]
        self.validation: list[str] = payload.get("validation", [])
        self.assets = Assets(root, out_dir)
        self.i18n: dict[str, dict[str, str]] = self._load_i18n(os.path.join(root, "assets", "i18n"))
        self.refs: dict[tuple[str, str], list[tuple[str, str, str]]] = {}
        self._build_refs()

    # ---- i18n

    @staticmethod
    def _load_i18n(directory: str) -> dict[str, dict[str, str]]:
        table: dict[str, dict[str, str]] = {}
        for name in ("content", "dialogue", "ui"):
            path = os.path.join(directory, f"{name}.csv")
            if not os.path.isfile(path):
                continue
            with open(path, encoding="utf-8-sig", newline="") as handle:
                for row in csv.DictReader(handle):
                    key = (row.get("keys") or "").strip()
                    if key:
                        table[key] = {
                            "zh": (row.get("zh_CN") or "").strip(),
                            "en": (row.get("en") or "").strip(),
                            "src": name,
                        }
        return table

    # ---- 查询

    def get(self, kind: str, rid: str) -> dict | None:
        return self.resources.get(kind, {}).get(rid)

    def items(self, kind: str) -> dict[str, dict]:
        return self.resources.get(kind, {})

    def slug(self, kind: str) -> str:
        return KINDS.get(kind, ("misc", kind))[0]

    def label(self, kind: str) -> str:
        return KINDS.get(kind, ("misc", kind))[1]

    def url(self, kind: str, rid: str) -> str:
        return f"#{self.slug(kind)}-{rid}"

    def name(self, kind: str, rid: str) -> str:
        """资源的显示名（中文），缺失时退回 id。"""
        res = self.get(kind, rid)
        if res is None:
            return rid
        for key in ("display_name_key", "title_key"):
            entry = self.i18n.get(res.get(key) or "")
            if entry and entry["zh"]:
                return entry["zh"]
        return rid

    # ---- 渲染片段

    def tr(self, key: object) -> str:
        if not isinstance(key, str) or not key:
            return '<span class="dim">—</span>'
        entry = self.i18n.get(key)
        if entry is None:
            return f'<span class="bad" title="{esc(key)}">缺译 {esc(key)}</span>'
        zh, en = entry["zh"], entry["en"]
        text = esc(zh or "（空）")
        if en and en != zh:
            text += f' <span class="en">{esc(en)}</span>'
        return text

    def chip(self, kind: str, rid: str) -> str:
        res = self.get(kind, rid)
        if res is None:
            return f'<span class="bad" title="{esc(kind)}">{esc(rid)} 悬空</span>'
        name = self.name(kind, rid)
        cid = f'<span class="cid">{esc(rid)}</span>' if name != rid else ""
        return f'<a class="chip" href="{self.url(kind, rid)}">{esc(name)}{cid}</a>'

    def thumb(self, res_path: object, scale: int = 3) -> str:
        url = self.assets.url(res_path)
        if url is None:
            return '<span class="dim">缺图</span>'
        return f'<img class="thumb" src="{url}" style="width:{16 * scale}px" alt="">'

    def rows(self, kind: str, rid: str, names: list[str]) -> str:
        res = self.get(kind, rid) or {}
        return render_rows(self, kind, {n: res[n] for n in names if n in res})

    # ---- 反查索引

    def _build_refs(self) -> None:
        for kind, bucket in self.resources.items():
            for rid, res in bucket.items():
                for field, target in REF_FIELDS.items():
                    self._add_ref(res.get(field), target, kind, rid, field)
                for field, target in REF_LIST_FIELDS.items():
                    for value in res.get(field) or []:
                        self._add_ref(value, target, kind, rid, field)
                for field, value in res.items():
                    if isinstance(value, dict) and "$ref" in value:
                        self._add_ref(value["id"], value["$ref"], kind, rid, field)

    def _add_ref(self, target_id: object, target_kind: str, kind: str, rid: str, field: str) -> None:
        if not isinstance(target_id, str) or not target_id:
            return
        self.refs.setdefault((target_kind, target_id), []).append((kind, rid, field))


# ---------------------------------------------------------------- 字段标签

FIELD_LABELS: dict[str, str] = {
    "id": "id", "category": "分类", "buy_price": "买入价", "sell_price": "卖出价",
    "stack_limit": "堆叠上限", "sellable": "可卖出", "display_name_key": "名称",
    "description_key": "描述", "icon": "图标", "tool_id": "工具", "crop_id": "作物",
    "animal_id": "动物", "seed_item_id": "种子", "harvest_item_id": "收获物",
    "harvest_amount": "收获数量", "days_per_stage": "各阶段天数", "seasons": "季节",
    "regrow_days": "复收天数", "days_without_water_tolerance": "缺水枯死天数",
    "seed_price": "种子价", "base_sell_price": "基础售价", "bonus_yield_chance": "额外产出概率",
    "sprite_sheet": "阶段图", "item_id": "道具", "water": "水域", "weathers": "天气",
    "min_hour": "起始小时", "max_hour": "结束小时", "weight": "权重", "difficulty": "难度",
    "size_cm": "体长(cm)", "species": "物种", "mature_days": "成年天数",
    "produce_days": "产出间隔", "product_item_id": "产物", "product_amount": "产物数量",
    "feed_item_id": "饲料", "max_affection": "好感上限", "affection_per_pet": "抚摸加成",
    "affection_decay_per_day": "每日衰减", "bonus_affection_threshold": "加成门槛",
    "bonus_product_chance": "额外产出概率", "capacity": "容量", "allowed_species": "允许物种",
    "kind": "类型", "spawn_weight": "四季扩散权重", "rain_bonus": "雨天加成",
    "grow_seasons": "生长季节", "max_per_world": "单图上限", "min_spacing": "最小间距",
    "initial_weight": "开局权重", "passable": "可穿过", "solid_from_stage": "挡路阶段",
    "solid_size": "碰撞尺寸", "solid_offset": "碰撞偏移", "tool_kind": "所需工具",
    "stamina_cost": "体力消耗", "grows_on_farmland": "可长在农田", "pickable_by_hand": "可徒手采",
    "drop_item_id": "掉落物", "drop_amount": "掉落数量", "drop_chance": "掉落概率",
    "reach": "作用距离", "area_size": "作用范围", "tier": "升级等级",
    "portrait": "立绘", "frames": "行走图", "default_dialogue": "默认对白",
    "seasonal_dialogue": "季节对白", "schedule": "日程", "shop_id": "商店",
    "move_speed": "移动速度", "romanceable": "可攻略", "confession_affection": "表白门槛",
    "marriage_affection": "结婚门槛", "loved_gifts": "最爱的礼物", "liked_gifts": "喜欢的礼物",
    "disliked_gifts": "讨厌的礼物", "friend_dialogue": "朋友对白", "lover_dialogue": "恋人对话",
    "married_dialogue": "婚后对白", "confession_dialogue": "表白对白", "proposal_dialogue": "求婚对白",
    "buys_from_player": "回收物品", "sell_multiplier": "回收倍率", "price_override": "覆盖售价",
    "unlimited": "无限库存", "initial_stock": "初始库存", "required_flag": "需要旗标",
    "available_days": "可购日", "title_key": "标题", "amount": "数量", "reward_money": "报酬",
    "message_key": "提示文案", "season": "季节", "day": "日", "weather": "天气",
    "forbidden_flag": "禁止旗标", "required_affection": "好感要求", "required_npc": "目标 NPC",
    "grant_money": "给钱", "set_flag": "写入旗标", "dialogue": "对白", "once": "只发生一次",
    "start_hour": "开始钟点", "end_hour": "结束钟点", "world_path": "地图",
    "gather_point": "聚集点", "npc_ids": "到场 NPC", "attendance_affection": "到场好感",
    "attendance_flag": "到场旗标", "intro_dialogue": "开场对白", "speaker_key": "说话人",
    "lines": "对白", "on_finish_signal": "结束时信号", "text_key": "正文",
    "choices": "选项", "next_line": "下一句", "affection_delta": "好感变化",
    "emotion": "情绪", "start_minute": "时刻", "location_id": "地点", "activity": "活动",
    "facing": "朝向", "entries": "时间块",
}


def field_label(name: str) -> str:
    return FIELD_LABELS.get(name, name)
