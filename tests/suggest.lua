local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(root)
local go_context = require("go-context")
local workspace = require("go-context.workspace")
local store = require("go-context.store")
local gopls = require("go-context.adapters.gopls")
local suggest = require("go-context.suggest")

local function run()
    local project = "/tmp/workspace-a"
    local saved, prompts, updates, events = {}, {}, {}, {}
    workspace.root = function(bufnr)
        assert(bufnr > 0)
        return project
    end
    workspace.normalize = function(value) return value end
    store.get = function(key) return vim.deepcopy(saved[key]) end
    store.set = function(key, value) saved[key] = vim.deepcopy(value) end
    gopls.update = function(key, value) updates[#updates + 1] = { key, value } end
    vim.api.nvim_create_autocmd("User", {
        pattern = "GoContextChanged",
        callback = function(event) events[#events + 1] = event.data end,
    })
    require("go-context.ui").select = function(items, opts, callback)
        prompts[#prompts + 1] = { items = items, tags = opts.tags, answer = callback }
    end
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(buf, "/tmp/suggestion.go")
    local function enter(expression)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
            "//go:build " .. expression, "package foo",
        })
        vim.api.nvim_exec_autocmds("BufEnter", { buffer = buf })
    end
    go_context.setup()
    go_context.setup()
    assert(#vim.api.nvim_get_autocmds({ group = "GoContextSuggest" }) == 1)
    saved[project] = { tags = { "integration" } }
    enter("integration")
    assert(#prompts == 0)
    enter("integration && postgres")
    assert(#prompts == 1)
    assert(vim.deep_equal(prompts[1].tags, { "postgres" }))
    enter("integration && postgres")
    assert(#prompts == 1, "A pending prompt must not be repeated")
    saved[project].tags[#saved[project].tags + 1] = "smoke"
    prompts[1].answer(prompts[1].items[1], 1)
    assert(vim.deep_equal(saved[project].tags, { "integration", "smoke", "postgres" }))
    assert(#updates == 1 and #events == 1, "Accepting tags must use the public set API")
    enter("postgres")
    assert(#prompts == 1)
    enter("e2e")
    prompts[2].answer(prompts[2].items[2], 2)
    enter("e2e")
    assert(#prompts == 2)
    assert(#updates == 1)
    project = "/tmp/workspace-b"
    enter("e2e")
    assert(#prompts == 3, "Declined tags must be isolated by workspace")
    project = "/tmp/workspace-c"
    prompts[3].answer(prompts[3].items[1], 1)
    assert(vim.deep_equal(saved["/tmp/workspace-b"].tags, { "e2e" }))
    assert(saved[project] == nil, "The response must use the original workspace")
    vim.api.nvim_buf_set_name(buf, "/tmp/suggestion.txt")
    suggest.buffer(buf)
    assert(#prompts == 3, "Non-Go buffers must be ignored")
    vim.api.nvim_buf_set_name(buf, "/tmp/suggestion.go")
    enter("cancelled")
    prompts[4].answer(nil, nil)
    enter("cancelled")
    assert(#prompts == 4)
    enter("linux && !enterprise")
    assert(#prompts == 4)
end
local ok, err = xpcall(run, debug.traceback)
if not ok then
    io.stderr:write(err .. "\n")
    vim.cmd("cquit 1")
end
print("PASS: workspace build tag suggestions")
vim.cmd("qa!")
