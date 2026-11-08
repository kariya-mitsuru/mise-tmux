local cmd = require("cmd")
local http = require("http")

local REPO = "https://github.com/tmux/tmux"

-- Release dates are only needed for versions near the minimum_release_age
-- cutoff (default 24h): mise never hides an undated version. Dates come from
-- GitHub's tags Atom feed (10 tags per page, no API token) until this many
-- days are covered; tmux releases rarely, so one page is normally enough.
local DATE_WINDOW_DAYS = tonumber(os.getenv("MISE_TMUX_DATE_WINDOW_DAYS") or "") or 30
local MAX_FEED_PAGES = 5

local VERSION_PATTERN = "^%d+%.%d+%l?$" -- 3.5, 3.5a, 0.8

--- Splits "3.7c" into { 3, 7 } and "c".
local function parse(v)
    local nums = {}
    for n in v:gmatch("%d+") do
        table.insert(nums, tonumber(n))
    end
    return nums, v:match("(%l*)$")
end

local function newer(a, b)
    local na, sa = parse(a)
    local nb, sb = parse(b)
    for i = 1, math.max(#na, #nb) do
        local x, y = na[i] or -1, nb[i] or -1
        if x ~= y then
            return x > y
        end
    end
    return sa > sb
end

--- Returns { ["3.8"] = "2026-10-08T07:20:35Z", ... } for recent tags.
--- Failures are not fatal: versions are then just listed without dates.
local function recent_tag_dates()
    local dates = {}
    -- RFC 3339 UTC strings compare correctly as plain strings.
    local ok, oldest_wanted = pcall(os.date, "!%Y-%m-%dT%H:%M:%SZ", os.time() - DATE_WINDOW_DAYS * 86400)
    if not ok then
        oldest_wanted = nil
    end

    local after = nil
    for _ = 1, MAX_FEED_PAGES do
        local url = REPO .. "/tags.atom" .. (after and ("?after=" .. after) or "")
        local resp = http.try_get({ url = url })
        if not resp or resp.status_code ~= 200 or not resp.body then
            break
        end

        local last_tag, last_date = nil, nil
        for entry in resp.body:gmatch("<entry>(.-)</entry>") do
            -- the entry title is the tag message ("tmux 3.8"), so take the tag from the link
            local tag = entry:match("/releases/tag/([^\"]+)\"")
            local date = entry:match("<updated>([^<]+)</updated>")
            if tag and date then
                dates[tag] = date
                last_tag, last_date = tag, date
            end
        end

        if not last_tag or (oldest_wanted and last_date < oldest_wanted) then
            break
        end
        after = last_tag
    end
    return dates
end

--- Lists release tags of tmux/tmux (3.8, 3.7c, ..., 0.8), newest first.
function PLUGIN:Available(ctx)
    local out = cmd.exec("git ls-remote --tags --refs " .. REPO .. ".git")
    local versions = {}
    for tag in out:gmatch("refs/tags/(%S+)") do
        if tag:match(VERSION_PATTERN) then
            table.insert(versions, tag)
        end
    end
    table.sort(versions, newer)

    local dates = recent_tag_dates()
    local result = {}
    for _, v in ipairs(versions) do
        table.insert(result, { version = v, created_at = dates[v] })
    end
    return result
end
