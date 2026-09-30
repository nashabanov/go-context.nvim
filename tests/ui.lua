local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(root)
local ui = require("go-context.ui")

local function press(key)
    vim.fn.maparg(key, "n", false, true).callback()
end

local function run()
    local original = vim.api.nvim_get_current_win()
    local answers = {}
    local function answer(value, index)
        answers[#answers + 1] = { value = value, index = index }
    end
    ui.input({ default = "integration, smoke" }, answer)
    local buf = vim.api.nvim_get_current_buf()
    assert(vim.bo[buf].buftype == "nofile")
    assert(vim.api.nvim_buf_get_lines(buf, 0, -1, false)[1] == "integration, smoke")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "postgres" })
    press("<CR>")
    assert(answers[1].value == "postgres")
    assert(not vim.api.nvim_buf_is_valid(buf))
    assert(vim.api.nvim_get_current_win() == original)
    ui.input({}, answer)
    press("<Esc>")
    assert(#answers == 2 and answers[2].value == nil)
    vim.o.columns = 36
    ui.select({ "Add tags", "Ignore for this session" }, {
        tags = { "integration", "postgres", "smoke", "enterprise" },
    }, answer)
    local config = vim.api.nvim_win_get_config(0)
    assert(config.width <= vim.o.columns - 4)
    for _, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
        assert(vim.fn.strdisplaywidth(line) <= config.width, "Tags should wrap in narrow windows")
    end
    press("j")
    press("<CR>")
    assert(answers[3].index == 2)
    ui.select({ "Add tags", "Ignore for this session" }, { tags = { "e2e" } }, answer)
    vim.api.nvim_set_current_win(original)
    assert(#answers == 4 and answers[4].value == nil)
    assert(#vim.api.nvim_list_wins() == 1)
end

local ok, err = xpcall(run, debug.traceback)
if not ok then
    io.stderr:write(err .. "\n")
    vim.cmd("cquit 1")
end
print("PASS: floating UI layout and lifecycle")
vim.cmd("qa!")
