--[[
    Hydra Emotes - Client

    Animation and emote system with scenario support, prop
    emotes, cancel-on-move, and integration with hydra_context
    for the emote menu. Uses hydra_anims as animation backend.
    Developers can register emotes at runtime.
]]

Hydra = Hydra or {}
Hydra.Emotes = {}

local cfg = HydraEmotesConfig

-- Runtime emote registry (config + dynamically added)
local emotes = {}
local isPlaying = false
local currentEmote = nil
local currentAnimId = nil
local hasAnims = false

-- Detect hydra_anims availability
CreateThread(function()
    Wait(1000)
    hasAnims = pcall(function() return exports['hydra_anims'] end)
end)

-- Initialize from config
for name, def in pairs(cfg.emotes) do
    emotes[name] = def
end

-- =============================================
-- EMOTE API
-- =============================================

--- Register a new emote at runtime
--- @param name string unique identifier
--- @param def table emote definition (same format as config)
function Hydra.Emotes.Register(name, def)
    emotes[name] = def
end

--- Unregister an emote
--- @param name string
function Hydra.Emotes.Unregister(name)
    emotes[name] = nil
end

--- Play an emote by name
--- @param name string
function Hydra.Emotes.Play(name)
    local emote = emotes[name]
    if not emote then
        TriggerEvent('hydra:notify:show', {
            type = 'error', title = 'Emote',
            message = ('Unknown emote: %s'):format(name),
            duration = 3000,
        })
        return
    end

    local ped = PlayerPedId()

    -- Vehicle check
    if IsPedInAnyVehicle(ped, false) and not cfg.allow_in_vehicle then
        TriggerEvent('hydra:notify:show', {
            type = 'error', title = 'Emote',
            message = 'Cannot use emotes in a vehicle.',
            duration = 2000,
        })
        return
    end

    -- Cancel current if playing
    if isPlaying then
        Hydra.Emotes.Cancel(true)
        Wait(100)
    end

    isPlaying = true
    currentEmote = { name = name, def = emote }

    if emote.type == 'anim' then
        playAnimation(ped, emote)
    elseif emote.type == 'scenario' then
        playScenario(ped, emote)
    end
end

--- Cancel the current emote
--- @param silent boolean|nil skip notification
function Hydra.Emotes.Cancel(silent)
    if not isPlaying then return end

    local ped = PlayerPedId()

    -- Use hydra_anims if available for clean stop
    if hasAnims and currentAnimId then
        pcall(function() exports['hydra_anims']:Stop(ped, currentAnimId) end)
    else
        ClearPedTasks(ped)
        ClearPedSecondaryTask(ped)
    end

    isPlaying = false
    currentEmote = nil
    currentAnimId = nil

    if not silent then
        TriggerEvent('hydra:notify:show', {
            type = 'info', title = 'Emote',
            message = 'Emote cancelled.',
            duration = 1500,
        })
    end
end

--- Check if an emote is currently playing
--- @return boolean
function Hydra.Emotes.IsPlaying()
    return isPlaying
end

--- Get current emote name
--- @return string|nil
function Hydra.Emotes.GetCurrent()
    return currentEmote and currentEmote.name
end

--- Get all registered emotes
--- @return table
function Hydra.Emotes.GetAll()
    return emotes
end

-- =============================================
-- ANIMATION / SCENARIO PLAYBACK (via hydra_anims)
-- =============================================

--- Play an animation emote
--- @param ped number
--- @param emote table
function playAnimation(ped, emote)
    if not emote.dict or not emote.anim then return end

    local flag = emote.flag or 49
    local duration = emote.duration or -1

    if emote.looping then
        flag = emote.flag or 1
        duration = -1
    end

    -- Use hydra_anims if available
    if hasAnims then
        local ok, animId = pcall(function()
            return exports['hydra_anims']:Play(ped, {
                dict = emote.dict,
                anim = emote.anim,
                flag = flag,
                duration = duration,
                label = currentEmote and currentEmote.name or 'emote',
                props = emote.props,
                onEnd = function(_, _, cancelled)
                    if isPlaying and not emote.looping then
                        isPlaying = false
                        currentEmote = nil
                        currentAnimId = nil
                    end
                end,
            })
        end)
        if ok and animId then
            currentAnimId = animId
            return
        end
    end

    -- Fallback: direct native calls
    RequestAnimDict(emote.dict)
    local t = 0
    while not HasAnimDictLoaded(emote.dict) and t < 3000 do
        Wait(10)
        t = t + 10
    end

    if not HasAnimDictLoaded(emote.dict) then
        isPlaying = false
        currentEmote = nil
        return
    end

    TaskPlayAnim(ped, emote.dict, emote.anim, 8.0, -8.0, duration, flag, 0, false, false, false)

    -- Auto-end for non-looping
    if not emote.looping and emote.duration and emote.duration > 0 then
        CreateThread(function()
            Wait(emote.duration)
            if isPlaying and not emote.looping then
                isPlaying = false
                currentEmote = nil
                currentAnimId = nil
            end
        end)
    end
end

--- Play a scenario emote
--- @param ped number
--- @param emote table
function playScenario(ped, emote)
    if not emote.scenario then return end

    -- Use hydra_anims if available
    if hasAnims then
        local ok, animId = pcall(function()
            return exports['hydra_anims']:PlayScenario(ped, emote.scenario, {
                label = currentEmote and currentEmote.name or 'scenario',
                onEnd = function()
                    if isPlaying then
                        isPlaying = false
                        currentEmote = nil
                        currentAnimId = nil
                    end
                end,
            })
        end)
        if ok and animId then
            currentAnimId = animId
            return
        end
    end

    -- Fallback
    TaskStartScenarioInPlace(ped, emote.scenario, 0, true)
end

-- =============================================
-- CANCEL ON MOVEMENT
-- =============================================

if cfg.cancel_on_move then
    CreateThread(function()
        while true do
            Wait(200)
            if isPlaying and currentEmote then
                local ped = PlayerPedId()

                -- Check if player is walking/running
                if IsPedWalking(ped) or IsPedRunning(ped) or IsPedSprinting(ped) then
                    -- Only cancel looping emotes on move (timed ones finish naturally)
                    if currentEmote.def and currentEmote.def.looping then
                        Hydra.Emotes.Cancel(true)
                    end
                end

                -- Cancel if player entered vehicle
                if IsPedInAnyVehicle(ped, false) and not cfg.allow_in_vehicle then
                    Hydra.Emotes.Cancel(true)
                end
            end
        end
    end)
end

-- Cancel keybind
RegisterCommand('+hydra_emote_cancel', function()
    Hydra.Emotes.Cancel()
end, false)
RegisterCommand('-hydra_emote_cancel', function() end, false)
RegisterKeyMapping('+hydra_emote_cancel', cfg.cancel_key_description, 'keyboard', cfg.cancel_key)

-- =============================================
-- COMMAND + MENU
-- =============================================

--- /emote [name] or /e [name]
RegisterCommand(cfg.command, function(_, args)
    if #args == 0 then
        openEmoteMenu()
    else
        Hydra.Emotes.Play(args[1])
    end
end, false)

if cfg.alias and cfg.alias ~= cfg.command then
    RegisterCommand(cfg.alias, function(_, args)
        if #args == 0 then
            openEmoteMenu()
        else
            Hydra.Emotes.Play(args[1])
        end
    end, false)
end

--- Open the emote menu using hydra_context
function openEmoteMenu()
    -- Group emotes by category
    local categories = {}
    for name, emote in pairs(emotes) do
        local cat = emote.category or 'custom'
        if not categories[cat] then categories[cat] = {} end
        categories[cat][#categories[cat] + 1] = { name = name, emote = emote }
    end

    -- Sort categories
    local catOrder = {}
    for cat in pairs(categories) do
        catOrder[#catOrder + 1] = cat
    end
    table.sort(catOrder)

    -- Build context menu items
    if Hydra.Context and Hydra.Context.Show then
        -- Register sub-menus for each category
        for _, cat in ipairs(catOrder) do
            local items = {}
            -- Sort emotes within category
            table.sort(categories[cat], function(a, b) return a.emote.label < b.emote.label end)

            for _, entry in ipairs(categories[cat]) do
                items[#items + 1] = {
                    label = entry.emote.label,
                    description = entry.emote.type == 'scenario' and 'Scenario' or nil,
                    onSelect = function()
                        Hydra.Emotes.Play(entry.name)
                    end,
                }
            end

            Hydra.Context.Register('emote_' .. cat, {
                id = 'emote_' .. cat,
                title = cfg.categories[cat] or cat,
                items = items,
            })
        end

        -- Build main menu
        local mainItems = {}
        for _, cat in ipairs(catOrder) do
            mainItems[#mainItems + 1] = {
                label = cfg.categories[cat] or cat,
                description = ('%d emotes'):format(#categories[cat]),
                icon = nil,
                submenu = 'emote_' .. cat,
            }
        end

        -- Cancel option at top if playing
        if isPlaying then
            table.insert(mainItems, 1, {
                label = 'Cancel Emote',
                icon = nil,
                onSelect = function()
                    Hydra.Emotes.Cancel()
                end,
            })
        end

        Hydra.Context.Show({
            id = 'emote_menu',
            title = 'Emotes',
            items = mainItems,
        })
    else
        -- No context menu - just list emotes in chat
        TriggerEvent('chat:addMessage', {
            color = { 108, 92, 231 },
            args = { 'Hydra Emotes', 'Use /emote [name]. Available emotes:' }
        })
        for name, emote in pairs(emotes) do
            TriggerEvent('chat:addMessage', {
                args = { '', ('  %s - %s'):format(name, emote.label) }
            })
        end
    end
end

-- =============================================
-- EXPORTS
-- =============================================

exports('Play', function(...) Hydra.Emotes.Play(...) end)
exports('Cancel', function(...) Hydra.Emotes.Cancel(...) end)
exports('IsPlaying', function() return Hydra.Emotes.IsPlaying() end)
exports('GetCurrent', function() return Hydra.Emotes.GetCurrent() end)
exports('RegisterEmote', function(...) Hydra.Emotes.Register(...) end)
exports('UnregisterEmote', function(...) Hydra.Emotes.Unregister(...) end)
exports('GetAllEmotes', function() return Hydra.Emotes.GetAll() end)
