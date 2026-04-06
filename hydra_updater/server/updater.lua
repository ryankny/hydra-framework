--[[
    Hydra Framework - Auto-Updater

    Checks GitHub for updates and optionally auto-pulls via git.
    Server owners configure behavior in config/config.lua.
]]

local config = nil
local resourcePath = GetResourcePath(GetCurrentResourceName())
local hydraPath = resourcePath:match('(.+)[/\\][^/\\]+$') -- parent directory ([hydra] folder)
local currentVersion = GetResourceMetadata('hydra_core', 'version', 0) or '0.0.0'

local COLORS = {
    reset  = '^7',
    red    = '^1',
    green  = '^2',
    yellow = '^3',
    blue   = '^4',
    cyan   = '^5',
    white  = '^7',
}

--- Load config from file
local function LoadConfig()
    local raw = LoadResourceFile(GetCurrentResourceName(), 'config/config.lua')
    if raw then
        local fn, err = load(raw)
        if fn then
            config = fn()
        else
            print(COLORS.red .. '[Hydra Updater] Failed to parse config: ' .. tostring(err) .. COLORS.reset)
            config = { mode = 'notify', check_on_start = true, repository = 'ryankny/hydra-framework', branch = 'master', check_interval = 60, show_banner = true }
        end
    end
end

--- Print the updater banner
local function PrintBanner()
    print(COLORS.cyan .. '┌─────────────────────────────────────────┐' .. COLORS.reset)
    print(COLORS.cyan .. '│       Hydra Framework Updater           │' .. COLORS.reset)
    print(COLORS.cyan .. '│       Mode: ' .. string.format('%-28s', config.mode) .. '│' .. COLORS.reset)
    print(COLORS.cyan .. '│       Version: ' .. string.format('%-25s', currentVersion) .. '│' .. COLORS.reset)
    print(COLORS.cyan .. '└─────────────────────────────────────────┘' .. COLORS.reset)
end

--- Get local HEAD commit hash via git
--- @return string|nil hash
local function GetLocalCommit()
    local handle = io.popen('git -C "' .. hydraPath .. '" rev-parse HEAD 2>/dev/null')
    if not handle then return nil end
    local result = handle:read('*l')
    handle:close()
    if result and #result == 40 then
        return result
    end
    return nil
end

--- Check if the hydra path is a git repo
--- @return boolean
local function IsGitRepo()
    local handle = io.popen('git -C "' .. hydraPath .. '" rev-parse --is-inside-work-tree 2>/dev/null')
    if not handle then return false end
    local result = handle:read('*l')
    handle:close()
    return result == 'true'
end

--- Fetch latest remote commit hash from GitHub API
--- @param cb function(remoteHash, commitMessage, commitDate)
local function FetchRemoteCommit(cb)
    local url = ('https://api.github.com/repos/%s/commits/%s'):format(config.repository, config.branch)

    PerformHttpRequest(url, function(status, body)
        if status ~= 200 then
            print(COLORS.red .. '[Hydra Updater] Failed to check for updates (HTTP ' .. tostring(status) .. ')' .. COLORS.reset)
            cb(nil)
            return
        end

        local data = json.decode(body)
        if not data or not data.sha then
            print(COLORS.red .. '[Hydra Updater] Invalid response from GitHub API' .. COLORS.reset)
            cb(nil)
            return
        end

        local message = data.commit and data.commit.message or 'No message'
        local date = data.commit and data.commit.committer and data.commit.committer.date or 'Unknown'

        cb(data.sha, message:match('[^\n]+'), date)
    end, 'GET', '', {
        ['User-Agent'] = 'HydraFramework/' .. currentVersion,
        ['Accept'] = 'application/vnd.github.v3+json',
    })
end

--- Perform git pull
--- @return boolean success, string output
local function GitPull()
    -- Fetch first to make sure remote refs are current
    local fetchHandle = io.popen('git -C "' .. hydraPath .. '" fetch origin ' .. config.branch .. ' 2>&1')
    if fetchHandle then
        fetchHandle:read('*a')
        fetchHandle:close()
    end

    local handle = io.popen('git -C "' .. hydraPath .. '" pull origin ' .. config.branch .. ' 2>&1')
    if not handle then
        return false, 'Failed to execute git pull'
    end

    local output = handle:read('*a')
    local _, _, exitCode = handle:close()

    local success = exitCode == 0 or output:match('Already up to date') ~= nil
    return success, output:gsub('%s+$', '')
end

--- Main update check
local function CheckForUpdates()
    if config.mode == 'off' then return end

    if not IsGitRepo() then
        print(COLORS.yellow .. '[Hydra Updater] Resources directory is not a git repo. Auto-update requires git clone installation.' .. COLORS.reset)
        print(COLORS.yellow .. '[Hydra Updater] To enable: cd into your resources/[hydra] folder and run: git clone https://github.com/' .. config.repository .. ' .' .. COLORS.reset)
        return
    end

    local localHash = GetLocalCommit()
    if not localHash then
        print(COLORS.red .. '[Hydra Updater] Could not read local git commit' .. COLORS.reset)
        return
    end

    print(COLORS.blue .. '[Hydra Updater] Checking for updates...' .. COLORS.reset)

    FetchRemoteCommit(function(remoteHash, commitMessage, commitDate)
        if not remoteHash then return end

        if localHash == remoteHash then
            print(COLORS.green .. '[Hydra Updater] Framework is up to date (' .. localHash:sub(1, 7) .. ')' .. COLORS.reset)
            return
        end

        print(COLORS.yellow .. '┌─────────────────────────────────────────┐' .. COLORS.reset)
        print(COLORS.yellow .. '│         UPDATE AVAILABLE                │' .. COLORS.reset)
        print(COLORS.yellow .. '├─────────────────────────────────────────┤' .. COLORS.reset)
        print(COLORS.yellow .. '│  Local:  ' .. string.format('%-31s', localHash:sub(1, 7)) .. '│' .. COLORS.reset)
        print(COLORS.yellow .. '│  Remote: ' .. string.format('%-31s', remoteHash:sub(1, 7)) .. '│' .. COLORS.reset)
        print(COLORS.yellow .. '│  Commit: ' .. string.format('%-31s', commitMessage:sub(1, 31)) .. '│' .. COLORS.reset)
        print(COLORS.yellow .. '│  Date:   ' .. string.format('%-31s', commitDate:sub(1, 31)) .. '│' .. COLORS.reset)
        print(COLORS.yellow .. '└─────────────────────────────────────────┘' .. COLORS.reset)

        if config.mode == 'auto' then
            print(COLORS.blue .. '[Hydra Updater] Auto-updating...' .. COLORS.reset)

            local success, output = GitPull()

            if success then
                print(COLORS.green .. '[Hydra Updater] Update successful! Restart the server to apply changes.' .. COLORS.reset)
                print(COLORS.green .. '[Hydra Updater] ' .. output .. COLORS.reset)

                -- Notify online admins
                for _, playerId in ipairs(GetPlayers()) do
                    if IsPlayerAceAllowed(playerId, 'hydra.admin') then
                        TriggerClientEvent('chat:addMessage', tonumber(playerId), {
                            template = '<div style="padding: 4px 8px; background: #1a5c2a; border-radius: 4px;">[Hydra] Framework updated. Server restart recommended.</div>',
                        })
                    end
                end
            else
                print(COLORS.red .. '[Hydra Updater] Update failed:' .. COLORS.reset)
                print(COLORS.red .. output .. COLORS.reset)
                print(COLORS.yellow .. '[Hydra Updater] Try manually: cd resources/[hydra] && git pull' .. COLORS.reset)
            end
        else
            print(COLORS.yellow .. '[Hydra Updater] Run "git pull" in your resources/[hydra] folder to update.' .. COLORS.reset)
            print(COLORS.yellow .. '[Hydra Updater] Or set mode = "auto" in hydra_updater/config/config.lua' .. COLORS.reset)

            -- Notify online admins
            for _, playerId in ipairs(GetPlayers()) do
                if IsPlayerAceAllowed(playerId, 'hydra.admin') then
                    TriggerClientEvent('chat:addMessage', tonumber(playerId), {
                        template = '<div style="padding: 4px 8px; background: #5c4b1a; border-radius: 4px;">[Hydra] Framework update available (' .. remoteHash:sub(1, 7) .. '). Restart after updating.</div>',
                    })
                end
            end
        end
    end)
end

--- Register admin command to manually check/pull
RegisterCommand('hydra_update', function(source, args)
    if source > 0 and not IsPlayerAceAllowed(tostring(source), 'hydra.admin') then
        return
    end

    local subcommand = args[1]

    if subcommand == 'check' then
        CheckForUpdates()
    elseif subcommand == 'pull' then
        if not IsGitRepo() then
            print(COLORS.red .. '[Hydra Updater] Not a git repo' .. COLORS.reset)
            return
        end
        local success, output = GitPull()
        if success then
            print(COLORS.green .. '[Hydra Updater] ' .. output .. COLORS.reset)
            print(COLORS.green .. '[Hydra Updater] Restart the server to apply changes.' .. COLORS.reset)
        else
            print(COLORS.red .. '[Hydra Updater] ' .. output .. COLORS.reset)
        end
    elseif subcommand == 'status' then
        print(COLORS.cyan .. '[Hydra Updater] Mode: ' .. config.mode .. COLORS.reset)
        print(COLORS.cyan .. '[Hydra Updater] Repo: ' .. config.repository .. COLORS.reset)
        print(COLORS.cyan .. '[Hydra Updater] Branch: ' .. config.branch .. COLORS.reset)
        print(COLORS.cyan .. '[Hydra Updater] Git: ' .. (IsGitRepo() and 'yes' or 'no') .. COLORS.reset)
        local hash = GetLocalCommit()
        if hash then
            print(COLORS.cyan .. '[Hydra Updater] Local commit: ' .. hash:sub(1, 7) .. COLORS.reset)
        end
    else
        print(COLORS.white .. 'Usage: hydra_update <check|pull|status>' .. COLORS.reset)
    end
end, true) -- restricted

--- Startup
CreateThread(function()
    LoadConfig()

    if config.show_banner then
        PrintBanner()
    end

    if config.check_on_start then
        Wait(5000) -- let the server finish booting
        CheckForUpdates()
    end

    -- Periodic check
    if config.mode == 'notify' and config.check_interval and config.check_interval > 0 then
        local interval = config.check_interval * 60 * 1000
        while true do
            Wait(interval)
            CheckForUpdates()
        end
    end
end)
