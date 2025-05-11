local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local LineWidget = require("ui/widget/linewidget")
local UIManager = require("ui/uimanager")
local Screen = Device.screen
local logger = require("logger")

local RulerUI = WidgetContainer:new()

function RulerUI:init()
    -- TODO: check if this correct
    self.ruler = self.ruler
    self.settings = self.settings
    self.ui = self.ui

    -- State
    self.ruler_widget = nil
    self.is_visible = false

    -- Create gesture handling
    self:setupGestures()
end

function RulerUI:setupGestures()
    -- Set up gesture ranges for different parts of the screen
    if Device:isTouchDevice() then
        self.ges_events = {
            TapDragRelease = {
                GestureRange:new {
                    ges = "tap_drag_release",
                    range = Geom:new {
                        x = 0, y = 0,
                        w = Screen:getWidth(),
                        h = Screen:getHeight(),
                    }
                },
            },
            Tap = {
                GestureRange:new {
                    ges = "tap",
                    range = Geom:new {
                        x = 0, y = 0,
                        w = Screen:getWidth(),
                        h = Screen:getHeight(),
                    }
                },
            },
            Swipe = {
                GestureRange:new {
                    ges = "swipe",
                    range = Geom:new {
                        x = 0, y = 0,
                        w = Screen:getWidth(),
                        h = Screen:getHeight(),
                    }
                },
            },
            Hold = {
                GestureRange:new {
                    ges = "hold",
                    range = Geom:new {
                        x = 0, y = 0,
                        w = Screen:getWidth(),
                        h = Screen:getHeight(),
                    }
                },
            },
        }
    end
end

function RulerUI:buildUI()
    -- Create or update the ruler line widget
    local line_props = self.ruler:getLineProperties()
    local geom = self.ruler:getLineGeometry()

    -- Create line widget
    self.ruler_widget = LineWidget:new {
        dimen = Geom:new {
            x = geom.x,
            y = geom.y,
            w = geom.w,
            h = geom.h,
        },
        thick = line_props.thickness,
        style = line_props.style,
        color = line_props.color,
    }

    -- Make ruler visible
    self:show()
end

function RulerUI:updateUI()
    -- Update the ruler widget with new position/properties
    if not self.ruler_widget then return end

    local line_props = self.ruler:getLineProperties()
    local geom = self.ruler:getLineGeometry()

    self.ruler_widget:free()
    self.ruler_widget = LineWidget:new {
        dimen = Geom:new {
            x = geom.x,
            y = geom.y,
            w = geom.w,
            h = geom.h,
        },
        thick = line_props.thickness,
        style = line_props.style,
        color = line_props.color,
    }

    -- Force a UI update
    UIManager:setDirty(self.ruler_widget)
end

function RulerUI:show()
    -- Show the ruler if not already visible
    if not self.is_visible and self.ruler_widget then
        UIManager:setDirty(nil, function()
            return "ui", self.ruler_widget.dimen
        end)
        self.is_visible = true
    end
end

function RulerUI:hide()
    -- Hide the ruler
    if self.is_visible and self.ruler_widget then
        UIManager:setDirty(nil, function()
            return "ui", self.ruler_widget.dimen
        end)
        self.is_visible = false
    end
end

function RulerUI:displayNotification(text)
    -- Only show notifications if enabled in settings
    if not self.settings:get("notification") then
        return
    end

    UIManager:show(Notification:new {
        text = text,
        timeout = 2,
    })
end

-- Gesture handling
function RulerUI:onTap(_, ges)
    if not self.settings:isEnabled() then
        return false
    end

    -- If tap mode, move ruler to tap position
    if self.settings:get("follow_mode") == "tap" then
        self.ruler:setPosition(ges.pos.y)
        self:updateUI()
        return true
    end

    return false
end

function RulerUI:onSwipe(_, ges)
    if not self.settings:isEnabled() then
        return false
    end

    -- If swipe mode, move ruler up/down
    if self.settings:get("follow_mode") == "swipe" then
        if ges.direction == "north" then
            self.ruler:moveUp(20)
            self:updateUI()
            return true
        elseif ges.direction == "south" then
            self.ruler:moveDown(20)
            self:updateUI()
            return true
        end
    end

    return false
end

function RulerUI:onHold(_, ges)
    if not self.settings:isEnabled() then
        return false
    end

    -- If hold mode, move ruler to hold position
    if self.settings:get("follow_mode") == "hold" then
        self.ruler:setPosition(ges.pos.y)
        self:updateUI()
        return true
    end

    return false
end

-- For drag-based movement
function RulerUI:onTapDragRelease(_, ges)
    if not self.settings:isEnabled() then
        return false
    end

    -- Move ruler to final drag position
    self.ruler:setPosition(ges.pos.y)
    self:updateUI()
    return true
end

return RulerUI
