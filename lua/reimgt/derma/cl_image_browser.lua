---@type DFrame
local PANEL = {}

function PANEL:Init()
    self:SetSize(600, 500)
    self:SetTitle("Image Browser")
    self:Center()
    self:MakePopup()

    self.tabs = self:Add("DPropertySheet")
    self.tabs:Dock(FILL)

    self.tabs.OnActiveTabChanged = function(_, newTab)
        if newTab:GetText() == "Saved URLs" and not self.localMaterialsLoaded then
            self:StartAsyncLoad()
            self.localMaterialsLoaded = true
        end
    end

    self.savedPanel = self:Add("DPanel")
    self.savedPanel:Dock(FILL)
    self.tabs:AddSheet("Saved URLs", self.savedPanel, "icon16/picture_edit.png")

    self.savedScroll = self.savedPanel:Add("DScrollPanel")
    self.savedScroll:Dock(FILL)

    self.savedLayout = self.savedScroll:Add("DIconLayout")
    self.savedLayout:Dock(FILL)
    self.savedLayout:SetSpaceY(5)
    self.savedLayout:SetSpaceX(5)

    self.localPanel = self:Add("DPanel")
    self.localPanel:Dock(FILL)
    self.tabs:AddSheet("Local Materials", self.localPanel, "icon16/folder_picture.png")

    self.localTree = self.localPanel:Add("DTree")
    self.localTree:Dock(FILL)

    self.loadingPanel = self.localPanel:Add("DPanel")
    self.loadingPanel:Dock(FILL)
    self.loadingPanel:SetVisible(false)
    self.loadingPanel.Paint = function(_, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200))
    end

    self.loadingLabel = self.loadingPanel:Add("DLabel")
    self.loadingLabel:Dock(TOP)
    self.loadingLabel:SetText("Loading materials...")
    self.loadingLabel:SetFont("DermaDefaultBold")
    self.loadingLabel:SizeToContents()
    self.loadingLabel:Center()

    self.bottomPanel = self:Add("DPanel")
    self.bottomPanel:Dock(BOTTOM)
    self.bottomPanel:SetTall(100)
    self.bottomPanel:DockMargin(5, 5, 5, 5)

    self.preview = self.bottomPanel:Add("DImage")
    self.preview:SetSize(96, 96)
    self.preview:Dock(LEFT)
    self.preview:DockMargin(0, 0, 5, 0)
    self.preview:SetImage("icon16/picture.png")

    self.copyBtn = self.bottomPanel:Add("DButton")
    self.copyBtn:SetText("Copy Path")
    self.copyBtn:SetWide(100)
    self.copyBtn:Dock(RIGHT)
    self.copyBtn:DockMargin(5, 0, 0, 0)
    self.copyBtn:SetEnabled(false)
    self.copyBtn.DoClick = function()
        if not self.selectedPath then return end
        SetClipboardText(self.selectedPath)

        local tool = LocalPlayer():GetTool()
        if tool and tool.Mode == reimgt.toolClass then
            tool:OnUpdateURL(self.selectedPath, true)
        end

        self:Remove()
    end

    self.pathLabel = self.bottomPanel:Add("DLabel")
    self.pathLabel:Dock(FILL)
    self.pathLabel:SetText("No image selected")
    self.pathLabel:SetWrap(true)

    self:PopulateSaved()
end

function PANEL:StartAsyncLoad()
    self.loadingPanel:SetVisible(true)
    self.localTree:SetVisible(false)

    self.materialsNode = self.localTree:AddNode("materials", "icon16/folder.png")

    self.loadCo = coroutine.create(function()
        self:AddDirectoryToTreeAsync("materials", self.materialsNode)

        if IsValid(self) then
            self.loadingPanel:Remove()
            self.localTree:SetVisible(true)
        end
    end)
end

function PANEL:Think()
    if self.loadCo and coroutine.status(self.loadCo) == "suspended" then
        local ok, err = coroutine.resume(self.loadCo)
        if not ok then
            ErrorNoHalt("Image browser load error: ", err, "\n")

            if IsValid(self.loadingPanel) then
                self.loadingPanel:SetVisible(false)
            end

            if IsValid(self.localTree) then
                self.localTree:SetVisible(true)
            end
        end
    end
end

function PANEL:AddDirectoryToTreeAsync(path, parentNode)
    local files, folders = file.Find(path .. "/*", "GAME")

    parentNode.childNodes = parentNode.childNodes or {}

    for _, folder in ipairs(folders) do
        if not IsValid(self) then return end

        local folderNode = parentNode:AddNode(folder, "icon16/folder.png")
        parentNode.childNodes[folder] = folderNode

        folderNode:AddNode("Loading...", "icon16/hourglass.png")
    end

    for _, _file in ipairs(files) do
        if not IsValid(self) then return end

        if string.EndsWith(_file:lower(), ".png") or string.EndsWith(_file:lower(), ".jpg") or string.EndsWith(_file:lower(), ".jpeg") or string.EndsWith(_file:lower(), ".vtf") then
            local fullPath = path .. "/" .. _file
            local fileNode = parentNode:AddNode(_file, "icon16/picture.png")
            fileNode.DoClick = function()
                self.selectedPath = fullPath

                local matPath = fullPath:gsub("^materials/", "")
                local mat = Material(matPath)

                if mat and not mat:IsError() then
                    self.preview:SetMaterial(mat)
                else
                    self.preview:SetImage("icon16/error.png")
                end

                self.pathLabel:SetText(fullPath)
                self.copyBtn:SetEnabled(true)
            end
        end
    end

    for _, folder in ipairs(folders) do
        if not IsValid(self) then return end

        local folderPath = path .. "/" .. folder
        local folderNode = parentNode.childNodes[folder]

        if folderNode and IsValid(folderNode) then
            folderNode:Clear()

            self:AddDirectoryToTreeAsync(folderPath, folderNode)
        end
    end
end

function PANEL:PopulateSaved()
    self.savedLayout:Clear()

    for hash, originalUrl in pairs(reimgt.cacheURLs) do
        local path = reimgt.cacheFolder .. hash .. ".png"

        if file.Exists(path, "DATA") then
            local icon = self.savedLayout:Add("DImageButton")
            icon:SetSize(64, 64)
            icon:SetImage("data/" .. path)
            icon.DoClick = function()
                self.selectedPath = originalUrl
                self.preview:SetImage("data/" .. path)
                self.pathLabel:SetText(originalUrl)
                self.copyBtn:SetEnabled(true)
            end
        end
    end
end

vgui.Register(reimgt.prefix .. ".Browser", PANEL, "DFrame")