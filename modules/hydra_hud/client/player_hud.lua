--[[
    Hydra HUD - Player HUD Data Collector

    Collects player vitals (health, armor, hunger, thirst, etc.)
    and sends efficient delta updates to the NUI.
]]

Hydra = Hydra or {}
Hydra.HUD = Hydra.HUD or {}

local lastPlayerData = {}
local playerConfig = {}

--- Collect player HUD data
local function collectPlayerData()
    local ped = PlayerPedId()
    local health = GetEntityHealth(ped) - 100  -- GTA health starts at 100
    local maxHealth = GetEntityMaxHealth(ped) - 100
    local armor = GetPedArmour(ped)
    local oxygen = GetPlayerUnderwaterTimeRemaining(PlayerId()) * 10  -- 0-100 scale

    -- Stamina (sprint ability)
    local stamina = 100.0 - GetPlayerSprintStaminaRemaining(PlayerId())

    -- Check if underwater
    local isUnderwater = IsEntityInWater(ped) and IsPedSwimmingUnderWater(ped)

    -- Get hunger/thirst from player metadata if available
    local hunger = 100
    local thirst = 100
    local playerStore = Hydra.Data and Hydra.Data.Store.GetAll('playerData') or {}
    local metadata = playerStore.metadata or {}
    hunger = metadata.hunger or 100
    thirst = metadata.thirst or 100

    return {
        health = math.max(health, 0),
        maxHealth = math.max(maxHealth, 1),
        armor = armor,
        hunger = hunger,
        thirst = thirst,
        stamina = math.floor(stamina),
        oxygen = math.floor(oxygen),
        isUnderwater = isUnderwater,
        isDead = IsEntityDead(ped),
    }
end

--- Check if data has changed (avoid unnecessary NUI updates)
local function hasChanged(newData, oldData)
    if not oldData then return true end
    for k, v in pairs(newData) do
        if oldData[k] ~= v then return true end
    end
    return false
end

--- Player HUD update loop
CreateThread(function()
    while not Hydra.IsReady() do Wait(200) end

    playerConfig = HydraHUDConfig.player or {}
    if not playerConfig.enabled then return end

    -- Wait for player to be loaded
    while not Hydra.PlayerState or not Hydra.PlayerState.IsLoaded() do Wait(200) end

    -- Send initial cash/bank/job data
    Wait(500)
    local store = Hydra.Data and Hydra.Data.Store.GetAll('playerData') or {}
    Hydra.HUD.Send('playerInit', {
        accounts = store.accounts or {},
        job = store.job or {},
    })

    local updateRate = HydraHUDConfig.update_rate or 100

    while true do
        Wait(updateRate)

        if Hydra.HUD.IsVisible() then
            local data = collectPlayerData()

            if hasChanged(data, lastPlayerData) then
                Hydra.HUD.Send('playerUpdate', data)
                lastPlayerData = data
            end
        end
    end
end)
