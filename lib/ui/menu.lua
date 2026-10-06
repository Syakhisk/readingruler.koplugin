local _ = require("gettext")
local Menu = {}
local UIManager = require("ui/uimanager")
local SpinWidget = require("ui/widget/spinwidget")
local Github = require("lib/github")
local DataStorage = require("datastorage")
local InfoMessage = require("ui/widget/infomessage")
local Font = require("ui/font")

local VERSION = require("readingruler_version")

function Menu:new(args)
    local o = {}
    setmetatable(o, self)
    self.__index = self

    o.settings = args.settings
    o.ruler = args.ruler
    o.ruler_ui = args.ruler_ui
    o.ui = args.ui

    return o
end

-- Add main entry for ReadingRuler in KOReader's menu
function Menu:addToMainMenu(menu_items)
    menu_items.reading_ruler = {
        text = _("Reading Ruler"),
        sub_item_table = {
            {
                text = _("Toggle reading ruler"),
                keep_menu_open = true,
                checked_func = function()
                    return self.settings:isEnabled()
                end,
                callback = function()
                    self.ruler_ui:toggleEnabled()
                end,
            },
            {
                text = _("Line thickness"),
                keep_menu_open = true,
                callback = function()
                    self:showLineThicknessDialog()
                end,
            },
            {
                text = _("Line intensity"),
                keep_menu_open = true,
                callback = function()
                    self:showLineIntensityDialog()
                end,
            },
            {
                text = _("Ruler height (lines)"),
                keep_menu_open = true,
                callback = function()
                    self:showRulerLineCountDialog()
                end,
            },
            {
                text = _("Navigation mode"),
                keep_menu_open = true,
                sub_item_table = {
                    {
                        text = _("Tap to move"),
                        checked_func = function()
                            return self.settings:get("navigation_mode") == "tap"
                        end,
                        callback = function()
                            self.settings:set("navigation_mode", "tap")
                            self.ruler_ui:displayNotification(_("Tap to move ruler"))
                        end,
                    },
                    {
                        text = _("Swipe to move"),
                        checked_func = function()
                            return self.settings:get("navigation_mode") == "swipe"
                        end,
                        callback = function()
                            self.settings:set("navigation_mode", "swipe")
                            self.ruler_ui:displayNotification(_("Swipe to move ruler"))
                        end,
                    },
                    {
                        text = _("None (bring-your-own gesture)"),
                        checked_func = function()
                            return self.settings:get("navigation_mode") == "none"
                        end,
                        callback = function()
                            self.settings:set("navigation_mode", "none")
                            self.ruler_ui:displayNotification(_("Ruler navigation disabled"))
                        end,
                    },
                },
            },
            {
                text = _("Auto scroll"),
                keep_menu_open = true,
                checked_func = function()
                    return self.settings:get("auto_scroll_enabled")
                end,
                callback = function()
                    self.ruler_ui:toggleAutoScroll()
                end,
            },
            {
                text = _("Auto scroll interval"),
                keep_menu_open = true,
                enabled_func = function()
                    return self.settings:get("auto_scroll_enabled")
                end,
                callback = function()
                    self:showAutoScrollIntervalDialog()
                end,
            },
            {
                text = _("End-of-page wait (seconds)"),
                keep_menu_open = true,
                enabled_func = function()
                    return self.settings:get("auto_scroll_enabled")
                end,
                callback = function()
                    self:showEndOfPageWaitDialog()
                end,
            },
            {
                text = _("Notifications"),
                checked_func = function()
                    return self.settings:get("notification")
                end,
                callback = function()
                    self.settings:toggle("notification")
                end,
            },
            {
                text = _("About"),
                callback = function()
                    local new_release = Github:newestRelease()
                    local version = table.concat(VERSION, ".")
                    require("logger").info(version)
                    local new_release_str = ""
                    if new_release then
                        new_release_str = " (latest v" .. new_release .. ")"
                    end
                    local settings_file = DataStorage:getSettingsDir() .. "/" .. "readingruler_settings.lua"

                    UIManager:show(InfoMessage:new({
                        text = [[
Reading Ruler Plugin
v]] .. version .. new_release_str .. [[


Reading Ruler is a plugin that brings movable underlines to KOReader!

Project:
github.com/syakhisk/readingruler.koplugin

Settings:
]] .. settings_file,
                        face = Font:getFace("cfont", 18),
                        show_icon = false,
                    }))
                end,
                keep_menu_open = true,
            },
        },
    }
end

function Menu:showRulerLineCountDialog()
    local spin_widget = SpinWidget:new({
        value = self.settings:get("line_count"),
        value_min = 1,
        value_max = 30,
        value_step = 1,
        value_hold_step = 5,
        title_text = _("Ruler height (number of lines)"),
        info_text = _("1 = single underline (default). Higher values draw one underline per line, covering several lines."),
        ok_text = _("Set lines"),
        callback = function(new_count)
            self.settings:set("line_count", new_count.value)

            if self.settings:isEnabled() then
                self.ruler_ui:updateUI()
            end
        end,
    })

    UIManager:show(spin_widget)
end

function Menu:showAutoScrollIntervalDialog()
    local spin_widget = SpinWidget:new({
        value = self.settings:get("auto_scroll_interval"),
        value_min = 1,
        value_max = 3600,
        value_step = 1,
        value_hold_step = 10,
        title_text = _("Auto scroll interval (seconds)"),
        info_text = _("Move the ruler one line down every N seconds."),
        ok_text = _("Set interval"),
        callback = function(new_interval)
            self.settings:set("auto_scroll_interval", new_interval.value)

            -- Apply the new interval immediately if auto scroll is running
            self.ruler_ui:restartAutoScrollIfRunning()

            if self.settings:get("auto_scroll_enabled") then
                self.ruler_ui:displayNotification(string.format(_("Auto scroll interval set to %d seconds"), new_interval.value))
            end
        end,
    })

    UIManager:show(spin_widget)
end

function Menu:showEndOfPageWaitDialog()
    local spin_widget = SpinWidget:new({
        value = self.settings:get("auto_scroll_end_interval"),
        value_min = 0,
        value_max = 3600,
        value_step = 1,
        value_hold_step = 10,
        title_text = _("End-of-page wait (seconds)"),
        info_text = _("When auto scroll reaches the last line of the page, wait this many seconds before turning to the next page, so you can re-read the rest of the page. 0 turns the page right away."),
        ok_text = _("Set wait"),
        callback = function(new_wait)
            self.settings:set("auto_scroll_end_interval", new_wait.value)

            if self.settings:get("auto_scroll_enabled") then
                self.ruler_ui:displayNotification(string.format(_("End-of-page wait set to %d seconds"), new_wait.value))
            end
        end,
    })

    UIManager:show(spin_widget)
end

function Menu:showLineThicknessDialog()
    local spin_widget = SpinWidget:new({
        value = self.settings:get("line_thickness"),
        value_min = 0,
        value_max = 100,
        value_step = 1,
        value_hold_step = 5,
        title_text = _("Line thickness"),
        ok_text = _("Set thickness"),
        callback = function(new_thickness)
            self.settings:set("line_thickness", new_thickness.value)

            if self.settings:isEnabled() then
                self.ruler_ui:updateUI()
            end
        end,
    })

    UIManager:show(spin_widget)
end

function Menu:showLineIntensityDialog()
    local spin_widget = SpinWidget:new({
        value = self.settings:get("line_intensity"),
        value_min = 0,
        value_max = 1,
        value_step = 0.1,
        value_hold_step = 0.5,
        precision = "%.2f",
        title_text = _("Line intensity"),
        ok_text = _("Set intensity"),
        callback = function(new_intensity)
            self.settings:set("line_intensity", new_intensity.value)

            if self.settings:isEnabled() then
                self.ruler_ui:updateUI()
            end
        end,
    })

    UIManager:show(spin_widget)
end

return Menu
