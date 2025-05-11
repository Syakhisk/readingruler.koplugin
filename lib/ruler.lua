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
    o.current_line_x = nil
    o.screen_height = Device.screen:getHeight()
    o.screen_width = Device.screen:getWidth()
    o.cached_texts = nil
    o.cached_texts_page = nil
    o.last_page = 0

    return o
end

function Ruler:onPageUpdate(new_page)
    local texts = self:getTexts()
    if #texts.sboxes < 1 then
        return
    end

    -- page change direction.
    local direction = new_page >= self.last_page and "next" or "prev"

    -- check if the page jump is more than 1 page.
    local is_jump = math.abs(new_page - self.last_page) > 1

    -- start at first line, if move to previous page, set to last line.
    -- if jump, set to first line.
    local line = 1
    if not is_jump and direction == "prev" then
        line = #texts.sboxes
    end

    self:move(0, texts.sboxes[line].y + texts.sboxes[line].h)
    self.last_page = new_page
end

--- Move the ruler to next line
---@return boolean
function Ruler:moveToNextLine()
    local positions = self:getNearestTextPositions()
    if positions.next then
        self:move(0, positions.next.y + positions.next.h)
        return true
    end

    return false
end

function Ruler:moveToPreviousLine()
    local positions = self:getNearestTextPositions()
    if positions.prev then
        self:move(0, positions.prev.y + positions.prev.h)
        return true
    end

    return false
end

function Ruler:move(x, y)
    self.current_line_y = y
    self.current_line_x = x
end

--- Get nearest text boxes from a given `y`, if `y` is nil, use the current line position.
---@param y? number
---@return table
function Ruler:getNearestTextPositions(y)
    if y == nil then
        y = self.current_line_y
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

function Ruler:getTexts(ignore_cache)
    local page = self.document:getCurrentPage()

    if not ignore_cache and self.cached_texts and self.cached_texts_page == page then
        logger.info("Ruler: cache hit")
        return self.cached_texts
    end

    logger.info("Ruler: cache miss")

    local texts = self.ui.document:getTextFromPositions(
        { x = 0, y = 0, page = page },
        { x = self.screen_width, y = self.screen_width },
        true
    )

    self.cached_texts = texts
    self.cached_texts_page = page

    return texts and texts or { sboxes = {} }
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
        x = self.current_line_x,
        y = self.current_line_y,
        w = self.screen_width,
        h = self.settings:get("line_thickness"),
    }
end

return Ruler
