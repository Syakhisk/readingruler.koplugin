local _ = require("gettext")
local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Dispatcher = require("dispatcher") -- luacheck:ignore
local Event = require("ui/event")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local LineWidget = require("ui/widget/linewidget")
local MovableContainer = require("ui/widget/container/movablecontainer")
local Screen = require("device").screen
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local logger = require("logger")

local ReadingRuler = InputContainer:extend({
    name = "readingruler",
    is_doc_only = true,

    -- TODO: use config files to set default value, see perceptionexpander plugin
    _enabled = true,
    _line_color_intensity = 0.7,
    _line_thickness = 5,
    _movable = nil,
    _last_hold_geom = nil,

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

    _swipe_threshold_ratio = 0.1,
})

function ReadingRuler:init()
    logger.info("--- ReadingRuler init ---")

    self.ui.menu:registerToMainMenu(self)
    self.view:registerViewModule("reading_ruler", self)
    self:onDispatcherRegisterActions()

    if Device.isTouchDevice() then
        local range = Geom:new({ x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() })
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

    self:addToHighlightDialog()

    if self._enabled then
        self:buildUI()
    end
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
                    -- TODO: see if self:buildUI can be used instead of setdirty
                    -- Force a UI refresh when enabling/disabling
                    UIManager:setDirty(self.view.dialog, "partial")
                    return true
                end,
            },
            {
                text = _("Reset Position"),
                callback = function()
                    -- Reset the position of the movable container
                    self:onReadingRulerResetPosition()
                end,
            },
        },
    }
end

function ReadingRuler:onDispatcherRegisterActions()
    Dispatcher:registerAction("reading_ruler_set_state", {
        category = "string",
        event = "ReadingRulerSetState",
        title = _("Reading Ruler"),
        general = true,
        args = { true, false },
        toggle = { _("enable"), _("disable") },
    })

    Dispatcher:registerAction("reading_ruler_toggle", {
        category = "none",
        event = "ReadingRulerToggle",
        title = _("Reading Ruler: toggle"),
        general = true,
    })

    Dispatcher:registerAction("reading_ruler_reset_position_action", {
        category = "none",
        event = "ReadingRulerResetPosition",
        title = _("Reading Ruler: Reset position"),
        general = true,
    })
end

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

    if ges.distance > Screen:getHeight() * self._swipe_threshold_ratio then
        if ges.direction == "south" then
            local positions = self:getNearestTextPositions()
            if positions.next then
                logger.info("ReadingRuler: move down")
                self:move(0, positions.next.y + positions.next.h)
                UIManager:setDirty(self.view.dialog, "partial")
            else
                logger.info("ReadingRuler: end of page")
            end

            return true
        end

        if ges.direction == "north" then
            local positions = self:getNearestTextPositions()
            if positions.prev then
                logger.info("ReadingRuler: move up")
                self:move(0, positions.prev.y + positions.prev.h)
                UIManager:setDirty(self.view.dialog, "partial")
            else
                logger.info("ReadingRuler: start of page")
            end

            return true
        end
    end
end

function ReadingRuler:onHold(arg, ges)
    if ges.pos then
        self._last_hold_geom = ges.pos
    end

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

    local width = screen_size.w

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

function ReadingRuler:addToHighlightDialog()
    self.ui.highlight:addToHighlightDialog("13_z_reading_ruler", function(this)
        return {
            text = _("Move/show reading ruler here"),
            callback = function()
                local sbox = this.selected_text.sboxes[#this.selected_text.sboxes]
                self:move(0, sbox.y + sbox.h)
                this:onClose()
            end,
        }
    end)
end

function ReadingRuler:onReadingRulerResetPosition()
    logger.info("ReadingRuler: Reset position")
    if self._movable then
        self._movable:setMovedOffset({ x = 0, y = 0 })
        UIManager:setDirty(self.view.dialog, "partial")
    end
end

function ReadingRuler:onReadingRulerSetState(state)
    logger.info("ReadingRuler: Set state to ", state)
    self._enabled = state
    UIManager:setDirty(self.view.dialog, "partial")
end

function ReadingRuler:onReadingRulerToggle()
    logger.info("ReadingRuler: Toggle to ", not self._enabled)
    self._enabled = not self._enabled
    UIManager:setDirty(self.view.dialog, "partial")
end

function ReadingRuler:truncateHorizontalMovement()
    if self._movable and self._movable.dimen then
        local offset = self._movable:getMovedOffset()
        offset.x = 0
        self._movable:setMovedOffset(offset)
    end
end

-- TODO: get current / last selected text in runtime instead of
--  recording it on generic hold event, this will make the line dimen more accurate as well.
function ReadingRuler:move(x, y)
    if not self._enabled then
        self._enabled = true
        UIManager:setDirty(self.view.dialog, "partial")
    end

    local offset = self._movable:getMovedOffset()

    offset.x = x - self[1].dimen.w / 2
    offset.y = y - self[1].dimen.h / 2

    -- logger.info("--------\n", "old_offset: ", self._movable:getMovedOffset(), "\nnew_offset: ", offset)

    self._movable:setMovedOffset(offset)
end

function ReadingRuler:shouldHandleGesture(ges)
    return ges.pos:intersectWith(self._movable.dimen)
end

function ReadingRuler:getNearestTextPositions()
    local ruler_y = self:getRulerGeom().y

    local pageno = self.document:getCurrentPage()
    local texts = self.ui.document:getTextFromPositions(
        { x = 0, y = 0, page = pageno },
        { x = Screen:getWidth(), y = Screen:getHeight() },
        true
    )

    local curr_idx, curr = nil, nil
    for i = 1, #texts.sboxes do
        local sbox = texts.sboxes[i]

        if curr == nil or math.abs(sbox.y + sbox.h - ruler_y) < math.abs(curr.y + curr.h - ruler_y) then
            curr_idx = i
            curr = sbox
        end
    end

    local prev, next = nil, nil
    if curr_idx ~= nil then
        prev = curr_idx > 1 and texts.sboxes[curr_idx - 1] or nil
        next = curr_idx < #texts.sboxes and texts.sboxes[curr_idx + 1] or nil
    end

    return { prev = prev, curr = curr, next = next }
end

function ReadingRuler:getRulerGeom()
    local center = self[1].dimen.h / 2
    local offset_y = self._movable:getMovedOffset().y

    return Geom:new({ x = self[1].dimen.x, y = offset_y + center, w = self._movable.dimen.w, h = self._movable.dimen.h })
end

return ReadingRuler
