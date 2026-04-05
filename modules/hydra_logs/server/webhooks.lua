--[[
    Hydra Logs - Webhook Engine

    Handles Discord webhook delivery with rate limiting,
    batching, retry logic, and embed formatting.
    Uses PerformHttpRequest for non-blocking sends.
]]

Hydra = Hydra or {}
Hydra.Logs = Hydra.Logs or {}
Hydra.Logs._queue = {}

local cfg = HydraLogsConfig
local sendCount = 0
local lastReset = os.time()

-- =============================================
-- QUEUE & BATCHING
-- =============================================

--- Add an embed to the send queue
--- @param url string webhook URL
--- @param embed table Discord embed object
function Hydra.Logs._Enqueue(url, embed)
    if not url or url == '' then return end

    Hydra.Logs._queue[#Hydra.Logs._queue + 1] = {
        url = url,
        embed = embed,
        timestamp = os.time(),
    }
end

--- Process the queue - sends batched embeds per URL
function Hydra.Logs._ProcessQueue()
    if #Hydra.Logs._queue == 0 then return end

    -- Reset rate counter each second
    local now = os.time()
    if now > lastReset then
        sendCount = 0
        lastReset = now
    end

    -- Group by URL
    local byUrl = {}
    local processed = 0

    for i, item in ipairs(Hydra.Logs._queue) do
        if sendCount >= cfg.rate_limit then break end

        local url = item.url
        if not byUrl[url] then byUrl[url] = {} end

        if #byUrl[url] < cfg.max_batch_size then
            byUrl[url][#byUrl[url] + 1] = item.embed
            processed = i
        end
    end

    -- Remove processed items
    if processed > 0 then
        local remaining = {}
        for i = processed + 1, #Hydra.Logs._queue do
            remaining[#remaining + 1] = Hydra.Logs._queue[i]
        end
        Hydra.Logs._queue = remaining
    end

    -- Send each URL batch
    for url, embeds in pairs(byUrl) do
        Hydra.Logs._Send(url, embeds)
        sendCount = sendCount + 1
    end
end

--- Send embeds to a Discord webhook
--- @param url string
--- @param embeds table[] array of embed objects
function Hydra.Logs._Send(url, embeds)
    if not url or url == '' or #embeds == 0 then return end

    local payload = json.encode({
        username = cfg.server_name or 'Hydra Logs',
        avatar_url = cfg.server_icon ~= '' and cfg.server_icon or nil,
        embeds = embeds,
    })

    PerformHttpRequest(url, function(statusCode, response, headers)
        if statusCode == 429 then
            -- Rate limited - re-queue embeds
            for _, embed in ipairs(embeds) do
                Hydra.Logs._Enqueue(url, embed)
            end
        elseif statusCode < 200 or statusCode >= 300 then
            -- Log failure silently (don't spam console)
            if statusCode ~= 204 then
                Hydra.Utils.Log('debug', 'Webhook returned %d for %s', statusCode, url)
            end
        end
    end, 'POST', payload, {
        ['Content-Type'] = 'application/json',
    })
end

-- Queue processing loop
CreateThread(function()
    while true do
        Wait(cfg.batch_interval * 1000)
        if cfg.enabled then
            Hydra.Logs._ProcessQueue()
        end
    end
end)

-- =============================================
-- EMBED BUILDER
-- =============================================

--- Build a Discord embed object
--- @param data table
---   title       string
---   description string
---   color       number
---   fields      table[]|nil  { { name, value, inline } }
---   footer      string|nil
---   thumbnail   string|nil
--- @return table embed
function Hydra.Logs._BuildEmbed(data)
    local embed = {
        title = data.title,
        description = data.description or '',
        color = data.color or 9807270,
        timestamp = cfg.timestamp and os.date('!%Y-%m-%dT%H:%M:%SZ') or nil,
        footer = {
            text = data.footer or cfg.server_name or 'Hydra Framework',
            icon_url = cfg.server_icon ~= '' and cfg.server_icon or nil,
        },
    }

    if data.fields and #data.fields > 0 then
        embed.fields = {}
        for _, field in ipairs(data.fields) do
            embed.fields[#embed.fields + 1] = {
                name = field.name or field[1] or '',
                value = field.value or field[2] or '',
                inline = field.inline ~= nil and field.inline or (field[3] or false),
            }
        end
    end

    if data.thumbnail then
        embed.thumbnail = { url = data.thumbnail }
    end

    return embed
end

--- Get player identifier fields for embeds
--- @param src number
--- @return table[] fields
function Hydra.Logs._GetPlayerFields(src)
    if not cfg.include_identifiers then return {} end

    local fields = {}
    local name = GetPlayerName(src) or 'Unknown'
    fields[#fields + 1] = { name = 'Player', value = ('%s (ID: %d)'):format(name, src), inline = true }

    -- Collect identifiers
    local identifiers = GetPlayerIdentifiers(src)
    local idStr = {}
    for _, id in ipairs(identifiers) do
        if id:find('^license:') then
            idStr[#idStr + 1] = '`' .. id .. '`'
        elseif id:find('^steam:') then
            idStr[#idStr + 1] = '`' .. id .. '`'
        elseif id:find('^discord:') then
            local discordId = id:gsub('discord:', '')
            idStr[#idStr + 1] = '<@' .. discordId .. '>'
        elseif id:find('^fivem:') then
            idStr[#idStr + 1] = '`' .. id .. '`'
        end
    end

    if #idStr > 0 then
        fields[#fields + 1] = { name = 'Identifiers', value = table.concat(idStr, '\n'), inline = false }
    end

    return fields
end
