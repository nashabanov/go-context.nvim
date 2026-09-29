local M = {}

local ignored, pending = {}, {}

local function report(err)
    vim.notify(tostring(err), vim.log.levels.ERROR, { title = "go-context.nvim" })
end

function M.buffer(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    if bufnr == 0 then
        bufnr = vim.api.nvim_get_current_buf()
    end
    if not vim.api.nvim_buf_is_valid(bufnr)
        or vim.bo[bufnr].buftype ~= ""
        or (vim.bo[bufnr].filetype ~= "go"
            and not vim.api.nvim_buf_get_name(bufnr):match("%.go$"))
    then
        return
    end

    local go_context = require("go_context")
    local root = go_context.root({ bufnr = bufnr })
    if not root or pending[root] then
        return
    end

    local detected = require("go_context.detect").buffer(bufnr)
    if #detected == 0 then
        return
    end
    local current, err = go_context.get({ root = root })
    if err then
        report(err)
        return
    end

    local present, missing = {}, {}
    for _, tag in ipairs(current and current.tags or {}) do
        present[tag] = true
    end
    for _, tag in ipairs(detected) do
        if not present[tag] and not (ignored[root] and ignored[root][tag]) then
            missing[#missing + 1] = tag
        end
    end
    if #missing == 0 then
        return
    end

    pending[root] = true
    local ok, failure = pcall(vim.ui.select, { "Add", "Decline" }, {
        prompt = "New Go build tags found: " .. table.concat(missing, ", ")
            .. ". Add them to this workspace context?",
    }, function(_, choice)
        -- Keep the lock during set: event handlers may re-enter the buffer.
        local applied, apply_err = pcall(function()
            if choice ~= 1 then
                ignored[root] = ignored[root] or {}
                for _, tag in ipairs(missing) do
                    ignored[root][tag] = true
                end
                return
            end

            local latest, read_err = go_context.get({ root = root })
            if read_err then
                error(read_err)
            end
            local tags = vim.deepcopy(latest and latest.tags or {})
            local seen = {}
            for _, tag in ipairs(tags) do
                seen[tag] = true
            end
            for _, tag in ipairs(missing) do
                if not seen[tag] then
                    tags[#tags + 1] = tag
                    seen[tag] = true
                end
            end
            go_context.set({ tags = tags }, { root = root })
        end)
        pending[root] = nil
        if not applied then
            report(apply_err)
        end
    end)
    if not ok then
        pending[root] = nil
        report(failure)
    end
end

function M.setup()
    local group = vim.api.nvim_create_augroup("GoContextSuggest", { clear = true })
    vim.api.nvim_create_autocmd("BufEnter", {
        group = group,
        pattern = "*.go",
        callback = function(event)
            M.buffer(event.buf)
        end,
        desc = "Suggest build tags from the current Go buffer",
    })
end

return M
