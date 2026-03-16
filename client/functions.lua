-- Dependencies
VORPcore = exports.vorp_core:GetCore()
BccUtils = exports['bcc-utils'].initiate()
-- Global NUI state (populated by menuSetup.lua)
MenuCallbackStack = MenuCallbackStack or {}
CurrentMaxSpeed   = CurrentMaxSpeed or 30
MiniGame = exports['bcc-minigames'].initiate()
-- Prompts
MenuPrompt = nil
MenuGroup = GetRandomIntInRange(0, 0xffffff)
BridgePrompt = nil
BridgeGroup = GetRandomIntInRange(0, 0xffffff)
DeliveryPrompt = nil
DeliveryGroup = GetRandomIntInRange(0, 0xffffff)
DeliveryPromptStarted = false
TargetPromptsStarted = false
-- Train Globals
MyTrain = nil
TrainId = nil
TrainFuel = nil
TrainCondition = nil
DrivingMenuOpened = false
FuelTarget = nil
RepairTarget = nil
InMission = false
EngineStarted = false
ForwardActive = false
BackwardActive = false
-- Teplota kotle
BoilerTemp             = 0
BoilerEfficiency       = 1.0
BoilerTempBoostActive  = false
BoilerTempBoostEndTime = 0

function AddBlip(station)
    local stationCfg = Stations[station]
    stationCfg.Blip = Citizen.InvokeNative(0x554d9d53f696d002, 1664425300,
                                           stationCfg.npc.coords) -- BlipAddForCoords
    SetBlipSprite(stationCfg.Blip, stationCfg.blip.sprite, true)
    SetBlipScale(stationCfg.Blip, 0.2)
    Citizen.InvokeNative(0x9CB1A1623062F402, stationCfg.Blip,
                         stationCfg.blip.name) -- SetBlipNameFromPlayerString
end

function AddNPC(station)
    local stationCfg = Stations[station]
    LoadModel(stationCfg.npc.model)
    stationCfg.NPC = CreatePed(stationCfg.npc.model, stationCfg.npc.coords.x,
                               stationCfg.npc.coords.y,
                               stationCfg.npc.coords.z - 1,
                               stationCfg.npc.heading, false, false, false,
                               false)
    Citizen.InvokeNative(0x283978A15512B2FE, stationCfg.NPC, true) -- SetRandomOutfitVariation
    SetEntityCanBeDamaged(stationCfg.NPC, false)
    SetEntityInvincible(stationCfg.NPC, true)
    Wait(500)
    FreezeEntityPosition(stationCfg.NPC, true)
    SetBlockingOfNonTemporaryEvents(stationCfg.NPC, true)
end

function LoadModel(model)
    local hash = joaat(model)
    RequestModel(hash)
    while not HasModelLoaded(hash) do Wait(10) end
end

function ShowHUD(condition, maxCondition, fuel, maxFuel)
    SendNUIMessage({
        type         = 'toggleHUD',
        HUDvisible   = true,
        condition    = condition,
        maxCondition = maxCondition,
        fuel         = fuel,
        maxFuel      = maxFuel,
        maxSpeed     = CurrentMaxSpeed or 30,
    })
    SetNuiFocus(true, true)
    MenuOpen = true
end

function UpdateHUD(condition, fuel)
    SendNUIMessage({type = 'update', condition = condition, fuel = fuel})
end

function HideHUD()
    SendNUIMessage({ type = 'toggleHUD', HUDvisible = false })
    SetNuiFocus(false, false)
end

function FuelUpdate(fuel)
    TrainFuel = fuel
    UpdateHUD(nil, fuel)
end

function ConditionUpdate(cond)
    TrainCondition = cond
    UpdateHUD(cond, nil)
end

function CalcTempEfficiency(temp)
    local minEff   = Config.boilerTemp.minEfficiency
    local maxEff   = Config.boilerTemp.maxEfficiency
    local boostEff = Config.boilerTemp.boostEfficiency
    local boostAmt = Config.boilerTemp.boostAmount
    if temp <= 100 then
        return minEff + (temp / 100) * (maxEff - minEff)
    else
        local t = math.min(1.0, (temp - 100) / boostAmt)
        return maxEff + t * (boostEff - maxEff)
    end
end

function GetMyOilCount()
    local count = 0
    local inventory = exports.vorp_inventory:getInventoryItems()
    if inventory then
        for _, item in pairs(inventory) do
            if item.name == Config.boilerTemp.boostItem then
                count = item.count or 0
                break
            end
        end
    end
    return count
end

function LoadTrainCars(trainHash)
    local cars = Citizen.InvokeNative(0x635423d55ca84fc8, trainHash) -- GetNumCarsFromTrainConfig
    for index = 0, cars - 1 do
        local model = Citizen.InvokeNative(0x8df5f6a19f99f0d5, trainHash, index) -- GetTrainModelFromTrainConfigByCarIndex
        RequestModel(model)
        while not HasModelLoaded(model) do Wait(10) end
    end
end

function notify(text)
    TriggerEvent('notifications:notify', "Vláčky", text, 3000)
end

TrackSwitchActive = false

function TrackSwitch(toggle)
    TrackSwitchActive = toggle
    if toggle == false then
        SetAllJunctionsCleared()
        return
    end
    local trackModels = {
        {model = 'braithwaites2_track_config'}, {model = 'freight_group'},
        {model = 'freight_nb1_inter'}, {model = 'trains3'},
        {model = 'trains_intersection1_3'},
        {model = 'trains_intersection1_ann'},
        {model = 'trains_intersection1_app'},
        {model = 'trains_intersection2_3'},
        {model = 'trains_intersection2_ann'},
        {model = 'trains_intersection2_3'},
        {model = 'trains_intersection3_cor'}, {model = 'trains_nb1'},
        {model = 'trains_nb2'}, {model = 'trains_nb3'},
        {model = 'trains_old_west01'}, {model = 'trains_old_west02'},
        {model = 'trains_old_west03'},
        {model = 'trains_old_west_intersection01'},
        {model = 'trains_old_west_intersection02'}, {model = 'trains_rob3'},
        {model = 'spooni01'}, {model = 'spooni02'}, {model = 'spooni03'},
        {model = 'spooni04'}
    }
    local counter = 0
    repeat
        for _, v in pairs(trackModels) do
            local trackHash = joaat(v.model) or v.hash
            Citizen.InvokeNative(0xE6C5E2125EB210C1, trackHash, counter, toggle)
        end
        counter = counter + 1
    until counter >= 50
    notify("Přepínač trati byl " ..
               (toggle and "aktivován" or "deaktivován"))
end

-- Blípy cizích vlaků (synchronizace mezi strojvedoucími): [trainId] = blipHandle
OtherTrainBlips = {}

-- Tabulky opuštěných a servisních vlaků (více najednou)
AbandonedTrains = {}  -- [trainId] = { netId, trainId, trainModel, fuel, condition }
TakeoverPrompt = nil
TakeoverGroup = GetRandomIntInRange(0, 0xffffff)
TakeoverCheckActive = false  -- guard proti spuštění více smyček

-- Vlaky v provozu bez vlastníka (/servis)
ServiceTrains = {}    -- [trainId] = { netId, trainId, trainModel, fuel, condition }
ServicePrompt = nil
ServiceGroup = GetRandomIntInRange(0, 0xffffff)
ServiceCheckActive = false  -- guard proti spuštění více smyček

-- Server poslal info o opuštěném vlaku
RegisterNetEvent('bcc-train:TrainFreed')
AddEventHandler('bcc-train:TrainFreed', function(abandonedData)
    if MyTrain then return end  -- tento hráč vlak řídí, netýká se ho
    while not LocalPlayer.state or not LocalPlayer.state.Character do
        Wait(500)
    end
    if LocalPlayer.state.Character.Job ~= Config.Job then return end

    AbandonedTrains[abandonedData.trainId] = abandonedData
    VORPcore.NotifyRightTip(_U('trainNowAvailable'), 6000)

    -- Spusť smyčku pro kontrolu blízkosti (pokud ještě neběží)
    if not TakeoverCheckActive then
        TriggerEvent('bcc-train:StartTakeoverCheck')
    end
end)

-- Smyčka: čeká na přiblížení k opuštěnému vlaku a nabídne převzetí (podporuje více vlaků)
AddEventHandler('bcc-train:StartTakeoverCheck', function()
    if TakeoverCheckActive then return end
    TakeoverCheckActive = true

    -- Registruj prompt pokud ještě neexistuje
    if not TakeoverPrompt then
        TakeoverPrompt = PromptRegisterBegin()
        PromptSetControlAction(TakeoverPrompt, Config.keys.station)
        PromptSetText(TakeoverPrompt, CreateVarString(10, 'LITERAL_STRING', _U('takeoverTrain')))
        PromptSetEnabled(TakeoverPrompt, true)
        PromptSetVisible(TakeoverPrompt, false)
        PromptSetStandardMode(TakeoverPrompt, true)
        PromptSetGroup(TakeoverPrompt, TakeoverGroup)
        PromptRegisterEnd(TakeoverPrompt)
    end

    while next(AbandonedTrains) ~= nil do
        local sleep = 500
        local playerPed = PlayerPedId()
        local closestTrainId = nil
        local closestDist = 15.0

        -- Odstraň neexistující vlaky a najdi nejbližší
        for trainId, data in pairs(AbandonedTrains) do
            if not NetworkDoesEntityExistWithNetworkId(data.netId) then
                AbandonedTrains[trainId] = nil
            else
                local trainEnt = NetworkGetEntityFromNetworkId(data.netId)
                if DoesEntityExist(trainEnt) then
                    local dist = #(GetEntityCoords(playerPed) - GetEntityCoords(trainEnt))
                    if dist <= closestDist then
                        closestDist = dist
                        closestTrainId = trainId
                    end
                else
                    AbandonedTrains[trainId] = nil
                end
            end
        end

        if closestTrainId and not IsPedDeadOrDying(playerPed) then
            sleep = 0
            PromptSetVisible(TakeoverPrompt, true)
            local label = CreateVarString(10, 'LITERAL_STRING', _U('takeoverTrain'))
            PromptSetActiveGroupThisFrame(TakeoverGroup, label)

            if Citizen.InvokeNative(0xC92AC953F0A982AE, TakeoverPrompt) then  -- PromptHasStandardModeCompleted
                PromptSetVisible(TakeoverPrompt, false)
                -- Pošli serveru trainId vlaku, který chceme převzít
                local result = VORPcore.Callback.TriggerAwait('bcc-train:TakeoverTrain', closestTrainId)
                if result then
                    local ent = NetworkGetEntityFromNetworkId(result.netId)
                    if DoesEntityExist(ent) then
                        MyTrain = ent
                        TrainId = result.trainid
                        TrainFuel = result.fuel
                        TrainCondition = result.condition
                        AbandonedTrains[closestTrainId] = nil

                        for _, cfg in pairs(Trains) do
                            if cfg.model == result.trainModel then
                                SetupTrainHandlers(cfg, result)
                                break
                            end
                        end

                        VORPcore.NotifyRightTip(_U('trainTakenOver'), 4000)
                    else
                        AbandonedTrains[closestTrainId] = nil
                        VORPcore.NotifyRightTip(_U('trainNowAvailable'), 5000)
                    end
                else
                    -- Server zamítl – vlak už někdo jiný převzal, odeber lokálně
                    AbandonedTrains[closestTrainId] = nil
                    VORPcore.NotifyRightTip(_U('trainSpawnedAlrady'), 4000)
                end
                -- Po akci vyčkej zda jsou další vlaky, smyčka pokračuje
            end
        else
            PromptSetVisible(TakeoverPrompt, false)
        end

        Wait(sleep)
    end

    PromptSetVisible(TakeoverPrompt, false)
    TakeoverCheckActive = false
end)

-- Server broadcastuje, že vlak byl převzat jiným hráčem
RegisterNetEvent('bcc-train:TrainTakenOver')
AddEventHandler('bcc-train:TrainTakenOver', function(data)
    AbandonedTrains[data.trainId] = nil
end)

-- Server potvrdil, že vlak byl úspěšně uveden do provozu (/servis)
RegisterNetEvent('bcc-train:TrainServiceConfirmed')
AddEventHandler('bcc-train:TrainServiceConfirmed', function()
    -- Resetuj stav bez smazání entity (vlak zůstává na trati)
    SendNUIMessage({ type = 'resetTrainState' })
    MyTrain = nil
    TrainId = nil
    TrainFuel = nil
    TrainCondition = nil
    DrivingMenuOpened = false
    EngineStarted = false
    ForwardActive = false
    BackwardActive = false
    FuelTarget = nil
    RepairTarget = nil
    TargetPromptsStarted = false
    HideHUD()
    VORPcore.NotifyRightTip(_U('trainPutInService'), 6000)
end)

-- Server informuje o vlaku dostupném v provozu bez vlastníka
RegisterNetEvent('bcc-train:TrainInService')
AddEventHandler('bcc-train:TrainInService', function(serviceData)
    if MyTrain then return end  -- tento hráč řídí vlastní vlak
    while not LocalPlayer.state or not LocalPlayer.state.Character do
        Wait(500)
    end
    if LocalPlayer.state.Character.Job ~= Config.Job then return end

    ServiceTrains[serviceData.trainId] = serviceData
    VORPcore.NotifyRightTip(_U('trainInService'), 6000)

    -- Spusť smyčku pro kontrolu blízkosti (pokud ještě neběží)
    if not ServiceCheckActive then
        TriggerEvent('bcc-train:StartServiceClaimCheck')
    end
end)

-- Smyčka: čeká na přiblížení k servisnímu vlaku a nabídne převzetí (podporuje více vlaků)
AddEventHandler('bcc-train:StartServiceClaimCheck', function()
    if ServiceCheckActive then return end
    ServiceCheckActive = true

    if not ServicePrompt then
        ServicePrompt = PromptRegisterBegin()
        PromptSetControlAction(ServicePrompt, Config.keys.station)
        PromptSetText(ServicePrompt, CreateVarString(10, 'LITERAL_STRING', _U('claimServiceTrain')))
        PromptSetEnabled(ServicePrompt, true)
        PromptSetVisible(ServicePrompt, false)
        PromptSetStandardMode(ServicePrompt, true)
        PromptSetGroup(ServicePrompt, ServiceGroup)
        PromptRegisterEnd(ServicePrompt)
    end

    while next(ServiceTrains) ~= nil do
        local sleep = 500
        local playerPed = PlayerPedId()
        local closestTrainId = nil
        local closestDist = 15.0

        -- Odstraň neexistující vlaky a najdi nejbližší
        for trainId, data in pairs(ServiceTrains) do
            if not NetworkDoesEntityExistWithNetworkId(data.netId) then
                ServiceTrains[trainId] = nil
            else
                local trainEnt = NetworkGetEntityFromNetworkId(data.netId)
                if DoesEntityExist(trainEnt) then
                    local dist = #(GetEntityCoords(playerPed) - GetEntityCoords(trainEnt))
                    if dist <= closestDist then
                        closestDist = dist
                        closestTrainId = trainId
                    end
                else
                    ServiceTrains[trainId] = nil
                end
            end
        end

        if closestTrainId and not IsPedDeadOrDying(playerPed) then
            sleep = 0
            PromptSetVisible(ServicePrompt, true)
            local label = CreateVarString(10, 'LITERAL_STRING', _U('claimServiceTrain'))
            PromptSetActiveGroupThisFrame(ServiceGroup, label)

            if Citizen.InvokeNative(0xC92AC953F0A982AE, ServicePrompt) then  -- PromptHasStandardModeCompleted
                PromptSetVisible(ServicePrompt, false)
                -- Pošli serveru trainId vlaku, který chceme převzít
                local result = VORPcore.Callback.TriggerAwait('bcc-train:ClaimServiceTrain', closestTrainId)
                if result then
                    local ent = NetworkGetEntityFromNetworkId(result.netId)
                    if DoesEntityExist(ent) then
                        MyTrain = ent
                        TrainId = result.trainid
                        TrainFuel = result.fuel
                        TrainCondition = result.condition
                        ServiceTrains[closestTrainId] = nil

                        for _, cfg in pairs(Trains) do
                            if cfg.model == result.trainModel then
                                SetupTrainHandlers(cfg, result)
                                break
                            end
                        end

                        VORPcore.NotifyRightTip(_U('trainClaimedFromService'), 4000)
                    else
                        ServiceTrains[closestTrainId] = nil
                        VORPcore.NotifyRightTip(_U('trainInService'), 5000)
                    end
                else
                    -- Server zamítl – vlak už někdo jiný převzal, odeber lokálně
                    ServiceTrains[closestTrainId] = nil
                    VORPcore.NotifyRightTip(_U('trainSpawnedAlrady'), 4000)
                end
                -- Po akci vyčkej zda jsou další vlaky, smyčka pokračuje
            end
        else
            PromptSetVisible(ServicePrompt, false)
        end

        Wait(sleep)
    end

    PromptSetVisible(ServicePrompt, false)
    ServiceCheckActive = false
end)

-- Server broadcastuje, že servisní vlak byl převzat jiným hráčem
RegisterNetEvent('bcc-train:ServiceTrainClaimed')
AddEventHandler('bcc-train:ServiceTrainClaimed', function(data)
    ServiceTrains[data.trainId] = nil
end)

-- ─────────────────────────────────────────────────────────────────
--  SYNCHRONIZACE BLIPŮ VLAKŮ MEZI STROJVEDOUCÍMI
-- ─────────────────────────────────────────────────────────────────

local function CreateOtherTrainBlip(data)
    -- Přeskočit vlastní vlak (i v případě zpožděného příjmu)
    if data.trainId == TrainId then return end
    -- Odstraň existující blip pro tento vlak
    if OtherTrainBlips[data.trainId] then
        RemoveBlip(OtherTrainBlips[data.trainId])
        OtherTrainBlips[data.trainId] = nil
    end
    Citizen.CreateThread(function()
        local netId    = data.netId
        local attempts = 0
        while not NetworkDoesEntityExistWithNetworkId(netId) and attempts < 60 do
            Wait(200)
            attempts = attempts + 1
        end
        if not NetworkDoesEntityExistWithNetworkId(netId) then return end
        local ent = NetworkGetEntityFromNetworkId(netId)
        if not DoesEntityExist(ent) then return end
        -- Znovu zkontrolovat, zda to není náš vlastní vlak (race condition)
        if data.trainId == TrainId then return end

        local blipHandle = Citizen.InvokeNative(0x23f74c2fda6e7c61, -1749618580, ent) -- BlipAddForEntity
        local trainCfg = nil
        for _, cfg in pairs(Trains) do
            if cfg.model == data.trainModel then trainCfg = cfg; break end
        end
        if trainCfg and trainCfg.blip then
            SetBlipSprite(blipHandle, joaat(trainCfg.blip.sprite), true)
            local blipName = (data.engineerName and data.engineerName ~= '') and data.engineerName or trainCfg.blip.name
            Citizen.InvokeNative(0x9CB1A1623062F402, blipHandle, blipName) -- SetBlipNameFromPlayerString
            Citizen.InvokeNative(0x662D364ABF16DE2F, blipHandle,
                joaat(Config.blipColors[trainCfg.blip.color])) -- BlipAddModifier
        end
        OtherTrainBlips[data.trainId] = blipHandle
    end)
end

RegisterNetEvent('bcc-train:SyncTrainBlip')
AddEventHandler('bcc-train:SyncTrainBlip', function(data)
    CreateOtherTrainBlip(data)
end)

RegisterNetEvent('bcc-train:RemoveTrainBlip')
AddEventHandler('bcc-train:RemoveTrainBlip', function(data)
    local trainId = data.trainId
    if OtherTrainBlips[trainId] then
        RemoveBlip(OtherTrainBlips[trainId])
        OtherTrainBlips[trainId] = nil
    end
end)

-- Po načtení postavy si vyžádáme blípy všech aktuálně jedoucích vlaků
CreateThread(function()
    while not LocalPlayer.state or not LocalPlayer.state.Character do Wait(1000) end
    Wait(3000)  -- pauza pro ustálení síťové synchronizace
    local activeBlips = VORPcore.Callback.TriggerAwait('bcc-train:GetActiveBlips')
    if activeBlips then
        for _, data in ipairs(activeBlips) do
            CreateOtherTrainBlip(data)
        end
    end
end)

-- Potvrzení serveru: vlak opuštěn (smrt/vzdálení) – NEmaže entitu, jen resetuje UI
RegisterNetEvent('bcc-train:TrainAbandonConfirmed')
AddEventHandler('bcc-train:TrainAbandonConfirmed', function()
    -- MyTrain byl již nastaven na nil v TrainHandler, resetujeme zbytek stavu
    SendNUIMessage({ type = 'resetTrainState' })
    TrainId = nil
    TrainFuel = nil
    TrainCondition = nil
    DrivingMenuOpened = false
    EngineStarted = false
    ForwardActive = false
    BackwardActive = false
    FuelTarget = nil
    RepairTarget = nil
    TargetPromptsStarted = false
    BoilerTempBoostActive = false
    BoilerEfficiency = 1.0
    HideHUD()
    SendNUIMessage({ type = 'closeStationMenu' })
    MenuCallbackStack = {}
    if DestinationBlip then
        RemoveBlip(DestinationBlip)
        DestinationBlip = nil
    end
    if DeliveryBlip then
        RemoveBlip(DeliveryBlip)
        DeliveryBlip = nil
    end
    if InMission then
        VORPcore.NotifyRightTip(_U('missionFailed'), 4000)
        InMission = false
    end
end)

AddEventHandler('bcc-train:ResetTrain', function()
    if MyTrain then
        DeleteEntity(MyTrain)
        MyTrain = nil
    end
    SendNUIMessage({ type = 'resetTrainState' })
    HideHUD()
    if InMission then
        VORPcore.NotifyRightTip(_U('missionFailed'), 4000)
        InMission = false
    end
    SendNUIMessage({ type = 'closeStationMenu' })
    MenuCallbackStack = {}
    TargetPromptsStarted = false
    EngineStarted = false
    FuelTarget = nil
    RepairTarget = nil
    ForwardActive = false
    BackwardActive = false
    BoilerTempBoostActive = false
    BoilerEfficiency = 1.0
    if DestinationBlip then
        RemoveBlip(DestinationBlip)
        DestinationBlip = nil
    end
    if DeliveryBlip then
        RemoveBlip(DeliveryBlip)
        DeliveryBlip = nil
    end
    TriggerServerEvent('bcc-train:UpdateTrainSpawnVar', false)
end)

-- Menu for Train Maintenance
AddEventHandler('bcc-train:TargetMenu', function(trainCfg)
    local playerPed = PlayerPedId()
    local player = PlayerId()
    while MyTrain do
        local sleep = 1000
        local dist = #(GetEntityCoords(playerPed) - GetEntityCoords(MyTrain))
        if dist >= 6 or
            not Citizen.InvokeNative(0xEC5F66E459AF3BB2, playerPed, MyTrain) then -- IsPedOnSpecificVehicle
            Citizen.InvokeNative(0x05254BA0B44ADC16, MyTrain, false) -- SetVehicleCanBeTargetted
            goto continue
        end
        Citizen.InvokeNative(0x05254BA0B44ADC16, MyTrain, true) -- SetVehicleCanBeTargetted
        if Citizen.InvokeNative(0x27F89FDC16688A7A, player, MyTrain, 0) then -- IsPlayerTargettingEntity
            sleep = 0
            local trainGroup = Citizen.InvokeNative(0xB796970BD125FCE8, MyTrain) -- PromptGetGroupIdForTargetEntity
            TriggerEvent('bcc-train:TargetPrompts', trainGroup, trainCfg)

            if Citizen.InvokeNative(0x580417101DDB492F, 0, Config.keys.fuel) then -- IsControlJustPressed
                local fuel = VORPcore.Callback.TriggerAwait(
                                 'bcc-train:FuelTrain', TrainId)
                if fuel then FuelUpdate(fuel) end

            elseif Citizen.InvokeNative(0x580417101DDB492F, 0,
                                        Config.keys.repair) then -- IsControlJustPressed
                local cond = VORPcore.Callback.TriggerAwait(
                                 'bcc-train:RepairTrain', TrainId)
                if cond then ConditionUpdate(cond) end
            end
        end
        ::continue::
        Wait(sleep)
    end
end)

-- Prompts
AddEventHandler('bcc-train:TargetPrompts', function(trainGroup, trainCfg)

    if not TargetPromptsStarted then
        local fuelStr = CreateVarString(10, 'LITERAL_STRING', _U('addFuel'))
        FuelTarget = PromptRegisterBegin()
        PromptSetControlAction(FuelTarget, Config.keys.fuel)
        PromptSetText(FuelTarget, fuelStr)
        PromptSetEnabled(FuelTarget, true)
        PromptSetVisible(FuelTarget, true)
        PromptSetStandardMode(FuelTarget, true)
        PromptSetGroup(FuelTarget, trainGroup)
        PromptRegisterEnd(FuelTarget)

        local repairStr = CreateVarString(10, 'LITERAL_STRING',
                                          _U('repairTrain'))
        RepairTarget = PromptRegisterBegin()
        PromptSetControlAction(RepairTarget, Config.keys.repair)
        PromptSetText(RepairTarget, repairStr)
        PromptSetEnabled(RepairTarget, true)
        PromptSetVisible(RepairTarget, true)
        PromptSetStandardMode(RepairTarget, true)
        PromptSetGroup(RepairTarget, trainGroup)
        PromptRegisterEnd(RepairTarget)

        TargetPromptsStarted = true
    end

    local alive = not IsPedDeadOrDying(PlayerPedId())
    if trainCfg.fuel.enabled and alive then
        PromptSetVisible(FuelTarget, true)
    else
        PromptSetVisible(FuelTarget, false)
    end

    if trainCfg.condition.enabled and alive then
        PromptSetVisible(RepairTarget, true)
    else
        PromptSetVisible(RepairTarget, false)
    end
end)

function StartMainPrompts()
    MenuPrompt = PromptRegisterBegin()
    PromptSetControlAction(MenuPrompt, Config.keys.station)
    PromptSetText(MenuPrompt,
                  CreateVarString(10, 'LITERAL_STRING', _U('openMainMenu')))
    PromptSetVisible(MenuPrompt, true)
    PromptSetStandardMode(MenuPrompt, true)
    PromptSetGroup(MenuPrompt, MenuGroup)
    PromptRegisterEnd(MenuPrompt)

    BridgePrompt = PromptRegisterBegin()
    PromptSetControlAction(BridgePrompt, Config.keys.bridge)
    PromptSetText(BridgePrompt,
                  CreateVarString(10, 'LITERAL_STRING', _U('blowUpBridge')))
    PromptSetEnabled(BridgePrompt, true)
    PromptSetVisible(BridgePrompt, true)
    Citizen.InvokeNative(0x74C7D7B72ED0D3CF, BridgePrompt, 'MEDIUM_TIMED_EVENT') -- PromptSetStandardizedHoldMode
    PromptSetGroup(BridgePrompt, BridgeGroup)
    PromptRegisterEnd(BridgePrompt)
end

function StartDeliveryPrompt()
    if not DeliveryPromptStarted then
        DeliveryPrompt = PromptRegisterBegin()
        PromptSetControlAction(DeliveryPrompt, Config.keys.delivery)
        PromptSetText(DeliveryPrompt,
                      CreateVarString(10, 'LITERAL_STRING', _U('start')))
        PromptSetEnabled(DeliveryPrompt, true)
        PromptSetVisible(DeliveryPrompt, true)
        Citizen.InvokeNative(0x74C7D7B72ED0D3CF, DeliveryPrompt,
                             'MEDIUM_TIMED_EVENT') -- PromptSetStandardizedHoldMode
        PromptSetGroup(DeliveryPrompt, DeliveryGroup)
        PromptRegisterEnd(DeliveryPrompt)

        DeliveryPromptStarted = true
    end
end
