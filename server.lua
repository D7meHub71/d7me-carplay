local function canUse(src)
    if Config.CanUse then return Config.CanUse(src) == true end
    return true
end

RegisterNetEvent('d7me-carradio:start', function(netId, url, vol, dist)
    local src = source
    if not canUse(src) then return end
    if type(netId) ~= 'number' or not url or url == '' then return end

    vol  = tonumber(vol)  or (Config.DefaultVolume)
    dist = tonumber(dist) or (Config.DefaultDistance)
    local maxD = Config.MaxDistance or 40.0
    if dist > maxD then dist = maxD end

    TriggerClientEvent('d7me-carradio:client:start', -1, netId, url, vol, dist)
end)

RegisterNetEvent('d7me-carradio:stop', function(netId)
    if type(netId) ~= 'number' then return end
    TriggerClientEvent('d7me-carradio:client:stop', -1, netId)
end)

RegisterNetEvent('d7me-carradio:setvol', function(netId, vol)
    if type(netId) ~= 'number' then return end
    vol = tonumber(vol); if not vol then return end
    TriggerClientEvent('d7me-carradio:client:setvol', -1, netId, vol)
end)

RegisterNetEvent('d7me-carradio:setdist', function(netId, dist)
    if type(netId) ~= 'number' then return end
    dist = tonumber(dist); if not dist then return end
    local maxD = Config.MaxDistance or 40.0
    if dist > maxD then dist = maxD end
    TriggerClientEvent('d7me-carradio:client:setdist', -1, netId, dist)
end)
