local urlEntry = nil ---@cast urlEntry DTextEntry
local urlCheck = nil ---@cast urlCheck DImage

local previewMaterial = nil

local function loadingUrlPanel(CPanel, url)
    local urlPanel = vgui.Create("Panel")
    urlPanel:Dock(TOP)
    urlPanel:SetTall(41)
    CPanel:AddPanel(urlPanel)

    local urlLabel = urlPanel:Add("DLabel")
    urlLabel:Dock(TOP)
    urlLabel:SetText("Image URL:")
    urlLabel:DockMargin(0, 0, 0, 5)
    urlLabel:SetTextColor(Color(0, 0, 0))

    urlEntry = urlPanel:Add("DTextEntry")
    urlEntry:Dock(FILL)
    urlEntry:SetText("")
    urlEntry:SetPlaceholderText("https://i.imgur.com/4vyQ6Hl.png")
    urlEntry.OnChange = function(self)
        local value = self:GetText()

        local tool = LocalPlayer():GetTool()
        if !tool or tool.Mode != reimgt.toolClass then return end

        tool:OnUpdateURL(value, true)
        RunConsoleCommand("reimagetool_url", value)
    end

    if url then
        urlEntry:RequestFocus()
        urlEntry:SetText(url)
        urlEntry:SetCaretPos(utf8.len(url))
    end

    urlCheck = urlPanel:Add("DImage")
    urlCheck:Dock(RIGHT)
    urlCheck:SetWide(16)
    urlCheck:DockMargin(5, 0, 5, 0)
    urlCheck:SetImage(url and "icon16/tick.png" or "icon16/cross.png")
end

AddCSLuaFile()

cleanup.Register("images")

TOOL.Name = "Re;Image Tool"
TOOL.Category = "Asterion Tools"
TOOL.Information = {
    {name = "left", stage = 0},
    {name = "right", stage = 0},
    {name = "reload", stage = 0},

    {name = "left", icon2 = "gui/e.png", stage = 0}
}

TOOL.ClientConVar.url = ""
TOOL.ClientConVar.width = "256"
TOOL.ClientConVar.height = "256"
TOOL.ClientConVar.scale = "0.25"
TOOL.ClientConVar.render_distance = "2000"
TOOL.ClientConVar.position = "1"
TOOL.ClientConVar.rotation_x = "90"
TOOL.ClientConVar.rotation_y = "90"
TOOL.ClientConVar.rotation_z = "0"
TOOL.ClientConVar.offset_right = "0"
TOOL.ClientConVar.offset_up = "1"
TOOL.ClientConVar.offset_forward = "0"
TOOL.ClientConVar.color_r = "255"
TOOL.ClientConVar.color_g = "255"
TOOL.ClientConVar.color_b = "255"
TOOL.ClientConVar.color_a = "255"
TOOL.ClientConVar.use_lighting = "0"
TOOL.ClientConVar.light_multiplier = "1.5"
TOOL.ClientConVar.double_sided = "0"
TOOL.ClientConVar.disable_collision = "0"

if CLIENT then
    language.Add("tool.reimagetool.name", "Re;Image Tool")
    language.Add("tool.reimagetool.desc", "Allows you to create pictures in the world")
    language.Add("tool.reimagetool.left", "Place the image")
    language.Add("tool.reimagetool.right", "Attach image to existing one (welding)")
    language.Add("tool.reimagetool.reload", "Change image position")

    language.Add("Undone.images", "Undone image")
    language.Add("Undone_images", "Undone image")
    language.Add("Cleanup.images", "Images")
    language.Add("Cleanup_images", "Images")
    language.Add("Cleaned.images", "Cleaned up all Images")
    language.Add("Cleaned_images", "Cleaned up all Images")
    language.Add("SBoxLimit.images", "You've hit the images limit!")
    language.Add("SBoxLimit_images", "You've hit the iconmages limit!")
end

local function CalculateImagePlacement(oldPos, trace)
    local newPos = trace.HitPos
    local traceNormal = trace.HitNormal
    local traceAngle = traceNormal:Angle()

    local localOldPos = WorldToLocal(oldPos, angle_zero, Vector(0, 0, 0), traceAngle)
    local localNewPos = WorldToLocal(newPos, angle_zero, Vector(0, 0, 0), traceAngle)

    local maxWidth = GetConVar("reimagetool_max_width"):GetInt()
    local maxHeigth = GetConVar("reimagetool_max_heigth"):GetInt()

    local sizeX = 1
    local sizeY = math.Clamp(localNewPos.y - localOldPos.y, -maxWidth, maxWidth)
    local sizeZ = math.Clamp(localNewPos.z - localOldPos.z, -maxHeigth, maxHeigth)

    return sizeX, sizeY, sizeZ, traceAngle
end

function TOOL:CreateHook()
    hook.Add("PostDrawTranslucentRenderables", reimgt.prefix .. ".ToolDraw", function()
        local client = LocalPlayer()

        local tool = client:GetTool()
        if !tool or tool.Mode != reimgt.toolClass then return end

        local tr = client:GetEyeTrace()
        if !tr.Hit then return end

        local previewPosition = tonumber(self:GetClientInfo("position")) or 1
        local previewRotationX = tonumber(self:GetClientInfo("rotation_x")) or 90
        local previewRotationY = tonumber(self:GetClientInfo("rotation_y")) or 90
        local previewRotationZ = tonumber(self:GetClientInfo("rotation_z")) or 0
        local previewOffsetRight = tonumber(self:GetClientInfo("offset_right")) or 0
        local previewOffsetUp = tonumber(self:GetClientInfo("offset_up")) or 1
        local previewOffsetForward = tonumber(self:GetClientInfo("offset_forward")) or 0
        local previewColor = Color(
            tonumber(self:GetClientInfo("color_r")) or 255,
            tonumber(self:GetClientInfo("color_g")) or 255,
            tonumber(self:GetClientInfo("color_b")) or 255,
            tonumber(self:GetClientInfo("color_a")) or 255
        )
        local bLighting = tobool(self:GetClientInfo("use_lighting"))
        local lightMultiplier = tonumber(self:GetClientInfo("light_multiplier")) or 1.5
        local doubleSided = tobool(self:GetClientInfo("double_sided"))

        local pos = tr.HitPos
        local normal = tr.HitNormal
        local angle = normal:Angle()

        angle:RotateAroundAxis(angle:Up(), previewRotationY)
        angle:RotateAroundAxis(angle:Forward(), previewRotationX)
        angle:RotateAroundAxis(angle:Right(), previewRotationZ)

        pos = pos + angle:Right() * previewOffsetRight
        pos = pos + angle:Up() * previewOffsetUp
        pos = pos + angle:Forward() * previewOffsetForward

        local sizeX = tonumber(self:GetClientInfo("width")) or 256
        local sizeY = tonumber(self:GetClientInfo("height")) or 256
        local sizeScale = tonumber(self:GetClientInfo("scale")) or 0.25

        local maxScale = GetConVar("reimagetool_max_scale"):GetInt()
        sizeScale = math.Clamp(sizeScale, 0.01, maxScale)

        sizeX = sizeX * sizeScale
        sizeY = sizeY * sizeScale

        local maxWidth = GetConVar("reimagetool_max_width"):GetInt()
        local maxHeigth = GetConVar("reimagetool_max_heigth"):GetInt()

        sizeX = math.Clamp(sizeX, 1, maxWidth)
        sizeY = math.Clamp(sizeY, 1, maxHeigth)

        local positionData = reimgt.PositionsRotating[previewPosition]
        if positionData then
            pos = pos + positionData.offset(sizeX, sizeY, angle)
        end

        local data = {
            pos = pos,
            material = previewMaterial,

            x = -sizeX / 2,
            y = -sizeY / 2,
            w = sizeX,
            h = sizeY,
            color = previewColor,
            bLighting = bLighting,
            lightMultiplier = lightMultiplier,
        }

        local oldPos = client.useAdvancedPos
        if client:KeyDown(IN_USE) then
            if oldPos then
                local r_sizeX, r_sizeY, r_sizeZ, r_traceAngle = CalculateImagePlacement(oldPos, client:GetEyeTrace())

                local renderPos = oldPos + r_traceAngle:Forward() * (r_sizeX / 2)
                renderPos = renderPos - r_traceAngle:Right() * (r_sizeY / 2)
                renderPos = renderPos + r_traceAngle:Up() * (r_sizeZ / 2)

                local mins = Vector(-r_sizeX / 2, -r_sizeY / 2, -r_sizeZ / 2)
                local maxs = Vector(r_sizeX / 2, r_sizeY / 2, r_sizeZ / 2)

                render.DrawWireframeBox(renderPos, r_traceAngle, mins, maxs, color_white, false)
            end
        else
            cam.Start3D2D(pos, angle, 1)
                reimgt.DrawImage(data)
            cam.End3D2D()

            if doubleSided then
                cam.Start3D2D(pos, angle, 1)
                    render.CullMode(MATERIAL_CULLMODE_CW)
                        reimgt.DrawImage(data)
                    render.CullMode(MATERIAL_CULLMODE_CCW)
                cam.End3D2D()
            end
        end
    end)
end

function TOOL:CreateImageEntityBase(params)
    local client = self:GetOwner()
    local trace = params.trace
    local entity = trace.Entity

    if !client:CheckLimit("images") then return false end
    if hook.Run("PlayerSpawnImage", client, trace) == false then return false end
    if IsValid(entity) and entity:GetClass() == "player" and hook.Run("OnCanSpawnImageInPlayer", client, entity, trace) == false then return false end

    local url = reimgt.CorrectingURL(self:GetClientInfo("url"))
    if url == "" then return end

    local image = ents.Create(reimgt.entityClass) ---@cast image ReImgt.Entity
    if !IsValid(image) then return false end

    image:SetPos(params.pos)
    image:SetAngles(params.angle)
    image:Spawn()

    image:SetImageParams(
        url,
        params.width,
        params.height,
        tonumber(self:GetClientInfo("render_distance")) or 2000,
        Color(
            tonumber(self:GetClientInfo("color_r")) or 255,
            tonumber(self:GetClientInfo("color_g")) or 255,
            tonumber(self:GetClientInfo("color_b")) or 255,
            tonumber(self:GetClientInfo("color_a")) or 255
        ),
        tobool(self:GetClientInfo("use_lighting")) or false,
        tonumber(self:GetClientInfo("light_multiplier")) or 1.5,
        tobool(self:GetClientInfo("double_sided")),
        tobool(self:GetClientInfo("disable_collision"))
    )

    image:Sync()
    image:SetCreator(client)

    -- CPPI support
    if image.CPPISetOwner then
        image:CPPISetOwner(client)
    end

    if IsValid(params.entityLink) then
        constraint.Weld(image, params.entityLink, 0, 0, 0, true, false)
        constraint.NoCollide(image, params.entityLink, 0, 0, true)

        local phys = image:GetPhysicsObject()
        if IsValid(phys) then
            phys:EnableMotion(true)
        end
    end

    undo.Create("images")
        undo.AddEntity(image)
        undo.SetPlayer(self:GetOwner())
    undo.Finish()

    client:AddCount("images", image)
    client:AddCleanup("images", image)

    return image
end

function TOOL:CreateSimpleImageEntity(trace, entityLink)
    local width = tonumber(self:GetClientInfo("width")) or 256
    local height = tonumber(self:GetClientInfo("height")) or 256
    local scale = tonumber(self:GetClientInfo("scale")) or 0.25
    width = width * scale
    height = height * scale

    local pos = trace.HitPos
    local normal = trace.HitNormal
    local angle = normal:Angle()

    angle:RotateAroundAxis(angle:Up(), tonumber(self:GetClientInfo("rotation_y")) or 90)
    angle:RotateAroundAxis(angle:Forward(), tonumber(self:GetClientInfo("rotation_x")) or 90)
    angle:RotateAroundAxis(angle:Right(), tonumber(self:GetClientInfo("rotation_z")) or 0)

    pos = pos + angle:Right() * (tonumber(self:GetClientInfo("offset_right")) or 0)
    pos = pos + angle:Up() * (tonumber(self:GetClientInfo("offset_up")) or 1)
    pos = pos + angle:Forward() * (tonumber(self:GetClientInfo("offset_forward")) or 0)

    local previewPosition = tonumber(self:GetClientInfo("position")) or 1
    local positionData = reimgt.PositionsRotating[previewPosition]
    if positionData then
        pos = pos + positionData.offset(width, height, angle)
    end

    return self:CreateImageEntityBase({
        trace = trace,
        pos = pos,
        angle = angle,
        width = width,
        height = height,
        entityLink = entityLink
    })
end

function TOOL:CreateAdvancedImageEntity(oldPos, trace)
    local r_sizeX, r_sizeY, r_sizeZ, r_traceAngle = CalculateImagePlacement(oldPos, trace)
    local normal = trace.HitNormal
    local angle = normal:Angle()

    if math.abs(normal.z) > 0.7 then
        angle:RotateAroundAxis(angle:Up(), 90)
        angle:RotateAroundAxis(angle:Forward(), 90)
    else
        angle:RotateAroundAxis(angle:Up(), 90)
        angle:RotateAroundAxis(angle:Forward(), 90)
    end

    local pos = oldPos + r_traceAngle:Forward() * (r_sizeX / 2)
    pos = pos + r_traceAngle:Right() * -(r_sizeY / 2)
    pos = pos + r_traceAngle:Up() * (r_sizeZ / 2)

    return self:CreateImageEntityBase({
        trace = trace,
        pos = pos,
        angle = angle,
        width = math.abs(r_sizeY),
        height = math.abs(r_sizeZ),
        entityLink = nil
    })
end

function TOOL:OnUpdateURL(url, bUpdateSize)
    if !url then return end

    url = reimgt.CorrectingURL(url)

    reimgt.bLoading = url

    RunConsoleCommand("reimagetool_url", url)

    if IsValid(urlCheck) then
        urlCheck:SetImage("icon16/connect.png")
    end

    reimgt.QueueImageDownload(url, function(mat)
        if IsValid(urlCheck) then
            urlCheck:SetImage("icon16/tick.png")
        end

        previewMaterial = mat

        if bUpdateSize then
            -- По какой то причине необходима задержка при получении размера, иначе вернется старый размер, понятие не имею с чем это связано
            timer.Simple(0.3, function()
                local defaultWidth = mat:Width()
                local defaultHeight = mat:Height()

                RunConsoleCommand("reimagetool_width", tostring(defaultWidth))
                RunConsoleCommand("reimagetool_height", tostring(defaultHeight))
            end)
        end

        self:UpdateControls(url)
    end, function()
        if IsValid(urlCheck) then
            urlCheck:SetImage("icon16/cross.png")
        end
    end)
end

function TOOL:UpdateControls(url)
    local maxWidth = GetConVar("reimagetool_max_width"):GetInt()
    local maxHeigth = GetConVar("reimagetool_max_heigth"):GetInt()
    local maxScale = GetConVar("reimagetool_max_scale"):GetInt()

    local CPanel = controlpanel.Get(reimgt.toolClass) ---@cast CPanel ControlPanel
    if !IsValid(CPanel) or !previewMaterial then return end

    CPanel:Clear()

    local function AddDescription(text)
        local desc = vgui.Create("DLabel")
        desc:SetText(text)
        desc:SetWrap(true)
        desc:SetTextColor(Color(80, 80, 80))
        CPanel:AddPanel(desc)
    end

    loadingUrlPanel(CPanel, url)

    CPanel:NumSlider("Width", "reimagetool_width", 32, maxWidth, 0)
    AddDescription("Sets the horizontal size of the image in pixels.")

    CPanel:NumSlider("Height", "reimagetool_height", 32, maxHeigth, 0)
    AddDescription("Sets the vertical size of the image in pixels.")

    CPanel:NumSlider("Scale", "reimagetool_scale", 0.01, maxScale, 2)
    AddDescription("Uniformly scales the image size by the selected multiplier.")

    CPanel:NumSlider("Render Distance", "reimagetool_render_distance", 500, 10000, 0)
    AddDescription("Distance at which images will stop rendering (in Hammer units)")

    local rotX = CPanel:NumSlider("Rotation X", "reimagetool_rotation_x", 0, 360, 0) ---@cast rotX DNumSlider
    rotX:SetValue(tonumber(self:GetClientInfo("rotation_x")) or 90)
    AddDescription("Rotates the image around the X axis (forward direction).")

    local rotY = CPanel:NumSlider("Rotation Y", "reimagetool_rotation_y", 0, 360, 0) ---@cast rotY DNumSlider
    rotY:SetValue(tonumber(self:GetClientInfo("rotation_y")) or 90)
    AddDescription("Rotates the image around the Y axis (up direction).")

    local rotZ = CPanel:NumSlider("Rotation Z", "reimagetool_rotation_z", 0, 360, 0) ---@cast rotZ DNumSlider
    rotZ:SetValue(tonumber(self:GetClientInfo("rotation_z")) or 0)
    AddDescription("Rotates the image around the Z axis (right direction).")

    local offsetRight = CPanel:NumSlider("Offset X", "reimagetool_offset_right", -100, 100, 0) ---@cast offsetRight DNumSlider
    offsetRight:SetValue(tonumber(self:GetClientInfo("offset_right")) or 0)
    AddDescription("Shifts the image along the right (X) axis.")

    local offsetUp = CPanel:NumSlider("Offset Up", "reimagetool_offset_up", -100, 100, 0) ---@cast offsetUp DNumSlider
    offsetUp:SetValue(tonumber(self:GetClientInfo("offset_up")) or 1)
    AddDescription("Shifts the image along the up (Y) axis.")

    local offsetForward = CPanel:NumSlider("Offset Forward", "reimagetool_offset_forward", -1000, 1000, 0) ---@cast offsetForward DNumSlider
    offsetForward:SetValue(tonumber(self:GetClientInfo("offset_forward")) or 0)
    AddDescription("Shifts the image along the forward (Z) axis.")

    local colorMixer = vgui.Create("DColorMixer")
    colorMixer:SetPalette(true)
    colorMixer:SetAlphaBar(true)
    colorMixer:SetWangs(true)
    colorMixer:SetColor(Color(
        tonumber(self:GetClientInfo("color_r")) or 255,
        tonumber(self:GetClientInfo("color_g")) or 255,
        tonumber(self:GetClientInfo("color_b")) or 255,
        tonumber(self:GetClientInfo("color_a")) or 255
    ))
    colorMixer.ValueChanged = function(_, color)
        RunConsoleCommand("reimagetool_color_r", tostring(color.r))
        RunConsoleCommand("reimagetool_color_g", tostring(color.g))
        RunConsoleCommand("reimagetool_color_b", tostring(color.b))
        RunConsoleCommand("reimagetool_color_a", tostring(color.a))
    end
    CPanel:AddPanel(colorMixer)
    AddDescription("Choose the color and transparency applied to the image.")

    CPanel:CheckBox("Affected by world lighting", "reimagetool_use_lighting")
    AddDescription("Enable dynamic lighting based on map lighting.")

    CPanel:NumSlider("Light Multiplier", "reimagetool_light_multiplier", 0.1, 10, 1)
    AddDescription("Adjusts how strongly the image is affected by lighting.")

    CPanel:CheckBox("Double-sided (show on both sides)", "reimagetool_double_sided")
    AddDescription("Enable to show the image on both sides of the surface.")

    CPanel:CheckBox("Disable collision (players can walk through)", "reimagetool_disable_collision")
    AddDescription("Disable physical collision for this image.")

    local setSizeBtn = vgui.Create("DButton")
    setSizeBtn:SetText("Set size to image")
    setSizeBtn:Dock(TOP)
    setSizeBtn:DockMargin(0, 5, 0, 5)
    setSizeBtn:SetTall(30)
    setSizeBtn.DoClick = function()
        if !previewMaterial then return end
        local w = previewMaterial:Width()
        local h = previewMaterial:Height()

        RunConsoleCommand("reimagetool_width", tostring(w))
        RunConsoleCommand("reimagetool_height", tostring(h))
    end
    CPanel:AddPanel(setSizeBtn)

    local resetButton = vgui.Create("DButton")
    resetButton:SetText("Reset settings")
    resetButton:SetTall(30)
    resetButton:Dock(TOP)
    resetButton:DockMargin(0, 10, 0, 0)
    resetButton.DoClick = function()
        local w, h = 256, 256
        if previewMaterial then
            w = previewMaterial:Width()
            h = previewMaterial:Height()
        end

        RunConsoleCommand("reimagetool_width", tostring(w))
        RunConsoleCommand("reimagetool_height", tostring(h))
        RunConsoleCommand("reimagetool_scale", "0.25")
        RunConsoleCommand("reimagetool_render_distance", "2000")
        RunConsoleCommand("reimagetool_position", "1")
        RunConsoleCommand("reimagetool_rotation_x", "90")
        RunConsoleCommand("reimagetool_rotation_y", "90")
        RunConsoleCommand("reimagetool_rotation_z", "0")
        RunConsoleCommand("reimagetool_offset_right", "0")
        RunConsoleCommand("reimagetool_offset_up", "1")
        RunConsoleCommand("reimagetool_offset_forward", "0")
        RunConsoleCommand("reimagetool_color_r", "255")
        RunConsoleCommand("reimagetool_color_g", "255")
        RunConsoleCommand("reimagetool_color_b", "255")
        RunConsoleCommand("reimagetool_color_a", "255")
        RunConsoleCommand("reimagetool_use_lighting", "0")
        RunConsoleCommand("reimagetool_light_multiplier", "1.5")
        RunConsoleCommand("reimagetool_double_sided", "0")
        RunConsoleCommand("reimagetool_disable_collision", "0")
    end

    CPanel:AddPanel(resetButton)
end

function TOOL:Deploy()
    if SERVER then
        local client = self:GetOwner()

        net.Start(reimgt.prefix .. ".DeployTool")
        net.Send(client)
    end

    return true
end

function TOOL:DeployNet()
    self:OnUpdateURL(IsValid(urlEntry) and urlEntry:GetValue() or nil)
    self:CreateHook()
end

function TOOL:Holster()
    if SERVER then
        local client = self:GetOwner()

        net.Start(reimgt.prefix .. ".HolsterTool")
        net.Send(client)
    end

    return true
end

function TOOL:HolsterNet()
    -- hm?
end

function TOOL:LeftClick(trace)
    if !IsFirstTimePredicted() then return end

    local client = self:GetOwner()
    if client:KeyDown(IN_USE) then
        client.useAdvancedPos = trace.HitPos

        self:AdvancedLeftClick(client)

        return false
    else
        if CLIENT then return true end

        self:SimpleLeftClick(trace)
    end

    return true
end

function TOOL:SimpleLeftClick(trace)
    self:CreateSimpleImageEntity(trace)
end

function TOOL:AdvancedLeftClick(client)
    local uniqueID = reimgt.prefix .. ".AdvancedLeftClick.Think_" .. client:EntIndex()

    local function remove()
        if IsValid(client) then
            client.useAdvancedPos = nil
        end
        return hook.Remove("Think", uniqueID)
    end

    local function set()
        local trace = client:GetEyeTrace()
        if !trace.Hit then return remove() end

        if SERVER then
            self:CreateAdvancedImageEntity(client.useAdvancedPos, trace)
        end

        return remove()
    end

    hook.Add("Think", uniqueID, function()
        if !IsValid(client) then return remove() end
        if !client.useAdvancedPos then return remove() end
        if !client:KeyDown(IN_USE) then return remove() end

        local tool = client.GetTool and client:GetTool()
        if !tool or tool.Mode != reimgt.toolClass then return remove() end

        if !client:KeyDown(IN_ATTACK) then
            return set()
        end
    end)
end

function TOOL:RightClick(trace)
    if !IsFirstTimePredicted() then return end
    if CLIENT then return true end

    local entity = trace.Entity
    self:CreateSimpleImageEntity(trace, IsValid(entity) and entity or nil)

    return true
end

function TOOL:Notify(message)
    notification.AddLegacy(message, NOTIFY_HINT, 2)
    surface.PlaySound("buttons/button15.wav")
end

function TOOL:Reload(trace)
    if !IsFirstTimePredicted() then return end

    if CLIENT then
        local previewPosition = tonumber(self:GetClientInfo("position")) or 1
        previewPosition = previewPosition + 1
        if previewPosition > #reimgt.PositionsRotating then
            previewPosition = 1
        end

        RunConsoleCommand("reimagetool_position", tostring(previewPosition))

        local positionData = reimgt.PositionsRotating[previewPosition]
        if positionData then
            notification.AddLegacy("Position: " .. positionData.name, NOTIFY_HINT, 2)
            surface.PlaySound("buttons/button15.wav")
        end
    end

    return true
end

---@param CPanel ControlPanel
function TOOL.BuildCPanel(CPanel)
    timer.Simple(0.5, function()
        local client = LocalPlayer()
        if !IsValid(client) then return end

        local weapon = client:GetActiveWeapon()
        if !IsValid(weapon) then return end
        if weapon:GetClass() != "gmod_tool" then return end

        local tool = LocalPlayer():GetTool()

        if tool and tool.Mode == reimgt.toolClass and tool.DeployNet then
            tool:DeployNet()
        end
    end)

    local browserBtn = vgui.Create("DButton", CPanel)
    browserBtn:SetText("Open Image Browser")
    browserBtn:SetIcon("icon16/folder_picture.png")
    browserBtn:Dock(TOP)
    browserBtn:DockMargin(10, 10, 10, 0)
    browserBtn:SetTall(30)
    browserBtn.DoClick = function()
        vgui.Create(reimgt.prefix .. ".Browser")
    end

    loadingUrlPanel(CPanel)
end