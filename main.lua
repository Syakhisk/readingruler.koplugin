local _ = require("gettext")
local InputContainer = require("ui/widget/container/inputcontainer")
local logger = require("logger")

local Settings = require("lib/settings")
local Ruler = require("lib/ruler")
local RulerUI = require("lib/ui/ruler_ui")
local Menu = require("lib/ui/menu")

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

    -- Initialize UI if enabled
    if self.settings:isEnabled() then
        self.ruler_ui:buildUI()
    end
end

function ReadingRuler:addToMainMenu(menu_items)
    self.menu:addToMainMenu(menu_items)
end

function ReadingRuler:paintTo(bb, x, y)
    if not self.settings:isEnabled() then
        return
    end

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

return ReadingRuler
