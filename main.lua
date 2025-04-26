local Blitbuffer = require("ffi/blitbuffer")
local RectSpan = require("ui/widget/rectspan")
local Device = require("device")
local Geom = require("ui/geometry")
local LineWidget = require("ui/widget/linewidget")
local MovableContainer = require("ui/widget/container/movablecontainer")
local AlphaContainer = require("ui/widget/container/alphacontainer")
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
})

function ReadingRuler:init()
    logger.info("--- ReadingRuler init ---")

    self:buildUI()
    self.ui.menu:registerToMainMenu(self)
    self.view:registerViewModule("reading_ruler", self)

    if Device:isTouchDevice() then
        -- -- Register a range that covers the whole screen
        -- local range = Geom:new({ x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() })

        -- Register gesture events to handle touches anywhere on screen
        self.ges_events = {}
    end
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

    InputContainer.paintTo(self, bb, x, y)
end

function ReadingRuler:buildUI()
    local screen_size = Screen:getSize()

    -- Create the horizontal line widget
    local line_wget = LineWidget:new({
        background = Blitbuffer.gray(self._line_color_intensity),
        dimen = Geom:new({ h = self._line_thickness, w = screen_size.w }),
    })

    local overlay_alpha = 0.5

    local top_overlay = AlphaContainer:new({
        alpha = overlay_alpha,
        FrameContainer:new({
            background = Blitbuffer.COLOR_WHITE,
            bordersize = 0,
            margin = 0,
            padding = 0,
            RectSpan:new({ height = screen_size.h * 0.1, width = screen_size.w }),
        }),
    })

    local bottom_overlay = AlphaContainer:new({
        alpha = overlay_alpha,
        FrameContainer:new({
            background = Blitbuffer.COLOR_WHITE,
            bordersize = 0,
            margin = 0,
            padding = 0,
            RectSpan:new({ height = screen_size.h * 0.1, width = screen_size.w }),
        }),
    })

    self[1] = CenterContainer:new({
        dimen = Geom:new({ x = 0, y = 0, w = screen_size.w, h = screen_size.h }),
        MovableContainer:new({
            -- Add the group containing both line and button
            VerticalGroup:new({
                dimen = Geom:new({
                    w = screen_size.w,
                    h = math.max(self._line_thickness + bottom_overlay:getSize().h + top_overlay:getSize().h),
                }),
                top_overlay,
                -- RectSpan:new({ height = screen_size.h * 0.05, width = screen_size.w }),
                line_wget,
                bottom_overlay,
            }),
        }),
    })
end

return ReadingRuler
