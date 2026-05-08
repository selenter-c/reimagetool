local function PermaProps_Support()
    if not PermaProps then return end

    PermaProps.SpecialENTSSave["reimgt_image"] = function(entity)
        ---@cast entity ReImgt.Entity

        local data = entity:GetData()
        if not data then return end

        local serializableData = {
            url = data.url,
            width = data.width,
            height = data.height,
            render_distance = data.render_distance,
            color = {
                r = data.color.r,
                g = data.color.g,
                b = data.color.b,
                a = data.color.a
            },
            bLighting = data.bLighting,
            lightMultiplier = data.lightMultiplier,
            doubleSided = data.doubleSided,
            disableCollision = data.disableCollision
        }

        return {Other = {reimgt_data = serializableData}}
    end

    PermaProps.SpecialENTSSpawn["reimgt_image"] = function(entity, otherData)
        ---@cast entity ReImgt.Entity

        if not otherData or not otherData.reimgt_data then
            return entity:Spawn()
        end

        local data = otherData.reimgt_data

        entity:Spawn()
        entity:SetImageParams(
            data.url,
            data.width,
            data.height,
            data.render_distance,
            Color(data.color.r, data.color.g, data.color.b, data.color.a),
            data.bLighting,
            data.lightMultiplier,
            data.doubleSided,
            data.disableCollision
        )

        entity:Sync()
    end
end

hook.Add("Initialize", reimgt.prefix .. ".Initialize", function()
    PermaProps_Support()
end)