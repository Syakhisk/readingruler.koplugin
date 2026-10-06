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
    o.current_line_y = nil
    o.current_line_x = nil
    o.current_line_idx = nil -- index of the anchored line in getUniqueLines()
    o.cached_texts = nil
    o.cached_texts_page = nil
    o.cached_screen_w = nil -- screen dims when cached_texts was built
    o.cached_screen_h = nil
    o.last_page = 0
    o.tap_to_move = false

    return o
end

--- Screen dims, queried live on every call. The plugin used to capture
--- these once at start-up, which froze the ruler at the portrait width:
--- after rotating the device (e.g. a Kindle turned 90 degrees) the
--- underline no longer reached the right edge of the screen.
---@return number
function Ruler:getScreenWidth()
    return Device.screen:getWidth()
end

---@return number
function Ruler:getScreenHeight()
    return Device.screen:getHeight()
end

--- Move the anchor to the line at `idx` (in getUniqueLines()), remembering
--- the index so block calculations never depend on reverse lookups.
---@param idx number
---@return boolean
function Ruler:moveToLine(idx)
    local lines = self:getUniqueLines()
    if idx < 1 or idx > #lines then
        return false
    end

    self.current_line_idx = idx
    self:move(0, lines[idx].y + lines[idx].h)
    return true
end

--- Get the current anchor line index. Uses the remembered index when
--- available; falls back to a nearest-line lookup (e.g. after tap-to-move
--- on a fresh state). The index is clamped to the current page.
---@return number?
function Ruler:getCurrentLineIndex()
    local lines = self:getUniqueLines()
    if #lines < 1 then
        return nil
    end

    local idx = self.current_line_idx
    if idx == nil then
        idx = self:getNearestTextPositions().idx
    end
    if idx == nil then
        return nil
    end

    -- Guard against a stale index after a page change
    if idx > #lines then
        idx = #lines
    end
    return idx
end

--- Get the configured number of lines covered by the ruler (min 1)
---@return number
function Ruler:getLineCount()
    local count = math.floor(tonumber(self.settings:get("line_count")) or 1)
    if count < 1 then
        count = 1
    end
    return count
end

--- Position the ruler on a newly shown page.
--- `auto_scroll` marks a page change driven by the auto scroll timer (as
--- opposed to a manual page turn by the user), which changes where the
--- ruler should land when going backwards.
---@param new_page number
---@param auto_scroll? boolean
function Ruler:setInitialPositionOnPage(new_page, auto_scroll)
    local lines = self:getUniqueLines()
    if #lines < 1 then
        self.current_line_idx = nil
        logger.error("No text lines found on page " .. new_page)
        return
    end

    -- page change direction.
    local direction = new_page >= self.last_page and "next" or "prev"

    -- check if the page jump is more than 1 page.
    local is_jump = math.abs(new_page - self.last_page) > 1

    -- Anchor so that a full block of `line_count` lines is visible right
    -- away: bottom line of the first block when moving next, bottom line
    -- of the last block when moving previous, first block on page jumps.
    local line = math.min(self:getLineCount(), #lines)

    -- Going back while auto scrolling re-reads the page from the top: the
    -- user asked for the previous page, not for its last line. Landing on
    -- the last line would leave the wait-and-turn logic to immediately
    -- jump forward again.
    -- A manual turn back keeps the old behaviour (anchor at the bottom),
    -- so putting the ruler back where it was still works.
    if not is_jump and direction == "prev" and not auto_scroll then
        line = #lines
    end

    self:moveToLine(line)
    self.last_page = new_page
end

function Ruler:moveToNextLine()
    local lines = self:getUniqueLines()
    if #lines < 1 then
        return false
    end

    local idx = self:getCurrentLineIndex()
    if not idx then
        return false
    end

    -- Advance a whole block of `line_count` lines (e.g. lines 1-3 -> 4-6).
    -- Clamp to the last line so no line is ever skipped; page turn happens
    -- on the following call once the block already sits at the bottom.
    local target = idx + self:getLineCount()
    if target > #lines then
        if idx < #lines then
            target = #lines
        else
            return false
        end
    end

    return self:moveToLine(target)
end

function Ruler:moveToPreviousLine()
    local lines = self:getUniqueLines()
    if #lines < 1 then
        return false
    end

    local idx = self:getCurrentLineIndex()
    if not idx then
        return false
    end

    -- Go back a whole block of `line_count` lines; when already at (or
    -- above) the first block, let the caller turn to the previous page.
    local target = idx - self:getLineCount()
    if target < 1 then
        return false
    end

    return self:moveToLine(target)
end

function Ruler:moveToNearestLine(y)
    local lines = self:getUniqueLines()
    if #lines < 1 then
        return false
    end

    local idx = self:getNearestTextPositions(y).idx
    if not idx then
        return false
    end

    return self:moveToLine(idx)
end

function Ruler:move(x, y)
    self.current_line_y = y
    self.current_line_x = x
end

--- Get nearest text lines from a given `y`, if `y` is nil, use the current line position.
--- This function is used to find the nearest text lines above and below the current line.
--- It works on unique visual lines (merged sboxes), so lines that are split
--- into multiple segments are treated as a single line.
---@param y? number
---@return table
function Ruler:getNearestTextPositions(y)
    -- local before = os.clock()

    if y == nil then
        y = self.current_line_y
    end

    local lines = self:getUniqueLines()

    local nearest_idx, nearest_line = nil, nil
    local min_distance = math.huge

    for i, line in ipairs(lines) do
        local distance = math.abs(line.y + line.h - y)
        if distance < min_distance then
            min_distance = distance
            nearest_idx = i
            nearest_line = line
        end
    end

    local prev = nearest_idx and lines[nearest_idx - 1] or nil
    local next = nearest_idx and lines[nearest_idx + 1] or nil

    -- self:__printTextFromSbox(nearest_line)

    -- local after = os.clock()
    -- -- logger.info(string.format("Ruler:getNearestTextPositions time: %0.6f", after - before))

    return { prev = prev, curr = nearest_line, next = next, idx = nearest_idx }
end

--- Get the textboxes (dimen) of texts on the current page
---@param ignore_cache? boolean
---@return table
function Ruler:getTexts(ignore_cache)
    local page = self.document:getCurrentPage()

    -- A rotation (or any resize) swaps the screen dims: cached line boxes
    -- were measured in the old orientation and must not survive it, even
    -- on the same page.
    if self.cached_texts
        and (self.cached_screen_w ~= self:getScreenWidth()
            or self.cached_screen_h ~= self:getScreenHeight()) then
        self.cached_texts = nil
    end

    if not ignore_cache and self.cached_texts and self.cached_texts_page == page then
        -- logger.info("--- Ruler: cache hit ---")
        return self.cached_texts
    end

    -- logger.info("--- Ruler: cache miss ---")

    --- TODO: handle multi column
    local texts = self.ui.document:getTextFromPositions(
        { x = 0, y = 0, page = page },
        { x = self:getScreenWidth(), y = self:getScreenHeight() },
        true
    )

    if texts then
        -- Merge raw sboxes into unique visual lines (see __mergeLineSegments)
        texts.lines = self:__mergeLineSegments(texts.sboxes)
    else
        texts = { sboxes = {}, lines = {} }
    end

    self.cached_texts = texts
    self.cached_texts_page = page
    self.cached_screen_w = self:getScreenWidth()
    self.cached_screen_h = self:getScreenHeight()

    return texts
end

--- A single visual text line can be reported as multiple sboxes (segments)
--- when it contains mixed formatting (bold, links, ruby, CJK font runs...).
--- Merge boxes that vertically overlap into one box per visual line, so we
--- can reason in terms of lines instead of segments.
---@param sboxes table
---@return table
function Ruler:__mergeLineSegments(sboxes)
    local lines = {}

    for _, sbox in ipairs(sboxes or {}) do
        local merged = false
        for _, line in ipairs(lines) do
            -- Belongs to a known line when the vertical ranges overlap
            -- (1px tolerance so that merely *touching* boxes stay separate)
            if sbox.y < line.y + line.h - 1 and line.y < sbox.y + sbox.h - 1 then
                local top = math.min(line.y, sbox.y)
                local bottom = math.max(line.y + line.h, sbox.y + sbox.h)
                local left = math.min(line.x, sbox.x)
                local right = math.max(line.x + line.w, sbox.x + sbox.w)
                line.x = left
                line.y = top
                line.w = right - left
                line.h = bottom - top
                merged = true
                break
            end
        end
        if not merged then
            table.insert(lines, { x = sbox.x, y = sbox.y, w = sbox.w, h = sbox.h })
        end
    end

    return lines
end

--- Get the unique visual lines of the current page (merged from sboxes)
---@return table
function Ruler:getUniqueLines()
    return self:getTexts().lines or {}
end

-- Get ruler properties and geometry --
function Ruler:getRulerProperties()
    return {
        thickness = self.settings:get("line_thickness"),
        style = self.line_style,
        color = Blitbuffer.gray(self.settings:get("line_intensity")),
    }
end

--- Get the Y positions of the underlines to draw: one per covered line,
--- anchored at the bottom edge of each line. With `line_count` == 1 this
--- is just the current line (original behaviour).
---@return table
function Ruler:getUnderlinePositions()
    local count = self:getLineCount()

    -- Nothing positioned yet (e.g. during initial UI build)
    if not self.current_line_y then
        return { self.current_line_y }
    end

    if count == 1 then
        return { self.current_line_y }
    end

    local idx = self:getCurrentLineIndex()
    if not idx then
        return { self.current_line_y }
    end

    local lines = self:getUniqueLines()
    -- Clamp at the top of the page when there are fewer lines above
    local first_idx = math.max(1, idx - (count - 1))

    local ys = {}
    for i = first_idx, idx do
        table.insert(ys, lines[i].y + lines[i].h)
    end
    return ys
end

function Ruler:getRulerGeometry()
    local ys = self:getUnderlinePositions()
    local thickness = self.settings:get("line_thickness")

    if not ys or #ys == 0 or ys[1] == nil then
        return {
            x = self.current_line_x,
            y = self.current_line_y,
            w = self:getScreenWidth(),
            h = thickness,
            offsets = { 0 },
        }
    end

    -- Offsets relative to the first (topmost) underline
    local offsets = {}
    for _, y in ipairs(ys) do
        table.insert(offsets, y - ys[1])
    end

    return {
        x = self.current_line_x,
        y = ys[1],
        w = self:getScreenWidth(),
        h = offsets[#offsets] + thickness,
        offsets = offsets,
    }
end

-- Tap to move mode handling --
function Ruler:isTapToMoveMode()
    return self.tap_to_move
end

function Ruler:enterTapToMoveMode()
    self.tap_to_move = true
    self.line_style = "dashed"
end

function Ruler:exitTapToMoveMode()
    self.tap_to_move = false
    self.line_style = "solid"
end

-- Debugging functions --
function Ruler:__printTextFromSbox(sbox)
    local page = self.document:getCurrentPage()

    if sbox == nil then
        -- logger.info("nil")
        return
    end

    local dbg_texts = self.ui.document:getTextFromPositions(
        { x = sbox.x, y = sbox.y, page = page },
        { x = sbox.x + sbox.w, y = sbox.y + sbox.h },
        true
    )

    -- logger.info(dbg_texts.text:sub(1, 20), sbox)
end

return Ruler
