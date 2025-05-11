local _ = require("gettext")
local Device = require("device")
local Screen = require("device").screen
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local logger = require("logger")

local Settings = require("lib/settings")
local Ruler = require("lib/ruler")
local RulerUI = require("lib/ui/ruler_ui")
local Menu = require("lib/ui/menu")
local Dispatcher = require("dispatcher")

local ReadingRuler = InputContainer:extend({
    name = "readingruler",
    is_doc_only = true,
})

function ReadingRuler:init()
    logger.info("--- ReadingRuler init ---")

    -- Initialize components
    self.settings = Settings:new()

    self.ruler = Ruler:new({
        settings = self.settings,
        ui = self.ui,
        view = self.view,
        document = self.document,
    })

    self.ruler_ui = RulerUI:new({
        settings = self.settings,
        ruler = self.ruler,
        ui = self.ui,
        inputContainer = self,
    })

    self.menu = Menu:new({
        settings = self.settings,
        ruler = self.ruler,
        ruler_ui = self.ruler_ui,
        ui = self.ui,
    })

    --- Register to main menu so that `addToMainMenu` is called
    self.ui.menu:registerToMainMenu(self.menu)

    -- Register to UIManager
    self.view:registerViewModule("reading_ruler", self)

    -- Set up gesture events
    self:setupGestures()

    -- Register actions (custom gesture by user)
    self:onDispatcherRegisterActions()

    -- Initialize UI if enabled
    if self.settings:isEnabled() then
        self.ruler_ui:buildUI()
    end
end

function ReadingRuler:onDispatcherRegisterActions()
    -- Register line navigation actions
    Dispatcher:registerAction("reading_ruler_move_to_next_line", {
        category = "none",
        event = "ReadingRulerMoveToNextLine",
        title = _("Reading Ruler: Move to next line"),
        general = true,
    })

    Dispatcher:registerAction("reading_ruler_move_to_previous_line", {
        category = "none",
        event = "ReadingRulerMoveToPreviousLine",
        title = _("Reading Ruler: Move to previous line"),
        general = true,
    })

    -- Register state management actions
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
end

function ReadingRuler:setupGestures()
    local screen = Screen:getSize()
    local offset_ratio = 0.125
    local offset_ratio_end = 1 - offset_ratio * 2

    -- Set up gesture ranges for different parts of the screen
    if Device:isTouchDevice() then
        local range = Geom:new({
            x = offset_ratio * screen.w,
            y = offset_ratio * screen.h,
            w = offset_ratio_end * Screen:getWidth(),
            h = offset_ratio_end * Screen:getHeight(),
        })

        self.ges_events = {
            Tap = {
                GestureRange:new({
                    ges = "tap",
                    range = range,
                }),
            },
            Swipe = {
                GestureRange:new({
                    ges = "swipe",
                    range = range,
                }),
            },
        }
    end
end

function ReadingRuler:addToMainMenu(menu_items)
    self.menu:addToMainMenu(menu_items)
end

function ReadingRuler:paintTo(bb, x, y)
    self.ruler_ui:paintTo(bb, x, y)
end

function ReadingRuler:onPageUpdate(new_page)
    logger.info("--- ReadingRuler:onPageUpdate ---")
    return self.ruler_ui:onPageUpdate(new_page)
end

-- Forward events to UI component
function ReadingRuler:onSwipe(arg, ges)
    logger.info("--- ReadingRuler:onSwipe ---")
    return self.ruler_ui:onSwipe(arg, ges)
end

function ReadingRuler:onHold(arg, ges)
    logger.info("--- ReadingRuler:onHold ---")
    return self.ruler_ui:onHold(arg, ges)
end

function ReadingRuler:onTap(arg, ges)
    logger.info("--- ReadingRuler:onTap ---")
    return self.ruler_ui:onTap(arg, ges)
end

function ReadingRuler:onReadingRulerMoveToNextLine()
    logger.info("ReadingRulerMoveToNextLine")
    self.ruler_ui:handleLineNavigation("next")
end

function ReadingRuler:onReadingRulerMoveToPreviousLine()
    logger.info("ReadingRulerMoveToPreviousLine")
    self.ruler_ui:handleLineNavigation("prev")
end

function ReadingRuler:onReadingRulerSetState(state)
    logger.info("ReadingRulerSetState: " .. tostring(state))
    if state then
        self.settings:enable()
    else
        self.settings:disable()
    end
end

function ReadingRuler:onReadingRulerToggle()
    logger.info("ReadingRulerToggle")

    self.settings:toggle()
end

return ReadingRuler
