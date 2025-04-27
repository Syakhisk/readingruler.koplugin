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
})

function ReadingRuler:init()
    logger.info("--- ReadingRuler init ---")

    self.ui.menu:registerToMainMenu(self)
    self.view:registerViewModule("reading_ruler", self)
    self:onDispatcherRegisterActions()

    if Device.isTouchDevice() then
        local range = Geom:new({ x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() })
        self.ges_events = {
            Hold = {
                GestureRange:new({ ges = "hold", range = range }),
            },
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

function ReadingRuler:onHold(_, ges)
    if ges.pos then
        self._last_hold_geom = ges.pos
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
                self:move(0, self._last_hold_geom.y)
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
    local line_coeff = Screen:getHeight() * 0.01

    offset.x = x - self[1].dimen.w / 2
    offset.y = y - self[1].dimen.h / 2 + line_coeff

    -- logger.info("--------\n", "old_offset: ", self._movable:getMovedOffset(), "\nnew_offset: ", offset)

    self._movable:setMovedOffset(offset)
end

return ReadingRuler
