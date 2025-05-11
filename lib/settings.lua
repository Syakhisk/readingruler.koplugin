local DataStorage = require("datastorage")
local LuaSettings = require("luasettings")
local Device = require("device")
local logger = require("logger")

-- Constants for settings
local SETTINGS_FILE = DataStorage:getSettingsDir() .. "/readingruler_settings.lua"
local DEFAULTS = {
    enabled = false,
    line_thickness = 2,
    -- TODO: use blitbuffer and use intensity instead of color here
    line_intensity = 0.7,
    line_style = "solid", -- solid, dashed, dotted
    follow_mode = "tap", -- tap, swipe, hold
    notification = true,
    position = 0.5, -- 0.0 to 1.0 (percentage of screen height)
}

---@class Settings
local Settings = {}

--- Creates a new Settings object and loads settings from file.
---@return Settings
function Settings:new()
    ---@class Settings
    local o = {}
    setmetatable(o, self)
    self.__index = self

    -- Load settings from file
    ---@module "luasettings"
    o.settings = LuaSettings:open(SETTINGS_FILE)

    -- Initialize with defaults for any missing settings
    o:init()

    return o
end

--- Load the default settings and overwrite it with value from settings file.
function Settings:init()
    -- Initialize with default values if not set
    for key, value in pairs(DEFAULTS) do
        if self:get(key) == nil then
            self:set(key, value)
        end
    end
    self:flush()
end

--- Get settings from the settings file.
---@param key string The key of the setting to retrieve.
---@return any
function Settings:get(key)
    return self.settings:readSetting(key)
end

--- Set a setting in the settings file, returning true if the value changed.
---@param key string The key of the setting to set.
---@param value any The value to set.
---@return boolean
function Settings:set(key, value)
    if self:get(key) ~= value then
        self.settings:saveSetting(key, value)
        self.settings:flush()
        return true
    end
    return false
end

--- Toggle a boolean setting and return the new value.
---@param key string The key of the setting to toggle.
---@return boolean
function Settings:toggle(key)
    local current = self:get(key)
    if type(current) == "boolean" then
        self:set(key, not current)
        return not current
    end
    return current
end

--- Check if the plugin is enabled.
---@return boolean
function Settings:isEnabled()
    return self:get("enabled")
end

--- Enable the plugin and flush.
function Settings:enable()
    self:set("enabled", true)
    -- self:flush()
end

--- Disable the plugin and flush.
function Settings:disable()
    self:set("enabled", false)
    -- self:flush()
end

--- Write the settings to the file.
function Settings:flush()
    self.settings:flush()
end

--
function Settings:___dump()
    logger.info("--- Settings ---")
    logger.info(require("ffi/serpent").block(self.settings.data))
end

return Settings
