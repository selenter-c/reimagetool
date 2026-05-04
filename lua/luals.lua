---@meta

-- reimgt documentation --

---@class ReImgt.ImageParameters
---@field material IMaterial|nil
---@field bLighting boolean
---@field pos Vector
---@field lightMultiplier number
---@field color Color
---@field x number
---@field y number
---@field w number
---@field h number
---@field loadingStartTime? number

---@class ReImgt.SerializeData
---@field url? string
---@field width number
---@field height number
---@field render_distance number
---@field bLighting boolean
---@field doubleSided boolean
---@field lightMultiplier number
---@field disableCollision boolean
---@field color Color
---@field motion? boolean

---@class ReImgt.PendingEntitiesData
---@field data ReImgt.SerializeData
---@field callback fun(success: boolean, entity: Entity, attempts: number)
---@field attempts number

---@class Player
local PLAYER

---@type Vector|nil
PLAYER.useAdvancedPos = nil



-- CPPI documentation --

---@class Entity
local ENTITY

---@param client Player
function ENTITY:CPPISetOwner(client)
end