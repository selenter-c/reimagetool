---@class ReImgt
---@field instances table<ReImgt.Entity, boolean>
---@field queue table<number, boolean>
---@field pendingEntities table<number, ReImgt.PendingEntitiesData>
reimgt = reimgt or {}
reimgt.instances = reimgt.instances or {}
reimgt.entityClass = "reimgt_image"
reimgt.toolClass = "reimagetool"
reimgt.prefix = "Re;ImageTool"

reimgt.PositionsRotating = {
    [1] = {
        name = "Center",
        offset = function(sizeX, sizeY, angle)
            return Vector(0, 0, 0)
        end
    },
    [2] = {
        name = "Right",
        offset = function(sizeX, sizeY, angle)
            return angle:Forward() * -sizeX * 0.5
        end
    },
    [3] = {
        name = "Left",
        offset = function(sizeX, sizeY, angle)
            return angle:Forward() * sizeX * 0.5
        end
    },
    [4] = {
        name = "Up",
        offset = function(sizeX, sizeY, angle)
            return angle:Right() * sizeY * 0.5
        end
    },
    [5] = {
        name = "Down",
        offset = function(sizeX, sizeY, angle)
            return angle:Right() * -sizeY * 0.5
        end
    },
    [6] = {
        name = "Up-Right",
        offset = function(sizeX, sizeY, angle)
            return angle:Forward() * -sizeX * 0.5 + angle:Right() * sizeY * 0.5
        end
    },
    [7] = {
        name = "Up-Left",
        offset = function(sizeX, sizeY, angle)
            return angle:Forward() * sizeX * 0.5 + angle:Right() * sizeY * 0.5
        end
    },
    [8] = {
        name = "Left-Down",
        offset = function(sizeX, sizeY, angle)
            return angle:Forward() * sizeX * 0.5 + angle:Right() * -sizeY * 0.5
        end
    },
    [9] = {
        name = "Right-Down",
        offset = function(sizeX, sizeY, angle)
            return angle:Forward() * -sizeX * 0.5 + angle:Right() * -sizeY * 0.5
        end
    }
}

reimgt.ValidExtensions = {
    fileExtensions = {
        png = true,
        jpg = true,
        jpeg = true,
        jfif = true
    },
    mimeTypes = {
        ["image/png"] = true,
        ["image/jpeg"] = true,
        ["image/jpg"] = true
    },
    domainBlacklist = {
        ["test.com"] = true
    },
    domainReplacements = {
        ["www%.imgur%.com"] = "i.imgur.com",
        ["www%.gyazo%.com"] = "i.gyazo.com",
        ["images%.discordapp%.net"] = "media.discordapp.net",

        -- Imgur
        ["imugr.com"] = "imgur.com",
        ["imgr.com"] = "imgur.com",
        ["imgu.com"] = "imgur.com",
        ["imgur.cm"] = "imgur.com",
        ["imgur.co"] = "imgur.com",
        ["imgur.ne"] = "imgur.com",
        ["i.imgur.cm"] = "imgur.com",
        ["i.imgur.co"] = "imgur.com",
        ["imgur%.ru"] = "imgur.com",
        ["imgur%.ua"] = "imgur.com",
        ["imgur%.uk"] = "imgur.com",

        -- VGY.ME
        ["vgy%.me"] = "vgy.me",
        ["vgyme%.com"] = "vgy.me",
        ["vgy%.me%."] = "vgy.me",
        ["vgy%.im"] = "vgy.me",
        ["vyg%.me"] = "vgy.me",
        ["vgy%.net"] = "vgy.me",
        ["vgy%.co"] = "vgy.me",
        ["i%.vgy%.me"] = "vgy.me",

        -- IMGBB
        ["imgbb%.com"] = "imgbb.com",
        ["ibbb%.com"] = "imgbb.com",
        ["imgb%.com"] = "imgbb.com",
        ["imgbb%.co"] = "imgbb.com",
        ["imgbb%.net"] = "imgbb.com",
        ["imbg%.com"] = "imgbb.com",
        ["i%.imgbb%.com"] = "imgbb.com",
        ["imgbb%.me"] = "imgbb.com",
        ["imgb%.cc"] = "imgbb.com",

        -- Discord
        ["discordapp.org"] = "discordapp.net",
        ["discordapp.com"] = "media.discordapp.net",
        ["cdn.discord.com"] = "media.discordapp.net",
        ["discord.gg"] = "media.discordapp.net",

        -- Gyazo
        ["gazo.com"] = "gyazo.com",
        ["gyazo.net"] = "gyazo.com",
        ["gyazo.org"] = "gyazo.com",

        -- Postimg
        ["postimage.org"] = "postimg.cc",
        ["postimg.com"] = "postimg.cc",

        -- Flickr
        ["flicker.com"] = "flickr.com",
        ["flicr.com"] = "flickr.com",

        -- Reddit
        ["redd.it"] = "reddit.com",
        ["i.redd.it.com"] = "i.redd.it",

        -- Google
        ["gogle.com"] = "google.com",
        ["gooogle.com"] = "google.com",
    },
    preserveQueryURLs = {
        ["media.discordapp.net"] = true
    }
}

---@param body any
---@param headers table
function reimgt.IsValidImage(body, headers)
    local contentType = headers and headers["Content-Type"]
    if contentType then
        contentType = contentType:lower():gsub(";.+$", "")

        if reimgt.ValidExtensions.mimeTypes[contentType] then
            return true
        end
    end

    if type(body) != "string" or #body < 4 then
        return false
    end

    local domain = body:match("^https?://([^/]+)")
    if domain and reimgt.ValidExtensions.domainBlacklist[domain:lower()] then
        return false
    end

    local fileExtension = body:match("^.+(%..+)$")
    if fileExtension then
        fileExtension = fileExtension:sub(2):lower()

        return reimgt.ValidExtensions.fileExtensions[fileExtension]
    end

    return false
end

local function levenshtein(s, t)
    local m, n = #s, #t
    if m == 0 then return n end
    if n == 0 then return m end

    local d = {}
    for i = 0, m do d[i] = {[0] = i} end
    for j = 1, n do d[0][j] = j end

    for j = 1, n do
        for i = 1, m do
            d[i][j] = math.min(
                d[i-1][j] + 1,
                d[i][j-1] + 1,
                d[i-1][j-1] + (s:sub(i,i) == t:sub(j,j) and 0 or 1)
            )
        end
    end

    return d[m][n]
end

local function fixDiscordURL(url)
    url = url:gsub("^https?://cdn%.discordapp%.com", "https://media.discordapp.net")

    url = url:gsub("^https?://discord%.com/attachments/", "https://media.discordapp.net/attachments/")
    url = url:gsub("^https?://discordapp%.com/attachments/", "https://media.discordapp.net/attachments/")

    return url
end

---@param url string
---@return string
function reimgt.CorrectingURL(url)
    if url:StartsWith("materials/") then
        return url
    end

    url = url:Trim():gsub("[^\32-\126]", "")

    local http_pos = url:lower():find("https?://")
    if http_pos then
        url = url:sub(http_pos)
        url = url:gsub("https?://[^/]+//", "http://")
    else
        url = "https://" .. url
    end

    url = fixDiscordURL(url)

    local domain = url:match("^https?://([^/]+)")
    if domain then
        local lowerDomain = domain:lower()

        for wrong, correct in pairs(reimgt.ValidExtensions.domainReplacements) do
            if lowerDomain == wrong or lowerDomain:find(wrong:gsub("%.", "%%.")) then
                url = url:gsub(domain, correct)
                domain = correct

                break
            end
        end
    end

    local preserveQuery = domain and reimgt.ValidExtensions.preserveQueryURLs[domain:lower()]
    if !preserveQuery then
        url = url:gsub("[%?#].*$", "")
    end

    url = url:gsub("([^:])//+", "%1/")

    if !url:match("^https?://[%w%.%-]+%.[%a]+") then
        return ""
    end

    if !preserveQuery then
        local last_dot = url:reverse():find("%.")

        if !last_dot then
            for ext in pairs(reimgt.ValidExtensions.fileExtensions) do
                if url:match("/[^/]+$") then
                    url = url .. "." .. ext
                    break
                end
            end

            return url
        end

        last_dot = #url - last_dot + 1

        local ext_part = url:sub(last_dot + 1)
        local clean_ext = ext_part:gsub("[^%a]", ""):lower()

        local corrected_ext = nil
        local min_distance = math.huge
        local max_length = 0

        for valid_ext in pairs(reimgt.ValidExtensions.fileExtensions) do
            if valid_ext:sub(1, #clean_ext) == clean_ext and #valid_ext > max_length then
                corrected_ext = valid_ext
                max_length = #valid_ext
            end

            if clean_ext:find(valid_ext) then
                corrected_ext = valid_ext
                break
            end

            local distance = levenshtein(clean_ext, valid_ext)
            if distance < 2 and distance < min_distance then
                corrected_ext = valid_ext
                min_distance = distance
            end
        end

        if corrected_ext then
            url = url:sub(1, last_dot) .. corrected_ext
        else
            url = url:sub(1, last_dot - 1)
        end

        if !url:match("%.[%a]+$") then
            for ext in pairs(reimgt.ValidExtensions.fileExtensions) do
                if url:match("/[^/]+$") then
                    url = url .. "." .. ext

                    break
                end
            end
        end
    end

    return url
end

reimgt.ColorPrints = {
    info = Color(100, 255, 100),
    warning = Color(255, 255, 100),
    error = Color(255, 100, 100),
    system = Color(100, 200, 255),
    separator = Color(150, 150, 150),
    server = Color(100, 150, 255),
    client = Color(255, 150, 100),
    prefix = Color(200, 200, 255)
}

reimgt.ColorPrints = {
    info = Color(100, 255, 100),
    warning = Color(255, 255, 100),
    error = Color(255, 100, 100),
    system = Color(100, 200, 255),
    separator = Color(150, 150, 150),
    server = Color(100, 150, 255),
    client = Color(255, 150, 100),
    prefix = Color(200, 200, 255)
}

reimgt.TypeFormats = {
    warning = "WARNING",
    system  = " SYSTEM",
    error   = "  ERROR",
    info    = "   INFO"
}

---@param stype string
---@param message string
function reimgt.Print(stype, message)
    local time = os.date("%d/%m/%Y %H:%M:%S")
    local typeFormat = reimgt.TypeFormats[stype] or stype
    local typeColor = reimgt.ColorPrints[stype] or Color(255, 255, 255)

    local sideText = SERVER and "[SERVER]" or "[CLIENT]"
    local sideColor = SERVER and reimgt.ColorPrints.server or reimgt.ColorPrints.client

    MsgC(
        reimgt.ColorPrints.separator, time,
        typeColor, typeFormat,
        reimgt.ColorPrints.separator, " --- ",
        sideColor, sideText,
        reimgt.ColorPrints.separator, " ",
        reimgt.ColorPrints.prefix, reimgt.prefix,
        reimgt.ColorPrints.separator, " : ",
        Color(255, 255, 255), message,
        "\n"
    )
end

---@param data string
---@return string
function reimgt.EncodeData(data)
    return util.Base64Encode(util.Compress(data))
end

---@param compressed string
---@return string|nil
function reimgt.DecodeData(compressed)
    if !compressed or compressed == "" then
        return reimgt.Print("error", "DecodeData: empty input string")
    end

    local succ, decoded = pcall(util.Base64Decode, compressed)
    if !succ then
        return reimgt.Print("error", "DecodeData: Base64 decode failed")
    end

    local decompressed = util.Decompress(decoded)
    if !decompressed then
        return reimgt.Print("error", "DecodeData: Decompress failed")
    end

    return decompressed
end

---@param entIndex number
---@param data ReImgt.SerializeData
function reimgt.SerializeData(entIndex, data)
    local color = data.color or Color(255, 255, 255, 255)

    local info = ("%d~%s~%d~%d~%d~%d~%d~%d~%d~%s~%s~%.1f~%s"):format(
        entIndex or -1,
        data.url or "",
        data.width or 64,
        data.height or 64,
        data.render_distance or 2000,
        color.r or 255,
        color.g or 255,
        color.b or 255,
        color.a or 255,
        data.bLighting and 1 or 0,
        data.doubleSided and 1 or 0,
        data.lightMultiplier or 1,
        data.disableCollision and 1 or 0
    )

    return info
end

---@param fields string|number|boolean[]
---@return ReImgt.SerializeData
function reimgt.CreateDataTable(fields)
    local data = {
        url = tostring(fields[2]),
        width = tonumber(fields[3]),
        height = tonumber(fields[4]),
        render_distance = tonumber(fields[5]),
        color = {
            r = tonumber(fields[6]),
            g = tonumber(fields[7]),
            b = tonumber(fields[8]),
            a = tonumber(fields[9])
        },
        bLighting = tobool(fields[10]),
        doubleSided = tobool(fields[11]),
        lightMultiplier = tonumber(fields[12]),
        disableCollision = tobool(fields[13])
    }

    return data
end

---@param str string
---@return number|nil, ReImgt.SerializeData|nil
function reimgt.ParseData(str)
    if !str or str == "" then return nil end

    local fields = {}
    for val in str:gmatch("([^~]+)") do
        fields[#fields + 1] = val
    end

    if #fields < 13 then
        return reimgt.Print("error", ("ParseData: invalid format, got %d fields, expected 12"):format(#fields))
    end

    local data = reimgt.CreateDataTable(fields)
    if !data then return nil end

    local entIndex = tonumber(fields[1])
    return entIndex != -1 and entIndex or nil, data
end

---@param data ReImgt.SerializeData
---@return string
function reimgt.CompressData(data)
    if !data then return "" end

    return reimgt.EncodeData(reimgt.SerializeData(-1, data))
end

---@param compressed string
---@return number|nil, ReImgt.SerializeData|nil
function reimgt.DecompressData(compressed)
    local raw = reimgt.DecodeData(compressed)
    if !raw then
        return reimgt.Print("error", "DecompressData: DecodeData failed")
    end

    local entIndex, data = reimgt.ParseData(raw)
    if !data then
        return reimgt.Print("error", "DecompressData: ParseData failed for raw: " .. tostring(raw))
    end

    return entIndex, data
end

---@param data table
---@return string
function reimgt.CompressHeavyData(data)
    if !data or table.IsEmpty(data) then return "" end

    local buffer = {}
    for entIndex, info in pairs(data) do
        buffer[#buffer + 1] = reimgt.SerializeData(entIndex, info)
    end

    return reimgt.EncodeData(table.concat(buffer, "|"))
end

---@param compressed string
---@return table<number, ReImgt.SerializeData>
function reimgt.DecompressHeavyData(compressed)
    local raw = reimgt.DecodeData(compressed)
    if !raw then return {} end

    local result = {}
    for entry in raw:gmatch("([^|]+)") do
        local entIndex, data = reimgt.ParseData(entry)

        if entIndex and data then
            result[entIndex] = data
        end
    end

    return result
end


CreateConVar("reimagetool_max_filesize", "10", {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED}, "Max image file size in MB", 1, 100)
CreateConVar("reimagetool_max_width", "2048", {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED, FCVAR_LUA_SERVER}, "", 1, 2048)
CreateConVar("reimagetool_max_heigth", "2048", {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED, FCVAR_LUA_SERVER}, "", 1, 2048)
CreateConVar("reimagetool_max_scale", "10", {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED, FCVAR_LUA_SERVER}, "", 0.01, 10)
CreateConVar("sbox_maximages", "5", {FCVAR_NOTIFY, FCVAR_REPLICATED, FCVAR_LUA_SERVER}, "Determines the maximum number of images users can spawn.")