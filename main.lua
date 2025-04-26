local Blitbuffer = require("ffi/blitbuffer")
local Size = require("ui/size")
local Button = require("ui/widget/button")
local Device = require("device")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local LineWidget = require("ui/widget/linewidget")
local MovableContainer = require("ui/widget/container/movablecontainer")
local OverlapGroup = require("ui/widget/overlapgroup")
local Screen = require("device").screen
local UIManager = require("ui/uimanager")
local InputContainer = require("ui/widget/container/inputcontainer")
local _ = require("gettext")
local logger = require("logger")

local ReadingRuler = InputContainer:extend({
    name = "readingruler",
    is_doc_only = true,

    -- field to store movable container
    movable = nil,
    drag_handle = nil,

    _enabled = true,
    _line_color_intensity = 0.7,
    _line_thickness = 10,
})

function ReadingRuler:init()
    logger.info("--- ReadingRuler init ---")

    self.movable = self:buildUI()
    self.ui.menu:registerToMainMenu(self)
    self.view:registerViewModule("reading_ruler", self)

    if Device:isTouchDevice() then
        -- Register a range that covers the whole screen
        local range = Geom:new({
            x = 0,
            y = 0,
            w = Screen:getWidth(),
            h = Screen:getHeight(),
        })

        -- Register gesture events to handle touches anywhere on screen
        self.ges_events = {
            -- Only register the basic events we need - MovableContainer has its own handlers
            MovableTouch = { GestureRange:new({ ges = "touch", range = range }) },
            MovablePan = { GestureRange:new({ ges = "pan", range = range }) },
            MovablePanRelease = { GestureRange:new({ ges = "pan_release", range = range }) },
            MovableHold = { GestureRange:new({ ges = "hold", range = range }) },
            MovableHoldRelease = { GestureRange:new({ ges = "hold_release", range = range }) },
        }
    end
end

function ReadingRuler:onMovableTouch(_, ges)
    if not self._enabled then
        return false
    end

    -- Forward to the movable container
    return self.movable:onMovableTouch(_, ges)
end

function ReadingRuler:onMovablePan(_, ges)
    if not self._enabled then
        return false
    end
    -- Forward to the movable container
    return self.movable:onMovablePan(_, ges)
end

function ReadingRuler:onMovablePanRelease(_, ges)
    if not self._enabled then
        return false
    end
    -- Forward to the movable container
    return self.movable:onMovablePanRelease(_, ges)
end

function ReadingRuler:onMovableHold(_, ges)
    if not self._enabled then
        return false
    end
    -- Forward to the movable container
    return self.movable:onMovableHold(_, ges)
end

function ReadingRuler:onMovableHoldRelease(_, ges)
    if not self._enabled then
        return false
    end
    -- Forward to the movable container
    return self.movable:onMovableHoldRelease(_, ges)
end

function ReadingRuler:addToMainMenu(menu_items)
    menu_items.reading_ruler = {
        text = _("Reading Ruler"),
        sorting_hint = "tools",
        checked_func = function()
            return self._enabled
        end,
        callback = function()
            self._enabled = not self._enabled
            -- Force a UI refresh when enabling/disabling
            UIManager:setDirty(self.view.dialog, "partial")
        end,
    }
end

function ReadingRuler:paintTo(bb, x, y)
    if not self._enabled then
        return
    end

    -- Let the movable container do its own painting
    self.movable:paintTo(bb, x, y)
end

function ReadingRuler:buildUI()
    local screen_size = Screen:getSize()

    -- Create the horizontal line widget
    local line_wget = LineWidget:new({
        background = Blitbuffer.gray(self._line_color_intensity),
        dimen = Geom:new({ h = self._line_thickness, w = screen_size.w }),
    })

    -- Create the drag handle button
    self.drag_handle = Button:new({
        text = _("↕"),
        height = 50,
        width = 50, -- Also specify width to ensure button is visible
        bordersize = 1,
        margin = 0,
        padding = 0,
        overlap_align = "right",
    })

    -- Create and configure the movable container with our widgets
    local movable = MovableContainer:new({
        -- Initial position centered horizontally and placed at 1/3 of the screen height
        anchor = Geom:new({
            x = 0,
            y = math.floor(screen_size.h * 0.5),
            w = screen_size.w, -- Ensure the width is set properly
            h = math.max(self._line_thickness, self.drag_handle:getSize().h), -- Make sure container is tall enough
        }),
        dimen = Geom:new({
            x = 0,
            y = math.floor(screen_size.h * 0.5),
            w = screen_size.w, -- Ensure the width is set properly
            h = math.max(self._line_thickness, self.drag_handle:getSize().h), -- Make sure container is tall enough
        }),
        -- Add the group containing both line and button
        OverlapGroup:new({
            dimen = Geom:new({
                w = screen_size.w,
                h = math.max(self._line_thickness, self.drag_handle:getSize().h),
            }),
            line_wget,
            self.drag_handle,
        }),
    })

    return movable
end

return ReadingRuler
