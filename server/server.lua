VORPcore = exports.vorp_core:GetCore()
BccUtils = exports['bcc-utils'].initiate()

local discord = BccUtils.Discord.setup(Config.webhookLink, Config.webhookTitle, Config.WebhookAvatar)

-- Tabulky pro správu více vlaků najednou
ActiveTrains = {}    -- [src] = { netId, trainId }  – vlaky aktivně řízené hráčem
AbandonedTrains = {} -- [trainId] = { netId, trainId, trainModel, fuel, condition } – opuštěné vlaky
ServiceTrains = {}   -- [trainId] = { netId, trainId, trainModel, fuel, condition } – vlaky v provozu bez vlastníka
BridgeDestroyed = false

local function GetTrainCfgByModel(model)
    for _, cfg in pairs(Trains) do
        if cfg.model == model then return cfg end
    end
    return nil
end

local function GetOwnedTrain(trainid, charIdentifier)
    local rows = MySQL.query.await('SELECT * FROM train WHERE trainid = ?', { trainid })
    if rows and rows[1] then return rows[1] end
    return nil
end

local function GetTrainById(trainid)
    local rows = MySQL.query.await('SELECT * FROM train WHERE trainid = ?', { trainid })
    if rows and rows[1] then return rows[1] end
    return nil
end

VORPcore.Callback.Register('bcc-train:JobCheck', function(source, cb, station)
    local _source = source
    local Character = VORPcore.getUser(_source).getUsedCharacter
    local charJob = Character.job
    local jobGrade = Character.jobGrade
    if not charJob then
        cb(false)
        return
    end
    local hasJob = false
    hasJob = CheckPlayerJob(charJob, jobGrade, station)
    if hasJob then
        cb(true)
    else
        cb(false)
    end
end)

function CheckPlayerJob(charJob, jobGrade, station)
    for _, job in pairs(Stations[station].shop.jobs) do
        if (charJob == job.name) and (tonumber(jobGrade) >= tonumber(job.grade)) then
            return true
        end
    end
end

VORPcore.Callback.Register('bcc-train:CheckTrainSpawn', function(source, cb)
    local src = source
    -- Hráč již má aktivní vlak
    if ActiveTrains[src] then cb(false) return end
    -- Dosažen maximální počet aktivních vlaků na serveru
    local count = 0
    for _ in pairs(ActiveTrains) do count = count + 1 end
    if count >= Config.maxActiveTrains then cb(false) return end
    cb(true)
end)

RegisterServerEvent('bcc-train:UpdateTrainSpawnVar', function(spawned, trainNetId, trainId)
    local _source = source
    local Character = VORPcore.getUser(_source).getUsedCharacter
    if spawned then
        ActiveTrains[_source] = { netId = trainNetId, trainId = trainId }
        -- Broadcast blip to all other clients
        local trainRow = GetTrainById(trainId)
        TriggerClientEvent('bcc-train:SyncTrainBlip', -1, {
            netId        = trainNetId,
            trainId      = trainId,
            trainModel   = trainRow and trainRow.trainModel or nil,
            engineerName = Character.firstname .. ' ' .. Character.lastname,
            src          = _source,
        })
        discord:sendMessage(
            _U('trainSpawnedwebMain') ..
            _U('charNameWeb') ..
            Character.firstname ..
            " " ..
            Character.lastname ..
            _U('charIdentWeb') ..
            Character.identifier ..
            _U('charIdWeb') ..
            Character.charIdentifier)
    else
        -- Broadcast blip removal before clearing
        local prevData = ActiveTrains[_source]
        ActiveTrains[_source] = nil
        if prevData then
            TriggerClientEvent('bcc-train:RemoveTrainBlip', -1, { trainId = prevData.trainId })
        end
        discord:sendMessage(
            _U('trainNotSpawnedWeb') ..
            _U('charNameWeb') ..
            Character.firstname .. " " ..
            Character.lastname ..
            _U('charIdentWeb') ..
            Character.identifier ..
            _U('charIdWeb') ..
            Character.charIdentifier)
    end
end)

-- Vrátí data všech aktivních vlaků pro synchronizaci blipů (nový hráč při připojení)
VORPcore.Callback.Register('bcc-train:GetActiveBlips', function(source, cb)
    local blips = {}
    for src, trainData in pairs(ActiveTrains) do
        local trainRow = GetTrainById(trainData.trainId)
        local ok, user = pcall(function() return VORPcore.getUser(src) end)
        local engineerName = 'Strojvedoucí'
        if ok and user then
            local ch = user.getUsedCharacter
            if ch then engineerName = ch.firstname .. ' ' .. ch.lastname end
        end
        blips[#blips + 1] = {
            netId        = trainData.netId,
            trainId      = trainData.trainId,
            trainModel   = trainRow and trainRow.trainModel or nil,
            engineerName = engineerName,
            src          = src,
        }
    end
    cb(blips)
end)

RegisterServerEvent('bcc-train:RegisterInventory', function(trainId)
    local _source = source
    local Character = VORPcore.getUser(_source).getUsedCharacter
    local row = GetOwnedTrain(trainId, Character.charIdentifier)
    if not row then return end
    local trainCfg = GetTrainCfgByModel(row.trainModel)
    if not trainCfg or not trainCfg.inventory.enabled then return end
    local data = {
        id = 'Train_' .. trainId .. '_bcc-traininv',
        name = _U('trainInv'),
        limit = 999999999,
        acceptWeapons = trainCfg.inventory.acceptWeapons,
        shared = true,
        ignoreItemStackLimit = true,
        whitelistItems = false,
        UsePermissions = false,
        UseBlackList = false,
        whitelistWeapons = false,
        useWeight = true,
        weight = trainCfg.inventory.limit,
    }
    exports.vorp_inventory:registerInventory(data)
end)

RegisterServerEvent('bcc-train:OpenInventory', function(trainId)
    local _source = source
    local Character = VORPcore.getUser(_source).getUsedCharacter
    local row = GetOwnedTrain(trainId, Character.charIdentifier)
    if not row then return end
    exports.vorp_inventory:openInventory(_source, 'Train_' .. trainId .. '_bcc-traininv')
end)

VORPcore.Callback.Register('bcc-train:GetMyTrains', function(source, cb)
    local _source = source
    local Character = VORPcore.getUser(_source).getUsedCharacter
    local myTrains = MySQL.query.await('SELECT * FROM train', { })
    if myTrains then
        cb(myTrains)
    else
        cb(nil)
    end
end)

RegisterServerEvent('bcc-train:BuyTrain', function(trainModel)
    local _source = source
    local Character = VORPcore.getUser(_source).getUsedCharacter
    local trainCfg = GetTrainCfgByModel(trainModel)
    if not trainCfg then
        VORPcore.NotifyRightTip(_source, _U('notEnoughMoney'), 4000)
        return
    end
    if Character.money >= trainCfg.price then
        MySQL.query.await('INSERT INTO train ( `trainModel`, `fuel`, `condition`) VALUES ( ?, ?, ?)',
        {trainCfg.model, trainCfg.fuel.maxAmount, trainCfg.condition.maxAmount })

        Character.removeCurrency(0, trainCfg.price)
        VORPcore.NotifyRightTip(_source, _U('trainBought'), 4000)
        discord:sendMessage(
            _U('charNameWeb') ..
            Character.firstname ..
            " " ..
            Character.lastname ..
            _U('charIdentWeb') ..
            Character.identifier ..
            _U('charIdWeb') ..
            Character.charIdentifier ..
            _U('boughtTrainWeb') ..
            trainCfg.model ..
            _U('charPriceWeb') ..
            trainCfg.price)
    else
        VORPcore.NotifyRightTip(_source, _U('notEnoughMoney'), 4000)
    end
end)

VORPcore.Callback.Register('bcc-train:SellTrain', function(source, cb, trainid)
    local _source = source
    local Character = VORPcore.getUser(_source).getUsedCharacter
    local row = GetOwnedTrain(trainid, Character.charIdentifier)
    if not row then
        cb(false)
        return
    end
    local trainCfg = GetTrainCfgByModel(row.trainModel)
    if not trainCfg then
        cb(false)
        return
    end
    MySQL.query.await('DELETE FROM train WHERE trainid = ?', { trainid })
    local price = trainCfg.price * 0.6
    Character.addCurrency(0, price)
    VORPcore.NotifyRightTip(_source, _U('soldTrain') .. price, 4000)
    discord:sendMessage(
        _U('charNameWeb') ..
        Character.firstname ..
        " " ..
        Character.lastname ..
        _U('charIdentWeb') ..
        Character.identifier ..
        _U('charIdWeb') ..
        Character.charIdentifier ..
        _U('soldTrainWeb') ..
        trainCfg.model ..
        _U('charPriceWeb') ..
        price)
    cb(true)
end)

VORPcore.Callback.Register('bcc-train:DecTrainFuel', function(source, cb, trainid)
    local _source = source
    local Character = VORPcore.getUser(_source).getUsedCharacter
    local row = GetOwnedTrain(trainid, Character.charIdentifier)
    if not row then cb(nil) return end
    local trainCfg = GetTrainCfgByModel(row.trainModel)
    if not trainCfg then cb(nil) return end
    local newFuel = row.fuel - trainCfg.fuel.decreaseAmount
    MySQL.query.await('UPDATE train SET `fuel` = ? WHERE `trainid` = ?', { newFuel, trainid })
    cb(newFuel)
end)

VORPcore.Callback.Register('bcc-train:DecTrainCond', function(source, cb, trainid)
    local _source = source
    local Character = VORPcore.getUser(_source).getUsedCharacter
    local row = GetOwnedTrain(trainid, Character.charIdentifier)
    if not row then cb(nil) return end
    local trainCfg = GetTrainCfgByModel(row.trainModel)
    if not trainCfg then cb(nil) return end
    local newCondition = row.condition - trainCfg.condition.decreaseAmount
    MySQL.query.await('UPDATE train SET `condition` = ? WHERE `trainid` = ?', { newCondition, trainid })
    cb(newCondition)
end)

VORPcore.Callback.Register('bcc-train:FuelTrain', function(source, cb, trainId)
    local _source = source
    local Character = VORPcore.getUser(_source).getUsedCharacter
    local row = GetOwnedTrain(trainId, Character.charIdentifier)
    if not row then cb(nil) return end
    local trainCfg = GetTrainCfgByModel(row.trainModel)
    if not trainCfg then cb(nil) return end
    local maxFuel = trainCfg.fuel.maxAmount
    if row.fuel >= maxFuel then
        VORPcore.NotifyRightTip(_source, _U('noFuelNeeded'), 4000)
        cb(nil)
        return
    end
    local itemCount = exports.vorp_inventory:getItemCount(_source, nil, Config.fuel.item)
    if itemCount >= trainCfg.fuel.itemAmount then
        exports.vorp_inventory:subItem(_source, Config.fuel.item, trainCfg.fuel.itemAmount)
        MySQL.query.await('UPDATE train SET `fuel` = ? WHERE `trainid` = ?', { maxFuel, trainId })
        VORPcore.NotifyRightTip(_source, _U('fuelAdded'), 4000)
        cb(maxFuel)
    else
        VORPcore.NotifyRightTip(_source, _U('noItem'), 4000)
        cb(nil)
    end
end)

VORPcore.Callback.Register('bcc-train:RepairTrain', function(source, cb, trainId)
    local _source = source
    local Character = VORPcore.getUser(_source).getUsedCharacter
    local row = GetOwnedTrain(trainId, Character.charIdentifier)
    if not row then cb(nil) return end
    local trainCfg = GetTrainCfgByModel(row.trainModel)
    if not trainCfg then cb(nil) return end
    local maxCondition = trainCfg.condition.maxAmount
    if row.condition >= maxCondition then
        VORPcore.NotifyRightTip(_source, _U('noRepairsNeeded'), 4000)
        cb(nil)
        return
    end
    local itemCount = exports.vorp_inventory:getItemCount(_source, nil, Config.condition.item)
    if itemCount >= trainCfg.condition.itemAmount then
        exports.vorp_inventory:subItem(_source, Config.condition.item, trainCfg.condition.itemAmount)
        MySQL.query.await('UPDATE train SET `condition` = ? WHERE `trainid` = ?', { maxCondition, trainId })
        VORPcore.NotifyRightTip(_source, _U('trainRepaired'), 4000)
        cb(maxCondition)
    else
        VORPcore.NotifyRightTip(_source, _U('noItem'), 4000)
        cb(nil)
    end
end)

VORPcore.Callback.Register('bcc-train:UseBoilerOil', function(source, cb)
    local _source = source
    local itemCount = exports.vorp_inventory:getItemCount(_source, nil, Config.boilerTemp.boostItem)
    if itemCount >= 1 then
        exports.vorp_inventory:subItem(_source, Config.boilerTemp.boostItem, 1)
        cb(true)
    else
        VORPcore.NotifyRightTip(_source, _U('noItem'), 4000)
        cb(false)
    end
end)

RegisterServerEvent('bcc-train:BridgeFallHandler', function(freshJoin)
    local _source = source
    local Character = VORPcore.getUser(_source).getUsedCharacter
    if not freshJoin then
        local itemCount = exports.vorp_inventory:getItemCount(_source, nil, Config.bacchusBridge.item)
        if itemCount >= Config.bacchusBridge.itemAmount then
            if not BridgeDestroyed then
                exports.vorp_inventory:subItem(_source, Config.bacchusBridge.item, Config.bacchusBridge.itemAmount)
                BridgeDestroyed = true
                VORPcore.NotifyRightTip(_source, _U('runFromExplosion') .. Config.bacchusBridge.timer .. _U('seconds'), 4000)
                Wait(Config.bacchusBridge.timer * 1000)
                discord:sendMessage(
                    _U('charNameWeb') ..
                    Character.firstname ..
                    " " ..
                    Character.lastname ..
                    _U('charIdentWeb') ..
                    Character.identifier ..
                    _U('charIdWeb') ..
                    Character.charIdentifier ..
                    _U('bacchusDestroyedWebhook')
                )
                BccUtils.Discord.sendMessage(Config.webhookLink, Config.webhookTitle, Config.webhookAvatar, _U('bacchusDestroyedWebhook'), '')
                TriggerClientEvent('bcc-train:BridgeFall', -1) --triggers for all clients
            end
        else
            VORPcore.NotifyRightTip(_source, _U('noItem'), 4000)
        end
    else
        if BridgeDestroyed then
            TriggerClientEvent('bcc-train:BridgeFall', _source) --triggers for new client
        end
    end
end)

RegisterServerEvent('bcc-train:DeliveryPay', function(destinationIndex)
    local _source = source
    local Character = VORPcore.getUser(_source).getUsedCharacter
    local destination = Config.deliveryLocations[destinationIndex]
    if not destination then return end
    Character.addCurrency(0, destination.pay)
    discord:sendMessage(
        _U('charNameWeb') ..
        Character.firstname ..
        " " ..
        Character.lastname ..
        _U('charIdentWeb') ..
        Character.identifier ..
        _U('charIdWeb') ..
        Character.charIdentifier ..
        _U('paidDeliveryWeb') ..
        destination.pay)
end)

local CooldownData = {}
RegisterServerEvent('bcc-train:SetPlayerCooldown', function(mission)
    local src = source
    local Character = VORPcore.getUser(src).getUsedCharacter
    CooldownData[mission .. tostring(Character.charIdentifier)] = os.time()
end)

VORPcore.Callback.Register('bcc-train:CheckPlayerCooldown', function(source, cb, mission)
    local src = source
    local Character = VORPcore.getUser(src).getUsedCharacter
    local cooldown = Config.cooldown[mission]
    local onList = false
    local missionId = mission .. tostring(Character.charIdentifier)
    for id, time in pairs(CooldownData) do
        if id == missionId then
            onList = true
            if os.difftime(os.time(), time) >= cooldown * 60 then
                cb(false) -- Not on Cooldown
                break
            else
                cb(true)
                break
            end
        end
    end
    if not onList then
        cb(false)
    end
end)

-- Check if properly downloaded
function file_exists(name)
  local f = LoadResourceFile(GetCurrentResourceName(), name)
  return f ~= nil
end



-- Uvolnění vlaku při odpojení/pádu hry strojvedoucího
AddEventHandler('playerDropped', function(reason)
    local src = source
    if not ActiveTrains[src] then return end

    local trainData = ActiveTrains[src]

    -- Načti data vlaku z DB
    local trainRow = GetTrainById(trainData.trainId)

    -- Ulož data pro případné převzetí (NEsmaž entitu – jiný strojvedoucí ji může převzít)
    local abandonedEntry = {
        netId      = trainData.netId,
        trainId    = trainData.trainId,
        trainModel = trainRow and trainRow.trainModel or nil,
        fuel       = trainRow and trainRow.fuel or 0,
        condition  = trainRow and trainRow.condition or 0,
    }

    ActiveTrains[src] = nil
    AbandonedTrains[abandonedEntry.trainId] = abandonedEntry

    discord:sendMessage('🚂 Vlak opuštěn – strojvedoucí (src: ' .. src .. ') se odpojil. Důvod: ' .. tostring(reason))

    -- Notifikace všem klientům včetně dat o opuštěném vlaku
    TriggerClientEvent('bcc-train:TrainFreed', -1, abandonedEntry)

    -- Automatický úklid po 10 minutách, pokud nikdo vlak nepřevzal
    local savedTrainId = abandonedEntry.trainId
    SetTimeout(600000, function()
        if AbandonedTrains[savedTrainId] then
            local ent = NetworkGetEntityFromNetworkId(AbandonedTrains[savedTrainId].netId)
            if DoesEntityExist(ent) then DeleteEntity(ent) end
            TriggerClientEvent('bcc-train:RemoveTrainBlip', -1, { trainId = savedTrainId })
            AbandonedTrains[savedTrainId] = nil
        end
    end)
end)

-- Převzetí opuštěného vlaku jiným strojvedoucím (klient posílá trainId konkrétního vlaku)
VORPcore.Callback.Register('bcc-train:TakeoverTrain', function(source, cb, targetTrainId)
    local src = source
    if ActiveTrains[src] then cb(nil) return end  -- hráč již řídí jiný vlak
    if not AbandonedTrains[targetTrainId] then cb(nil) return end  -- vlak mezitím převzal někdo jiný

    local abandoned = AbandonedTrains[targetTrainId]
    local Character = VORPcore.getUser(src).getUsedCharacter

    -- Přepiš vlastnictví v DB na nového strojvedoucího
    MySQL.query.await('UPDATE train SET charidentifier = ? WHERE trainid = ?',
        { Character.charIdentifier, abandoned.trainId })

    local result = {
        netId      = abandoned.netId,
        trainid    = abandoned.trainId,
        trainModel = abandoned.trainModel,
        fuel       = abandoned.fuel,
        condition  = abandoned.condition,
    }

    -- Aktivuj nového vlastníka
    ActiveTrains[src] = { netId = abandoned.netId, trainId = abandoned.trainId }
    AbandonedTrains[targetTrainId] = nil

    -- Informuj všechny ostatní klienty, ať odeberou vlak ze svých lokálních tabulek
    TriggerClientEvent('bcc-train:TrainTakenOver', -1, { trainId = targetTrainId })

    discord:sendMessage(
        _U('charNameWeb') .. Character.firstname .. ' ' .. Character.lastname ..
        _U('charIdentWeb') .. Character.identifier ..
        _U('charIdWeb') .. Character.charIdentifier ..
        '\nPřevzal opuštěný vlak!')

    cb(result)
end)



-- Opuštění vlaku při smrti nebo vzdálení strojvedoucího (vlak zůstává na trati)
RegisterServerEvent('bcc-train:AbandonTrain')
AddEventHandler('bcc-train:AbandonTrain', function()
    local src = source
    if not ActiveTrains[src] then return end

    local trainData = ActiveTrains[src]
    local trainRow = GetTrainById(trainData.trainId)

    local abandonedEntry = {
        netId      = trainData.netId,
        trainId    = trainData.trainId,
        trainModel = trainRow and trainRow.trainModel or nil,
        fuel       = trainRow and trainRow.fuel or 0,
        condition  = trainRow and trainRow.condition or 0,
    }

    ActiveTrains[src] = nil
    AbandonedTrains[abandonedEntry.trainId] = abandonedEntry

    discord:sendMessage('🚂 Vlak opuštěn – strojvedoucí (src: ' .. src .. ') zemřel nebo se vzdálil od vlaku.')

    -- Notifikace všem klientům o volném vlaku
    TriggerClientEvent('bcc-train:TrainFreed', -1, abandonedEntry)
    -- Potvrzení původnímu řidiči pro reset UI bez smazání entity
    TriggerClientEvent('bcc-train:TrainAbandonConfirmed', src)

    -- Automatický úklid po 10 minutách, pokud nikdo vlak nepřevzal
    local savedTrainId = abandonedEntry.trainId
    SetTimeout(600000, function()
        if AbandonedTrains[savedTrainId] then
            local ent = NetworkGetEntityFromNetworkId(AbandonedTrains[savedTrainId].netId)
            if DoesEntityExist(ent) then DeleteEntity(ent) end
            TriggerClientEvent('bcc-train:RemoveTrainBlip', -1, { trainId = savedTrainId })
            AbandonedTrains[savedTrainId] = nil
        end
    end)
end)

RegisterServerEvent('bcc-train:Server:DeleteTrain')
AddEventHandler('bcc-train:Server:DeleteTrain', function(entity)
    local _source = source
    local Character = VORPcore.getUser(_source).getUsedCharacter
    if Character.job == Config.Job then
        print('Deleting Train',NetworkGetEntityFromNetworkId(entity))
        DeleteEntity(NetworkGetEntityFromNetworkId(entity))
    end
end)

-- Uvedení vlaku do provozu bez vlastníka (příkaz /servis)
RegisterServerEvent('bcc-train:PutTrainInService')
AddEventHandler('bcc-train:PutTrainInService', function()
    local src = source
    local Character = VORPcore.getUser(src).getUsedCharacter

    if Character.job ~= Config.Job then
        VORPcore.NotifyRightTip(src, _U('wrongJob'), 4000)
        return
    end

    if not ActiveTrains[src] then
        VORPcore.NotifyRightTip(src, _U('noActiveTrain'), 4000)
        return
    end

    local trainData = ActiveTrains[src]
    local trainRow = GetTrainById(trainData.trainId)

    local serviceEntry = {
        netId      = trainData.netId,
        trainId    = trainData.trainId,
        trainModel = trainRow and trainRow.trainModel or nil,
        fuel       = trainRow and trainRow.fuel or 0,
        condition  = trainRow and trainRow.condition or 0,
    }

    -- Uvolni zámek – vlak zůstane na trati, ale nemá vlastníka
    ActiveTrains[src] = nil
    ServiceTrains[serviceEntry.trainId] = serviceEntry

    -- Nejprve rozešli informaci o volném vlaku všem strojvedoucím,
    -- pak potvrď původnímu řidiči (aby MyTrain ještě blokoval příjem TrainInService)
    TriggerClientEvent('bcc-train:TrainInService', -1, serviceEntry)
    TriggerClientEvent('bcc-train:TrainServiceConfirmed', src)

    discord:sendMessage(
        _U('charNameWeb') .. Character.firstname .. ' ' .. Character.lastname ..
        _U('charIdentWeb') .. Character.identifier ..
        _U('charIdWeb') .. Character.charIdentifier ..
        '\nVlak uveden do provozu bez vlastníka (/servis).')

    -- Automatický úklid po 10 minutách, pokud nikdo vlak nepřevzal
    local savedTrainId = serviceEntry.trainId
    SetTimeout(600000, function()
        if ServiceTrains[savedTrainId] then
            local ent = NetworkGetEntityFromNetworkId(ServiceTrains[savedTrainId].netId)
            if DoesEntityExist(ent) then DeleteEntity(ent) end
            TriggerClientEvent('bcc-train:RemoveTrainBlip', -1, { trainId = savedTrainId })
            ServiceTrains[savedTrainId] = nil
        end
    end)
end)

-- Převzetí vlaku z provozu jiným strojvedoucím (klient posílá trainId konkrétního vlaku)
VORPcore.Callback.Register('bcc-train:ClaimServiceTrain', function(source, cb, targetTrainId)
    local src = source
    if ActiveTrains[src] then cb(nil) return end  -- hráč již řídí jiný vlak
    if not ServiceTrains[targetTrainId] then cb(nil) return end  -- vlak mezitím někdo převzal

    local service = ServiceTrains[targetTrainId]
    local Character = VORPcore.getUser(src).getUsedCharacter

    MySQL.query.await('UPDATE train SET charidentifier = ? WHERE trainid = ?',
        { Character.charIdentifier, service.trainId })

    local result = {
        netId      = service.netId,
        trainid    = service.trainId,
        trainModel = service.trainModel,
        fuel       = service.fuel,
        condition  = service.condition,
    }

    ActiveTrains[src] = { netId = service.netId, trainId = service.trainId }
    ServiceTrains[targetTrainId] = nil

    -- Informuj všechny ostatní klienty, ať odeberou vlak ze svých lokálních tabulek
    TriggerClientEvent('bcc-train:ServiceTrainClaimed', -1, { trainId = targetTrainId })

    discord:sendMessage(
        _U('charNameWeb') .. Character.firstname .. ' ' .. Character.lastname ..
        _U('charIdentWeb') .. Character.identifier ..
        _U('charIdWeb') .. Character.charIdentifier ..
        '\nPřevzal vlak z provozu (/servis).')

    cb(result)
end)