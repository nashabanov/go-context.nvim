local M = {}

local function normalize_tags(tags)
    local result, seen = {}, {}

    for _, tag in ipairs(tags or {}) do
        assert(
            type(tag) == "string" and tag:match("^[%w_.]+$"),
            "Invalid Go build tag: " .. tostring(tag)
        )

        if not seen[tag] then
            result[#result + 1] = tag
            seen[tag] = true
        end
    end

    return result
end

function M.parse_tags(value)
    assert(type(value) == "string", "Go build tags must be a string")

    local tags = {}

    for tag in value:gmatch("[^,%s]+") do
        tags[#tags + 1] = tag
    end

    return normalize_tags(tags)
end

function M.normalize(context)
    context = context or {}

    return {
        tags = normalize_tags(context.tags)
    }
end

return M
