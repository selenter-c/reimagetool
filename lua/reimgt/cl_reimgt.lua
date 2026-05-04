reimgt.cache = reimgt.cache or {}
reimgt.downloadQueue = reimgt.downloadQueue or {}
reimgt.activeDownloads = reimgt.activeDownloads or {}
reimgt.cacheURLs = reimgt.cacheURLs or {}
reimgt.downloadCallbacks = reimgt.downloadCallbacks or {}
reimgt.pendingEntities = reimgt.pendingEntities or {}
reimgt.cacheFolder = "reimgt_cache/"

if !file.IsDir(reimgt.cacheFolder, "DATA") then
    file.CreateDir(reimgt.cacheFolder)
    reimgt.Print("system", "Created cache directory: " .. reimgt.cacheFolder)
end


---@param entityIdx number
---@param data ReImgt.SerializeData
function reimgt.CheckAndApplyEntity(entityIdx, data, callback)
    reimgt.pendingEntities[entityIdx] = {
        data = data,
        callback = callback,
        attempts = 1
    }
end

---@param data ReImgt.ImageParameters
function reimgt.DrawImage(data)
    if data.material then
        local mulR, mulG, mulB = 1, 1, 1

        if data.bLighting then
            local lightColor = render.GetLightColor(data.pos) * data.lightMultiplier

            mulR = lightColor[1]
            mulG = lightColor[2]
            mulB = lightColor[3]
        end

        surface.SetDrawColor(data.color.r * mulR, data.color.g * mulG, data.color.b * mulB, data.color.a)
        surface.SetMaterial(data.material)
        surface.DrawTexturedRect(data.x, data.y, data.w, data.h)
    else
        data.loadingStartTime = data.loadingStartTime or CurTime()

        surface.SetDrawColor(30, 30, 40, 200)
        surface.DrawRect(data.x, data.y, data.w, data.h)

        local loadingSize = math.min(data.w, data.h) * 0.8
        local centerX, centerY = -loadingSize / 2, -loadingSize / 2
        local curTime = CurTime()
        local realTime = RealTime()
        local time = curTime - data.loadingStartTime
        local spinnerRadius = loadingSize * 0.3
        local spinnerWidth = loadingSize * 0.05
        local spinnerSegments = 10

        local spinnerSpeed = math.sin(realTime)
        local spinnerAngle = realTime * (spinnerSpeed * 0.03)

        for i = 1, spinnerSegments do
            local segmentAngle = spinnerAngle + (i * (360 / spinnerSegments))
            local alpha = 0
            local angleMod = (segmentAngle % 120) / 120
            if angleMod < 0.5 then
                alpha = angleMod * 2 * 255
            else
                alpha = (1 - angleMod) * 2 * 255
            end

            local segmentX = centerX + loadingSize / 2 + math.cos(math.rad(segmentAngle)) * spinnerRadius
            local segmentY = centerY + loadingSize / 2 + math.sin(math.rad(segmentAngle)) * spinnerRadius

            surface.SetDrawColor(100, 150, 255, alpha)
            surface.DrawRect(segmentX - spinnerWidth / 2, segmentY - spinnerWidth / 2, spinnerWidth, spinnerWidth)
        end

        draw.SimpleText("Loading...", "DermaLarge", centerX + loadingSize / 2, centerY + loadingSize * 0.75, Color(255, 255, 255, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        local progressWidth = loadingSize * 0.6
        local progressHeight = loadingSize * 0.02
        local progressX = centerX + (loadingSize - progressWidth) / 2
        local progressY = centerY + loadingSize * 0.85

        surface.SetDrawColor(60, 60, 80, 200)
        surface.DrawRect(progressX, progressY, progressWidth, progressHeight)

        local progress = math.abs(math.sin(time * 0.5))
        surface.SetDrawColor(100, 180, 255, 220)
        surface.DrawRect(progressX, progressY, progressWidth * progress, progressHeight)
    end
end

---@param url string
---@param onSuccess? fun(material: IMaterial)
---@param onError? fun(message: string)
function reimgt.QueueImageDownload(url, onSuccess, onError)
    if url:StartsWith("materials/") then
        local materialPath = url:gsub("^materials/", "")
        local mat = Material(materialPath)

        if mat and !mat:IsError() then
            reimgt.cache[url] = mat

            if onSuccess then
                onSuccess(mat)
            end
        else
            if onError then
                onError("Failed to load local material")
            end

            reimgt.Print("error", "Failed to load local material: " .. url)
        end

        return
    end

    url = reimgt.CorrectingURL(url)

    if url == "" then
        if onError then
            onError("Invalid URL provided")
        end

        return reimgt.Print("error", "Invalid URL provided")
    end

    if reimgt.cache[url] then
        if onSuccess then
            onSuccess(reimgt.cache[url])
        end

        return
    end

    if reimgt.downloadCallbacks[url] then
        table.insert(reimgt.downloadCallbacks[url].callbacks, onSuccess)
    end

    reimgt.downloadCallbacks[url] = reimgt.downloadCallbacks[url] or {
        success = onSuccess,
        error = onError,
        callbacks = {}
    }

    table.insert(reimgt.downloadQueue, url)

    reimgt.Print("info", "Added to queue: " .. url)
end

---@param url string
function reimgt.StartDownload(url)
    if reimgt.activeDownloads[url] or reimgt.cache[url] then
        return
    end

    reimgt.activeDownloads[url] = true

    reimgt.Print("system", "Starting download: " .. url)

    local sha256 = util.SHA256(url)
    local filename = reimgt.cacheFolder .. sha256 .. ".png"
    local dataPath = "data/" .. filename

    if file.Exists(filename, "DATA") then
        reimgt.activeDownloads[url] = nil
        reimgt.cache[url] = Material(dataPath)
        reimgt.Print("info", "Loaded from disk cache: " .. url)

        if reimgt.downloadCallbacks and reimgt.downloadCallbacks[url] then
            local succFunc = reimgt.downloadCallbacks[url].success
            if succFunc then
                local material = reimgt.cache[url]

                succFunc(material)

                for _, callback in ipairs(reimgt.downloadCallbacks[url].callbacks) do
                    callback(material)
                end
            end

            reimgt.downloadCallbacks[url] = nil
        end

        return
    end

    http.Fetch(url, function(body, size, headers, code)
        local maxSizeBytes = (GetConVar("reimagetool_max_filesize"):GetInt() or 10) * 1024 * 1024

        reimgt.activeDownloads[url] = nil

        if code != 200 then
            reimgt.Print("error", "Download failed (" .. code .. "): " .. url)

            if reimgt.downloadCallbacks and reimgt.downloadCallbacks[url] then
                if reimgt.downloadCallbacks[url].error then
                    reimgt.downloadCallbacks[url].error()
                end

                reimgt.downloadCallbacks[url] = nil
            end

            return
        end

        if !reimgt.IsValidImage(body, headers) then
            reimgt.Print("warning", "Invalid image format: " .. url)

            if reimgt.downloadCallbacks and reimgt.downloadCallbacks[url] then
                if reimgt.downloadCallbacks[url].error then
                    reimgt.downloadCallbacks[url].error()
                end

                reimgt.downloadCallbacks[url] = nil
            end

            return
        end

        local contentLength = tonumber(headers["Content-Length"])
        if contentLength and contentLength > maxSizeBytes then
            reimgt.activeDownloads[url] = nil
            reimgt.Print("error", "File too large: " .. url .. " (" .. contentLength .. " bytes, max " .. maxSizeBytes .. ")")

            if reimgt.downloadCallbacks[url] then
                if reimgt.downloadCallbacks[url].error then reimgt.downloadCallbacks[url].error() end
                reimgt.downloadCallbacks[url] = nil
            end

            return
        end

        if size > maxSizeBytes then
            reimgt.activeDownloads[url] = nil
            reimgt.Print("error", "File too large (actual): " .. url .. " (" .. size .. " bytes)")
            if reimgt.downloadCallbacks[url] then
                if reimgt.downloadCallbacks[url].error then reimgt.downloadCallbacks[url].error() end
                reimgt.downloadCallbacks[url] = nil
            end

            return
        end

        file.Write(filename, body)

        reimgt.cacheURLs[sha256] = url

        file.Write("reimgt_cache.json", util.TableToJSON(reimgt.cacheURLs, true))

        reimgt.cache[url] = Material(dataPath)

        reimgt.Print("info", "Successfully downloaded and cached: " .. url)

        if reimgt.downloadCallbacks and reimgt.downloadCallbacks[url] then
            if reimgt.downloadCallbacks[url].success then
                local material = reimgt.cache[url]

                reimgt.downloadCallbacks[url].success(material)

                for _, callback in ipairs(reimgt.downloadCallbacks[url].callbacks) do
                    callback(material)
                end
            end

            reimgt.downloadCallbacks[url] = nil
        end
    end,
    function(error)
        reimgt.activeDownloads[url] = nil

        reimgt.Print("error", "Download error: " .. error .. " (" .. url .. ")")

        if reimgt.downloadCallbacks and reimgt.downloadCallbacks[url] then
            if reimgt.downloadCallbacks[url].error then
                reimgt.downloadCallbacks[url].error()
            end

            reimgt.downloadCallbacks[url] = nil
        end
    end)
end


net.Receive(reimgt.prefix .. ".UpdateImage", function()
    local entityIdx = net.ReadUInt(16)
    local length = net.ReadUInt(32)
    local compressed = net.ReadData(length)

    local _, decompressed = reimgt.DecompressData(compressed)
    if !decompressed then
        return reimgt.Print("error", "UpdateImage: failed to decompress data for entity " .. entityIdx)
    end

    reimgt.CheckAndApplyEntity(entityIdx, decompressed, function(success, entity, attempts)
        if success then
            reimgt.Print("info", ("Updated entity %s after %d attempts"):format(tostring(entity), attempts))
        else
            reimgt.Print("error", ("Failed to find entity %d after %d attempts"):format(entityIdx, attempts))
        end
    end)
end)

net.Receive(reimgt.prefix .. ".RemoveImage", function()
    local entityIdx = net.ReadUInt(16)

    local data = reimgt.pendingEntities[entityIdx]
    if data then
        reimgt.Print("error", ("Failed to find entity %d after %d attempts"):format(entityIdx, data.attempts))

        reimgt.pendingEntities[entityIdx] = nil
    end
end)

net.Receive(reimgt.prefix .. ".SyncAll", function()
    local length = net.ReadUInt(32)
    local compressed = net.ReadData(length)
    local dataTable = reimgt.DecompressHeavyData(compressed)

    if !dataTable then
        return reimgt.Print("error", "SyncAll: failed to decompress data")
    end

    for entityIdx, data in pairs(dataTable) do
        reimgt.CheckAndApplyEntity(entityIdx, data, function(success, entity, attempts)
            if success then
                reimgt.Print("info", ("Synced entity %s after %d attempts"):format(tostring(entity), attempts))
            else
                reimgt.Print("error", ("Failed to sync entity %d after %d attempts"):format(entityIdx, attempts))
            end
        end)
    end
end)

net.Receive(reimgt.prefix .. ".DeployTool", function()
    local client = LocalPlayer()

    local tool = client.GetTool and client:GetTool()
    if !tool or tool.Mode != reimgt.toolClass then return end

    tool:DeployNet()
end)

net.Receive(reimgt.prefix .. ".HolsterTool", function()
    local client = LocalPlayer()

    hook.Remove("PostDrawTranslucentRenderables", reimgt.prefix .. ".ToolDraw")

    local tool = client.GetTool and client:GetTool()
    if !tool or tool.Mode != reimgt.toolClass then return end

    tool:HolsterNet()
end)

timer.Simple(math.random(), function()
    timer.Create(reimgt.prefix .. ".DownloaderTimer", 0.5, 0, function()
        if #reimgt.downloadQueue == 0 then return end

        local url = reimgt.downloadQueue[1]
        table.remove(reimgt.downloadQueue, 1)

        if !reimgt.activeDownloads[url] and !reimgt.cache[url] then
            reimgt.StartDownload(url)
        end
    end)
end)

timer.Simple(math.random(), function()
    timer.Create(reimgt.prefix .. ".PendingEntities", 1, 0, function()
        for entIdx, data in pairs(reimgt.pendingEntities) do
            local entity = Entity(entIdx) ---@cast entity ReImgt.Entity

            if IsValid(entity) and entity:GetClass() == reimgt.entityClass and entity.SetImageParams then
                entity:SetImageParams(
                    data.data.url,
                    data.data.width,
                    data.data.height,
                    data.data.render_distance,
                    Color(data.data.color.r, data.data.color.g, data.data.color.b, data.data.color.a),
                    data.data.bLighting,
                    data.data.lightMultiplier,
                    data.data.doubleSided,
                    data.data.disableCollision
                )

                if data.callback then
                    data.callback(true, entity, data.attempts)
                end

                reimgt.pendingEntities[entIdx] = nil
            else
                data.attempts = data.attempts + 1
            end
        end
    end)
end)

-- clear old image (use cache)
timer.Simple(1, function()
    RunConsoleCommand("reimagetool_url", "")
end)