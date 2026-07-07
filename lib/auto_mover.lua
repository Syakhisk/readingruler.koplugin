local UIManager = require("ui/uimanager")
local logger = require("logger")

local AutoMover = {}

function AutoMover:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    o.ruler = o.ruler
    o.ruler_ui = o.ruler_ui
    o.settings = o.settings
    o._running = false
    return o
end


function AutoMover:_calculateDelay()
    local wc = self.ruler:getCurrentLineWordCount()
    local wpm = self.settings:get("auto_mode_wpm")
    return (wc * 60) / wpm
end

function AutoMover:_tick()
    if not self._running then return end

    if UIManager._window_stack and #UIManager._window_stack > 1 then
        UIManager:scheduleIn(0.5, function() self:_tick() end)
        return
    end

    self.ruler_ui:handleLineNavigation("next")
    local delay = self:_calculateDelay()
    logger.dbg("AutoMover: next tick in", delay, "s")
    UIManager:scheduleIn(delay, function() self:_tick() end)
end

function AutoMover:start()
    if self._running then return end
    self._running = true
    -- ponytail: schedule first tick, don't advance immediately — tap toggles, doesn't move
    local delay = self:_calculateDelay()
    UIManager:scheduleIn(delay, function() self:_tick() end)
end

function AutoMover:stop()
    self._running = false
end

function AutoMover:toggle()
    if self._running then
        self:stop()
        return false
    else
        self:start()
        return true
    end
end

function AutoMover:isRunning()
    return self._running
end

return AutoMover
