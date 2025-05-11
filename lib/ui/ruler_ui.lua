local FrameContainer = require("ui/widget/container/framecontainer")
local Device = require("device")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local MovableContainer = require("ui/widget/container/movablecontainer")
local LineWidget = require("ui/widget/linewidget")
local UIManager = require("ui/uimanager")
local Screen = Device.screen
local logger = require("logger")
local Event = require("ui/event")

local ignore_events = {
    "hold",
    "hold_release",
    "hold_pan",
    "swipe",
    "touch",
    "pan",
    "pan_release",
}

---@class RulerUI
local RulerUI = WidgetContainer:new()

function RulerUI:new(args)
    -- Create a new instance of RulerUI
    local o = WidgetContainer:new(args)
    setmetatable(o, self)
    self.__index = self

    -- Initialize properties
    o.ruler = args.ruler
    o.settings = args.settings
    o.ui = args.ui
    o.inputContainer = args.inputContainer

    -- Initialize the ruler UI
    o:init()

    return o
end

function RulerUI:init()
    -- State
    self.ruler_widget = nil
    self.touch_container_widget = nil
    self.movable_widget = nil
    self.is_visible = false

    -- Create gesture handling
    self:setupGestures()
end

function RulerUI:setupGestures()
    -- Set up gesture ranges for different parts of the screen
    if Device:isTouchDevice() then
        local range = Geom:new({ x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() })

        self.inputContainer.ges_events = {
            Tap = {
                GestureRange:new({
                    ges = "tap",
                    range = range,
                }),
            },
            Swipe = {
                GestureRange:new({
                    ges = "swipe",
                    range = range,
                }),
            },
        }
    end
end

function RulerUI:buildUI()
    logger.info("--- build ruler UI")
    -- Create or update the ruler line widget
    local line_props = self.ruler:getLineProperties()
    local geom = self.ruler:getLineGeometry()

    -- Create line widget
    self.ruler_widget = LineWidget:new({
        background = line_props.color,
        dimen = Geom:new({ w = geom.w, h = geom.h }),
    })

    local padding_y = 0.01 * Screen:getHeight() -- NOTE: see if this needs to be configurable
    self.touch_container_widget = FrameContainer:new({
        bordersize = 0,
        padding = 0,
        padding_top = padding_y,
        padding_bottom = padding_y,
        self.ruler_widget,
    })

    self.movable_widget = MovableContainer:new({
        ignore_events = ignore_events,
        self.touch_container_widget,
    })
end

function RulerUI:updateUI()
    local geom = self.ruler:getLineGeometry()

    -- remove the top padding from container to get the correct y position of line.
    local trans_y = geom.y - self.touch_container_widget.padding_top
    local curr_y = self.movable_widget:getMovedOffset().y

    if trans_y ~= curr_y then
        self.movable_widget:setMovedOffset({ x = geom.x, y = trans_y })
    end

    local line_props = self.ruler:getLineProperties()
    self.ruler_widget.style = line_props.style
    self.ruler_widget.dimen.h = line_props.thickness

    if self.movable_widget ~= nil and self.movable_widget.dimen ~= nil then
        local orig_dimen = self.movable_widget.dimen:copy() -- dimen before move/paintTo

        UIManager:setDirty("all", function()
            local update_region = orig_dimen:combine(self.movable_widget.dimen)
            logger.dbg("ReadingRuler: refresh region", update_region)
            return "ui", update_region
        end)
    end
end

function RulerUI:paintTo(bb, x, y)
    if not self.settings:isEnabled() then
        return
    end

    -- Paint the ruler widget to the screen
    if self.movable_widget then
        logger.info("--- RulerUI:paintTo")
        self.movable_widget:paintTo(bb, x, y)
    end
end

function RulerUI:hide()
    -- Hide the ruler
    if self.is_visible and self.movable_widget then
        UIManager:setDirty(nil, function()
            return "ui", self.movable_widget.dimen
        end)
        self.is_visible = false
    end
end

function RulerUI:displayNotification(text)
    -- Only show notifications if enabled in settings
    if not self.settings:get("notification") then
        return
    end

    UIManager:show(Notification:new({
        text = text,
        timeout = 2,
    }))
end

function RulerUI:onPageUpdate(new_page)
    self.ruler:setInitialPosition(new_page)
    self:updateUI()
end

-- Gesture handling
function RulerUI:onTap(_, ges)
    if not self.settings:isEnabled() then
        return false
    end

    local is_tap_to_move = self.ruler:isTapToMoveMode()
    local is_tap_on_ruler = ges.pos:intersectWith(self.touch_container_widget.dimen)

    if is_tap_on_ruler then
        if is_tap_to_move then
            logger.info("--- exit tap to move")
            self.ruler:exitTapToMoveMode()
        else
            logger.info("--- enter tap to move")
            self.ruler:enterTapToMoveMode()
        end

        self:updateUI()
        return true
    end

    if is_tap_to_move then
        logger.info("--- tap to move")
        self.ruler:moveToNearestLine(ges.pos.y)
        self.ruler:exitTapToMoveMode()
        self:updateUI()
        return true
    end

    if self.settings:get("follow_mode") == "tap" then
        self.ruler:moveToNextLine()
        self:updateUI()
        return true
    end

    return false
end

function RulerUI:onSwipe(_, ges)
    if not self.settings:isEnabled() then
        return false
    end

    logger.info("--- RulerUI:onSwipe ---")

    if self.settings:get("follow_mode") ~= "swipe" then
        return false
    end

    if ges.direction == "north" then
        if self.ruler:moveToPreviousLine() then
            self:updateUI()
            return true
        end

        self.ui:handleEvent(Event:new("GotoViewRel", -1))
        return true
    end

    if ges.direction == "south" then
        if self.ruler:moveToNextLine() then
            self:updateUI()
            return true
        end

        self.ui:handleEvent(Event:new("GotoViewRel", 1))
        return true
    end

    return false
end

return RulerUI
