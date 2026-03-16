-- Start Train
CreateThread(function()
    StartMainPrompts()
    SetRandomTrains(false)
    TriggerServerEvent('bcc-train:BridgeFallHandler', true)
    while true do
        local playerPed = PlayerPedId()
        local pCoords = GetEntityCoords(playerPed)
        local hour = GetClockHours()
        local sleep = 1000

        if IsEntityDead(playerPed) then
            PromptSetEnabled(MenuPrompt, false)
            PromptSetEnabled(BridgePrompt, false)
            goto continue
        end
        for station, stationCfg in pairs(Stations) do
            if stationCfg.shop.hours.active then
                -- Using Shop Hours - Shop Closed
                if hour >= stationCfg.shop.hours.close or hour < stationCfg.shop.hours.open then
                    if stationCfg.blip.show and stationCfg.blip.showClosed then
                        if not Stations[station].Blip then
                            AddBlip(station)
                        end
                        Citizen.InvokeNative(0x662D364ABF16DE2F, Stations[station].Blip,
                            joaat(Config.blipColors[stationCfg.blip.color.closed])) -- BlipAddModifier
                    else
                        if Stations[station].Blip then
                            RemoveBlip(Stations[station].Blip)
                            Stations[station].Blip = nil
                        end
                    end
                    if stationCfg.NPC then
                        DeleteEntity(stationCfg.NPC)
                        stationCfg.NPC = nil
                    end
                    local distance = #(pCoords - stationCfg.npc.coords)
                    if distance <= stationCfg.shop.distance then
                        sleep = 0
                        local shopClosed = CreateVarString(10, 'LITERAL_STRING',
                            stationCfg.shop.name .. _U('hours') .. stationCfg.shop.hours.open .. _U('to') ..
                                stationCfg.shop.hours.close .. _U('hundred'))
                        PromptSetActiveGroupThisFrame(MenuGroup, shopClosed)
                        PromptSetEnabled(MenuPrompt, false)
                    end
                elseif hour >= stationCfg.shop.hours.open then
                    -- Using Shop Hours - Shop Open
                    if stationCfg.blip.show then
                        if not Stations[station].Blip then
                            AddBlip(station)
                        end
                        Citizen.InvokeNative(0x662D364ABF16DE2F, Stations[station].Blip,
                            joaat(Config.blipColors[stationCfg.blip.color.open])) -- BlipAddModifier
                    end
                    if not stationCfg.shop.jobsEnabled then
                        local distance = #(pCoords - stationCfg.npc.coords)
                        if stationCfg.npc.active then
                            if distance <= stationCfg.npc.distance then
                                if not stationCfg.NPC then
                                    AddNPC(station)
                                end
                            else
                                if stationCfg.NPC then
                                    DeleteEntity(stationCfg.NPC)
                                    stationCfg.NPC = nil
                                end
                            end
                        end
                        if distance <= stationCfg.shop.distance then
                            sleep = 0
                            local shopOpen = CreateVarString(10, 'LITERAL_STRING', stationCfg.shop.prompt)
                            PromptSetActiveGroupThisFrame(MenuGroup, shopOpen)
                            PromptSetEnabled(MenuPrompt, true)

                            if Citizen.InvokeNative(0xC92AC953F0A982AE, MenuPrompt) then -- PromptHasStandardModeCompleted
                                MainMenu(station)
                            end
                        end
                    else
                        -- Using Shop Hours - Shop Open - Job Locked
                        if Stations[station].Blip then
                            Citizen.InvokeNative(0x662D364ABF16DE2F, Stations[station].Blip,
                                joaat(Config.blipColors[stationCfg.blip.color.job])) -- BlipAddModifier
                        end
                        local distance = #(pCoords - stationCfg.npc.coords)
                        if stationCfg.npc.active then
                            if distance <= stationCfg.npc.distance then
                                if not stationCfg.NPC then
                                    AddNPC(station)
                                end
                            else
                                if stationCfg.NPC then
                                    DeleteEntity(stationCfg.NPC)
                                    stationCfg.NPC = nil
                                end
                            end
                        end
                        if distance <= stationCfg.shop.distance then
                            sleep = 0
                            local shopOpen = CreateVarString(10, 'LITERAL_STRING', stationCfg.shop.prompt)
                            PromptSetActiveGroupThisFrame(MenuGroup, shopOpen)
                            PromptSetEnabled(MenuPrompt, true)

                            if Citizen.InvokeNative(0xC92AC953F0A982AE, MenuPrompt) then -- PromptHasStandardModeCompleted
                                local hasJob = VORPcore.Callback.TriggerAwait('bcc-train:JobCheck', station)
                                if hasJob then
                                    MainMenu(station)
                                else
                                    VORPcore.NotifyRightTip(_U('wrongJob'), 4000)
                                end
                            end
                        end
                    end
                end
            else
                -- Not Using Shop Hours - Shop Always Open
                if stationCfg.blip.show then
                    if not Stations[station].Blip then
                        AddBlip(station)
                    end
                    Citizen.InvokeNative(0x662D364ABF16DE2F, Stations[station].Blip,
                        joaat(Config.blipColors[stationCfg.blip.color.open])) -- BlipAddModifier
                end
                if not stationCfg.shop.jobsEnabled then
                    local distance = #(pCoords - stationCfg.npc.coords)
                    if stationCfg.npc.active then
                        if distance <= stationCfg.npc.distance then
                            if not stationCfg.NPC then
                                AddNPC(station)
                            end
                        else
                            if stationCfg.NPC then
                                DeleteEntity(stationCfg.NPC)
                                stationCfg.NPC = nil
                            end
                        end
                    end
                    if distance <= stationCfg.shop.distance then
                        sleep = 0
                        local shopOpen = CreateVarString(10, 'LITERAL_STRING', stationCfg.shop.prompt)
                        PromptSetActiveGroupThisFrame(MenuGroup, shopOpen)
                        PromptSetEnabled(MenuPrompt, true)

                        if Citizen.InvokeNative(0xC92AC953F0A982AE, MenuPrompt) then -- PromptHasStandardModeCompleted
                            MainMenu(station)
                        end
                    end
                else
                    -- Not Using Shop Hours - Shop Always Open - Job Locked
                    if Stations[station].Blip then
                        Citizen.InvokeNative(0x662D364ABF16DE2F, Stations[station].Blip,
                            joaat(Config.blipColors[stationCfg.blip.color.job])) -- BlipAddModifier
                    end
                    local distance = #(pCoords - stationCfg.npc.coords)
                    if stationCfg.npc.active then
                        if distance <= stationCfg.npc.distance then
                            if not stationCfg.NPC then
                                AddNPC(station)
                            end
                        else
                            if stationCfg.NPC then
                                DeleteEntity(stationCfg.NPC)
                                stationCfg.NPC = nil
                            end
                        end
                    end
                    if distance <= stationCfg.shop.distance then
                        sleep = 0
                        local shopOpen = CreateVarString(10, 'LITERAL_STRING', stationCfg.shop.prompt)
                        PromptSetActiveGroupThisFrame(MenuGroup, shopOpen)
                        PromptSetEnabled(MenuPrompt, true)

                        if Citizen.InvokeNative(0xC92AC953F0A982AE, MenuPrompt) then -- PromptHasStandardModeCompleted
                            local hasJob = VORPcore.Callback.TriggerAwait('bcc-train:JobCheck', station)
                            if hasJob then
                                MainMenu(station)
                            else
                                VORPcore.NotifyRightTip(_U('wrongJob'), 4000)
                            end
                        end
                    end
                end
            end
        end
        ::continue::
        Wait(sleep)
    end
end)

-- Sdílené spuštění handlerů – volá se jak ze SpawnTrain, tak z TakeoverTrain
function SetupTrainHandlers(trainCfg, myTrainData)
    if trainCfg.blip.show then
        local trainBlip = Citizen.InvokeNative(0x23f74c2fda6e7c61, -1749618580, MyTrain) -- BlipAddForEntity
        SetBlipSprite(trainBlip, joaat(trainCfg.blip.sprite), true)
        Citizen.InvokeNative(0x9CB1A1623062F402, trainBlip, trainCfg.blip.name) -- SetBlipNameFromPlayerString
        Citizen.InvokeNative(0x662D364ABF16DE2F, trainBlip, joaat(Config.blipColors[trainCfg.blip.color])) -- BlipAddModifier
    end

    if trainCfg.inventory.enabled then
        TriggerServerEvent('bcc-train:RegisterInventory', TrainId)
    end

    if trainCfg.fuel.enabled then
        TriggerEvent('bcc-train:FuelDecreaseHandler', trainCfg, myTrainData)
    end

    if trainCfg.condition.enabled then
        TriggerEvent('bcc-train:CondDecreaseHandler', trainCfg, myTrainData)
    end

    if trainCfg.fuel.enabled or trainCfg.condition.enabled then
        TriggerEvent('bcc-train:TargetMenu', trainCfg)
    end
    TriggerEvent('bcc-train:TrainHandler', trainCfg, myTrainData)
    TriggerEvent('bcc-train:TrainActions')
    TriggerEvent('bcc-train:BoilerHandler', trainCfg)
end

function SpawnTrain(trainCfg, myTrainData, dirChange, station) -- credit to rsg_trains for some of the logic here
    local model = trainCfg.model
    local trainHash = joaat(model)
    if trainCfg.hash then
        trainHash = trainCfg.hash
    end
    TrainFuel = myTrainData.fuel
    TrainCondition = myTrainData.condition
    TrainId = myTrainData.trainid

    LoadTrainCars(trainHash)
    MyTrain = Citizen.InvokeNative(0xc239dbd9a57d2a71, trainHash, Stations[station].train.coords, dirChange, false,
        true, false) -- CreateMissionTrain
    SetModelAsNoLongerNeeded(model)
    -- Freeze Train on Spawn
    Citizen.InvokeNative(0xDFBA6BBFF7CCAFBB, MyTrain, 0.0) -- SetTrainSpeed
    Citizen.InvokeNative(0x01021EB2E96B793C, MyTrain, 0.0) -- SetTrainCruiseSpeed

    -- Posíláme network ID (ne lokální entity handle) + trainId pro server-side tracking
    TriggerServerEvent('bcc-train:UpdateTrainSpawnVar', true, NetworkGetNetworkIdFromEntity(MyTrain), TrainId)

    SetupTrainHandlers(trainCfg, myTrainData)
end

AddEventHandler('bcc-train:TrainHandler', function(trainCfg, myTrainData)
    DrivingMenuOpened = false
    while MyTrain do
        local sleep = 1000
        local playerPed = PlayerPedId()
        local isDead = IsEntityDead(playerPed)
        local distance = #(GetEntityCoords(playerPed) - GetEntityCoords(MyTrain))
        if distance >= Config.despawnDist or isDead then
            if MyTrain then
                if not isDead then
                    VORPcore.NotifyRightTip(_U('tooFarFromTrain'), 4000)
                end
                -- Uvolni vlak k převzetí místo smazání
                MyTrain = nil  -- ukončí všechny while MyTrain smyčky okamžitě
                TriggerServerEvent('bcc-train:AbandonTrain')
                break
            end
        elseif distance <= 10 then
            sleep = 0
            if not Citizen.InvokeNative(0xE052C1B1CAA4ECE4, MyTrain, -1) and GetPedInVehicleSeat(MyTrain, -1) ==
                playerPed then -- IsVehicleSeatFree
                if not DrivingMenuOpened then
                    DrivingMenuOpened = true
                    DrivingMenu(trainCfg, myTrainData)
                    ShowHUD(TrainCondition, trainCfg.condition.maxAmount, TrainFuel, trainCfg.fuel.maxAmount)
                end
            else
                if DrivingMenuOpened then
                    DrivingMenuOpened = false
                    SendNUIMessage({ type = 'closeStationMenu' })
                    HideHUD()
                    ForwardActive = false
                    BackwardActive = false
                end
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('bcc-train:FuelDecreaseHandler', function(trainCfg, myTrainData)
    local fuelEmpty = false
    while MyTrain do
        Wait(1000)
        if EngineStarted and TrainFuel >= 1 then
            Wait(trainCfg.fuel.decreaseTime * 1000)
            local fuel = VORPcore.Callback.TriggerAwait('bcc-train:DecTrainFuel', TrainId)
            if fuel then
                FuelUpdate(fuel)
            end
        else
            Citizen.InvokeNative(0x9F29999DFDF2AEB8, MyTrain, 0.0) -- SetTrainMaxSpeed
        end
        if (TrainFuel or 0) <= 0 and not fuelEmpty then
            fuelEmpty = true
            EngineStarted = false
            ForwardActive  = false
            BackwardActive = false
            Citizen.InvokeNative(0x9F29999DFDF2AEB8, MyTrain, 0.0) -- SetTrainMaxSpeed
            if DrivingMenuOpened then
                SendNUIMessage({ type = 'updateDriving', engineStarted = false, forwardActive = false, backwardActive = false })
            end
        elseif fuelEmpty and TrainFuel >= 1 then
            fuelEmpty = false
        end
    end
end)

AddEventHandler('bcc-train:CondDecreaseHandler', function(trainCfg, myTrainData)
    local conditionEmpty = false
    while MyTrain do
        Wait(1000)
        if EngineStarted and TrainCondition >= 1 then
            Wait(trainCfg.condition.decreaseTime * 1000)
            local cond = VORPcore.Callback.TriggerAwait('bcc-train:DecTrainCond', TrainId)
            if cond then
                ConditionUpdate(cond)
            end
        else
            Citizen.InvokeNative(0x9F29999DFDF2AEB8, MyTrain, 0.0) -- SetTrainMaxSpeed
        end
        if (TrainCondition or 0) <= 0 and not conditionEmpty then
            conditionEmpty = true
            EngineStarted = false
            ForwardActive  = false
            BackwardActive = false
            Citizen.InvokeNative(0x9F29999DFDF2AEB8, MyTrain, 0.0) -- SetTrainMaxSpeed
            if DrivingMenuOpened then
                SendNUIMessage({ type = 'updateDriving', engineStarted = false, forwardActive = false, backwardActive = false })
            end
        elseif conditionEmpty and TrainCondition >= 1 then
            conditionEmpty = false
        end
    end
end)

-- Open Train Inventory + camera mode toggle
AddEventHandler('bcc-train:TrainActions', function()
    local invKey    = Config.keys.inventory
    local spaceKey  = joaat("INPUT_JUMP")  -- mezerník / skok
    while MyTrain do
        local playerPed = PlayerPedId()
        Wait(0)

        -- Vrácení z kamera módu: mezerník detekuje Lua (NUI nemá focus)
        if CameraMode and DrivingMenuOpened then
            if Citizen.InvokeNative(0x580417101DDB492F, 0, spaceKey) then -- IsControlJustPressed
                CameraMode = false
                SetNuiFocus(true, true)
                SendNUIMessage({ type = 'setCameraMode', value = false })
            end
            goto continue  -- v kamera módu přeskočíme zbytek
        end

        -- Inventář
        if Citizen.InvokeNative(0x580417101DDB492F, 0, invKey) then -- IsControlJustPressed
            if not Citizen.InvokeNative(0x6F972C1AB75A1ED0, playerPed) then -- IsPedInAnyTrain
                goto continue
            end
            local dist = #(GetEntityCoords(playerPed) - GetEntityCoords(MyTrain))
            if dist <= 10 then
                TriggerServerEvent('bcc-train:OpenInventory', TrainId)
            end
        end

        ::continue::
    end
end)

-- ─────────────────────────────────────────────────────────────────
--  BOILER HANDLER — tlak a teplota kotle
-- ─────────────────────────────────────────────────────────────────
BoilerPressure = 0
RegisterNetEvent('bcc-train:BoilerHandler')
AddEventHandler('bcc-train:BoilerHandler', function(trainCfg)
    BoilerPressure = 0
    BoilerTemp     = 0
    
    local tickMs        = 100 -- Zrychleno na 100 ms pro plynulou fyziku jízdy!
    local buildPerTick  = 100 / (Config.boiler.buildTime  * (1000 / tickMs))
    local drainPerTick  = 100 / (Config.boiler.drainTime  * (1000 / tickMs))
    local lastSent      = -1

    local tempBuildPerTick = 100 / (Config.boilerTemp.buildTime * (1000 / tickMs))
    local tempDrainPerTick = 100 / (Config.boilerTemp.drainTime * (1000 / tickMs))
    local lastTempSent     = -1

    TrainCurrentSpeed      = 0.0 -- Globální sledování rychlosti (využívá menuSetup.lua pro penalizace)
    local lastPistonPct    = 0   -- Slouží k detekci prudkého zatáhnutí pístů

    while MyTrain do
        Wait(tickMs)

        -- =========================================================
        -- 1. SKOKOVÁ ZTRÁTA TLAKU PŘI PRUDKÉM OTEVŘENÍ PÍSTŮ
        -- =========================================================
        local pistonDelta = BoilerPistonPct - lastPistonPct
        if pistonDelta > 10 then 
            -- Např. skok z 0 na 100 % = ztráta 25 % tlaku okamžitě
            local shockDrain = pistonDelta * 0.25
            BoilerPressure = math.max(0, BoilerPressure - shockDrain)
        end
        lastPistonPct = BoilerPistonPct

        -- =========================================================
        -- 2. BUDOVÁNÍ TLAKU (Násobeno teplotou a olejem)
        -- =========================================================
        if EngineStarted then
            local currentBuild = buildPerTick * BoilerEfficiency
            BoilerPressure = math.min(100, BoilerPressure + currentBuild)
        else
            BoilerPressure = math.max(0, BoilerPressure - drainPerTick)
        end

        -- =========================================================
        -- 3. SPOTŘEBA TLAKU (Běžný odtok do pístů)
        -- =========================================================
        local totalUsagePct = (BoilerPistonPct + BoilerBrakePct) / 100
        local consumeDrain  = totalUsagePct * Config.boiler.consumptionRate * (tickMs / 1000)
        BoilerPressure = math.max(0, BoilerPressure - consumeDrain)

        -- Odeslání updatů tlaku do NUI (Optimalizováno)
        local rounded = math.floor(BoilerPressure * 10 + 0.5) / 10
        if math.abs(rounded - lastSent) >= 0.5 then
            lastSent = rounded
            if DrivingMenuOpened then
                SendNUIMessage({ type = 'boilerUpdate', pressure = rounded })
            end
        end

        -- Konflikt poškozování (brzdy a plyn naráz nad limitem)
        local conflict = BoilerPistonPct > Config.boiler.damageThreshold
                      and BoilerBrakePct  > Config.boiler.damageThreshold
        if DrivingMenuOpened and conflict and TrainCondition > 0 then
            TrainCondition = math.max(0, TrainCondition - Config.boiler.damageRate * (tickMs / 1000))
            ConditionUpdate(TrainCondition)
        end
        if DrivingMenuOpened then
            SendNUIMessage({ type = 'conflictDamage', active = conflict })
        end

        -- =========================================================
        -- 4. TEPLOTA KOTLE A BOOST
        -- =========================================================
        local maxTemp = 100
        if BoilerTempBoostActive then
            maxTemp = 100 + Config.boilerTemp.boostAmount
            if GetGameTimer() >= BoilerTempBoostEndTime then
                BoilerTempBoostActive = false
                maxTemp = 100
            end
        end

        if EngineStarted then
            BoilerTemp = math.min(maxTemp, BoilerTemp + tempBuildPerTick)
        else
            BoilerTemp = math.max(0, BoilerTemp - tempDrainPerTick)
        end

        -- Přepočet koeficientu výkonu lokomotivy
        BoilerEfficiency = CalcTempEfficiency(BoilerTemp)

        -- Update UI teploměru
        local tempRounded = math.floor(BoilerTemp * 10 + 0.5) / 10
        if math.abs(tempRounded - lastTempSent) >= 0.5 then
            lastTempSent = tempRounded
            if DrivingMenuOpened then
                SendNUIMessage({ type = 'boilerTempUpdate', temp = tempRounded, boostActive = BoilerTempBoostActive })
            end
        end

        -- =========================================================
        -- 5. FYZIKA VLAKU A SETRVAČNOST
        -- =========================================================
        local targetDir = 0
        if ForwardActive then targetDir = 1
        elseif BackwardActive then targetDir = -1
        end

        -- Aby měl vlak plnou sílu na max rychlost, musí mít v kotli tlak aspoň 25 %
        local pressureFactor = math.min(1.0, BoilerPressure / 25.0) 
        local powerSpeed = (BoilerPistonPct / 100) * CurrentMaxSpeed * pressureFactor * BoilerEfficiency

        if EngineStarted and targetDir ~= 0 then
            local targetVelocity = powerSpeed * targetDir
            
            if targetDir > 0 then
                -- Jízda Vpřed
                if TrainCurrentSpeed < targetVelocity then
                    TrainCurrentSpeed = TrainCurrentSpeed + 0.10 -- Akcelerace (tah pístů)
                    if TrainCurrentSpeed > targetVelocity then TrainCurrentSpeed = targetVelocity end
                elseif TrainCurrentSpeed > targetVelocity then
                    TrainCurrentSpeed = TrainCurrentSpeed - 0.02 -- Vypnutí pístů = extrémně dlouhá setrvačnost (coasting)
                    if TrainCurrentSpeed < targetVelocity then TrainCurrentSpeed = targetVelocity end
                end
            elseif targetDir < 0 then
                -- Jízda Vzad (Couvání do mínusu)
                if TrainCurrentSpeed > targetVelocity then
                    TrainCurrentSpeed = TrainCurrentSpeed - 0.10 
                    if TrainCurrentSpeed < targetVelocity then TrainCurrentSpeed = targetVelocity end
                elseif TrainCurrentSpeed < targetVelocity then
                    TrainCurrentSpeed = TrainCurrentSpeed + 0.02 
                    if TrainCurrentSpeed > targetVelocity then TrainCurrentSpeed = targetVelocity end
                end
            end
        else
            -- Plný neutrál (vyřazen směr) -> Volnoběh (Coasting)
            if TrainCurrentSpeed > 0 then
                TrainCurrentSpeed = math.max(0.0, TrainCurrentSpeed - 0.02)
            elseif TrainCurrentSpeed < 0 then
                TrainCurrentSpeed = math.min(0.0, TrainCurrentSpeed + 0.02)
            end
        end

        -- =========================================================
        -- 6. BRZDY (Vždy přebíjí akceleraci)
        -- =========================================================
        if BoilerBrakePct > 0 then
            -- 0.5 rychlosti za tick (100 ms) znamená prudké zastavení při 100% zatažení brzd
            local brakeForce = (BoilerBrakePct / 100) * 0.5 
            if TrainCurrentSpeed > 0 then
                TrainCurrentSpeed = math.max(0.0, TrainCurrentSpeed - brakeForce)
            elseif TrainCurrentSpeed < 0 then
                TrainCurrentSpeed = math.min(0.0, TrainCurrentSpeed + brakeForce)
            end
        end

        -- Limitace absolutní max rychlosti definované v configu vlaku
        if TrainCurrentSpeed > CurrentMaxSpeed then TrainCurrentSpeed = CurrentMaxSpeed end
        if TrainCurrentSpeed < -CurrentMaxSpeed then TrainCurrentSpeed = -CurrentMaxSpeed end

        -- =========================================================
        -- 7. UPDATE TACHOMETRU A NATIVES (Přebití AI hry)
        -- =========================================================
        local absSpeed = math.abs(TrainCurrentSpeed)
        
        -- Zobrazení fyzikální rychlosti v UI
        local displaySpeed = math.floor(absSpeed * 10 + 0.5) / 10
        if DrivingMenuOpened then
            SendNUIMessage({ type = 'updateDriving', speed = displaySpeed })
        end

        -- Přinucení enginu hry, aby vlaku neurčoval rychlost 0 a necukal s ním
        Citizen.InvokeNative(0x9F29999DFDF2AEB8, MyTrain, absSpeed) -- SetTrainMaxSpeed (vždy kladné)
        Citizen.InvokeNative(0x01021EB2E96B793C, MyTrain, TrainCurrentSpeed) -- SetTrainCruiseSpeed (podporuje mínusové hodnoty)
        Citizen.InvokeNative(0xDFBA6BBFF7CCAFBB, MyTrain, TrainCurrentSpeed) -- SetTrainSpeed (vynucení hybnosti)
    end

    -- Cleanup při vystoupení / smazání vlaku
    BoilerPressure   = 0
    BoilerTemp       = 0
    BoilerEfficiency = 1.0
    TrainCurrentSpeed = 0.0
end)

-- Cleanup
AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
        return
    end
    if MyTrain then
        DeleteEntity(MyTrain)
        HideHUD()
    end
    for _, stationCfg in pairs(Stations) do
        if stationCfg.Blip then
            RemoveBlip(stationCfg.Blip)
            stationCfg.Blip = nil
        end
        if stationCfg.NPC then
            DeleteEntity(stationCfg.NPC)
            stationCfg.NPC = nil
        end
    end
    SendNUIMessage({ type = 'closeStationMenu' })
    SetNuiFocus(false, false)
    DisplayRadar(true)
    if DestinationBlip then
        RemoveBlip(DestinationBlip)
        DestinationBlip = nil
    end
    if DeliveryBlip then
        RemoveBlip(DeliveryBlip)
        DeliveryBlip = nil
    end
    for _, blip in pairs(OtherTrainBlips) do
        RemoveBlip(blip)
    end
    OtherTrainBlips = {}
end)

-- Poznámka: uvolnění vlaku při odpojení/pádu je řešeno server-side handlerem
-- v server/server.lua (playerDropped). Client-side handler zde by se nespustil
-- pro hráče, jehož hra crashla.

RegisterCommand('train', function()
    local trainTrack, junctionIndex = Citizen.InvokeNative(0x09034479E6E3E269, MyTrain, Citizen.PointerValueInt(), Citizen.PointerValueInt())
    print(trainTrack)
    print(junctionIndex)
end)


function drawMarker(x, y, z, r, g, b)
    Citizen.InvokeNative(0x2A32FAA57B937173, 0x94FDAE17, x, y, z, 0, 0, 0, 0.0, 0.0, 0.0, 1.0, 1.0, 0.4, r, g, b, 150.0,
        0, 0, 2, 0, 0, 0, 0)
end

function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = GetScreenCoordFromWorldCoord(x, y, z)
    local px, py, pz = table.unpack(GetGameplayCamCoord())
    local dist = GetDistanceBetweenCoords(px, py, pz, x, y, z, 1)
    local scale = (2 / dist) * 2.0

    local str = CreateVarString(10, "LITERAL_STRING", text, Citizen.ResultAsLong())
    local fov = (2 / GetGameplayCamFov()) * 100
    local scale = scale * fov
    if onScreen then
        SetTextScale(0.18 * scale, 0.18 * scale)
        SetTextFontForCurrentCommand(1)
        SetTextColor(180, 180, 240, 205)
        SetTextCentre(1)
        DisplayText(str, _x, _y)
        local factor = (string.len(text)) / 355
    end
end

Junctions = {{
    name = "Annesburg Sever",
    coords = vector3(3033.574707, 1482.612671, 49.630657),
    track1 = vector3(3022.072998, 1473.614746, 48.623791),
    track2 = vector3(3022.548096, 1467.882080, 48.287476)
}, {
    name = "Annesburg město 1",
    coords = vector3(2940.687744, 1373.550171, 43.883778),
    track1 = vector3(2938.450684, 1356.988037, 44.115356),
    track2 = vector3(2932.744629, 1352.640747, 43.973007)
}, {
    name = "Annesburg město 2",
    coords = vector3(2885.031982, 1226.897461, 44.799953),
    track1 = vector3(2896.537354, 1243.361572, 44.676441),
    track2 = vector3(2895.230957, 1248.475220, 44.602673)
}, {
    name = "Annesburg Jih",
    coords = vector3(2872.032471, 1197.534790, 45.100624),
    track2 = vector3(2886.129883, 1213.337402, 44.923492),
    track1 = vector3(2880.656494, 1216.487549, 45.008194),
    track = "FREIGHT_GROUP",
    junctionIndex = 1
}, {
    name = "SaintDenis 1",
    coords = vector3(2514.877930, -1482.208252, 45.942749),
    track1 = vector3(2495.069336, -1479.130005, 45.970329),
    track2 = vector3(2491.045410, -1482.287720, 46.008759),
    track = "TRAINS_OLD_WEST01",
    junctionIndex = 1
}, {
    name = "Emerald 1",
    coords = vector3(1691.414062, 544.387634, 98.476357),
    track1 = vector3(1663.304565, 541.806030, 96.103088),
    track2 = vector3(1660.655396, 545.266418, 96.050957),
    track = "TRAINS3",
    junctionIndex = 1
}, {
    name = "Emerald 2",
    coords = vector3(1529.954956, 465.333221, 90.221588),
    track1 = vector3(1529.339966, 501.765442, 89.659874),
    track2 = vector3(1535.521362, 497.633850, 89.607521),
    track = "BRAITHWAITES2_TRACK_CONFIG",
    junctionIndex = 1
}, {
    name = "Emerald 3",
    coords = vector3(1485.075439, 645.549805, 92.354111),
    track1 = vector3(1501.112671, 628.676270, 92.628242),
    track2 = vector3(1508.364502, 628.781616, 92.657631),
    track = "TRAINS3",
    junctionIndex = 1
}, {
    name = "FlatNeck 1",
    coords = vector3(32.251190, -27.353247, 103.268005),
    track1 = vector3(15.403493, -69.931618, 104.444595),
    track2 = vector3(13.784247, -64.693199, 104.382614),
    track = "TRAINS3",
    junctionIndex = 1
}, {
    name = "FlatNeck 2",
    coords = vector3(68.262428, -374.338287, 90.932365),
    track1 = vector3(51.954693, -363.582764, 91.229767),
    track2 = vector3(49.394257, -368.076630, 91.271355),
    track = "FREIGHT_GROUP",
    junctionIndex = 1
}, {
    name = "FlatNeck 3",
    coords = vector3(-277.306274, -317.675354, 89.007538),
    track1 = vector3(-246.608749, -300.591949, 89.026062),
    track2 = vector3(-242.577606, -302.040802, 89.096382),
    track = "FREIGHT_GROUP",
    junctionIndex = 1
}, {
    name = "Diablo 1",
    coords = vector3(-1307.491699, -290.815125, 101.024071),
    track2 = vector3(-1310.692993, -265.475830, 100.940880),
    track1 = vector3(-1314.540527, -263.657104, 100.931465),
    track = "trains3",
    junctionIndex = 1
}, {
    name = "Diablo 2",
    coords = vector3(-1377.212769, -134.871994, 100.872391),
    track2 = vector3(-1358.621094, -156.897263, 100.926537),
    track1 = vector3(-1358.174072, -163.589706, 100.899452),
    track = "trains3",
    junctionIndex = 1
}, {
    name = "Baccus 1",
    coords = vector3(557.308899, 1725.832886, 187.811768),
    track2 = vector3(565.925476, 1718.942017, 187.804733),
    track1 = vector3(562.673340, 1716.587280, 187.644226),
    track = "trains3",
    junctionIndex = 1
}, {
    name = "Baccus 2",
    coords = vector3(612.030212, 1658.744141, 187.370377),
    track2 = vector3(603.907532, 1675.234009, 187.426025),
    track1 = vector3(603.019043, 1670.616943, 187.378799),
    track = "trains3",
    junctionIndex = 1
}, {
    name = "ARM 1",
    coords = vector3(-2215.369629, -2518.896484, 65.702164),
    track2 = vector3(-2204.773193, -2523.334473, 65.931046),
    track1 = vector3(-2199.671631, -2520.815186, 65.891998),
    track = "trains3",
    junctionIndex = 1
}, {
    name = "ARM 2",
    coords = vector3(612.030212, 1658.744141, 187.370377),
    track2 = vector3(603.907532, 1675.234009, 187.426025),
    track1 = vector3(603.019043, 1670.616943, 187.378799),
    track = "trains3",
    junctionIndex = 1
}, {
    name = "Ben 1",
    coords = vector3(-4847.458008, -3086.713135, -15.706179),
    track2 = vector3(-4866.940918, -3082.118408, -16.095512),
    track1 = vector3(-4869.788086, -3076.750000, -16.242447),
    track = "trains3",
    junctionIndex = 1
}, {
    name = "Ben 2",
    coords = vector3(-4917.662598, -3007.376465, -18.231289),
    track1 = vector3(-4906.977051, -3025.554199, -17.837807),
    track2 = vector3(-4908.475098, -3032.170166, -17.751568),
    track = "trains3",
    junctionIndex = 1
}, {
    name = "Ben 3",
    coords = vector3(2659.942139, -437.593689, 43.388462),
    track1 = vector3(2659.627197, -408.133423, 43.476681),
    track2 = vector3(2665.962158, -398.157990, 43.396107),
    track = "trains3",
    junctionIndex = 1
},
{
    name = "Old West 1",
    coords = vector3(-1627.420044, -2326.340088, 44.330002),
    track1 = vector3(-1630.926514, -2308.498047, 45.218784),
    track2 = vector3(-1639.758423, -2309.636719, 45.155766),
    track = "trains_old_west01",
    junctionIndex = 1
}
,
{
    name = "Old West 2",
    coords = vector3(-2510.020020, -2372.770020, 60.020000),
    track1 = vector3(-2501.413574, -2341.509766, 62.685886),
    track2 = vector3(-2508.441895, -2347.535645, 62.123573),
    track = "trains_old_west01",
    junctionIndex = 1
},
{
    name = "Old West 3",
    coords = vector3(-2174.406250, -2509.110596, 65.804878),
    track1 = vector3(-2199.934082, -2520.785645, 65.898689),
    track2 = vector3(-2178.746094, -2525.684082, 66.028557),
    track = "trains_old_west01",
    junctionIndex = 1
},
{
    name = "Old West 4",
    coords = vector3(-2159.443604, -2540.838867, 67.842941),
    track1 = vector3(-2186.834717, -2529.749268, 66.295631),
    track2 = vector3(-2179.162598, -2525.189697, 65.989052),
    track = "trains_old_west01",
    junctionIndex = 1
}
,
{
    name = "Rigs Cross 1",
    coords = vector3(-1007.670898, -709.998108, 65.196518),
    track2 = vector3(-1005.099243, -678.735352, 68.786194),
    track1 = vector3(-1011.117737, -672.726013, 69.467293),
    junctionIndex = 1
}
,
{
    name = "Rigs Cross 2",
    coords = vector3(-937.046936, -635.700623, 72.720558),
    track2 = vector3(-973.876099, -634.156433, 73.426010),
    track1 = vector3(-979.126831, -643.368774, 73.465797),
    junctionIndex = 1
},
{
    name = "Rigs Cross 3",
    coords = vector3(-1053.802124, -611.634155, 77.262756),
    track2 = vector3(-1030.897095, -621.073486, 75.096199),
    track1 = vector3(-1028.029053, -629.928040, 74.785072),
    junctionIndex = 1
}

,
{
    name = "BW Cross 1",
    coords = vector3(-1007.600159, -990.305115, 61.329205),
    track1 = vector3(-1010.983582, -1023.050232, 60.990826),
    track2 = vector3(-1004.002502, -1029.841309, 60.756386),
    junctionIndex = 1
}
,
{
    name = "BW Cross 2",
    coords = vector3(-1069.656128, -1090.383301, 62.070637),
    track2 = vector3(-1048.192749, -1078.441895, 60.959965),
    track1 = vector3(-1037.042603, -1080.799805, 60.593048),
    junctionIndex = 1
},
{
    name = "BW Cross 3",
    coords =vector3(-939.449463, -1123.162231, 51.054241),
    track2 = vector3(-976.829895, -1084.106445, 56.659454),
    track1 = vector3(-976.548340, -1094.416016, 56.041012),
    junctionIndex = 1
}
}

-- Vizuální zobrazení výhybek: zelená = aktivní trať, oranžová = neaktivní
CreateThread(function()
    while not LocalPlayer.state or not LocalPlayer.state.Character do Wait(1000) end
    while true do
        local pause = 1000
        if LocalPlayer.state.Character and LocalPlayer.state.Character.Job == Config.Job then
            local playerCoords = GetEntityCoords(PlayerPedId())
            for _, junction in ipairs(Junctions) do
                if #(playerCoords - junction.coords) <= 80.0 then
                    pause = 1
                    local state = TrackSwitchActive
                    local stateLabel = state and " [\u{2192} přepnuto]" or " [\u{2192} výchozí]"
                    DrawText3D(junction.coords.x, junction.coords.y, junction.coords.z + 1.0, junction.name .. stateLabel)
                    if state then
                        drawMarker(junction.track1.x, junction.track1.y, junction.track1.z, 0, 220, 0)
                        drawMarker(junction.track2.x, junction.track2.y, junction.track2.z, 220, 80, 0)
                    else
                        drawMarker(junction.track1.x, junction.track1.y, junction.track1.z, 220, 80, 0)
                        drawMarker(junction.track2.x, junction.track2.y, junction.track2.z, 0, 220, 0)
                    end
                end
            end
        end
        Wait(pause)
    end
end)



CreateThread(function()
    repeat Wait(5000) until LocalPlayer.state.IsInSession
    local isNuiFocused = false

    while true do
        local sleep = 0
        if MenuOpen then
            if not isNuiFocused then
                SetNuiFocusKeepInput(true)
                isNuiFocused = true
            end

            DisableAllControlActions(0)
            EnableControlAction(0, GetHashKey("INPUT_PUSH_TO_TALK"), true)

            -- ==== PŘIDANÁ ČÁST PRO KAMERA MÓD ====
            if CameraMode then
                -- Povolit stisk mezerníku pro návrat zpět
                EnableControlAction(0, joaat("INPUT_JUMP"), true)
                -- Povolit rozhlížení myší / ovladačem
                EnableControlAction(0, joaat("INPUT_LOOK_LR"), true)
                EnableControlAction(0, joaat("INPUT_LOOK_UD"), true)
            end
            -- =====================================
        else
            sleep = 1000
            if isNuiFocused then
                SetNuiFocusKeepInput(false)
                isNuiFocused = false
            end
        end
        Wait(sleep)
    end
end)