local WidgetContainer = require("ui.widget.container.widgetcontainer")
local logger = require("logger")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local serpent = require("ffi/serpent")

local ReadingRuler = WidgetContainer:extend({
    name = "readingruler",
    is_doc_only = true,

    _enabled = true,
})

function ReadingRuler:init()
    logger.info("--- ReadingRuler init ---")

    self.ui.menu:registerToMainMenu(self)
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

return ReadingRuler
