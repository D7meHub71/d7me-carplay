local QBCore = exports['qb-core']:GetCoreObject()
local sounds  = {}
local lastUrl = nil

local function playerVeh()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return 0 end
    return GetVehiclePedIsIn(ped, false)
end

local function isPlayerDriverOf(veh)
    return GetPedInVehicleSeat(veh, -1) == PlayerPedId()
end

local function ensureVehAndPerms()
    local veh = playerVeh()
    if veh == 0 then
        QBCore.Functions.Notify('You are not in a vehicle.', 'error')
        return nil
    end
    if Config.DriverOnly and not isPlayerDriverOf(veh) then
        QBCore.Functions.Notify('Only the driver can control the radio.', 'error')
        return nil
    end
    if (Config.CanUse and Config.CanUse() ~= true) then
        QBCore.Functions.Notify('You are not allowed to use the car radio.', 'error')
        return nil
    end
    return veh
end

local function getEntityByNetId(netId)
    local ent = NetworkGetEntityFromNetworkId(netId)
    if ent ~= 0 and DoesEntityExist(ent) and IsEntityAVehicle(ent) then return ent end
    return nil
end

local function playFollow3D(netId, url, vol, dist, veh)
    local id = 'car_radio_'..tostring(netId)
    local s  = sounds[netId]

    if s and exports['xsound']:soundExists(s.id) and s.url == url then
        local newVol  = vol  or s.vol  or (Config.DefaultVolume or 0.35)
        local newDist = dist or s.dist or (Config.DefaultDistance or 25.0)
        s.vol  = newVol
        s.dist = newDist
        exports['xsound']:setVolume(s.id, newVol)
        exports['xsound']:Distance(s.id, newDist)
        return
    end

    if exports['xsound']:soundExists(id) then exports['xsound']:Destroy(id) end

    local c = GetEntityCoords(veh)
    local useVol  = vol  or (s and s.vol)  or (Config.DefaultVolume or 0.35)
    local useDist = dist or (s and s.dist) or (Config.DefaultDistance or 25.0)

    exports['xsound']:PlayUrlPos(id, url, useVol, c, true) -- loop = true
    exports['xsound']:setVolume(id, useVol)
    exports['xsound']:Distance(id, useDist)

    sounds[netId] = { id = id, url = url, vol = useVol, dist = useDist }

    pcall(function()
        if exports['xsound'].setSoundEntity then
            exports['xsound']:setSoundEntity(id, veh)
            exports['xsound']:setSoundDynamic(id, true)
        end
    end)
    CreateThread(function()
        while exports['xsound']:soundExists(id) do
            if not DoesEntityExist(veh) then break end
            exports['xsound']:Position(id, GetEntityCoords(veh))
            Wait(120)
        end
    end)
end

local function openRadioMenu()
    local veh = ensureVehAndPerms(); if not veh then return end
    local netId = NetworkGetNetworkIdFromEntity(veh)
    local id    = (sounds[netId] and sounds[netId].id) or ('car_radio_'..netId)

    local volNow  = (exports['xsound']:soundExists(id) and exports['xsound']:getVolume(id))
                    or (sounds[netId] and sounds[netId].vol)
                    or (Config.DefaultVolume)

    local distNow = (sounds[netId] and sounds[netId].dist)
                    or (exports['xsound']:soundExists(id) and exports['xsound']:getDistance(id))
                    or (Config.DefaultDistance)

    local rows = {
        { header = "Car Radio", txt = "3D follow for everyone", icon = "fa-solid fa-radio", isMenuHeader = true },
        {
            header = "Play / Change URL",
            txt    = lastUrl and ("Last: "..lastUrl) or "Enter a direct audio/stream URL",
            icon   = "fa-solid fa-play",
            params = { event = "d7me-carradio:client:playMenu", args = { netId = netId } }
        },
        {
            header = "Volume",
            txt    = ("Current: %d%%"):format(math.floor((volNow or 0)*100)),
            icon   = "fa-solid fa-volume-high",
            params = { event = "d7me-carradio:client:volMenu", args = { netId = netId } }
        },
        {
            header = "Hear Distance",
            txt    = ("Current: %.1f m (max %dm)"):format(distNow, Config.MaxDistance or 40),
            icon   = "fa-solid fa-broadcast-tower",
            params = { event = "d7me-carradio:client:distMenu", args = { netId = netId } }
        },
        {
            header = "Stop",
            txt    = "Stop playing",
            icon   = "fa-solid fa-stop",
            params = { event = "d7me-carradio:client:stopMneu", args = { netId = netId } }
        },
    }
    exports['qb-menu']:openMenu(rows)
end

if Config.CommandsUse then
    RegisterCommand((Config.Commands and Config.Commands.main) or 'carradio', function()
        openRadioMenu()
    end, false)
else
    RegisterNetEvent('d7me-carradio:client:openMenu', function()
        openRadioMenu()
    end)
end

RegisterNetEvent('d7me-carradio:client:playMenu', function(data)
    local netId = data.netId
    local dialog = exports['qb-input']:ShowInput({
        header = "Play Audio",
        submitText = "Play",
        inputs = { { type='text', isRequired=true, name='url', text='Direct audio URL (mp3/stream)' } }
    })
    if not dialog or not dialog.url or dialog.url == '' then return end
    if not string.find(dialog.url, 'http') then
        QBCore.Functions.Notify('Enter a valid http/https URL.', 'error'); return
    end
    lastUrl = dialog.url
    TriggerServerEvent('d7me-carradio:start', netId, dialog.url, Config.DefaultVolume, Config.DefaultDistance)
end)

RegisterNetEvent('d7me-carradio:client:volMenu', function(data)
    local netId = data.netId
    local dialog = exports['qb-input']:ShowInput({
        header = "Set Volume",
        submitText = "Apply",
        inputs = { { type='number', isRequired=true, name='vol', text='0 - 100 (%)' } }
    })
    if not dialog or not dialog.vol then return end
    local v = math.floor(tonumber(dialog.vol) or -1)
    if v < 0 or v > 100 then
        QBCore.Functions.Notify("Allowed range is 0 - 100", "error"); return
    end
    TriggerServerEvent('d7me-carradio:setvol', netId, v/100.0)
end)

RegisterNetEvent('d7me-carradio:client:distMenu', function(data)
    local netId = data.netId
    local dialog = exports['qb-input']:ShowInput({
        header = "Set Hear Distance (meters)",
        submitText = "Apply",
        inputs = { { type='number', isRequired=true, name='dist', text=('5 - %d (meters)'):format(Config.MaxDistance or 40) } }
    })
    if not dialog or not dialog.dist then return end
    local d = tonumber(dialog.dist) or -1
    local maxD = Config.MaxDistance or 40
    if d < 5 or d > maxD then
        QBCore.Functions.Notify(("Allowed range is 5 - %d meters"):format(maxD), "error")
        return
    end
    TriggerServerEvent('d7me-carradio:setdist', netId, d)
end)

RegisterNetEvent('d7me-carradio:client:stopMneu', function(data)
    TriggerServerEvent('d7me-carradio:stop', data.netId)
end)

RegisterNetEvent('d7me-carradio:client:start', function(netId, url, vol, dist)
    local veh = getEntityByNetId(netId)
    if not veh then return end
    playFollow3D(netId, url, vol, dist, veh)
end)

RegisterNetEvent('d7me-carradio:client:setvol', function(netId, vol)
    local s = sounds[netId]; if s then s.vol = vol end
    local id = (s and s.id) or ('car_radio_'..netId)
    if exports['xsound']:soundExists(id) then exports['xsound']:setVolume(id, vol) end
end)

RegisterNetEvent('d7me-carradio:client:setdist', function(netId, dist)
    local s = sounds[netId]; if s then s.dist = dist end
    local id = (s and s.id) or ('car_radio_'..netId)
    if exports['xsound']:soundExists(id) then exports['xsound']:Distance(id, dist) end
end)

RegisterNetEvent('d7me-carradio:client:stop', function(netId)
    local s = sounds[netId]
    local id = (s and s.id) or ('car_radio_'..netId)
    if exports['xsound']:soundExists(id) then exports['xsound']:Destroy(id) end
    sounds[netId] = nil
end)

AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' then return end
    local entity = args[1]
    if DoesEntityExist(entity) and IsEntityAVehicle(entity) and GetEntityHealth(entity) <= 0 then
        local netId = NetworkGetNetworkIdFromEntity(entity)
        if sounds[netId] then TriggerServerEvent('d7me-carradio:stop', netId) end
    end
end)
