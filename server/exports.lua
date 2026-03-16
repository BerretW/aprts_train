-- Check If any train is spawned or in use
exports('CheckIfTrainIsSpawned', function()
    return next(ActiveTrains) ~= nil
end)

-- Get all active train network IDs (returns table { [src] = { netId, trainId } })
exports('GetTrainEntity', function()
    local result = {}
    for src, data in pairs(ActiveTrains) do
        result[src] = data.netId
    end
    return result
end)

-- Get network ID of a specific player's active train (src = player source)
exports('GetPlayerTrainEntity', function(src)
    if ActiveTrains[src] then
        return ActiveTrains[src].netId
    end
    return nil
end)

-- Check if baccus bridge destroyed
exports('BacchusBridgeDestroyed', function()
    if BridgeDestroyed then
        return true
    else
        return false
    end
end)