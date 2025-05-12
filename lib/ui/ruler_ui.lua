local _ = require("gettext")
local Device = require("device")
local Event = require("ui/event")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local LineWidget = require("ui/widget/linewidget")
local MovableContainer = require("ui/widget/container/movablecontainer")
local Notification = require("ui/widget/notification")
local Screen = Device.screen
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local logger = require("logger")

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
    o.document = args.document

    -- Initialize the ruler UI
    o:init()

    return o
end

function RulerUI:init()
    -- State
    self.ruler_widget = nil
    self.touch_container_widget = nil
    self.movable_widget = nil
    self.is_built = false
end

-- Build the UI components needed, BUT not responsible for drawing them
-- drawing will be taken care of by the updateUI/repaint functions.
-- The reason is that, during initialization buildUI will be called.
-- In that flow, we will draw the UI in the onPageUpdate function.
-- @see RulerUI:setEnabled to see the flow of how the UI is built and drawn.
function RulerUI:buildUI()
    -- Create or update the ruler line widget
    local line_props = self.ruler:getRulerProperties()
    local geom = self.ruler:getRulerGeometry()

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

-- Set positions and styling of the ruler, and repaint the UI to reflect changes.
function RulerUI:updateUI()
    local geom = self.ruler:getRulerGeometry()

    -- remove the top padding from container to get the correct y position of line.
    local trans_y = geom.y - self.touch_container_widget.padding_top
    local curr_y = self.movable_widget:getMovedOffset().y

    if trans_y ~= curr_y then
        self.movable_widget:setMovedOffset({ x = geom.x, y = trans_y })
    end

    local line_props = self.ruler:getRulerProperties()
    self.ruler_widget.background = line_props.color
    self.ruler_widget.style = line_props.style
    self.ruler_widget.dimen.h = line_props.thickness

    self:repaint()
end

-- Refresh only select region of the screen where the ruler has or will be drawn.
function RulerUI:repaint()
    -- logger.info("--- RulerUI:repaint ---")

    if not self.movable_widget then
        return
    end

    local orig_dimen = nil
    -- If widget is already drawn, get the dimen before move
    if self.movable_widget.dimen then
        orig_dimen = self.movable_widget.dimen:copy()
    end

    -- The callback will be called in the next tick, so the movable_widget here is the one that is moved to the new position
    UIManager:setDirty("all", function()
        -- If widget is already drawn, combine the original dimen with the new one
        local update_region = orig_dimen and orig_dimen:combine(self.movable_widget.dimen) or self.movable_widget.dimen
        logger.dbg("ReadingRuler: refresh region", update_region)
        return "ui", update_region
    end)
end

-- We'll delegate the drawing of the movable container to MovableContainer widget.
function RulerUI:paintTo(bb, x, y)
    if not self.settings:isEnabled() then
        return
    end

    -- Paint the ruler widget to the screen
    if self.movable_widget then
        -- logger.info("--- RulerUI:paintTo ---")
        self.movable_widget:paintTo(bb, x, y)
    end
end

-- In each page update, we need to calculate the coordinates of the ruler line
-- based on each page text lines and navigation direction (next, prev, jump).
function RulerUI:onPageUpdate(new_page)
    if not self.settings:isEnabled() then
        return
    end

    -- This will only calculate the ruler position
    self.ruler:setInitialPositionOnPage(new_page)

    -- After calculating the position, we need to update the UI
    self:updateUI()
end

--- Handle navigation between lines or pages, returns true if handled
---@param direction string "next" or "prev" to indicate navigation direction
---@return boolean
function RulerUI:handleLineNavigation(direction)
    if direction == "next" then
        if self.ruler:moveToNextLine() then
            self:updateUI()
            return true
        end
        -- If we can't move to next line, go to next page
        self.ui:handleEvent(Event:new("GotoViewRel", 1))
        return true
    elseif direction == "prev" then
        if self.ruler:moveToPreviousLine() then
            self:updateUI()
            return true
        end
        -- If we can't move to previous line, go to previous page
        self.ui:handleEvent(Event:new("GotoViewRel", -1))
        return true
    end
    return false
end

-- Ruler enabled state --
function RulerUI:setEnabled(enabled)
    if enabled then
        self.settings:enable()
        self:buildUI()
        self.ruler:setInitialPositionOnPage(self.document:getCurrentPage())
        self:updateUI()
        self:displayNotification(_("Reading ruler enabled"))
    else
        self.settings:disable()
        self:repaint()
        self:displayNotification(_("Reading ruler disabled"))
    end
end

function RulerUI:toggleEnabled()
    self:setEnabled(not self.settings:isEnabled())
end

-- Gesture handling --
function RulerUI:onTap(_, ges)
    if not self.settings:isEnabled() then
        return false
    end

    local is_tap_to_move = self.ruler:isTapToMoveMode()
    local is_tap_on_ruler = ges.pos:intersectWith(self.touch_container_widget.dimen)

    if is_tap_on_ruler then
        if is_tap_to_move then
            -- logger.info("--- ReadingRuler: exit tap to move ---")
            self.ruler:exitTapToMoveMode()
        else
            -- logger.info("--- ReadingRuler: enter tap to move ---")
            self.ruler:enterTapToMoveMode()
            self:notifyTapToMove()
        end

        self:updateUI()
        return true
    end

    if is_tap_to_move then
        -- logger.info("--- ReadingRuler: tap to move ---")
        self.ruler:moveToNearestLine(ges.pos.y)
        self.ruler:exitTapToMoveMode()
        self:updateUI()
        return true
    end

    if self.settings:get("navigation_mode") == "tap" then
        return self:handleLineNavigation("next")
    end

    return false
end

function RulerUI:onSwipe(_, ges)
    if not self.settings:isEnabled() then
        return false
    end

    local navigation_mode = self.settings:get("navigation_mode")

    if navigation_mode == "swipe" or navigation_mode == "tap" then
        -- Swipe up will move to previous line either way
        if ges.direction == "north" then
            return self:handleLineNavigation("prev")
        end

        -- only move down if swipe to south and navigation_mode is swipe
        if navigation_mode == "swipe" and ges.direction == "south" then
            return self:handleLineNavigation("next")
        end
    end

    return false
end

-- Notifications --
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

function RulerUI:notifyTapToMove()
    UIManager:show(Notification:new({
        face = Font:getFace("xx_smallinfofont"),
        text = _("Tap anywhere to move ruler or tap the ruler again to exit."),
        timeout = 3,
    }))
end

return RulerUI
