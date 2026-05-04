reimgt.queue = reimgt.queue or {}

util.AddNetworkString(reimgt.prefix .. ".UpdateImage")
util.AddNetworkString(reimgt.prefix .. ".RemoveImage")
util.AddNetworkString(reimgt.prefix .. ".SyncAll")
util.AddNetworkString(reimgt.prefix .. ".DeployTool")
util.AddNetworkString(reimgt.prefix .. ".HolsterTool")

function reimgt.SyncAll(receivers)
    local data = {}
    for entity in pairs(reimgt.instances) do
        if IsValid(entity) then
            data[entity:EntIndex()] = entity:GetData()

            -- entity:SyncUpdateTransmit()
        end
    end

    if table.IsEmpty(data) then return end

    local compressed = reimgt.CompressHeavyData(data)
    net.Start(reimgt.prefix .. ".SyncAll")
        net.WriteUInt(#compressed, 32)
        net.WriteData(compressed, #compressed)

    if receivers == nil then
        net.Broadcast()
    else
        net.Send(receivers)
    end
end

hook.Add("EntityRemoved", reimgt.prefix .. ".EntityRemoved", function(entity)
    if entity:GetClass() == reimgt.entityClass then
        local idx = entity:EntIndex()

        net.Start(reimgt.prefix .. ".RemoveImage")
            net.WriteUInt(idx, 16)
        net.Broadcast()
    end
end)

hook.Add("PlayerInitialSpawn", reimgt.prefix .. ".PlayerInitialSpawn", function(client)
    reimgt.queue[client:UserID()] = true
end)

gameevent.Listen("OnRequestFullUpdate")
hook.Add("OnRequestFullUpdate", reimgt.prefix .. ".OnRequestFullUpdate", function(data)
    local UID = data.userid
    if !reimgt.queue[UID] then return end

    reimgt.queue[UID] = nil

    local client = Player(UID)
    if IsValid(client) then
        reimgt.SyncAll(client)
    end
end)