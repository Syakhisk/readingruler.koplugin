local https = require("ssl.https")
local json = require("json")
local ltn12 = require("ltn12")

local VERSION = require("readingruler_version")

local RELEASE_API = "https://api.github.com/repos/syakhisk/readingruler.koplugin/releases?per_page=1"

local Github = {}

function Github:newestRelease()
    local responseBody = {}
    local res, code, responseHeaders = https.request({
        url = RELEASE_API,
        sink = ltn12.sink.table(responseBody),
    })

    if code == 200 or code == 304 then
        local data = json.decode(table.concat(responseBody), json.decode.simple)
        if data and #data > 0 then
            local raw_tag = data[1].tag_name
            local index = 1
            local tag = raw_tag:gsub("^v", "") -- Remove leading 'v' if present
            for str in string.gmatch(tag, "([^.]+)") do
                local part = tonumber(str)

                if part < VERSION[index] then
                    return nil
                elseif part > VERSION[index] then
                    return tag
                end

                index = index + 1
            end
        end
    end
end

return Github
