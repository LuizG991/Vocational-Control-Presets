-- VocationalControlPresets.lua  (v1.0.0)
-- Dragon's Dogma 2 - REFramework script
--
-- Saves one gamepad control preset per vocation and applies it automatically
-- when the player changes vocation. For the Warfarer, the preset follows the
-- vocation of the weapon currently in hand.
--
-- How it works (same principle as "Classic Aim Controls" / "Custom Keybinds"):
--   The game keeps its gamepad bindings in app.UserInputManager's current
--   character pad assign (AssignList). Each entry has an Action
--   (app.CharacterInput.Action), a Button (via.hid.GamePadButton) and a
--   PreInput (the modifier: None, or Shift1 = the LB "Switch Weapon Skill" button).
--   This script rewrites Button / PreInput of those entries in memory.
--
--   1. The game's default layout is built in (DEFAULTS); controls without one use values captured once.
--   2. When the effective vocation changes (and stays stable for a few frames),
--      the preset of that vocation is applied on top of the game defaults.
--      A vocation without an active preset gets the game defaults back.
--   3. Every control found in the game's binding table can be edited. Controls the
--      script cannot remap (analog sticks, button chords such as "LB + Y B") are
--      listed as read-only.
--   4. Presets are stored in <game folder>/reframework/data/VocationalControlPresets/config.json
--
-- Install: <game folder>/reframework/autorun/VocationalControlPresets.lua
-- Menu:    REFramework menu > Script Generated UI > VocationalControlPresets
--
-- NOTE: do not use this together with the "Apply automatically on startup"
-- option of Classic Aim Controls; both rewrite the same binding table.

local NAME, VERSION = "VocationalControlPresets", "1.0.0"
local CONFIG_PATH = NAME .. "/config.json"
local OLD_CONFIG_PATH = "JobControlPresets/config.json"   -- name used before 1.0.0 (presets are carried over)
local migrated = false

------------------------------------------------------------------------
-- Safe helpers (every game access is wrapped in pcall)
------------------------------------------------------------------------
local function Call(obj, method, ...)
    if obj == nil then return nil end
    local args = { ... }
    local ok, res = pcall(function() return obj:call(method, table.unpack(args)) end)
    if ok then return res end
    return nil
end

local function Get(obj, field)
    if obj == nil then return nil end
    local ok, res = pcall(function() return obj:get_field(field) end)
    if ok then return res end
    return nil
end

local function Set(obj, field, value)
    if obj == nil then return false end
    return (pcall(function() obj:set_field(field, value) end))
end

local function address_of(obj)
    if obj == nil then return nil end
    local ok, a = pcall(function() return obj:get_address() end)
    if ok then return a end
    return nil
end

-- Iterates a .NET enumerable (GetEnumerator / MoveNext / get_Current)
local function sdk_iter(enumerable)
    if not enumerable then return function() return nil end end
    local ok, en = pcall(function() return enumerable:call("GetEnumerator") end)
    if not ok or not en then return function() return nil end end
    return function()
        local mok, moved = pcall(function() return en:call("MoveNext") end)
        if mok and moved then
            local cok, cur = pcall(function() return en:call("get_Current") end)
            if cok then return cur end
        end
        return nil
    end
end

-- Builds name -> value and value -> name tables from a game enum
local function enum_map(typename)
    local by_name, by_id = {}, {}
    local td = sdk.find_type_definition(typename)
    if td then
        for _, f in ipairs(td:get_fields()) do
            if f:is_static() then
                local ok, v = pcall(function() return f:get_data(nil) end)
                if ok and type(v) == "number" then
                    by_name[f:get_name()] = v
                    by_id[v] = f:get_name()
                end
            end
        end
    end
    return by_name, by_id
end

local ACTION_ID, ACTION_NAME = enum_map("app.CharacterInput.Action")
local PAD_BTN, PAD_NAME = enum_map("via.hid.GamePadButton")

------------------------------------------------------------------------
-- Static data
------------------------------------------------------------------------
local WARFARER = 10
local JOB_NAMES = {
    [1] = "Fighter", [2] = "Archer", [3] = "Mage", [4] = "Thief", [5] = "Warrior",
    [6] = "Sorcerer", [7] = "Mystic Spearhand", [8] = "Magick Archer", [9] = "Trickster",
    [10] = "Warfarer (only used when weapon detection is off)",
}
local JOB_LIST = {}
for i = 1, 10 do JOB_LIST[i] = i .. " - " .. JOB_NAMES[i] end

-- Linked controls: one entry in the game's menu that drives several game actions at once.
-- Everything else found in the binding table is listed individually under "All other controls".
-- More linked controls can be added in config.json:
--   "extra_groups": [ { "name": "My control", "actions": ["ActionNameA", "ActionNameB"] } ]
local GROUPS = {
    { name = "Vocation Action", actions = { "JobSpecialAction", "AimHold", "ShootRelease",
        "ThrowRelease", "GimmickAction", "Shift1OnlySpecificJob" } },
    { name = "Sheathe/Draw/Cancel", actions = { "ActCancel", "Sheathe", "Draw" } },
    { name = "Light Attack", actions = { "AttackS" } },
    { name = "Heavy Attack", actions = { "AttackL" } },
    { name = "Jump",         actions = { "Jump" } },
    { name = "Grab",         actions = { "Grab" } },
    { name = "Interact",     actions = { "Interact" } },
    { name = "Switch Weapon Skill (LB)", actions = { "Shift1" } },
    { name = "Weapon Skill 1", actions = { "Skill1" } },
    { name = "Weapon Skill 2", actions = { "Skill2" } },
    { name = "Weapon Skill 3", actions = { "Skill3" } },
    { name = "Weapon Skill 4", actions = { "Skill4" } },
    { name = "Weapon Skill 5", actions = { "Skill5" } },
    { name = "Weapon Skill 6", actions = { "Skill6" } },   -- hidden if this game version has no such action
}

-- Built-in game defaults (the layout of the game's own Button Mapping screen).
-- Vocations without a preset always get these back, whatever a previous preset changed.
-- Key = action name, or "Name#n" for actions that appear several times in the table.
-- Controls that are not listed here (pawn extras, SkillAdditional, lock-on...) use the values
-- captured the first time the script ran (see "Recapture other defaults").
local function D(button, pre) return { button = button, pre = pre or "None" } end
local DEFAULTS = {
    AttackS = D("RLeft"),                        -- Light Attack: X
    AttackL = D("RUp"),                          -- Heavy Attack: Y
    Jump = D("RDown"),                           -- Jump: A
    Interact = D("RRight"),                      -- Examine: B
    ["Dash#1"] = D("RRight"),                    -- Examine/Dash: B
    ["Dash#2"] = D("LStickPush"),                -- Dash 2: L3
    ActCancel = D("LTrigBottom"),                -- Sheathe/Draw/Cancel: LT
    Sheathe = D("LTrigBottom"),
    Draw = D("LTrigBottom"),
    Grab = D("RTrigBottom"),                     -- Grab: RT
    CameraReset = D("RStickPush"),               -- Reset Camera: R3
    Shift1 = D("LTrigTop"),                      -- Switch Weapon Skill: LB
    Skill1 = D("RLeft", "Shift1"),               -- Weapon Skill 1: LB + X
    Skill2 = D("RUp", "Shift1"),                 -- Weapon Skill 2: LB + Y
    Skill3 = D("RDown", "Shift1"),               -- Weapon Skill 3: LB + A
    Skill4 = D("RRight", "Shift1"),              -- Weapon Skill 4: LB + B
    Skill5 = D(144, "Shift1"),                   -- Weapon Skill 5: LB + Y B (chord)
    JobSpecialAction = D("RTrigTop"),            -- Vocation Action: RB
    AimHold = D("RTrigTop"),
    ShootRelease = D("RTrigTop"),
    ThrowRelease = D("RTrigTop"),
    GimmickAction = D("RTrigTop"),
    Shift1OnlySpecificJob = D("RTrigTop"),
    Go = D("LUp"),                               -- Pawn Command: Go!
    Come = D("LDown"),                           -- Pawn Command: To me!
    Help = D("LLeft"),                           -- Pawn Command: Help!
    Wait = D("LRight"),                          -- Pawn Command: Wait!
}

-- Xbox-style labels for via.hid.GamePadButton names
local BUTTONS = {
    { label = "LT", name = "LTrigBottom" }, { label = "LB", name = "LTrigTop" },
    { label = "RT", name = "RTrigBottom" }, { label = "RB", name = "RTrigTop" },
    { label = "A",  name = "RDown" },       { label = "B",  name = "RRight" },
    { label = "X",  name = "RLeft" },       { label = "Y",  name = "RUp" },
    { label = "L3", name = "LStickPush" },  { label = "R3", name = "RStickPush" },
    { label = "D-Pad Left", name = "LLeft" }, { label = "D-Pad Up", name = "LUp" },
    { label = "D-Pad Right", name = "LRight" }, { label = "D-Pad Down", name = "LDown" },
}
local BUTTON_BY_NAME = {}
for _, b in ipairs(BUTTONS) do BUTTON_BY_NAME[b.name] = b end

local function button_label(name)
    local b = BUTTON_BY_NAME[name]
    return b and b.label or tostring(name)
end

local function button_label_of_id(id)
    local n = id and PAD_NAME[id]
    if n then return button_label(n) end
    return id and ("#" .. tostring(id)) or "?"
end

-- Modifier (PreInput): "None" or "Shift1" (= the Switch Weapon Skill button, LB by default)
local function pre_name(preid)
    if preid == nil then return "None" end
    return ACTION_NAME[preid] or tostring(preid)
end

local function pre_label(preid)
    local n = pre_name(preid)
    if n == "None" then return "none" end
    if n == "Shift1" then return "Shift" end
    return n
end

local function mod_index(v)
    if v == "None" then return 2 elseif v == "Shift1" then return 3 end
    return 1
end

local function mod_from_index(i)
    if i == 2 then return "None" elseif i == 3 then return "Shift1" end
    return nil
end

------------------------------------------------------------------------
-- Config
------------------------------------------------------------------------
local CFG = {
    enabled = true,
    auto_apply = true,            -- apply the preset automatically when the vocation changes
    settle_frames = 30,           -- the vocation must stay the same this many frames before applying
    warfarer_uses_weapon = true,  -- Warfarer follows the vocation of the weapon in hand
    presets = {},                 -- ["2"] = { enabled = true, bindings = { ["Light Attack"] = { button = "RTrigBottom", pre = "None" } } }
    extra_groups = {},
    extra_defaults = {},          -- defaults of controls without a built-in one, captured once
    extra_captured = false,
}

-- A binding is { button = "<GamePadButton name>" | nil, pre = "None" | "Shift1" | nil }.
-- v0.1.x stored just the button name as a string.
local function norm_binding(v)
    if type(v) == "string" then return { button = v } end
    if type(v) == "table" then return v end
    return nil
end

local function load_config()
    local ok, data = pcall(json.load_file, CONFIG_PATH)
    if not (ok and type(data) == "table") then
        ok, data = pcall(json.load_file, OLD_CONFIG_PATH)
        migrated = ok and type(data) == "table"
    end
    if ok and type(data) == "table" then
        for k, _ in pairs(CFG) do
            if data[k] ~= nil then CFG[k] = data[k] end
        end
    end
    if type(CFG.presets) ~= "table" then CFG.presets = {} end
    if type(CFG.extra_groups) ~= "table" then CFG.extra_groups = {} end
    if type(CFG.extra_defaults) ~= "table" then CFG.extra_defaults = {} end
    local renamed = { Skill1 = "Weapon Skill 1", Skill2 = "Weapon Skill 2", Skill3 = "Weapon Skill 3",
        Skill4 = "Weapon Skill 4", Skill5 = "Weapon Skill 5", Skill6 = "Weapon Skill 6" }
    for _, p in pairs(CFG.presets) do
        if type(p) == "table" and type(p.bindings) == "table" then
            for k, v in pairs(p.bindings) do p.bindings[k] = norm_binding(v) end
            for old, new in pairs(renamed) do      -- skills moved to the initial list under new names
                if p.bindings[old] and not p.bindings[new] then
                    p.bindings[new] = p.bindings[old]
                    p.bindings[old] = nil
                end
            end
        end
    end
end

local function save_config()
    return (pcall(json.dump_file, CONFIG_PATH, CFG))
end

load_config()
if migrated then save_config() end

local function all_groups()
    local list = {}
    for _, g in ipairs(GROUPS) do list[#list + 1] = g end
    for _, g in ipairs(CFG.extra_groups) do
        if type(g) == "table" and type(g.name) == "string" and type(g.actions) == "table" then
            list[#list + 1] = g
        end
    end
    return list
end

local function ensure_preset(job)
    local key = tostring(job)
    local p = CFG.presets[key]
    if type(p) ~= "table" then
        p = { enabled = false, bindings = {} }
        CFG.presets[key] = p
    end
    if type(p.bindings) ~= "table" then p.bindings = {} end
    return p
end

local function active_preset(job)
    local p = CFG.presets[tostring(job)]
    if type(p) == "table" and p.enabled and type(p.bindings) == "table" then return p end
    return nil
end

------------------------------------------------------------------------
-- State
------------------------------------------------------------------------
local S = {
    frame = 0,
    job = nil, cur_job = nil, weapon_job = nil, wf_diag = "-",
    seen_job = nil, seen_since = 0,
    applied_job = nil,          -- vocation whose preset is currently applied
    baseline = nil,             -- [entry key] = { action = id, button = id, pre = id|nil }
    list_addr = nil,            -- address of the AssignList the baseline belongs to
    dirty = false,              -- something changed in the menu: re-apply
    save_pending = false,
    last_try = -1000,
    msg = "", err = nil,
    edit_job = 2,
    show_mod = false,
    friendly = nil, friendly_try = -1000,
}

------------------------------------------------------------------------
-- Vocation detection (same sources used by Classic Aim Controls)
------------------------------------------------------------------------
-- Warfarer: vocation (1..9) of the weapon in hand
local function read_weapon_job(ply, hum)
    local chara = nil
    pcall(function() chara = hum:get_Chara() end)
    if chara then
        local wj = nil
        pcall(function() wj = sdk.to_int64(chara.WeaponJob) end)
        if type(wj) == "number" and wj >= 1 and wj <= 9 then return wj, "Chara.WeaponJob" end
    end
    -- fallback: the current Arisen weapon, from the equipment data
    local found = nil
    pcall(function()
        local im = sdk.get_managed_singleton("app.ItemManager")
        local eq = im and im:getEquipData(ply:get_CharaID())
        if not eq then return end
        local data = eq:get_field("Data")
        local idx = data and data:get_field("<CurrentArisenWeaponIndex>k__BackingField")
        local list = eq:get_ArisenWeaponList()
        if type(idx) ~= "number" or not list then return end
        for i = 0, list:get_size() - 1 do
            local e = list:get_element(i)
            for k = 1, 2 do
                local w = (k == 1) and e.Main or e.Sub
                if w then
                    local ep, wp = w:call("get_EquipParam()"), w:call("get_WeaponParam()")
                    if ep and wp then
                        if w:call("get_ArisenEquipNo()") == idx + 1 then found = tonumber(ep:call("getJob()")) end
                        break
                    end
                end
            end
            if found then return end
        end
    end)
    if found and found >= 1 and found <= 9 then return found, "EquipData" end
    return nil, "unknown"
end

-- Effective vocation: the player's vocation or, for the Warfarer, the weapon's vocation
local function read_job()
    local cm = sdk.get_managed_singleton("app.CharacterManager")
    local ply = Call(cm, "get_ManualPlayer")
    local hum = Call(ply, "get_Human")
    local ctx = Call(hum, "get_JobContext") or Get(hum, "<JobContext>k__BackingField")
    local job = Get(ctx, "CurrentJob")
    if job == nil then job = Call(ctx, "get_CurrentJob") end
    S.cur_job = (type(job) == "number") and job or nil
    S.weapon_job, S.wf_diag = nil, "-"
    if S.cur_job == WARFARER and CFG.warfarer_uses_weapon then
        local wj, how = read_weapon_job(ply, hum)
        S.weapon_job, S.wf_diag = wj, how
        return wj
    end
    return S.cur_job
end

------------------------------------------------------------------------
-- Localized control names (same source Custom Keybinds uses for its list)
------------------------------------------------------------------------
local function build_friendly_names()
    local map = {}
    pcall(function()
        local uim = sdk.get_managed_singleton("app.UserInputManager")
        local kbc = Call(uim, "get_KeyBindController")
        local tbl = Call(kbc, "getCurrentKeyBindSettingTable")
        local td = sdk.find_type_definition("via.gui.message")
        local get_message = td and td:get_method("get")
        if not tbl or not get_message then return end
        for hash in sdk_iter(Call(tbl, "get_Keys")) do
            local kb = Call(tbl, "get_Item", hash)
            local cmd = Call(kb, "get_CharacterCommand")
            local msg_id = Call(kb, "get_FunctionMsgId")
            if type(cmd) == "number" and cmd ~= 0 and msg_id ~= nil and not map[cmd] then
                local ok, text = pcall(function() return get_message(nil, msg_id) end)
                if ok and type(text) == "string" and #text > 0 then map[cmd] = text end
            end
        end
    end)
    return map
end

local function friendly(action_id)
    if S.friendly == nil and (S.frame - S.friendly_try) > 300 then
        S.friendly_try = S.frame
        local m = build_friendly_names()
        if next(m) ~= nil then S.friendly = m end
    end
    return S.friendly and S.friendly[action_id] or nil
end

------------------------------------------------------------------------
-- Binding table access
------------------------------------------------------------------------
local function get_assign_list()
    local manager = sdk.get_managed_singleton("app.UserInputManager")
    local assign = manager and Call(manager, "getCurrentCharacterPadAssign")
    return Get(assign, "AssignList")
end

-- fn(item, key, write_back_index_or_nil)
local function each_entry(list, fn)
    local count = Call(list, "get_Count")
    if type(count) == "number" then
        for i = 0, count - 1 do
            local item = Call(list, "get_Item", i)
            if item then fn(item, i, i) end
        end
        return
    end
    local ok, elements = pcall(function() return list:get_elements() end)
    if ok and elements then
        local j = 0
        for _, item in pairs(elements) do
            if item then fn(item, j, nil) end
            j = j + 1
        end
    end
end

local function capture_baseline(list)
    local b = {}
    local occ = {}
    each_entry(list, function(item, key)
        local a, btn = Get(item, "Action"), Get(item, "Button")
        if type(a) == "number" and type(btn) == "number" then
            occ[a] = (occ[a] or 0) + 1       -- some actions have several entries (e.g. Dash, SkillAdditional)
            b[key] = { action = a, button = btn, pre = Get(item, "PreInput"), occ = occ[a] }
        end
    end)
    for _, e in pairs(b) do e.total = occ[e.action] end
    if next(b) == nil then S.baseline = nil; return end
    S.baseline, S.list_addr = b, address_of(list)
end

-- The game rebuilds the table when the controls are changed in its own menu:
-- a new table means a new baseline (it holds the player's own bindings again).
local function ensure_baseline(list)
    if S.baseline == nil or address_of(list) ~= S.list_addr then
        capture_baseline(list)
        return true
    end
    return false
end

-- Baseline entry of a linked control (first matching action)
local function group_baseline(group)
    if not S.baseline then return nil end
    local ids = {}
    for _, an in ipairs(group.actions) do
        if ACTION_ID[an] then ids[ACTION_ID[an]] = true end
    end
    for _, b in pairs(S.baseline) do
        if ids[b.action] then return b end
    end
    return nil
end

-- The game default of a table entry: built-in layout, else the value captured on the first run,
-- else whatever the table held when it was last read.
local function resolve_default(b)
    local an = ACTION_NAME[b.action]
    local key = an and (((b.total or 1) > 1) and (an .. "#" .. b.occ) or an)
    local d = key and (DEFAULTS[key] or CFG.extra_defaults[key])
    if d then
        local btn = d.button
        if type(btn) == "string" then btn = PAD_BTN[btn] end
        local pre = d.pre
        if type(pre) == "string" then pre = ACTION_ID[pre] end
        if btn then return { button = btn, pre = (pre ~= nil) and pre or b.pre } end
    end
    return b
end

-- Remembers (once, saved in config.json) the defaults of controls that have no built-in one
local function ensure_extras()
    if CFG.extra_captured or not S.baseline then return end
    local ex = {}
    for _, b in pairs(S.baseline) do
        local an = ACTION_NAME[b.action]
        if an and an ~= "None" then
            local key = ((b.total or 1) > 1) and (an .. "#" .. b.occ) or an
            if not DEFAULTS[key] then
                ex[key] = { button = PAD_NAME[b.button] or b.button,
                            pre = (b.pre ~= nil) and (ACTION_NAME[b.pre] or b.pre) or nil }
            end
        end
    end
    CFG.extra_defaults = ex
    CFG.extra_captured = true
    S.save_pending = true
end

-- Rows shown in the menu: linked controls first, then every other action in the table
local function build_rows()
    local groups, others = {}, {}
    local in_group = {}
    for _, g in ipairs(all_groups()) do
        local known = false
        for _, an in ipairs(g.actions) do
            in_group[an] = true
            if ACTION_ID[an] then known = true end
        end
        if known then
            local b = group_baseline(g)
            groups[#groups + 1] = { key = g.name, label = g.name, base = b and resolve_default(b) }
        end
    end
    for _, b in pairs(S.baseline or {}) do
        local an = ACTION_NAME[b.action]
        if an and an ~= "None" and not in_group[an] then
            local multi = (b.total or 1) > 1
            local fr = friendly(b.action)
            local label = fr and (fr .. " (" .. an .. ")") or an
            if multi then label = label .. " #" .. b.occ end
            others[#others + 1] = { key = multi and (an .. "#" .. b.occ) or an, label = label, base = resolve_default(b) }
        end
    end
    table.sort(others, function(x, y) return x.label:lower() < y.label:lower() end)
    return groups, others
end

local function row_editable(row)
    return row.base ~= nil and BUTTON_BY_NAME[PAD_NAME[row.base.button] or ""] ~= nil
end

-- preset -> { act = { [action id] = t }, ent = { ["action id:occurrence"] = t } }, plus action names
-- unknown to this game version. t = { button = id|nil, pre = id|nil }
local function build_target(preset)
    local target = { act = {}, ent = {} }
    local unknown = {}
    if not preset then return target, unknown end
    local function make(b)
        return { button = b.button and PAD_BTN[b.button], pre = b.pre and ACTION_ID[b.pre] }
    end
    local is_group = {}
    for _, g in ipairs(all_groups()) do
        is_group[g.name] = true
        local b = norm_binding(preset.bindings[g.name])
        if b then
            local t = make(b)
            if t.button or t.pre then
                for _, an in ipairs(g.actions) do
                    local aid = ACTION_ID[an]
                    if aid then target.act[aid] = t else unknown[#unknown + 1] = an end
                end
            end
        end
    end
    for key, v in pairs(preset.bindings) do
        if not is_group[key] then
            local b = norm_binding(v)
            local name, occ = tostring(key):match("^(.-)#(%d+)$")
            local aid = ACTION_ID[name or key]
            if b and aid then
                local t = make(b)
                if t.button or t.pre then
                    if occ then target.ent[tostring(aid) .. ":" .. occ] = t else target.act[aid] = t end
                end
            end
        end
    end
    return target, unknown
end

-- Writes target on top of the baseline. Returns the number of entries changed, or nil + reason.
local function apply_target(target)
    local list = get_assign_list()
    if not list then return nil, "pad assign not found (is a game loaded?)" end
    ensure_baseline(list)
    if not S.baseline then return nil, "binding table is empty" end
    local patched = 0
    local occ = {}
    local act, ent = target.act or {}, target.ent or {}
    each_entry(list, function(item, key, wb)
        local aid = Get(item, "Action")
        if aid == nil then return end
        occ[aid] = (occ[aid] or 0) + 1
        local t = ent[tostring(aid) .. ":" .. occ[aid]] or act[aid]
        local b0 = S.baseline[key]
        if b0 and b0.action ~= aid then b0 = nil end          -- table changed under us: ignore baseline
        local d = b0 and resolve_default(b0)
        local want_btn = (t and t.button) or (d and d.button)
        local want_pre = (t and t.pre) or (d and d.pre)
        local changed = false
        if want_btn and Get(item, "Button") ~= want_btn then
            if Set(item, "Button", want_btn) then changed = true end
        end
        if want_pre ~= nil and Get(item, "PreInput") ~= want_pre then
            if Set(item, "PreInput", want_pre) then changed = true end
        end
        if changed then
            if wb then Call(list, "set_Item", wb, item) end   -- write back (items may be copies)
            patched = patched + 1
        end
    end)
    return patched
end

local function apply_for_job(job)
    local preset = CFG.enabled and active_preset(job) or nil
    local target, unknown = build_target(preset)
    local n, note = apply_target(target)
    if n == nil then
        S.msg = "Could not apply: " .. tostring(note)
        return false
    end
    local who = JOB_NAMES[job] or tostring(job)
    if preset then
        S.msg = string.format("%s: preset applied (%d entries changed).", who, n)
    else
        S.msg = string.format("%s: no preset, game bindings restored (%d entries changed).", who, n)
    end
    if #unknown > 0 then S.msg = S.msg .. " Unknown actions: " .. table.concat(unknown, ", ") end
    return true
end

------------------------------------------------------------------------
-- Main loop
------------------------------------------------------------------------
local function tick()
    local list = get_assign_list()
    if list then
        -- the game rebuilt the table (e.g. controls changed in its menu): our preset is gone, re-apply it
        if S.baseline and S.applied_job ~= nil and address_of(list) ~= S.list_addr then S.applied_job = nil end
        ensure_baseline(list)                                 -- map of the live table
        ensure_extras()                                       -- once: defaults of controls without a built-in one
    end

    if S.save_pending then
        S.save_pending = false
        save_config()
    end

    local job = read_job()
    S.job = job
    if job == nil then S.seen_job = nil; return end          -- loading / no player: do nothing
    if job ~= S.seen_job then S.seen_job, S.seen_since = job, S.frame end
    if not CFG.enabled then return end
    if (S.frame - S.seen_since) < CFG.settle_frames then return end   -- wait for the switch to settle

    if S.dirty or (CFG.auto_apply and S.applied_job ~= job) then
        if S.frame - S.last_try >= 30 then                    -- throttle retries
            S.last_try = S.frame
            if apply_for_job(job) then
                S.applied_job = job
                S.dirty = false
            end
        end
    end
end

re.on_frame(function()
    S.frame = S.frame + 1
    if S.frame % 10 ~= 0 then return end
    local ok, err = pcall(tick)
    S.err = (not ok) and tostring(err) or nil
end)

-- Leave the player's own bindings in place when the script is reloaded
re.on_script_reset(function()
    pcall(function()
        if S.baseline then apply_target({}) end
    end)
end)

------------------------------------------------------------------------
-- UI
------------------------------------------------------------------------
local function touch()
    S.dirty = true
    S.save_pending = true
end

local function set_binding(p, key, field, value)
    local b = norm_binding(p.bindings[key]) or {}
    b[field] = value
    if b.button == nil and b.pre == nil then p.bindings[key] = nil else p.bindings[key] = b end
end

local function draw_row(p, row)
    imgui.push_id("row-" .. row.key)
    if not row.base then
        imgui.text(row.label .. ": not found in this game's binding table")
    elseif not row_editable(row) then
        imgui.text(string.format("%s: %s (not remappable)", row.label, button_label_of_id(row.base.button)))
    else
        local b = norm_binding(p.bindings[row.key]) or {}
        local items = { "(game default: " .. button_label_of_id(row.base.button) .. ")" }
        for _, bt in ipairs(BUTTONS) do items[#items + 1] = bt.label end
        local cur = 1
        for i, bt in ipairs(BUTTONS) do if bt.name == b.button then cur = i + 1 end end
        local c, idx = imgui.combo(row.label, cur, items)
        if c then
            set_binding(p, row.key, "button", (idx > 1) and BUTTONS[idx - 1].name or nil)
            touch()
        end
        if S.show_mod then
            imgui.same_line()
            local mitems = { "(game default: " .. pre_label(row.base.pre) .. ")", "none", "Shift (Switch Weapon Skill button)" }
            local mc, midx = imgui.combo("modifier", mod_index(b.pre), mitems)
            if mc then
                set_binding(p, row.key, "pre", mod_from_index(midx))
                touch()
            end
        end
    end
    imgui.pop_id()
end

-- Lists controls the preset moved onto a button/modifier already used by another control
local function draw_conflicts(p, groups, others)
    local all, by_sig = {}, {}
    for _, r in ipairs(groups) do all[#all + 1] = r end
    for _, r in ipairs(others) do all[#all + 1] = r end
    local eff = {}
    for _, r in ipairs(all) do
        if row_editable(r) then
            local b = norm_binding(p.bindings[r.key]) or {}
            local btn = b.button or PAD_NAME[r.base.button]
            local pre = b.pre or pre_name(r.base.pre)
            local sig = tostring(btn) .. "|" .. tostring(pre)
            eff[r.key] = { sig = sig, changed = (b.button ~= nil or b.pre ~= nil), row = r }
            by_sig[sig] = by_sig[sig] or {}
            table.insert(by_sig[sig], r.label)
        end
    end
    local shown = 0
    for _, e in pairs(eff) do
        if e.changed and #by_sig[e.sig] > 1 and shown < 8 then
            shown = shown + 1
            imgui.text(string.format("[!] %s shares its button with: %s", e.row.label, table.concat(by_sig[e.sig], ", ")))
        end
    end
end

local function draw_preset_editor()
    local p = ensure_preset(S.edit_job)
    local changed, v

    changed, v = imgui.checkbox("Use a preset for this vocation", p.enabled)
    if changed then p.enabled = v; touch() end
    changed, v = imgui.checkbox("Show modifier (Shift) options", S.show_mod)
    if changed then S.show_mod = v end

    if not S.baseline then
        imgui.text("Waiting for the game's binding table (load a save first)...")
        return
    end

    local groups, others = build_rows()

    if imgui.button("Fill with game defaults") then
        for _, r in ipairs(groups) do
            if row_editable(r) then set_binding(p, r.key, "button", PAD_NAME[r.base.button]) end
        end
        for _, r in ipairs(others) do
            if row_editable(r) then set_binding(p, r.key, "button", PAD_NAME[r.base.button]) end
        end
        touch()
    end
    imgui.same_line()
    if imgui.button("Clear preset") then
        p.bindings = {}
        touch()
    end

    if p.enabled then draw_conflicts(p, groups, others) end

    imgui.spacing()
    for _, r in ipairs(groups) do draw_row(p, r) end

    if imgui.tree_node("All other controls (" .. #others .. ")") then
        for _, r in ipairs(others) do draw_row(p, r) end
        imgui.tree_pop()
    end
end

re.on_draw_ui(function()
    if not imgui.tree_node(NAME .. " v" .. VERSION) then return end

    local changed, v
    changed, v = imgui.checkbox("Enabled", CFG.enabled)
    if changed then
        CFG.enabled = v
        if v then S.dirty = true else pcall(apply_target, {}); S.applied_job = nil end
        S.save_pending = true
    end
    changed, v = imgui.checkbox("Apply automatically when the vocation changes", CFG.auto_apply)
    if changed then CFG.auto_apply = v; S.save_pending = true end
    changed, v = imgui.checkbox("Warfarer follows the weapon's vocation", CFG.warfarer_uses_weapon)
    if changed then CFG.warfarer_uses_weapon = v; S.applied_job = nil; S.save_pending = true end
    changed, v = imgui.slider_int("Settle frames", CFG.settle_frames, 0, 120)
    if changed then CFG.settle_frames = v; S.save_pending = true end

    imgui.spacing()
    imgui.text(string.format("Current vocation: %s%s",
        S.job and (JOB_NAMES[S.job] or tostring(S.job)) or "unknown",
        (S.cur_job == WARFARER and CFG.warfarer_uses_weapon) and " (Warfarer, by weapon)" or ""))
    if S.msg ~= "" then imgui.text(S.msg) end
    if S.err then imgui.text("Error: " .. S.err) end

    imgui.spacing()
    if imgui.tree_node("Presets") then
        local c, idx = imgui.combo("Vocation to edit", S.edit_job, JOB_LIST)
        if c then S.edit_job = idx end
        draw_preset_editor()
        imgui.tree_pop()
    end

    imgui.spacing()
    if imgui.button("Apply now") then S.dirty = true; S.last_try = -1000 end
    imgui.same_line()
    if imgui.button("Restore game defaults") then
        local n = apply_target({})
        S.applied_job = S.job            -- do not re-apply until the vocation changes
        S.msg = n and string.format("Game bindings restored (%d entries changed).", n) or "Could not restore."
    end
    imgui.same_line()
    if imgui.button("Save settings") then
        S.msg = save_config() and "Settings saved." or "Could not save settings."
    end

    imgui.text("Controls with a built-in default always return to it. Use the button below only after changing,")
    imgui.text("in the game's menu, controls that have no built-in default (and with no preset active).")
    if imgui.button("Recapture other defaults") then
        local list = get_assign_list()
        if list then
            capture_baseline(list)
            CFG.extra_captured = false
            ensure_extras()
            S.applied_job = nil
            S.msg = "Other defaults recaptured."
        end
    end

    if imgui.tree_node("Live bindings (debug)") then
        local list = get_assign_list()
        if list then
            each_entry(list, function(item, key)
                imgui.text(string.format("%s = %s + %s",
                    tostring(ACTION_NAME[Get(item, "Action")] or "?"),
                    pre_label(Get(item, "PreInput")),
                    tostring(PAD_NAME[Get(item, "Button")] or Get(item, "Button") or "?")))
            end)
        else
            imgui.text("pad assign not found")
        end
        imgui.tree_pop()
    end

    imgui.tree_pop()
end)
