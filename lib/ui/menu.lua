local _ = require("gettext")
local Menu = {}
local UIManager = require("ui/uimanager")
local Notification = require("ui/widget/notification")
local SpinWidget = require("ui/widget/spinwidget")
local ConfirmBox = require("ui/widget/confirmbox")
local InfoMessage = require("ui/widget/infomessage")
local ButtonDialogTitle = require("ui/widget/buttondialogtitle")
local logger = require("logger")

function Menu:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    -- Dependencies
    o.settings = o.settings
    o.ruler = o.ruler
    o.ruler_ui = o.ruler_ui
    o.ui = o.ui

    return o
end

function Menu:addToMainMenu(menu_items)
    -- Add main entry for ReadingRuler in KOReader's menu
    menu_items.reading_ruler = {
        text = _("Reading Ruler"),
        sub_item_table = {
            {
                text = _("Toggle reading ruler"),
                keep_menu_open = true,
                checked_func = function() return self.settings:isEnabled() end,
                callback = function() self:toggleRuler() end,
            },
            {
                text = _("Line thickness"),
                keep_menu_open = true,
                callback = function()
                    self:showLineThicknessDialog()
                end,
            },
            {
                text = _("Line style"),
                keep_menu_open = true,
                sub_item_table = {
                    {
                        text = _("Solid"),
                        checked_func = function() return self.settings:get("line_style") == "solid" end,
                        callback = function()
                            self.settings:set("line_style", "solid")
                            if self.settings:isEnabled() then
                                self.ruler_ui:updateUI()
                            end
                        end,
                    },
                    {
                        text = _("Dashed"),
                        checked_func = function() return self.settings:get("line_style") == "dashed" end,
                        callback = function()
                            self.settings:set("line_style", "dashed")
                            if self.settings:isEnabled() then
                                self.ruler_ui:updateUI()
                            end
                        end,
                    },
                    {
                        text = _("Dotted"),
                        checked_func = function() return self.settings:get("line_style") == "dotted" end,
                        callback = function()
                            self.settings:set("line_style", "dotted")
                            if self.settings:isEnabled() then
                                self.ruler_ui:updateUI()
                            end
                        end,
                    },
                }
            },
            {
                text = _("Follow mode"),
                keep_menu_open = true,
                sub_item_table = {
                    {
                        text = _("Tap to move"),
                        checked_func = function() return self.settings:get("follow_mode") == "tap" end,
                        callback = function()
                            self.settings:set("follow_mode", "tap")
                            self:showNotification(_("Tap to move ruler"))
                        end,
                    },
                    {
                        text = _("Swipe to move"),
                        checked_func = function() return self.settings:get("follow_mode") == "swipe" end,
                        callback = function()
                            self.settings:set("follow_mode", "swipe")
                            self:showNotification(_("Swipe to move ruler"))
                        end,
                    },
                    {
                        text = _("Hold to move"),
                        checked_func = function() return self.settings:get("follow_mode") == "hold" end,
                        callback = function()
                            self.settings:set("follow_mode", "hold")
                            self:showNotification(_("Hold to move ruler"))
                        end,
                    },
                }
            },
            {
                text = _("Notifications"),
                checked_func = function() return self.settings:get("notification") end,
                callback = function()
                    self.settings:toggle("notification")
                end,
            },
            {
                text = _("Reset ruler position"),
                keep_menu_open = true,
                callback = function()
                    self.settings:set("position", 0.5) -- Reset to middle
                    if self.settings:isEnabled() then
                        self.ruler:calculateDefaultPosition()
                        self.ruler_ui:updateUI()
                    end
                    self:showNotification(_("Ruler position reset"))
                end,
            },
        }
    }
end

function Menu:toggleRuler()
    if self.settings:isEnabled() then
        -- Turn off
        self.settings:disable()
        self.ruler_ui:hide()
        self:showNotification(_("Reading ruler disabled"))
    else
        -- Turn on
        self.settings:enable()
        self.ruler_ui:buildUI()
        self:showNotification(_("Reading ruler enabled"))
    end
end

function Menu:showLineThicknessDialog()
    local current_thickness = self.settings:get("line_thickness")

    UIManager:show(SpinWidget:new {
        title_text = _("Line thickness"),
        info_text = _("Set the thickness of the ruler line."),
        width = math.floor(current_thickness),
        value = current_thickness,
        value_min = 1,
        value_max = 10,
        value_step = 1,
        value_hold_step = 2,
        ok_text = _("Set thickness"),
        callback = function(new_thickness)
            self.settings:set("line_thickness", new_thickness)
            if self.settings:isEnabled() then
                self.ruler_ui:updateUI()
            end
        end,
    })
end

function Menu:showNotification(text)
    if self.settings:get("notification") then
        UIManager:show(Notification:new {
            text = text,
            timeout = 2,
        })
    end
end

return Menu
