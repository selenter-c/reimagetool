AddCSLuaFile()

---@class ReImgt.Entity: Entity
ENT = ENT

ENT.Type = "anim"
ENT.PrintName = "Image Entity"
ENT.Author = "Selenter"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

function ENT:Initialize()
    self:SetModel("models/hunter/plates/plate1x1.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)

    self:DrawShadow(false)
    self:SetRenderMode(RENDERMODE_TRANSALPHA)

    self:AddEFlags(EFL_FORCE_CHECK_TRANSMIT)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)
    end

    ---@type ReImgt.SerializeData
    self.data = {
        url = nil,
        width = 64,
        height = 64,
        render_distance = 2000,
        color = Color(255, 255, 255),
        bLighting = false,
        lightMultiplier = 1.5,
        doubleSided = false,
        disableCollision = false
    }

    ---@type IMaterial
    self.imageMaterial = nil

    ---@type boolean
    self.bSync = nil

    ---@type number
    self.loadingStartTime = CurTime()
end

---@return ReImgt.SerializeData
function ENT:GetData()
    return self.data
end

---@param url string
---@param width number
---@param height number
---@param render_distance number
---@param color Color
---@param bLighting boolean
---@param lightMultiplier number
---@param doubleSided boolean
---@param disableCollision boolean
function ENT:SetImageParams(url, width, height, render_distance, color, bLighting, lightMultiplier, doubleSided, disableCollision)
    local maxWidth = GetConVar("reimagetool_max_width"):GetInt()
    local maxHeigth = GetConVar("reimagetool_max_heigth"):GetInt()

    self.data = {
        url = tostring(url),
        width = math.Clamp(width, 1, maxWidth),
        height = math.Clamp(height, 1, maxHeigth),
        render_distance = math.Clamp(render_distance, 500, 10000),

        color = Color(color.r or 255, color.g or 255, color.b or 255, color.a or 255),

        bLighting = tobool(bLighting),
        lightMultiplier = tonumber(lightMultiplier) or 1,

        doubleSided = tobool(doubleSided),
        disableCollision = tobool(disableCollision)
    }

    self:SetupCollision(self.data.width, self.data.height)

    if self.data.disableCollision then
        self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
    end

    if CLIENT then
        reimgt.QueueImageDownload(self.data.url, function(mat)
            self.imageMaterial = mat
        end)
    end

    reimgt.instances[self] = true
end

---@param width number
---@param height number
function ENT:SetupCollision(width, height)
    self:PhysicsDestroy()

    local thickness = 1
    local vertices = {
        Vector(-width / 2, -height / 2, -thickness / 2),
        Vector(width / 2, -height / 2, -thickness / 2),
        Vector(width / 2, height / 2, -thickness / 2),
        Vector(-width / 2, height / 2, -thickness / 2),

        Vector(-width / 2, -height / 2, thickness / 2),
        Vector(width / 2, -height / 2, thickness / 2),
        Vector(width / 2, height / 2, thickness / 2),
        Vector(-width / 2, height / 2, thickness / 2),
    }

    self:PhysicsInitConvex(vertices)

    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:EnableCustomCollisions()

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)

        local density = 0.005
        local area = self.data.width * self.data.height
        local mass = math.Clamp(density * area, 0.1, 500)

        phys:SetMass(mass)
    end

    self:SetCollisionBounds(
        Vector(-width / 2, -height / 2, -thickness / 2),
        Vector(width / 2, height / 2, thickness / 2)
    )

    if CLIENT then
        local size = math.max(self.data.width, self.data.height) * 2

        self:SetRenderBounds(
            Vector(-size, -size, -size),
            Vector(size, size, size)
        )
    end
end

function ENT:OnRemove()
    reimgt.instances[self] = nil
end

if CLIENT then
    -- METHODS:

    function ENT:DrawImage()
        reimgt.DrawImage({
            pos = self:GetPos(),
            material = self.imageMaterial,

            x = -self.data.width / 2,
            y = -self.data.height / 2,
            w = self.data.width,
            h = self.data.height,
            color = self.data.color,
            bLighting = self.data.bLighting,
            lightMultiplier = self.data.lightMultiplier,

            loadingStartTime = self.loadingStartTime
        })
    end


    -- EVENTS:

    function ENT:DrawTranslucent()
        local camPos = EyePos()
        local pos = self:GetPos()
        local angles = self:GetAngles()

        local renderDistance = self.data.render_distance
        if camPos:DistToSqr(pos) > (renderDistance * renderDistance) then return end

        cam.Start3D2D(pos, angles, 1)
            self:DrawImage()
        cam.End3D2D()

        if self.data.doubleSided then
            cam.Start3D2D(pos, angles, 1)
                render.CullMode(MATERIAL_CULLMODE_CW)
                    self:DrawImage()
                render.CullMode(MATERIAL_CULLMODE_CCW)
            cam.End3D2D()
        end
    end

    function ENT:Draw()
        return false
    end
else
    -- METHODS:

    ---@param receivers Player|Player[]|nil
    function ENT:Sync(receivers)
        local compressed = reimgt.CompressData(self:GetData())

        net.Start(reimgt.prefix .. ".UpdateImage")
            net.WriteUInt(self:EntIndex(), 16)
            net.WriteUInt(#compressed, 32)
            net.WriteData(compressed, #compressed)

        if receivers == nil then
            net.Broadcast()
        else
            net.Send(receivers)
        end

        -- self:SyncUpdateTransmit()
    end

    -- function ENT:SyncUpdateTransmit()
    --     self.bSync = true
    --     self:AddEFlags(EFL_FORCE_CHECK_TRANSMIT)

    --     timer.Simple(5, function()
    --         if !IsValid(self) then return end

    --         self.bSync = nil
    --         self:AddEFlags(EFL_FORCE_CHECK_TRANSMIT)
    --     end)
    -- end


    -- EVENTS:

    -- function ENT:UpdateTransmitState()
    --     if self.bSync then
    --         return TRANSMIT_ALWAYS
    --     end

    --     return TRANSMIT_PVS
    -- end

    function ENT:OnDuplicated()
        local data = self.BoneMods and self.BoneMods.imageData
        if !data then return end

        self:SetImageParams(
            data.url,
            data.width,
            data.height,
            data.render_distance,
            data.color,
            data.bLighting,
            data.lightMultiplier,
            data.doubleSided,
            data.disableCollision
        )

        self:Sync()

        local physObject = self:GetPhysicsObject()

        if IsValid(physObject) then
            local bMotion = data.motion

            if bMotion != nil then
                physObject:EnableMotion(bMotion)
            end
        end
    end

    function ENT:PreEntityCopy()
        self.BoneMods = self.BoneMods or {}
        self.BoneMods.imageData = self.BoneMods.imageData or {}

        local data = self.data
        if !data then return end

        self.BoneMods.imageData = data

        local physObject = self:GetPhysicsObject()
        if IsValid(physObject) then
            local bMotion = physObject:IsMotionEnabled()

            self.BoneMods.imageData.motion = tobool(bMotion)
        end
    end
end