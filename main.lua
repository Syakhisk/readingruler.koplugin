local Blitbuffer = require("ffi/blitbuffer")
local Geom = require("ui/geometry")
local LineWidget = require("ui/widget/linewidget")
local MovableContainer = require("ui/widget/container/movablecontainer")
local FrameContainer = require("ui/widget/container/framecontainer")
local CenterContainer = require("ui/widget/container/centercontainer")
local VerticalGroup = require("ui/widget/verticalgroup")
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

    _enabled = true,
    _line_color_intensity = 0.7,
    _line_thickness = 5,
    _show_overlay = false,
    _movable = nil,
})

function ReadingRuler:init()
    logger.info("--- ReadingRuler init ---")

    self.ui.menu:registerToMainMenu(self)
    self.view:registerViewModule("reading_ruler", self)

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

function ReadingRuler:paintTo(bb, x, y)
    if not self._enabled then
        return
    end

    self:truncateHorizontalMovement()

    InputContainer.paintTo(self, bb, x, y)
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

function ReadingRuler:resetPosition()
    self._movable:setMovedOffset({ x = 0, y = 0 })
end

function ReadingRuler:truncateHorizontalMovement()
    if self._movable and self._movable.dimen then
        local offset = self._movable:getMovedOffset()
        offset.x = 0
        self._movable:setMovedOffset(offset)
    end
end

return ReadingRuler
