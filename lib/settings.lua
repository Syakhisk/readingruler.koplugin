local DataStorage = require("datastorage")
local LuaSettings = require("luasettings")
local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local logger = require("logger")

-- Constants for settings
local SETTINGS_FILE = DataStorage:getSettingsDir() .. "/readingruler_settings.lua"
local DEFAULTS = {
    enabled = false,
    line_thickness = 2,
    -- TODO: use blitbuffer and use intensity instead of color here
    line_color = 0,
    line_style = "solid", -- solid, dashed, dotted
    follow_mode = "tap",  -- tap, swipe, hold
    notification = true,
    position = 0.5,       -- 0.0 to 1.0 (percentage of screen height)
}

local Settings = {}

function Settings:new()
    local o = {}
    setmetatable(o, self)
    self.__index = self

    -- Load settings from file or use defaults
    o.settings = LuaSettings:open(SETTINGS_FILE)
    if not o.settings then
        o.settings = LuaSettings:open(SETTINGS_FILE)
    end

    -- Initialize with defaults for any missing settings
    o:init()

    return o
end

function Settings:init()
    -- Initialize with default values if not set
    for key, value in pairs(DEFAULTS) do
        if self:get(key) == nil then
            self:set(key, value)
        end
    end
    self:flush()
end

function Settings:get(key)
    return self.settings:readSetting(key)
end

function Settings:set(key, value)
    if self:get(key) ~= value then
        self.settings:saveSetting(key, value)
        return true
    end
    return false
end

function Settings:toggle(key)
    local current = self:get(key)
    if type(current) == "boolean" then
        self:set(key, not current)
        return not current
    end
    return current
end

function Settings:isEnabled()
    return self:get("enabled")
end

function Settings:enable()
    self:set("enabled", true)
    self:flush()
end

function Settings:disable()
    self:set("enabled", false)
    self:flush()
end

function Settings:flush()
    self.settings:flush()
end

return Settings
