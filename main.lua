local WidgetContainer = require("ui.widget.container.widgetcontainer")
local logger = require("logger")
local UIManager = require("ui/uimanager")
local _ = require("gettext")
local MovableContainer = require("ui.widget.container.movablecontainer")
local OverlapGroup = require("ui.widget.overlapgroup")
local LineWidget = require("ui.widget.linewidget")
local Blitbuffer = require("ffi/blitbuffer")
local Geom = require("ui.geometry")
local Screen = require("device").screen
local Button = require("ui.widget.button")

local serpent = require("ffi/serpent")

local ReadingRuler = WidgetContainer:extend({
    name = "readingruler",
    is_doc_only = true,

    _enabled = true,
    _movable = nil,
    _line_color_intensity = 0.7,
    _line_thickness = 10,
})

function ReadingRuler:init()
    logger.info("--- ReadingRuler init ---")

    self._movable = self:buildMovableContainer()

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
    logger.info("--- ReadingRuler paintTo")

    if not self._enabled then
        return
    end

    self._movable:paintTo(bb, x, y)
end

function ReadingRuler:buildMovableContainer()
    local screen_size = Screen.getSize()

    local line_wget = LineWidget:new({
        background = Blitbuffer.gray(self._line_color_intensity),
        dimen = Geom:new({ h = self._line_thickness, w = screen_size.w }),
    })

    local movable = MovableContainer:new({
        OverlapGroup:new({
            line_wget,
            Button:new({
                text = _("↕"),
                height = 50,
                bordersize = 1,
                callback = function()
                    logger.info("--- Roller plugin button: drag")
                end,

                overlap_align = "right",
            }),
        }),
    })

    return movable
end

return ReadingRuler
