local _ = require("gettext")
local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Dispatcher = require("dispatcher") -- luacheck:ignore
local Event = require("ui/event")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local LineWidget = require("ui/widget/linewidget")
local MovableContainer = require("ui/widget/container/movablecontainer")
local Notification = require("ui/widget/notification")
local Screen = require("device").screen
local UIManager = require("ui/uimanager")
local logger = require("logger")

local ReadingRuler = InputContainer:extend({
    name = "readingruler",
    is_doc_only = true,

    -- TODO: use config files to set default value, see perceptionexpander plugin
    _enabled = true,
    _line_color_intensity = 0.7,
    _line_thickness = 5,

    _movable = nil,
    _touch_container = nil,
    _line = nil,

    _tap_to_move = false,

    _cached_texts = nil,
    _cached_texts_page = nil,
    _last_page = 0,

    _ignore_events = {
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
            Hold = { GestureRange:new({ ges = "hold", range = range }) },
            Tap = { GestureRange:new({ ges = "tap", range = range }) },
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

function ReadingRuler:addToHighlightDialog()
    self.ui.highlight:addToHighlightDialog("13_z_reading_ruler", function(this, index)
        return {
            text = _("Move/show reading ruler here"),
            callback = function()
                -- move the reading ruler to the selected position
                if this.selected_text.sboxes ~= nil then
                    local sbox = this.selected_text.sboxes[#this.selected_text.sboxes]
                    self:move(0, sbox.y + sbox.h)
                else -- if user is clickin on already highlighted text
                    local pos = this:getHighlightVisibleBoxes(index)[1]
                    self:move(0, pos.y + pos.h)
                end

                this:onClose()
            end,
        }
    end)
end

function ReadingRuler:paintTo(bb, x, y)
    if not self._enabled then
        return
    end

    InputContainer.paintTo(self, bb, x, y)
end

function ReadingRuler:onSwipe(_, ges)
    if not self._enabled then
        return false
    end

    if ges.direction == "south" then
        return self:moveToNextLine()
    elseif ges.direction == "north" then
        return self:moveToPreviousLine()
    end
end

function ReadingRuler:onHold(_, ges)
    if not self._enabled then
        return false
    end

    if not ges.pos:intersectWith(self._touch_container.dimen) then
        return false
    end

    return self:toggleTapToMove()
end

function ReadingRuler:onTap(_, ges)
    if not self._enabled then
        return false
    end

    local is_tapping_line = ges.pos:intersectWith(self._touch_container.dimen)

    if not self._tap_to_move and is_tapping_line then
        return self:enterTapToMoveMode()
    elseif self._tap_to_move and is_tapping_line then
        return self:exitTapToMoveMode()
    elseif self._tap_to_move then
        return self:moveToTappedPosition(ges.pos.y)
    end

    return false
end

function ReadingRuler:moveToNextLine()
    local positions = self:getNearestTextPositions()
    if positions.next then
        self:move(0, positions.next.y + positions.next.h)
        return true
    else
        self.ui:handleEvent(Event:new("GotoViewRel", 1))
        return false
    end
end

function ReadingRuler:moveToPreviousLine()
    local positions = self:getNearestTextPositions()
    if positions.prev then
        self:move(0, positions.prev.y + positions.prev.h)
        return true
    else
        self.ui:handleEvent(Event:new("GotoViewRel", -1))
        return false
    end
end

function ReadingRuler:toggleTapToMove()
    if not self._tap_to_move then
        return self:enterTapToMoveMode()
    else
        return self:exitTapToMoveMode()
    end
end

function ReadingRuler:enterTapToMoveMode()
    self._tap_to_move = true
    self._line.style = "dashed"

    self:notifyTapToMove()

    self:repaint()

    return true
end

function ReadingRuler:exitTapToMoveMode()
    self._tap_to_move = false
    self._line.style = "solid"

    self:repaint()

    return true
end

function ReadingRuler:moveToTappedPosition(y)
    local positions = self:getNearestTextPositions(y)
    self:move(0, positions.curr.y + positions.curr.h)

    self:exitTapToMoveMode()

    return true
end

function ReadingRuler:onPageUpdate(new_page)
    if not self._enabled then
        return
    end

    self:updateLinePosition(new_page)
end

function ReadingRuler:updateLinePosition(new_page)
    local texts = self:getTexts(true)

    if #texts.sboxes < 1 then
        return
    end

    local direction = new_page >= self._last_page and "next" or "prev"
    local is_jump = math.abs(new_page - self._last_page) > 1

    local idx = 1
    if not is_jump and direction == "prev" then
        idx = #texts.sboxes
    end

    local y = texts.sboxes[idx].y + texts.sboxes[idx].h
    self:move(0, y)

    self._last_page = new_page
end

function ReadingRuler:onReadingRulerResetPosition()
    if not self._enabled then
        return
    end

    logger.info("ReadingRuler: Reset position")
    if self._movable then
        local first_line = #self:getTexts().sboxes > 0 and self:getTexts().sboxes[1]
        local y = first_line and first_line.y + first_line.h or Screen:getHeight() * 0.5

        self:move(0, y)
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

-- Custom fns
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

function ReadingRuler:buildUI()
    local screen_size = Screen:getSize()

    self.dimen = Geom:new({ x = 0, y = 0, w = screen_size.w, h = screen_size.h })

    local width = screen_size.w

    -- Create the horizontal line widget
    self._line = LineWidget:new({
        background = Blitbuffer.gray(self._line_color_intensity),
        dimen = Geom:new({ h = self._line_thickness, w = width }),
    })

    self._touch_container = FrameContainer:new({
        color = Blitbuffer.gray(self._line_color_intensity),
        bordersize = 0,
        padding = 0,
        padding_top = screen_size.h * 0.01,
        padding_bottom = screen_size.h * 0.01,
        self._line,
    })

    self._movable = MovableContainer:new({
        ignore_events = self._ignore_events,
        self._touch_container,
    })

    self[1] = self._movable
end

function ReadingRuler:move(x, y)
    if not self._enabled then
        self._enabled = true

        UIManager:setDirty(self.view.dialog, "partial")
    end

    -- remove the top padding from container to get the correct y position of line
    local trans_y = y - self._touch_container.padding_top

    self._movable:setMovedOffset({ x = x, y = trans_y })

    self:repaint()
end

function ReadingRuler:repaint()
    -- only set dirty if movable is already rendered previously
    if self._movable ~= nil and self._movable.dimen ~= nil then
        local orig_dimen = self._movable.dimen:copy() -- dimen before move/paintTo

        UIManager:setDirty("all", function()
            local update_region = orig_dimen:combine(self._movable.dimen)
            logger.dbg("ReadingRuler: refresh region", update_region)
            return "ui", update_region
        end)
    end
end

function ReadingRuler:getTexts(ignore_cache)
    local page = self.document:getCurrentPage()

    if not ignore_cache and self._cached_texts and self._cached_texts_page == page then
        logger.dbg("ReadingRuler: cache hit")
        return self._cached_texts
    end

    logger.dbg("ReadingRuler: cache miss")

    local texts = self.ui.document:getTextFromPositions(
        { x = 0, y = 0, page = page },
        { x = Screen:getWidth(), y = Screen:getHeight() },
        true
    )

    self._cached_texts = texts
    self._cached_texts_page = page

    return texts and texts or { sboxes = {} }
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

function ReadingRuler:notifyTapToMove()
    UIManager:show(Notification:new({
        face = Font:getFace("xx_smallinfofont"),
        text = _("Tap anywhere to move the reading ruler or tap again to exit."),
        timeout = 3,
    }))
end

return ReadingRuler
