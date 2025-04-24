local Blitbuffer = require("ffi/blitbuffer")
local Size = require("ui/size")
local Button = require("ui.widget.button")
local Device = require("device")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui.geometry")
local GestureRange = require("ui/gesturerange")
local LineWidget = require("ui.widget.linewidget")
local MovableContainer = require("ui.widget.container.movablecontainer")
local OverlapGroup = require("ui.widget.overlapgroup")
local Screen = require("device").screen
local UIManager = require("ui/uimanager")
local InputContainer = require("ui.widget.container.inputcontainer")

local _ = require("gettext")

local logger = require("logger")
local serpent = require("ffi/serpent")

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

    if Device:isTouchDevice() then
        logger.info("--- ReadingRuler touch device ---")
        local range = Geom:new({
            x = 0,
            y = 0,
            w = Screen:getWidth(),
            h = Screen:getHeight(),
        })

        self.ges_events = {
            Pan = {
                GestureRange:new({
                    ges = "pan",
                    range = range,
                }),
            },
        }
    end

    self.movable = self:buildUI()

    self.ui.menu:registerToMainMenu(self)

    -- makes it call paintTo
    self.view:registerViewModule("reading_ruler", self)
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
        end,
    }
end

function ReadingRuler:paintTo(bb, x, y)
    logger.info("--- ReadingRuler paintTo: ")

    if not self._enabled then
        return
    end

    self.movable:paintTo(bb, self.movable.dimen.x, self.movable.dimen.y)

    -- NOTE: static y, update this to use events
end

function ReadingRuler:onPan(arg, ges)
    -- logger.info("--- ReadingRuler onPan", serpent.block(ges))

    if not self._enabled then
        return
    end

    logger.info("--- touchPrePanWasInside " .. serpent.block(self.movable._touch_pre_pan_was_inside))

    -- if self.drag_handle.dimen:contains(ges.start_pos) then
    --     logger.info("--- ReadingRuler onPan: inside")
    --     -- self.movable.dimen = Geom:new({ x = self.movable.dimen.x, y = ges.pos.y })
    --     -- return true
    --     return self.movable:onMovablePan(arg, ges)
    -- end
end

function ReadingRuler:buildUI()
    local screen_size = Screen.getSize()

    local line_wget = LineWidget:new({
        background = Blitbuffer.gray(self._line_color_intensity),
        dimen = Geom:new({ h = self._line_thickness, w = screen_size.w }),
    })

    self.drag_handle = Button:new({
        text = _("↕"),
        height = 50,
        bordersize = 1,
        callback = function()
            logger.info("--- Roller plugin button: drag")
        end,

        overlap_align = "right",
    })

    local movable = MovableContainer:new({
        dimen = Geom:new({ x = 0, y = screen_size.h * 0.5 }),
        OverlapGroup:new({
            line_wget,
            self.drag_handle,
        }),
    })

    return movable
end

return ReadingRuler
