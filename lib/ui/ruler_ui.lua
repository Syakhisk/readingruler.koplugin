local _ = require("gettext")
local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Event = require("ui/event")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local MovableContainer = require("ui/widget/container/movablecontainer")
local Notification = require("ui/widget/notification")
local Screen = Device.screen
local UIManager = require("ui/uimanager")
local Widget = require("ui/widget/widget")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local logger = require("logger")

-- Widget that draws one thin underline per covered text line.
-- `offsets` holds the relative y offset of each underline.
local MultiLineWidget = Widget:extend{
    offsets = { 0 },
    thickness = 2,
    style = "solid",
    background = Blitbuffer.COLOR_BLACK,
}

function MultiLineWidget:paintTo(bb, x, y)
    if self.style == "none" then return end
    for _, offset in ipairs(self.offsets) do
        if self.style == "dashed" then
            for i = 0, self.dimen.w - 20, 20 do
                bb:paintRect(x + i, y + offset, 16, self.thickness, self.background)
            end
        else
            bb:paintRect(x, y + offset, self.dimen.w, self.thickness, self.background)
        end
    end
end

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

    -- Auto scroll state
    self.auto_scroll_active = false
    self.auto_scroll_tick = nil
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

    -- Create multi-line widget (one underline per covered line)
    self.ruler_widget = MultiLineWidget:new({
        background = line_props.color,
        style = line_props.style,
        thickness = line_props.thickness,
        offsets = geom.offsets or { 0 },
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
    self.ruler_widget.thickness = line_props.thickness
    -- One underline per covered line; `h` spans from the topmost underline
    -- to the bottom of the current one (falls back to a single line)
    self.ruler_widget.offsets = geom.offsets or { 0 }
    -- Width too: after a rotation the screen width changes, and a stale
    -- width would leave the underline short of the right screen edge.
    self.ruler_widget.dimen.w = geom.w or self.ruler_widget.dimen.w
    self.ruler_widget.dimen.h = geom.h or line_props.thickness

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

    -- Any page change ends an ongoing end-of-page wait, whether the
    -- countdown ran out or the user turned the page early.
    self:endDwell()

    -- A page change while the auto scroll timer runs was requested by the
    -- timer itself, not by the user. Tell the ruler apart so going back
    -- under auto scroll can restart from the top of the page.
    local auto_scroll = self.auto_scroll_tick ~= nil
        and self.settings:get("auto_scroll_enabled") == true

    -- This will only calculate the ruler position
    self.ruler:setInitialPositionOnPage(new_page, auto_scroll)

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
        -- Start auto scroll if it was configured on
        if self.settings:get("auto_scroll_enabled") then
            self:startAutoScroll()
        end
    else
        self:stopAutoScroll()
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

-- Auto scroll --
-- Repeatedly move the ruler one line down every `auto_scroll_interval`
-- seconds until it is stopped or the ruler is disabled. When the ruler
-- reaches the last line of the page, optionally dwell there for
-- `auto_scroll_end_interval` seconds before turning the page, so the
-- user gets extra time to re-read the rest of the page.
function RulerUI:startAutoScroll()
    self:stopAutoScroll()

    local interval = tonumber(self.settings:get("auto_scroll_interval")) or 5
    if interval < 1 then
        interval = 1
    end

    self.auto_scroll_active = true

    local tick
    tick = function()
        -- Stop if we've been cancelled meanwhile, or if the ruler
        -- is no longer enabled (e.g. user toggled it off, or document closed).
        if not self.auto_scroll_active
            or not self.settings:isEnabled()
            or not self.settings:get("auto_scroll_enabled") then
            self.auto_scroll_active = false
            return
        end

        -- Skip this tick when the reading view does not have focus: with a
        -- menu, dialog, dictionary popup or the screensaver on top, the
        -- topmost visible widget is not ReaderUI. We keep the timer chain
        -- alive but do not advance the ruler (nor turn pages) until the
        -- user is back to reading. @see autoturn.koplugin
        local top_wg = UIManager:getTopmostVisibleWidget() or {}
        if top_wg.name ~= "ReaderUI" then
            -- Freeze the end-of-page countdown while unfocused: remember
            -- "now" without charging the elapsed time against it, so the
            -- wait resumes with the same remaining seconds on focus.
            if self.end_dwell_remaining then
                self.end_dwell_last_t = os.time()
            end
            logger.dbg("ReadingRuler: auto scroll tick skipped, reader not focused")
            UIManager:scheduleIn(interval, tick)
            return
        end

        -- End-of-page dwell: charge elapsed time against the countdown,
        -- then either turn the page or keep waiting.
        if self.end_dwell_remaining then
            local now = os.time()
            self.end_dwell_remaining = self.end_dwell_remaining - (now - (self.end_dwell_last_t or now))
            self.end_dwell_last_t = now

            if self.end_dwell_remaining > 0 then
                UIManager:scheduleIn(math.min(interval, self.end_dwell_remaining), tick)
                return
            end

            -- Countdown finished: clear the wait state and turn the page
            -- (onPageUpdate clears it as well, this just makes it immediate).
            self:endDwell()
            self:handleLineNavigation("next")
            UIManager:scheduleIn(interval, tick)
            return
        end

        if self.ruler:moveToNextLine() then
            self:updateUI()
            UIManager:scheduleIn(interval, tick)
            return
        end

        -- The ruler already sits on the last line of the page. Instead of
        -- turning right away, optionally dwell for a while so the user can
        -- look back at the rest of the page before it turns.
        local dwell = tonumber(self.settings:get("auto_scroll_end_interval")) or 0
        if dwell > 0 then
            self:startDwell(dwell)
            UIManager:scheduleIn(math.min(interval, dwell), tick)
            return
        end

        -- End-of-page wait disabled: turn the page right away (old behaviour)
        self:handleLineNavigation("next")
        UIManager:scheduleIn(interval, tick)
    end

    self.auto_scroll_tick = tick
    UIManager:scheduleIn(interval, tick)
end

function RulerUI:stopAutoScroll()
    self.auto_scroll_active = false
    if self.auto_scroll_tick then
        UIManager:unschedule(self.auto_scroll_tick)
        self.auto_scroll_tick = nil
    end
    -- Drop any pending end-of-page countdown
    self:endDwell()
end

-- End-of-page dwell --
-- Countdown state: `end_dwell_remaining` holds the seconds still to wait
-- on the last line; `end_dwell_last_t` is the timestamp of the last tick,
-- used to charge only the time spent *with* reading focus against the
-- countdown.
function RulerUI:startDwell(seconds)
    self.end_dwell_remaining = seconds
    self.end_dwell_last_t = os.time()
end

function RulerUI:endDwell()
    self.end_dwell_remaining = nil
    self.end_dwell_last_t = nil
end

function RulerUI:isEndDwellWaiting()
    return self.end_dwell_remaining ~= nil
end

function RulerUI:isAutoScrollRunning()
    return self.auto_scroll_active
end

-- Restart the timer if it is currently running (e.g. after interval change)
function RulerUI:restartAutoScrollIfRunning()
    if self.auto_scroll_active then
        self:startAutoScroll()
    end
end

-- Suspend/resume support --
-- Remember whether auto scroll was running and stop the timer, so it does
-- not fire while the device is locked (the chained scheduleIn timers would
-- otherwise keep advancing the ruler, and even turn pages, while the
-- screen is off or showing the screensaver).
function RulerUI:pauseAutoScrollForSuspend()
    self.auto_scroll_paused = self.auto_scroll_active
    if self.auto_scroll_paused then
        logger.dbg("ReadingRuler: pausing auto scroll for suspend")
    end
    self:stopAutoScroll()
end

-- Restart auto scroll on wake-up, but only if it was actually running
-- before the device was suspended.
function RulerUI:resumeAutoScrollAfterSuspend()
    if not self.auto_scroll_paused then
        return
    end
    self.auto_scroll_paused = nil
    if self.settings:isEnabled() and self.settings:get("auto_scroll_enabled") then
        logger.dbg("ReadingRuler: resuming auto scroll after resume")
        self:startAutoScroll()
    end
end

-- Toggle auto scroll from menu or gesture action
function RulerUI:toggleAutoScroll()
    local enabled = self.settings:toggle("auto_scroll_enabled")

    if enabled then
        -- Auto scroll only makes sense with the ruler visible
        if not self.settings:isEnabled() then
            self:setEnabled(true) -- setEnabled will start auto scroll
        else
            self:startAutoScroll()
        end
        local interval = tonumber(self.settings:get("auto_scroll_interval")) or 5
        self:displayNotification(string.format(_("Auto scroll enabled (%d seconds per line)"), interval))
    else
        self:stopAutoScroll()
        self:displayNotification(_("Auto scroll disabled"))
    end
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
