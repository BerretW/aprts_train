-- Uvede aktivní vlak do provozu bez vlastníka – jiný strojvedoucí ho může převzít
RegisterCommand('servis', function()
    if LocalPlayer.state.Character.Job ~= Config.Job then
        VORPcore.NotifyRightTip(_U('wrongJob'), 4000)
        return
    end
    if not MyTrain then
        VORPcore.NotifyRightTip(_U('noActiveTrain'), 4000)
        return
    end
    TriggerServerEvent('bcc-train:PutTrainInService')
end)

RegisterCommand('delTrain', function(source, args, rawCommand)
    if LocalPlayer.state.Character.Job == Config.Job then

       
        TriggerEvent('chat:addMessage', {
            color = {255, 0, 0},
            multiline = true,
            args = {"BCC-Train", "Vyber vlak pro smazání!"}
        })
        local train = exports["aprts_select"]:startSelecting(true)
        local model = GetEntityModel(train)
   


        if IsThisModelATrain(model) == 1 then
            TriggerEvent('chat:addMessage', {
                color = {255, 0, 0},
                multiline = true,
                args = {"BCC-Train", "Mažu vlak!"}
            })
            -- DeleteEntity(train)
            local networkEntity = NetworkGetNetworkIdFromEntity(train)
            TriggerServerEvent("bcc-train:Server:DeleteTrain", networkEntity)
        else
            TriggerEvent('chat:addMessage', {
                color = {255, 0, 0},
                multiline = true,
                args = {"BCC-Train", "Není možné smazat tento objekt!"}
            })
        end

    end
end)
