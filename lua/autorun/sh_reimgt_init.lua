AddCSLuaFile("reimgt/sh_reimgt.lua")
include("reimgt/sh_reimgt.lua")

AddCSLuaFile("reimgt/cl_reimgt.lua")
AddCSLuaFile("reimgt/derma/cl_image_browser.lua")

if CLIENT then
    include("reimgt/cl_reimgt.lua")
    include("reimgt/derma/cl_image_browser.lua")

    if file.Exists("reimgt_cache.json", "DATA") then
        reimgt.cacheURLs = util.JSONToTable(file.Read("reimgt_cache.json", "DATA") or "") or {}
    end
end

if SERVER then
    include("reimgt/sv_reimgt.lua")

    include("reimgt/extra/sv_permaprops_support.lua")
end