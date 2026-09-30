local M = {}
local ns = vim.api.nvim_create_namespace("GoContextUI")

local function open(lines, title, footer, editable, callback)
    local width = math.max(1, math.min(60, vim.o.columns - 4))
    local height = math.max(1, math.min(#lines, vim.o.lines - 5))
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].bufhidden = "wipe"
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = editable
    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        row = math.max(0, math.floor((vim.o.lines - height - 2) / 2)),
        col = math.max(0, math.floor((vim.o.columns - width - 2) / 2)),
        width = width,
        height = height,
        style = "minimal",
        border = "rounded",
        title = " " .. title .. " ",
        title_pos = "left",
        footer = vim.fn.strdisplaywidth(footer) <= width and footer or " Enter / Esc ",
        footer_pos = "left",
    })
    vim.wo[win].winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder,FloatTitle:Title,FloatFooter:Comment"
    vim.wo[win].wrap = false
    vim.wo[win].sidescrolloff = 3
    vim.wo[win].scrolloff = 0
    vim.wo[win].cursorline = not editable
    local done = false
    local function finish(value, index)
        if done then return end
        done = true
        if editable then vim.cmd("stopinsert") end
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end
        callback(value, index)
    end
    vim.api.nvim_create_autocmd({ "BufLeave", "BufWipeout" }, {
        buffer = buf,
        once = true,
        callback = function() finish(nil) end,
    })
    local function map(mode, key, fn)
        vim.keymap.set(mode, key, fn, { buffer = buf, silent = true, nowait = true })
    end
    map({ "n", "i" }, "<Esc>", function() finish(nil) end)
    map({ "n", "i" }, "<C-c>", function() finish(nil) end)
    if not editable then map("n", "q", function() finish(nil) end) end
    return buf, win, finish, map
end

function M.input(opts, callback)
    local buf, win, finish, map = open(
        { opts.default or "" }, "Go build tags",
        " Enter save · Esc cancel · comma or space ", true, callback
    )
    map({ "n", "i" }, "<CR>", function()
        finish(table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), " "))
    end)
    vim.api.nvim_win_set_cursor(win, { 1, #(opts.default or "") })
    vim.cmd("startinsert!")
end

function M.select(items, opts, callback)
    local width = math.max(1, math.min(60, vim.o.columns - 4))
    local lines = { "Add tags to this workspace?", "" }
    -- Wrap at tag boundaries; long identifiers remain accessible by scrolling.
    local line = "  "
    for _, tag in ipairs(opts.tags or {}) do
        local separator = line == "  " and "" or ", "
        if vim.fn.strdisplaywidth(line .. separator .. tag) > width and line ~= "  " then
            lines[#lines + 1] = line
            line, separator = "  ", ""
        end
        line = line .. separator .. tag
    end
    lines[#lines + 1] = line
    lines[#lines + 1] = ""
    local first = #lines + 1
    for _, item in ipairs(items) do lines[#lines + 1] = "  " .. item end
    local buf, win, finish, map = open(lines, "Go build tags", " Enter select · Esc cancel ", false, callback)
    for row = 3, first - 2 do
        vim.api.nvim_buf_add_highlight(buf, ns, "Special", row - 1, 0, -1)
    end
    vim.api.nvim_buf_add_highlight(buf, ns, "Comment", 0, 0, -1)
    local selected = 1
    local function move(delta)
        selected = (selected - 1 + delta) % #items + 1
        vim.api.nvim_win_set_cursor(win, { first + selected - 1, 2 })
    end
    map("n", "<CR>", function()
        local row = vim.api.nvim_win_get_cursor(win)[1]
        local index = row - first + 1
        if index >= 1 and index <= #items then selected = index end
        finish(items[selected], selected)
    end)
    for _, key in ipairs({ "j", "<Down>", "<Tab>" }) do map("n", key, function() move(1) end) end
    for _, key in ipairs({ "k", "<Up>", "<S-Tab>" }) do map("n", key, function() move(-1) end) end
    move(0)
end

return M
