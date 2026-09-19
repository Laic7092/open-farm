#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""tools/wiki/render.py — wiki 渲染层：字段格式化、卡片、对白 / 日程 / 货架等专用块。

只依赖 content.Context 提供的查询能力，不懂 HTML 之外的任何业务：
新增一个数据字段时，这里最多需要往 FIELD_LABELS / PRIMARY / TABLE_COLUMNS 补一行。
"""
from __future__ import annotations

from content import (
    ENUMS,
    KINDS,
    REF_FIELDS,
    REF_LIST_FIELDS,
    SEASON_KEYS,
    Context,
    WEATHER_KEYS,
    esc,
    field_label,
)

DIM = '<span class="dim">—</span>'
FLAG_FIELDS = {"required_flag", "set_flag", "forbidden_flag", "attendance_flag"}
## 已经在专用块里展示过、不再进「全部字段」的字段。
SPECIAL_FIELDS = {
    "DialogueData": {"lines"},
    "ShopData": {"stock"},
    "NpcData": {"schedule"},
}
## 已经用作卡片标题的字段，不再在「全部字段」里重复。
TITLE_FIELDS = {"display_name_key", "title_key"}
MONEY_FIELDS = {
    "buy_price", "sell_price", "seed_price", "base_sell_price",
    "price_override", "reward_money", "grant_money", "upgrade_money",
}
PERCENT_FIELDS = {
    "bonus_yield_chance", "bonus_product_chance", "drop_chance", "sell_multiplier",
    "quality_silver_chance", "quality_gold_chance", "quality_bonus",
}
## 空值但语义明确、必须保留展示的字段（如「不限季节」）。
MEANINGFUL_EMPTY = {"seasons", "grow_seasons", "weathers", "water"}
## 对白分组里不是 NPC 的前缀 → 分组显示名。
DIALOGUE_GROUP_LABELS = {"festival": "节日活动"}

## 卡片正面展示的字段（其余字段收进「全部字段」）。
PRIMARY: dict[str, list[str]] = {
    "ItemData": ["category", "buy_price", "sell_price", "stack_limit", "sellable",
                 "tool_id", "crop_id", "animal_id", "description_key"],
    "CropData": ["seed_item_id", "harvest_item_id", "harvest_amount", "seasons",
                 "days_per_stage", "regrow_days", "days_without_water_tolerance",
                 "seed_price", "base_sell_price", "bonus_yield_chance",
                 "quality_silver_chance", "quality_gold_chance"],
    "FishData": ["item_id", "water", "seasons", "weathers", "min_hour", "max_hour",
                 "weight", "difficulty", "size_cm"],
    "AnimalData": ["species", "mature_days", "produce_days", "product_item_id",
                   "product_amount", "feed_item_id", "max_affection", "affection_per_pet",
                   "affection_decay_per_day", "bonus_affection_threshold", "bonus_product_chance",
                   "breed_days", "breed_affection", "quality_silver_chance", "quality_gold_chance"],
    "BuildingData": ["capacity", "allowed_species"],
    "FloraData": ["kind", "drop_item_id", "drop_amount", "drop_chance", "tool_kind",
                  "stamina_cost", "days_per_stage", "grow_seasons", "spawn_weight",
                  "rain_bonus", "initial_weight", "max_per_world", "min_spacing",
                  "passable", "solid_from_stage", "grows_on_farmland", "pickable_by_hand",
                  "required_tier", "mine_min_depth", "mine_max_depth", "mine_weight",
                  "quality_silver_chance", "quality_gold_chance"],
    "ToolData": ["kind", "stamina_cost", "reach", "area_size", "tier",
                 "next_id", "upgrade_money", "upgrade_cost"],
    "NpcData": ["shop_id", "max_affection", "move_speed", "romanceable",
                "confession_affection", "marriage_affection", "loved_gifts",
                "liked_gifts", "disliked_gifts"],
    "ShopData": ["buys_from_player", "sell_multiplier"],
    "CommissionData": ["item_id", "amount", "reward_money"],
    "FestivalData": ["season", "day", "start_hour", "end_hour", "world_path", "gather_point",
                     "npc_ids", "attendance_affection", "attendance_flag", "required_flag",
                     "game_id", "intro_dialogue"],
    "EventData": ["season", "day", "weather", "required_flag", "forbidden_flag",
                  "required_npc", "required_affection", "grant_money", "set_flag",
                  "dialogue", "once"],
    "RecipeData": ["output_item_id", "output_amount", "ingredients", "required_flag"],
    "FestivalGameData": ["item_ids", "min_score", "reward_money", "consolation_money"],
    "VillageGoalData": ["metric", "target", "reward_money", "reward_flag",
                        "required_flag", "order"],
    "MineStratumData": ["depth_min", "depth_max", "ore_bonus", "loot_bias",
                        "quality_bonus", "tint"],
}

## 每种数据在「表格」视图里对比的列（缺省则只提供卡片视图）。
## 这里刻意只放可排序的标量 / 短引用，方便横向审阅数值平衡。
TABLE_COLUMNS: dict[str, list[str]] = {
    "ItemData": ["category", "buy_price", "sell_price", "stack_limit", "sellable",
                 "tool_id", "crop_id", "animal_id"],
    "CropData": ["seed_item_id", "harvest_item_id", "harvest_amount", "seasons",
                 "days_per_stage", "regrow_days", "seed_price", "base_sell_price",
                 "bonus_yield_chance", "quality_silver_chance", "quality_gold_chance",
                 "days_without_water_tolerance"],
    "FishData": ["water", "seasons", "weathers", "min_hour", "max_hour",
                 "weight", "difficulty", "size_cm", "item_id"],
    "AnimalData": ["species", "mature_days", "produce_days", "product_item_id",
                   "product_amount", "feed_item_id", "max_affection", "affection_per_pet",
                   "affection_decay_per_day", "bonus_affection_threshold",
                   "bonus_product_chance", "breed_days", "breed_affection",
                   "quality_silver_chance", "quality_gold_chance"],
    "BuildingData": ["capacity", "allowed_species"],
    "FloraData": ["kind", "drop_item_id", "drop_amount", "drop_chance", "tool_kind",
                  "stamina_cost", "grow_seasons", "spawn_weight", "rain_bonus",
                  "initial_weight", "max_per_world", "min_spacing", "passable",
                  "grows_on_farmland", "pickable_by_hand", "required_tier",
                  "mine_min_depth", "mine_max_depth", "mine_weight"],
    "ToolData": ["kind", "tier", "stamina_cost", "reach", "area_size", "next_id",
                 "upgrade_money", "upgrade_cost"],
    "NpcData": ["shop_id", "max_affection", "move_speed", "romanceable",
                "confession_affection", "marriage_affection", "loved_gifts",
                "liked_gifts", "disliked_gifts"],
    "ShopData": ["buys_from_player", "sell_multiplier"],
    "CommissionData": ["item_id", "amount", "reward_money"],
    "FestivalData": ["season", "day", "start_hour", "end_hour", "world_path",
                     "gather_point", "npc_ids", "attendance_affection", "game_id"],
    "EventData": ["season", "day", "weather", "required_npc", "required_affection",
                  "grant_money", "required_flag", "forbidden_flag", "set_flag", "once"],
    "RecipeData": ["output_item_id", "output_amount", "ingredients", "required_flag"],
    "FestivalGameData": ["item_ids", "min_score", "reward_money", "consolation_money"],
    "VillageGoalData": ["metric", "target", "reward_money", "reward_flag", "required_flag", "order"],
    "MineStratumData": ["depth_min", "depth_max", "ore_bonus", "loot_bias", "quality_bonus", "tint"],
}


# ---------------------------------------------------------------- 值格式化

def number(value: object) -> str:
    if isinstance(value, float) and value.is_integer():
        return str(int(value))
    return str(value)


def format_value(ctx: Context, value: object) -> str:
    if value is None or value == "":
        return DIM
    if isinstance(value, bool):
        return '<span class="yes">✓</span>' if value else '<span class="no">✗</span>'
    if isinstance(value, dict):
        return _format_dict(ctx, value)
    if isinstance(value, list):
        return _format_list(ctx, value)
    if isinstance(value, float):
        return esc(number(value))
    if isinstance(value, str):
        return esc(value) if value else DIM
    return esc(value)


def _format_dict(ctx: Context, value: dict) -> str:
    if not value:
        return DIM
    if "$ref" in value:
        return ctx.chip(value["$ref"], value["id"])
    if "$texture" in value:
        url = ctx.assets.url(value["$texture"])
        return f'<img class="icon" src="{url}" alt="">' if url else DIM
    if "$frames" in value:
        return f'<span class="dim">{esc(value["$frames"].rsplit("/", 1)[-1])}</span>'
    if "$class" in value:
        return _nested(ctx, value)
    if "x" in value and "y" in value:
        return esc(f'({number(value["x"])}, {number(value["y"])})')
    if {"r", "g", "b"} <= set(value):
        return _color(value)
    keys = list(value)
    # 季节下标 → 对白引用（NpcData.seasonal_dialogue）。
    if keys and all(k.isdigit() for k in keys) and all(
        isinstance(v, dict) and "$ref" in v for v in value.values()
    ):
        return " ".join(
            f'{ctx.tr(SEASON_KEYS[int(k)])} {ctx.chip(value[k]["$ref"], value[k]["id"])}'
            for k in sorted(keys, key=int)
            if int(k) < len(SEASON_KEYS)
        )
    # 物品 id → 数量（升级材料 / 合成 / 掉落表）。
    if keys and all(isinstance(v, (int, float)) and not isinstance(v, bool) for v in value.values()):
        return " ".join(
            f'{ctx.chip("ItemData", k)} <span class="dim">×{number(v)}</span>'
            for k, v in value.items()
        )
    return _nested(ctx, value)


def _color(value: dict) -> str:
    channels = [int(round(max(0.0, min(1.0, float(value[c]))) * 255)) for c in ("r", "g", "b")]
    hexcode = "#%02x%02x%02x" % tuple(channels)
    return (
        f'<span class="swatch" style="background:{hexcode}"></span>'
        f'<span class="dim">{hexcode}</span>'
    )


def _format_list(ctx: Context, value: list) -> str:
    if not value:
        return DIM
    return " ".join(_item_chip(ctx, item) for item in value)


def _item_chip(ctx: Context, item: object) -> str:
    if isinstance(item, dict):
        return _format_dict(ctx, item)
    if isinstance(item, str) and item:
        return f'<span class="chip">{esc(item)}</span>'
    return format_value(ctx, item)


def _nested(ctx: Context, value: dict) -> str:
    rows = "".join(
        f'<tr><th>{esc(field_label(key))}</th><td>{format_field(ctx, "", key, val)}</td></tr>'
        for key, val in value.items()
        if key != "$class"
    )
    return f'<table class="fields nested">{rows}</table>'


def format_field(ctx: Context, kind: str, name: str, value: object) -> str:
    if name.endswith("_key"):
        return ctx.tr(value)
    if name in REF_FIELDS:
        return ctx.chip(REF_FIELDS[name], value) if value else DIM
    if name in REF_LIST_FIELDS:
        return " ".join(ctx.chip(REF_LIST_FIELDS[name], i) for i in value) if value else DIM
    if name in FLAG_FIELDS:
        return f'<span class="flag">{esc(value)}</span>' if value else DIM
    if name == "ingredients":
        if not value:
            return DIM
        return " ".join(
            f'{ctx.chip("ItemData", entry.get("item_id", ""))}'
            f' <span class="dim">×{number(entry.get("amount", 1))}</span>'
            for entry in value
        )
    if name in ("depth_min", "depth_max", "mine_min_depth", "mine_max_depth"):
        return f'{esc(number(value))} 层'

    if name in ("seasons", "grow_seasons"):
        if not value:
            return '<span class="dim">任意季节</span>'
        return " ".join(ctx.tr(SEASON_KEYS[s]) for s in value)
    if name == "weathers":
        if not value:
            return '<span class="dim">任意天气</span>'
        return " ".join(ctx.tr(WEATHER_KEYS[w]) for w in value)
    if name == "water":
        if not value:
            return '<span class="dim">任意水域</span>'
        return " ".join(f'<span class="badge">{ENUMS["WaterKind"][w]}</span>' for w in value)
    if name == "season":
        return DIM if int(value) < 0 else ctx.tr(SEASON_KEYS[int(value)])
    if name == "weather":
        return DIM if int(value) < 0 else ctx.tr(WEATHER_KEYS[int(value)])
    if name == "category":
        return f'<span class="badge">{ENUMS["ItemCategory"][int(value)]}</span>'
    if name == "kind":
        table = "FloraKind" if kind == "FloraData" else "ToolKind"
        return f'<span class="badge">{ENUMS[table][int(value)]}</span>'
    if name == "tool_kind":
        return f'<span class="badge">{ENUMS["ToolKind"][int(value)]}</span>'
    if name == "emotion":
        return f'<span class="badge">{ENUMS["Emotion"][int(value)]}</span>'
    if name == "facing":
        return f'<span class="badge">{ENUMS["Facing"][int(value)]}</span>'
    if name == "metric":
        return f'<span class="badge">{ENUMS["Metric"][int(value)]}</span>'

    if name in MONEY_FIELDS and not isinstance(value, bool):
        return f'<span class="money">{esc(number(value))} G</span>'
    if name in PERCENT_FIELDS:
        return esc(f'{float(value) * 100:.0f}%')
    if name == "start_minute":
        return f'<span class="time">{int(value) // 60:02d}:{int(value) % 60:02d}</span>'
    if name == "days_per_stage":
        if not value:
            return '<span class="dim">无阶段</span>'
        total = sum(value)
        return f'{esc(", ".join(str(v) for v in value))} <span class="dim">共 {total} 天</span>'
    if name in ("size_cm", "drop_amount") and isinstance(value, dict):
        return esc(f'{number(value["x"])} ~ {number(value["y"])}')
    if name == "area_size" and isinstance(value, dict):
        return esc(f'{number(value["x"])} × {number(value["y"])}')
    return format_value(ctx, value)


# ---------------------------------------------------------------- 卡片

def _thumb(ctx: Context, kind: str, res: dict) -> str:
    if kind == "NpcData":
        path = res.get("portrait") or _actor_sheet(res.get("frames"))
    elif kind == "ItemData":
        path = (res.get("icon") or {}).get("$texture")
    else:
        path = (res.get("sprite_sheet") or {}).get("$texture")
    url = ctx.assets.url(path)
    if url is None:
        return ""
    width, height = ctx.assets.size(path)
    scale = max(1, min(4, 64 // max(width, height) or 1))
    return f'<img class="thumb" src="{url}" style="width:{width * scale}px;height:{height * scale}px" alt="">'


def _actor_sheet(frames: object) -> str:
    if isinstance(frames, dict) and isinstance(frames.get("$frames"), str):
        return frames["$frames"].replace("_frames.tres", ".png")
    return ""


def card(ctx: Context, kind: str, rid: str, res: dict) -> str:
    if kind == "DialogueData":
        title, cid = esc(rid), ""
    else:
        title, cid = esc(ctx.name(kind, rid)), f' <span class="cid">{esc(rid)}</span>'
    search = esc(f"{rid} {ctx.name(kind, rid)} {ctx.label(kind)}".lower())
    body = [
        '<header class="card-head">',
        _thumb(ctx, kind, res),
        f'<div><h3>{title}{cid}</h3>',
        f'<span class="kindtag">{esc(KINDS.get(kind, ("", kind))[1])}</span></div>',
        "</header>",
    ]
    body.append(_special(ctx, kind, rid, res))
    primary_names = PRIMARY.get(kind, [])
    primary = {
        n: res[n] for n in primary_names
        if n in res and not _blank(n, res[n])
    }
    if primary:
        body.append(_table(ctx, kind, primary))
    skip = set(primary_names) | SPECIAL_FIELDS.get(kind, set()) | TITLE_FIELDS | {"id"}
    rest = {
        k: v for k, v in res.items()
        if k != "$class" and k not in skip and v not in (None, "")
    }
    if rest:
        body.append(
            '<details class="more"><summary>全部字段（%d）</summary>%s</details>'
            % (len(rest), _table(ctx, kind, rest))
        )
    refs = ctx.refs.get((kind, rid))
    if refs:
        unique = _unique(refs)
        chips = " ".join(
            f'<a class="chip ref" href="{ctx.url(src_kind, src_id)}">'
            f'{esc(ctx.label(src_kind))}·{esc(ctx.name(src_kind, src_id))}</a>'
            for src_kind, src_id, _ in unique
        )
        body.append(f'<footer class="refs"><span class="refs-n">被引用 {len(unique)}</span>{chips}</footer>')
    return (
        f'<article class="card" id="{ctx.slug(kind)}-{rid}" data-kind="{ctx.slug(kind)}"'
        f' data-search="{search}">{"".join(body)}</article>'
    )


def _blank(name: str, value: object) -> bool:
    """字段是否应该从卡片正面隐去（保留有语义的空值，如「任意季节」）。"""
    if name in MEANINGFUL_EMPTY:
        return False
    if value is None or value == "":
        return True
    return isinstance(value, (list, dict)) and not value


def _unique(refs: list[tuple[str, str, str]]) -> list[tuple[str, str, str]]:
    seen: set[tuple[str, str]] = set()
    result: list[tuple[str, str, str]] = []
    for kind, rid, field in refs:
        if (kind, rid) not in seen:
            seen.add((kind, rid))
            result.append((kind, rid, field))
    return result


def _table(ctx: Context, kind: str, fields: dict) -> str:
    rows = "".join(
        f'<tr><th>{esc(field_label(name))}</th><td>{format_field(ctx, kind, name, value)}</td></tr>'
        for name, value in fields.items()
    )
    return f'<table class="fields">{rows}</table>'


# ---------------------------------------------------------------- 专用块

def _special(ctx: Context, kind: str, rid: str, res: dict) -> str:
    if kind == "CropData":
        days = res.get("days_per_stage") or []
        labels = [f"阶段 {i + 1}" for i in range(len(days))] + ["成熟", "枯死"]
        return sheet(ctx, (res.get("sprite_sheet") or {}).get("$texture"),
                     ctx.layout["crop_columns"], None, labels)
    if kind == "AnimalData":
        return sheet(ctx, (res.get("sprite_sheet") or {}).get("$texture"),
                     ctx.layout["animal_columns"], None, ["幼崽", "成年", "可收"])
    if kind == "FloraData":
        days = res.get("days_per_stage") or []
        labels = [f"阶段 {i + 1}" for i in range(len(days))] or ["阶段 1", "阶段 2", "阶段 3"]
        labels = (labels + ["成熟", "阶段 4", "阶段 4"])[:ctx.layout["flora_columns"]]
        return sheet(ctx, (res.get("sprite_sheet") or {}).get("$texture"),
                     ctx.layout["flora_columns"], None, labels)
    if kind == "DialogueData":
        return dialogue_block(ctx, res)
    if kind == "NpcData":
        return schedule_block(ctx, res.get("schedule"))
    if kind == "ShopData":
        return stock_block(ctx, res)
    return ""


def sheet(ctx: Context, path: object, columns: int, cell: object, labels: list[str], scale: int = 4) -> str:
    url = ctx.assets.url(path)
    if url is None:
        return ""
    width, height = ctx.assets.size(path) if isinstance(path, str) else (0, 0)
    cell_w = (width // columns) if columns else width
    cell_h = height
    frames = []
    for index in range(columns):
        label = labels[index] if index < len(labels) else str(index)
        style = (
            f"--scale:{scale};--cw:{cell_w}px;--ch:{cell_h}px;--sw:{width}px;--sh:{height}px;"
            f"--x:{index * cell_w}px;--y:0px;--img:url({url})"
        )
        frames.append(
            f'<figure class="frame"><span class="sheet" style="{style}"></span>'
            f'<figcaption>{esc(label)}</figcaption></figure>'
        )
    return f'<div class="frames">{"".join(frames)}</div>'


def dialogue_block(ctx: Context, res: dict) -> str:
    default_speaker = ctx.tr(res.get("speaker_key"))
    rows = []
    for index, line in enumerate(res.get("lines") or []):
        speaker = ctx.tr(line.get("speaker_key")) if line.get("speaker_key") else default_speaker
        next_line = int(line.get("next_line", -1))
        target = "顺序" if next_line == -1 else ("结束" if next_line == -2 else f"→ #{next_line}")
        choices = ""
        if line.get("choices"):
            items = []
            for choice in line["choices"]:
                c_next = int(choice.get("next_line", -2))
                c_target = "结束" if c_next < 0 else f"→ #{c_next}"
                effects = []
                if choice.get("affection_delta"):
                    effects.append(f'好感 {choice["affection_delta"]:+d}')
                if choice.get("set_flag"):
                    effects.append(f'旗标 {choice["set_flag"]}')
                if choice.get("required_flag"):
                    effects.append(f'需要 {choice["required_flag"]}')
                suffix = f' <span class="dim">({esc("，".join(effects))})</span>' if effects else ""
                items.append(f'<li>{ctx.tr(choice.get("text_key"))} <b>{esc(c_target)}</b>{suffix}</li>')
            choices = f'<ul class="choices">{"".join(items)}</ul>'
        rows.append(
            f'<div class="line"><span class="idx">#{index}</span>'
            f'<span class="speaker">{speaker}</span>'
            f'<span class="badge">{ENUMS["Emotion"][int(line.get("emotion", 0))]}</span>'
            f'<span class="dim">下一句 {esc(target)}</span>'
            f'<div class="text">{ctx.tr(line.get("text_key"))}</div>{choices}</div>'
        )
    finished = ctx.tr(res.get("on_finish_signal")) if res.get("on_finish_signal") else ""
    tail = f'<div class="dim">结束后触发：<span class="flag">{esc(res["on_finish_signal"])}</span></div>' if finished else ""
    return f'<div class="dialogue">{"".join(rows)}{tail}</div>'


def schedule_block(ctx: Context, schedule: object) -> str:
    if not isinstance(schedule, dict) or not schedule.get("entries"):
        return ""
    entries = sorted(schedule["entries"], key=lambda e: e.get("start_minute", 0))
    rows = "".join(
        f'<tr><td class="time">{int(e.get("start_minute", 0)) // 60:02d}:{int(e.get("start_minute", 0)) % 60:02d}</td>'
        f'<td>{esc(e.get("location_id"))}</td><td>{esc(e.get("activity"))}</td>'
        f'<td>{ENUMS["Facing"][int(e.get("facing", 0))]}</td></tr>'
        for e in entries
    )
    return (
        '<div class="block"><h4>日程 <span class="dim">每天循环</span></h4>'
        f'<table class="fields"><tr><th>时刻</th><th>地点</th><th>活动</th><th>朝向</th></tr>{rows}</table></div>'
    )


def stock_block(ctx: Context, res: dict) -> str:
    stock = res.get("stock") or []
    if not stock:
        return '<div class="dim">货架为空</div>'
    rows = []
    for entry in stock:
        item_id = entry.get("item_id", "")
        item = ctx.get("ItemData", item_id) or {}
        override = entry.get("price_override") or 0
        price = override or item.get("buy_price", 0)
        source = '<span class="dim">覆盖</span>' if override else '<span class="dim">原价</span>'
        flags = f'<span class="flag">{esc(entry["required_flag"])}</span>' if entry.get("required_flag") else DIM
        days = entry.get("available_days") or []
        stock_text = "∞" if entry.get("unlimited") else str(entry.get("initial_stock", 0))
        rows.append(
            f'<tr><td>{ctx.chip("ItemData", item_id)}</td>'
            f'<td class="money">{esc(number(price))} G {source}</td>'
            f'<td>{esc(stock_text)}</td><td>{flags}</td>'
            f'<td>{esc(days) if days else DIM}</td></tr>'
        )
    return (
        '<div class="block"><h4>货架 <span class="dim">%d 件</span></h4>'
        '<table class="fields"><tr><th>道具</th><th>售价</th><th>库存</th><th>条件</th><th>可购日</th></tr>'
        f'{"".join(rows)}</table></div>' % len(stock)
    )


def section(ctx: Context, kind: str) -> str:
    items = ctx.items(kind)
    if not items:
        return ""
    toggle = (
        '<div class="viewtoggle" role="group">'
        '<button type="button" data-view="cards" class="on">卡片</button>'
        '<button type="button" data-view="table">表格</button></div>'
        if kind in TABLE_COLUMNS else ""
    )
    return (
        f'<section id="{ctx.slug(kind)}" class="sec" data-kind="{ctx.slug(kind)}">'
        f'<header class="sec-head"><h2>{esc(ctx.label(kind))}'
        f' <span class="count">{len(items)}</span></h2>{toggle}</header>'
        f'<div class="view view-cards">{_cards_block(ctx, kind, items)}</div>'
        f'{data_table(ctx, kind)}'
        "</section>"
    )


def _cards_block(ctx: Context, kind: str, items: dict[str, dict]) -> str:
    """对白按持有者分组，其余每种数据一个卡片网格。"""
    if kind == "DialogueData":
        return "".join(
            f'<div class="dgroup"><h3 class="dgroup-head">{esc(label)}'
            f' <span class="count">{len(rids)}</span></h3>'
            f'<div class="grid">{"".join(card(ctx, kind, rid, items[rid]) for rid in rids)}</div></div>'
            for label, rids in _dialogue_groups(ctx, items)
        )
    return f'<div class="grid">{"".join(card(ctx, kind, rid, res) for rid, res in items.items())}</div>'


def _dialogue_groups(ctx: Context, items: dict[str, dict]) -> list[tuple[str, list[str]]]:
    npc_ids = sorted(ctx.items("NpcData"), key=len, reverse=True)
    buckets: dict[str, list[str]] = {}
    for rid in sorted(items):
        owner = next((nid for nid in npc_ids if rid.startswith(nid + "_")), None)
        key = owner or rid.split("_", 1)[0]
        buckets.setdefault(key, []).append(rid)
    grouped: list[tuple[str, list[str]]] = []
    for key in sorted(buckets):
        label = ctx.name("NpcData", key) if key in npc_ids else DIALOGUE_GROUP_LABELS.get(key, key)
        grouped.append((label, buckets[key]))
    return grouped


def data_table(ctx: Context, kind: str) -> str:
    """表格视图：一列一个字段，可点表头排序，便于横向对比数值。"""
    columns = TABLE_COLUMNS.get(kind)
    items = ctx.items(kind)
    if not columns or not items:
        return ""
    head = "".join(f"<th>{esc(field_label(name))}</th>" for name in columns)
    rows = []
    for rid, res in items.items():
        name = ctx.name(kind, rid)
        search = esc(f"{rid} {name}".lower())
        cells = "".join(
            f"<td>{format_field(ctx, kind, c, res.get(c))}</td>" for c in columns
        )
        rows.append(
            f'<tr class="data-row" data-search="{search}">'
            f'<td class="name"><a href="{ctx.url(kind, rid)}">{esc(name)}</a>'
            f' <span class="cid">{esc(rid)}</span></td>{cells}</tr>'
        )
    return (
        '<div class="view view-table hidden"><table class="data-table"><thead><tr>'
        f'<th>名称</th>{head}</tr></thead><tbody>{"".join(rows)}</tbody></table></div>'
    )
