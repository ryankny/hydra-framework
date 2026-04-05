--[[
    Hydra Players - Job System

    Manages player jobs, grades, and the job registry.
]]

Hydra = Hydra or {}
Hydra.Players = Hydra.Players or {}

local jobs = {}
local usableItems = {}

--- Initialize jobs from config
function Hydra.Players.InitJobs()
    jobs = HydraPlayersConfig.jobs or {}
    Hydra.Utils.Log('debug', 'Loaded %d jobs', Hydra.Utils.Keys(jobs) and #Hydra.Utils.Keys(jobs) or 0)
end

--- Get all registered jobs
--- @return table
function Hydra.Players.GetJobs()
    return jobs
end

--- Get a specific job definition
--- @param jobName string
--- @return table|nil
function Hydra.Players.GetJobDef(jobName)
    return jobs[jobName]
end

--- Register a new job (or update existing)
--- @param name string
--- @param data table { label, grades }
function Hydra.Players.RegisterJob(name, data)
    jobs[name] = data
    Hydra.Utils.Log('debug', 'Job registered: %s', name)
end

--- Get player's current job
--- @param source number
--- @return table
function Hydra.Players.GetJob(source)
    local player = Hydra.Players.GetPlayer(source)
    if not player then
        return { name = 'unemployed', label = 'Unemployed', grade = 0, grade_name = 'Unemployed', grade_label = 'Unemployed' }
    end
    return player.job or { name = 'unemployed', label = 'Unemployed', grade = 0 }
end

--- Set player's job
--- @param source number
--- @param jobName string
--- @param grade number|nil
--- @return boolean success
function Hydra.Players.SetJob(source, jobName, grade)
    local player = Hydra.Players.GetPlayer(source)
    if not player then return false end

    local jobDef = jobs[jobName]
    if not jobDef then
        Hydra.Utils.Log('warn', 'Attempted to set unknown job: %s', jobName)
        return false
    end

    grade = tonumber(grade) or 0
    local gradeDef = jobDef.grades and jobDef.grades[grade]

    player.job = {
        name = jobName,
        label = jobDef.label or jobName,
        grade = grade,
        grade_name = gradeDef and gradeDef.name or 'Unknown',
        grade_label = gradeDef and gradeDef.label or 'Unknown',
        salary = gradeDef and gradeDef.salary or 0,
    }

    TriggerClientEvent('hydra:store:sync', source, 'playerData', 'job', player.job)
    TriggerEvent('hydra:players:jobChanged', source, player.job)

    -- Bridge compatibility events
    TriggerClientEvent('esx:setJob', source, player.job)
    TriggerClientEvent('QBCore:Client:OnJobUpdate', source, player.job)

    Hydra.Utils.Log('debug', 'Player %d job set to: %s (grade %d)', source, jobName, grade)
    return true
end

--- Get player group/permission level
--- @param source number
--- @return string
function Hydra.Players.GetGroup(source)
    local player = Hydra.Players.GetPlayer(source)
    return player and player.group or 'user'
end

--- Set player group
--- @param source number
--- @param group string
function Hydra.Players.SetGroup(source, group)
    local player = Hydra.Players.GetPlayer(source)
    if not player then return end

    player.group = group
    TriggerClientEvent('hydra:store:sync', source, 'playerData', 'group', group)
    TriggerEvent('hydra:players:groupChanged', source, group)
end

--- Register a usable item
--- @param itemName string
--- @param callback function(source)
function Hydra.Players.RegisterUsableItem(itemName, callback)
    usableItems[itemName] = callback
end

--- Use an item
--- @param source number
--- @param itemName string
function Hydra.Players.UseItem(source, itemName, ...)
    local cb = usableItems[itemName]
    if cb then
        cb(source, ...)
    end
end
