-- ─────────────────────────────────────────────────────────────────
--  NUI menu helpers (replaces VORPMenu)
-- ─────────────────────────────────────────────────────────────────
local MenuCallbackStack = {} -- { onSelect, onBack }
DrivingTrainCfg = nil
DrivingTrainData = nil
DrivingSpeed = 0
CurrentMaxSpeed = 30
TrainCurrentSpeed = 0
MenuOpen = false
local function PushMenu(onSelect, onBack)
    table.insert(MenuCallbackStack, {
        onSelect = onSelect,
        onBack = onBack
    })
end

local function PopMenu()
    return table.remove(MenuCallbackStack)
end

-- hasCursor: true if driving panel is visible so cursor stays on
local function NuiFocusAfterClose()
    SetNuiFocus(DrivingMenuOpened, DrivingMenuOpened)
end

local function OpenNUIMenu(cfg)
    SendNUIMessage({
        type = 'showStationMenu',
        title = cfg.title or '',
        subtext = cfg.subtext or '',
        elements = cfg.elements or {},
        hasBack = cfg.hasBack or false
    })
    SetNuiFocus(true, true)
    PushMenu(cfg.onSelect, cfg.onBack)
    MenuOpen = true
end

-- ─────────────────────────────────────────────────────────────────
--  NUI CALLBACKS
-- ─────────────────────────────────────────────────────────────────
RegisterNUICallback('menuSelect', function(data, cb)
    cb('ok')
    local menu = PopMenu()
    NuiFocusAfterClose()
    if menu and menu.onSelect then
        Citizen.CreateThread(function()
            menu.onSelect(data)
        end)
    end
    MenuOpen = false
end)

RegisterNUICallback('menuBack', function(data, cb)
    cb('ok')
    local menu = PopMenu()
    NuiFocusAfterClose()
    if menu and menu.onBack then
        Citizen.CreateThread(function()
            menu.onBack()
        end)
    end
end)

RegisterNUICallback('menuClose', function(data, cb)
    cb('ok')
    MenuCallbackStack = {}
    NuiFocusAfterClose()
    SetNuiFocus(false, false)
    SendNUIMessage({
        type = 'closeStationMenu'
    })
    DisplayRadar(false)
    MenuOpen = false
end)

RegisterNUICallback('drivingAction', function(data, cb)
    cb('ok')
    Citizen.CreateThread(function()
        HandleDrivingAction(data.action, data.value)
    end)
end)

-- ─────────────────────────────────────────────────────────────────
--  DRIVING ACTIONS
-- ─────────────────────────────────────────────────────────────────
function HandleDrivingAction(action, value)
    if not DrivingTrainCfg then
        return
    end

    if action == 'setSpeed' then
        DrivingSpeed = value or 0
        -- MaxSpeedCalc(DrivingSpeed)  <-- TOTO ZAKOMENTUJ, RYCHLOST SI NYNÍ HLÍDÁ NOVÁ FYZIKA
        SendNUIMessage({
            type = 'updateDriving',
            speed = DrivingSpeed
        })

   elseif action == 'startEngine' then
        if TrainFuel >= 1 and TrainCondition >= 1 then
            VORPcore.NotifyRightTip(_U('engineStarted'), 4000)
            EngineStarted = true
            SendNUIMessage({ type = 'updateDriving', engineStarted = true })
            -- Smazali jsme volání MaxSpeedCalc, rychlost si řídí fyzika vlaku sama
        else
            VORPcore.NotifyRightTip(_U('checkTrain'), 4000)
        end

    elseif action == 'stopEngine' then
        VORPcore.NotifyRightTip(_U('engineStopped'), 4000)
        EngineStarted = false
        ForwardActive = false
        BackwardActive = false
        SendNUIMessage({
            type = 'updateDriving',
            engineStarted = false,
            forwardActive = false,
            backwardActive = false
        })
        -- Odstraněno: Citizen.InvokeNative(0x9F29999DFDF2AEB8, MyTrain, 0.0) pro plynulý dojezd vlaku po vypnutí motoru!

   elseif action == 'forward' then
        if not EngineStarted then return VORPcore.NotifyRightTip(_U('engineMustBeStarted'), 4000) end
        if BackwardActive then return VORPcore.NotifyRightTip(_U('backwardsIsOn'), 4000) end
        if ForwardActive then
            VORPcore.NotifyRightTip(_U('forwardDisbaled'), 4000)
            ForwardActive = false
            SendNUIMessage({ type = 'updateDriving', forwardActive = false })
            return
        end
        if TrainFuel <= 0 then return VORPcore.NotifyRightTip(_U('noCruiseNoFuel'), 4000) end
        
        if TrainCurrentSpeed < -0.5 then
            TrainCondition = math.max(0, TrainCondition - 15)
            ConditionUpdate(TrainCondition)
            VORPcore.NotifyRightTip("~r~Skřípot kovu!~q~ Zařazení vpřed během couvání poškodilo mechanismus!", 5000)
        end

        ForwardActive = true
        SendNUIMessage({ type = 'updateDriving', forwardActive = true })
        VORPcore.NotifyRightTip(_U('forwardEnabled'), 4000)
        
        while ForwardActive do
            Wait(1000)
            if not MyTrain then ForwardActive = false; break end
            local distance = #(GetEntityCoords(MyTrain) - vector3(517.56, 1757.27, 188.34))
            if distance <= 150 then -- Opravena vzdálenost z obřích 1000 na adekvátních 150 jednotek k mostu!
                VORPcore.NotifyRightTip(_U('cruiseDisabledInRegion'), 4000)
                ForwardActive = false
                SendNUIMessage({ type = 'updateDriving', forwardActive = false })
                break
            end
        end

    elseif action == 'backward' then
        if not EngineStarted then return VORPcore.NotifyRightTip(_U('engineMustBeStarted'), 4000) end
        if ForwardActive then return VORPcore.NotifyRightTip(_U('forwardsIsOn'), 4000) end
        if BackwardActive then
            VORPcore.NotifyRightTip(_U('backwardDisabled'), 4000)
            BackwardActive = false
            SendNUIMessage({ type = 'updateDriving', backwardActive = false })
            return
        end
        if TrainFuel <= 0 then return VORPcore.NotifyRightTip(_U('noCruiseNoFuel'), 4000) end

        if TrainCurrentSpeed > 0.5 then
            TrainCondition = math.max(0, TrainCondition - 15)
            ConditionUpdate(TrainCondition)
            VORPcore.NotifyRightTip("~r~Skřípot kovu!~q~ Zařazení zpátečky za jízdy drasticky poškodilo mechanismus!", 5000)
        end

        BackwardActive = true
        SendNUIMessage({ type = 'updateDriving', backwardActive = true })
        VORPcore.NotifyRightTip(_U('backwardEnabled'), 4000)
        
        while BackwardActive do
            Wait(1000)
            if not MyTrain then BackwardActive = false; break end
            local distance = #(GetEntityCoords(MyTrain) - vector3(517.56, 1757.27, 188.34))
            if distance <= 150 then -- Opravena vzdálenost z obřích 1000 na 150
                VORPcore.NotifyRightTip(_U('cruiseDisabledInRegion'), 4000)
                BackwardActive = false
                SendNUIMessage({ type = 'updateDriving', backwardActive = false })
                break
            end
        end

    elseif action == 'trackSwitch' then
        TrackSwitch(value == true or value == 'true')

    elseif action == 'deleteTrain' then
        TriggerEvent('bcc-train:ResetTrain')
        HideHUD()
        MenuOpen = false
    elseif action == 'closeHUD' then
        HideHUD()
        MenuOpen = false
    elseif action == 'boostBoiler' then
        if BoilerTempBoostActive then
            VORPcore.NotifyRightTip('Boost kotle je již aktivní!', 4000)
            return
        end
        local count = GetMyOilCount()
        if count <= 0 then
            VORPcore.NotifyRightTip('Nemáte ' .. Config.boilerTemp.boostItemName, 4000)
            return
        end
        local ok = VORPcore.Callback.TriggerAwait('bcc-train:UseBoilerOil')
        if ok then
            BoilerTempBoostActive = true
            BoilerTempBoostEndTime = GetGameTimer() + Config.boilerTemp.boostDuration * 1000
            VORPcore.NotifyRightTip('Teplota kotle posílena!', 4000)
        end
    elseif action == 'toggleCamera' then
        CameraMode = value
        if CameraMode then
            SetNuiFocus(false, false)
        else
            SetNuiFocus(true, true)
        end

    end

end

-- ─────────────────────────────────────────────────────────────────
--  GLOBÁLNÍ PROMĚNNÉ — kamera a tlak
-- ─────────────────────────────────────────────────────────────────
CameraMode = false
BoilerPistonPct = 0 -- aktuální % tlaku posílaného do pístů (z NUI)
BoilerBrakePct = 0 -- aktuální % tlaku posílaného do brzd (z NUI)

-- Callback: NUI posílá hodnoty tlaku každý tick (150 ms)
RegisterNUICallback('pressureUpdate', function(data, cb)
    cb('ok')
    BoilerPistonPct = data.pistons or 0
    BoilerBrakePct = data.brakes or 0
end)

-- ─────────────────────────────────────────────────────────────────
--  DRIVING MENU  (called when player sits in train)
-- ─────────────────────────────────────────────────────────────────
function DrivingMenu(trainCfg, myTrainData)
    DrivingTrainCfg = trainCfg
    DrivingTrainData = myTrainData
    DrivingSpeed = 0
    CurrentMaxSpeed = trainCfg.maxSpeed

    -- Close any open station menu
    SendNUIMessage({
        type = 'closeStationMenu'
    })
    MenuCallbackStack = {}

    -- Push driving state to panel
    SendNUIMessage({
        type = 'updateDriving',
        engineStarted = EngineStarted,
        forwardActive = ForwardActive,
        backwardActive = BackwardActive,
        speed = DrivingSpeed,
        maxSpeed = trainCfg.maxSpeed,
        cruiseControl = Config.cruiseControl
    })

    -- Show cursor so player can interact with the side panel
    SetNuiFocus(true, true)
end

function MaxSpeedCalc(speed)
    local eff = BoilerEfficiency or 1.0
    local s = speed * eff + 0.1
    if s >= 30.0 then
        s = 29.9
    end
    Citizen.InvokeNative(0x9F29999DFDF2AEB8, MyTrain, s) -- SetTrainMaxSpeed
end

-- ─────────────────────────────────────────────────────────────────
--  STATION MENUS
-- ─────────────────────────────────────────────────────────────────
function MainMenu(station)
    local elements = {{
        label = _U('ownedTrains'),
        value = 'owned',
        desc = _U('ownedTrains_desc')
    }, {
        label = _U('buyTrains'),
        value = 'buy',
        desc = _U('buyTrains_desc')
    }, {
        label = _U('sellTrains'),
        value = 'sell',
        desc = _U('sellTrains_desc')
    }, {
        label = _U('deliveryMission'),
        value = 'deliveryMission',
        desc = _U('deliveryMission_desc')
    }}
    OpenNUIMenu({
        title = Stations[station].shop.name,
        subtext = '',
        elements = elements,
        hasBack = false,
        onSelect = function(data)
            local v = data.value
            if v == 'owned' then
                local myTrains = VORPcore.Callback.TriggerAwait('bcc-train:GetMyTrains')
                if #myTrains <= 0 then
                    VORPcore.NotifyRightTip(_U('noOwnedTrains'), 4000)
                    MainMenu(station)
                else
                    OwnedMenu(myTrains, station)
                end

            elseif v == 'buy' then
                local myTrains = VORPcore.Callback.TriggerAwait('bcc-train:GetMyTrains')
                if #myTrains >= Config.maxTrains then
                    VORPcore.NotifyRightTip(_U('trainLimit') .. Config.maxTrains .. _U('trains'), 4000)
                    MainMenu(station)
                else
                    BuyMenu(myTrains, station)
                end

            elseif v == 'sell' then
                local myTrains = VORPcore.Callback.TriggerAwait('bcc-train:GetMyTrains')
                if #myTrains <= 0 then
                    VORPcore.NotifyRightTip(_U('noOwnedTrains'), 4000)
                    MainMenu(station)
                else
                    SellMenu(myTrains, station)
                end

            elseif v == 'deliveryMission' then
                if not MyTrain then
                    VORPcore.NotifyRightTip(_U('noTrain'), 4000)
                    MainMenu(station);
                    return
                end
                if InMission then
                    VORPcore.NotifyRightTip(_U('inMission'), 4000)
                    MainMenu(station);
                    return
                end
                local onCooldown = VORPcore.Callback.TriggerAwait('bcc-train:CheckPlayerCooldown', 'delivery')
                if onCooldown then
                    VORPcore.NotifyRightTip(_U('cooldown'), 4000)
                    MainMenu(station);
                    return
                end
                InMission = true
                SendNUIMessage({
                    type = 'closeStationMenu'
                })
                SetNuiFocus(false, false)
                DisplayRadar(false)
                DeliveryMission(station)
            end
        end,
        onBack = function()
            SetNuiFocus(false, false)
            DisplayRadar(false)
        end
    })
    DisplayRadar(false)
end

function BuyMenu(myTrains, station)
    local elements = {}
    local allOwned = false

    if #myTrains <= 0 then
        for train, trainCfg in pairs(Trains) do
            elements[#elements + 1] = {
                label = trainCfg.label,
                value = train,
                desc = _U('price') .. trainCfg.price .. '<br><br>' .. _U('maxSpeed') .. trainCfg.maxSpeed,
                info = trainCfg
            }
        end
    else
        for train, trainCfg in pairs(Trains) do
            local insert = true
            for _, d in pairs(myTrains) do
                if trainCfg.model == d.trainModel then
                    insert = false
                end
            end
            if insert then
                local wagons = "Engine: " .. trainCfg.Train .. " | People: " .. trainCfg.people .. " Cargo: " ..
                                   trainCfg.cargo
                elements[#elements + 1] = {
                    label = trainCfg.label,
                    value = train,
                    desc = _U('price') .. trainCfg.price .. '<br>' .. _U('maxSpeed') .. trainCfg.maxSpeed .. '<br>' ..
                        wagons,
                    info = trainCfg
                }
            end
        end
        if #elements <= 0 then
            allOwned = true
            elements = {{
                label = _U('ownAllTrains'),
                value = 'noBuy',
                desc = ''
            }}
        end
    end

    OpenNUIMenu({
        title = Stations[station].shop.name,
        subtext = _U('purchase'),
        elements = elements,
        hasBack = true,
        onSelect = function(data)
            if data.value ~= 'noBuy' then
                -- Locate trainCfg from elements
                for _, el in ipairs(elements) do
                    if el.value == data.value then
                        TriggerServerEvent('bcc-train:BuyTrain', el.info.model)
                        break
                    end
                end
            end
            MainMenu(station)
        end,
        onBack = function()
            MainMenu(station)
        end
    })
end

function OwnedMenu(myTrains, station)
    local elements = {}
    for _, trainCfg in pairs(Trains) do
        for myTrain, myTrainData in pairs(myTrains) do
            if myTrainData.trainModel == trainCfg.model then
                local wagons = "Engine: " .. trainCfg.Train .. " | People: " .. trainCfg.people
                elements[#elements + 1] = {
                    label = trainCfg.label,
                    value = myTrain,
                    desc = _U('maxSpeed') .. trainCfg.maxSpeed .. '<br>' .. _U('price') .. trainCfg.price .. '<br>' ..
                        wagons,
                    info = myTrainData
                }
            end
        end
    end

    OpenNUIMenu({
        title = Stations[station].shop.name,
        subtext = _U('selectTrain'),
        elements = elements,
        hasBack = true,
        onSelect = function(data)
            local canSpawn = VORPcore.Callback.TriggerAwait('bcc-train:CheckTrainSpawn')
            if not canSpawn then
                VORPcore.NotifyRightTip(_U('trainSpawnedAlrady'), 4000)
                OwnedMenu(myTrains, station)
                return
            end
            local trainData = nil
            for _, trainCfg in pairs(Trains) do
                if data.info and data.info.trainModel == trainCfg.model then
                    trainData = trainCfg;
                    break
                end
            end
            SendNUIMessage({
                type = 'closeStationMenu'
            })
            SetNuiFocus(false, false)
            DirectionMenu(trainData, data.info, station, myTrains)
        end,
        onBack = function()
            MainMenu(station)
        end
    })
end

function SellMenu(myTrains, station)
    local elements = {}
    for _, trainCfg in pairs(Trains) do
        for myTrain, myTrainData in pairs(myTrains) do
            if myTrainData.trainModel == trainCfg.model then
                elements[#elements + 1] = {
                    label = trainCfg.label,
                    value = myTrain,
                    desc = _U('sellPrice') .. (trainCfg.price * 0.6),
                    info = myTrainData
                }
            end
        end
    end

    OpenNUIMenu({
        title = Stations[station].shop.name,
        subtext = _U('sellTrains_sub'),
        elements = elements,
        hasBack = true,
        onSelect = function(data)
            local sold = VORPcore.Callback.TriggerAwait('bcc-train:SellTrain', data.info.trainid)
            if sold then
                MainMenu(station)
            else
                SellMenu(myTrains, station)
            end
        end,
        onBack = function()
            MainMenu(station)
        end
    })
end

function DirectionMenu(trainCfg, myTrainData, station, myTrains)
    local elements = {{
        label = _U('changeSpawnDir'),
        value = 'reverse',
        desc = _U('changeSpawnDir_desc')
    }, {
        label = _U('noChangeSpawnDir'),
        value = 'noChange',
        desc = _U('noChangeSpawnDir_desc')
    }}
    OpenNUIMenu({
        title = Stations[station].shop.name,
        subtext = '',
        elements = elements,
        hasBack = true,
        onSelect = function(data)
            SendNUIMessage({
                type = 'closeStationMenu'
            })
            SetNuiFocus(false, false)
            DisplayRadar(false)
            SpawnTrain(trainCfg, myTrainData, data.value == 'reverse', station)
        end,
        onBack = function()
            OwnedMenu(myTrains, station)
        end
    })
end
