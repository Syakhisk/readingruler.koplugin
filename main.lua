local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Geom = require("ui/geometry")
local LineWidget = require("ui/widget/linewidget")
local MovableContainer = require("ui/widget/container/movablecontainer")
local FrameContainer = require("ui/widget/container/framecontainer")
local CenterContainer = require("ui/widget/container/centercontainer")
local VerticalGroup = require("ui/widget/verticalgroup")
local Screen = require("device").screen
local GestureRange = require("ui/gesturerange")
local UIManager = require("ui/uimanager")
local InputContainer = require("ui/widget/container/inputcontainer")
local _ = require("gettext")
local logger = require("logger")

local ReadingRuler = InputContainer:extend({
    name = "readingruler",
    is_doc_only = true,

    -- field to store movable container
    movable = nil,

    _enabled = true,
    _line_color_intensity = 0.7,
    _line_thickness = 5,
    _show_overlay = false,
    _movable = nil,
    _ignore_events = {
        -- handle these events ourselves (to call the movablecontainer)
        "hold",
        "hold_release",
        "hold_pan",
        "swipe",
        "touch",
        "pan",
        "pan_release",
    },
})

function ReadingRuler:init()
    logger.info("--- ReadingRuler init ---")

    self.ui.menu:registerToMainMenu(self)
    self.view:registerViewModule("reading_ruler", self)

    if Device:isTouchDevice() then
        logger.info("--- ReadingRuler touch ---")

        -- Register a range that covers the whole screen
        local range = Geom:new({ x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() })

        -- Register gesture events to handle touches anywhere on screen
        self.ges_events = {
            Touch = { GestureRange:new({ ges = "tap", range = range }) },
            Swipe = { GestureRange:new({ ges = "swipe", range = range }) },
            Hold = { GestureRange:new({ ges = "hold", range = range }) },
            HoldPan = { GestureRange:new({ ges = "hold_pan", range = range }) },
            HoldRelease = { GestureRange:new({ ges = "hold_release", range = range }) },
            Pan = { GestureRange:new({ ges = "pan", range = range }) },
            PanRelease = { GestureRange:new({ ges = "pan_release", range = range }) },
        }
    end

    if not self._enabled then
        return
    end

    self:buildUI()
end

function ReadingRuler:addToMainMenu(menu_items)
    menu_items.reading_ruler = {
        text = _("Reading Ruler"),
        sub_item_table = {
            {
                text = _("Enable"),
                checked_func = function()
                    return self._enabled
                end,
                callback = function()
                    self._enabled = not self._enabled
                    -- Force a UI refresh when enabling/disabling
                    UIManager:setDirty(self.view.dialog, "partial")
                    return true
                end,
            },
            {
                text = _("Reset Position"),
                callback = function()
                    -- Reset the position of the movable container
                    if self._movable then
                        self:resetPosition()
                    end
                end,
            },
        },
    }
end

function ReadingRuler:update(bb, x, y) end

function ReadingRuler:paintTo(bb, x, y)
    if not self._enabled then
        return
    end

    self:truncateHorizontalMovement()

    InputContainer.paintTo(self, bb, x, y)
end

function ReadingRuler:onTouch(arg, ges)
    if self:shouldHandleGesture(ges) then
        logger.info("ReadingRuler:onTouch")
        return self._movable:onMovableTouch(arg, ges)
    end
end

function ReadingRuler:onSwipe(arg, ges)
    if self:shouldHandleGesture(ges) then
        logger.info("ReadingRuler:onSwipe")
        return self._movable:onMovableSwipe(arg, ges)
    end
end

function ReadingRuler:onHold(arg, ges)
    if self:shouldHandleGesture(ges) then
        logger.info("ReadingRuler:onHold")
        return self._movable:onMovableHold(arg, ges)
    end
end

function ReadingRuler:onHoldPan(arg, ges)
    if self:shouldHandleGesture(ges) then
        logger.info("ReadingRuler:onHoldPan")
        return self._movable:onMovableHoldPan(arg, ges)
    end
end

function ReadingRuler:onHoldRelease(arg, ges)
    if self:shouldHandleGesture(ges) then
        logger.info("ReadingRuler:onHoldRelease")
        return self._movable:onMovableHoldRelease(arg, ges)
    end
end

function ReadingRuler:onPan(arg, ges)
    if self:shouldHandleGesture(ges) then
        logger.info("ReadingRuler:onPan")
        return self._movable:onMovablePan(arg, ges)
    end
end

function ReadingRuler:onPanRelease(arg, ges)
    if self:shouldHandleGesture(ges) then
        logger.info("ReadingRuler:onPanRelease")
        return self._movable:onMovablePanRelease(arg, ges)
    end
end

function ReadingRuler:buildUI()
    local screen_size = Screen:getSize()

    local width = screen_size.w * 0.9

    -- Create the horizontal line widget
    local line_wget = LineWidget:new({
        background = Blitbuffer.gray(self._line_color_intensity),
        dimen = Geom:new({ h = self._line_thickness, w = width }),
    })

    self._movable = MovableContainer:new({
        ignore_events = self._ignore_events,

        -- Add some padding
        FrameContainer:new({
            color = Blitbuffer.COLOR_BLACK,
            bordersize = 0,
            -- Add the group containing both line and overlay
            VerticalGroup:new({
                line_wget,
            }),
        }),
    })

    self[1] = CenterContainer:new({
        dimen = Geom:new({ x = 0, y = 0, w = screen_size.w, h = screen_size.h }),
        self._movable,
    })
end

function ReadingRuler:resetPosition()
    self._movable:setMovedOffset({ x = 0, y = 0 })
end

function ReadingRuler:shouldHandleGesture(ges)
    return ges.pos:intersectWith(self._movable.dimen)
end

function ReadingRuler:truncateHorizontalMovement()
    if self._movable and self._movable.dimen then
        local offset = self._movable:getMovedOffset()
        offset.x = 0
        self._movable:setMovedOffset(offset)
    end
end

return ReadingRuler
