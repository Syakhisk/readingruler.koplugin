local _ = require("gettext")
local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Dispatcher = require("dispatcher") -- luacheck:ignore
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
    self:onDispatcherRegisterActions()

    if Device.isTouchDevice() then
        local range = Geom:new({ x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() })
        self.ges_events = {
            Swipe = { GestureRange:new({ ges = "swipe", range = range }) },
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

function ReadingRuler:onSwipe(arg, ges)
    if self:shouldHandleGesture(ges) then
        logger.info("ReadingRuler:onSwipe")
        return self._movable:onMovableSwipe(arg, ges)
    end

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

function ReadingRuler:buildUI()
    local screen_size = Screen:getSize()

    self.dimen = Geom:new({ x = 0, y = 0, w = screen_size.w, h = screen_size.h })

    local width = screen_size.w

    -- Create the horizontal line widget
    local line_wget = LineWidget:new({
        background = Blitbuffer.gray(self._line_color_intensity),
        dimen = Geom:new({ h = self._line_thickness, w = width }),
    })

    self._movable = MovableContainer:new({
        ignore_events = self._ignore_events,
        VerticalGroup:new({
            line_wget,
        }),
    })

    self[1] = self._movable
end

function ReadingRuler:onPageUpdate()
    local initial_y = 0
    local texts = self:getTexts()
    if #texts.sboxes > 0 then
        initial_y = texts.sboxes[1].y + texts.sboxes[1].h
    end

    self._movable:setMovedOffset({ x = 0, y = initial_y })
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

function ReadingRuler:move(x, y)
    -- logger.info("ReadingRuler: Move to ", x, y)
    if not self._enabled then
        self._enabled = true
        UIManager:setDirty(self.view.dialog, "partial")
    end

    local nearest_text = self:getNearestTextPositions(y).curr
    if nearest_text and y < nearest_text.y + nearest_text.h then
        y = nearest_text.y + nearest_text.h
    end

    -- logger.info("ReadingRuler: Move to (snapped)", x, y)

    local offset = self._movable:getMovedOffset()
    offset.x = x
    offset.y = y

    self._movable:setMovedOffset(offset)
end

function ReadingRuler:shouldHandleGesture(ges)
    return ges.pos:intersectWith(self._movable.dimen)
end

function ReadingRuler:getTexts()
    local page = self.document:getCurrentPage()
    return self.ui.document:getTextFromPositions(
        { x = 0, y = 0, page = page },
        { x = Screen:getWidth(), y = Screen:getHeight() },
        true
    )
end

function ReadingRuler:getNearestTextPositions(y)
    if y == nil then
        y = self._movable:getMovedOffset().y
    end

    local texts = self:getTexts()

    local nearest_idx, nearest_sbox = nil, nil
    local min_distance = math.huge

    for i, sbox in ipairs(texts.sboxes) do
        local distance = math.abs(sbox.y + sbox.h - y)
        if distance < min_distance then
            min_distance = distance
            nearest_idx = i
            nearest_sbox = sbox
        end
    end

    local prev = nearest_idx and texts.sboxes[nearest_idx - 1] or nil
    local next = nearest_idx and texts.sboxes[nearest_idx + 1] or nil

    return { prev = prev, curr = nearest_sbox, next = next }
end

return ReadingRuler
