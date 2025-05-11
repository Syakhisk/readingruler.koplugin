local Geom = require("ui/geometry")
local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local logger = require("logger")

local Ruler = {}

function Ruler:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    -- Dependencies
    o.settings = o.settings
    o.ui = o.ui
    o.view = o.view
    o.document = o.document

    -- State
    o.position = o.settings:get("position") -- position as percentage of screen height
    o.current_line_y = nil
    o.screen_height = Device.screen:getHeight()
    o.screen_width = Device.screen:getWidth()

    -- Initialize
    o:init()

    return o
end

function Ruler:init()
    -- Initial position calculation
    self:calculateDefaultPosition()
end

function Ruler:calculateDefaultPosition()
    -- Default to the position set in settings (percentage of screen height)
    local position_percentage = self.settings:get("position")
    self.current_line_y = math.floor(self.screen_height * position_percentage)

    return self.current_line_y
end

function Ruler:getCurrentPosition()
    return self.current_line_y
end

function Ruler:setPosition(y_position)
    -- Ensure the ruler stays within screen bounds
    if y_position < 0 then
        y_position = 0
    elseif y_position > self.screen_height then
        y_position = self.screen_height
    end

    self.current_line_y = y_position

    -- Save position as percentage for persistence across different screen sizes
    self.position = y_position / self.screen_height
    self.settings:set("position", self.position)

    return self.current_line_y
end

function Ruler:moveUp(step)
    step = step or 5
    return self:setPosition(self.current_line_y - step)
end

function Ruler:moveDown(step)
    step = step or 5
    return self:setPosition(self.current_line_y + step)
end

function Ruler:updateLinePosition(page)
    -- This would be called when the page changes
    -- Placeholder for future logic to adjust ruler position based on page content
    -- For now, just maintaining the current relative position

    -- If we want to find the nearest text line, we could do that here
    -- using the document and view APIs

    return self:calculateDefaultPosition()
end

function Ruler:getLineProperties()
    return {
        thickness = self.settings:get("line_thickness"),
        style = self.settings:get("line_style"),
        color = Blitbuffer.gray(self.settings:get("line_intensity")),
    }
end

function Ruler:getLineGeometry()
    -- Return the geometry for drawing the line
    return {
        x = 0,
        y = self.current_line_y,
        w = self.screen_width,
        h = self.settings:get("line_thickness"),
    }
end

return Ruler
