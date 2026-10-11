local repo = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(repo)
local workspace = require("go-context.workspace")
local dir = vim.fn.tempname()
vim.fn.mkdir(dir .. "/a/sub", "p")
vim.fn.mkdir(dir .. "/b", "p")
vim.fn.writefile({ "module example.com/a" }, dir .. "/a/go.mod")
local function run()
    local a = workspace.normalize(dir .. "/a")
    assert(workspace.normalize(dir .. "/a/sub/../") == a)
    assert(workspace.normalize("") == nil)
    assert(workspace.normalize(123) == nil)
    local linked = dir .. "/linked"
    assert(vim.uv.fs_symlink(dir .. "/a", linked))
    assert(workspace.normalize(linked) == a)
    assert(
        workspace.normalize("missing/../project/")
            == vim.fs.normalize(vim.fn.getcwd() .. "/project")
    )
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(buf, dir .. "/a/sub/main.go")
    local clients = {}
    vim.lsp.get_clients = function()
        return clients
    end
    assert(workspace.root(buf) == a)
    clients = { { config = { root_dir = a } }, { config = { root_dir = a .. "/" } } }
    assert(workspace.root(buf) == a)
    clients[2].config.root_dir = dir .. "/b"
    local root, err = workspace.root(buf)
    assert(root == nil and err:match("Multiple"))
    clients = {}
    vim.api.nvim_buf_set_name(buf, dir .. "/b/main.go")
    root, err = workspace.root(buf)
    assert(root == nil and err:match("No Go workspace"))
end
local ok, err = xpcall(run, debug.traceback)
vim.fn.delete(dir, "rf")
if not ok then
    io.stderr:write(err .. "\n")
    vim.cmd("cquit 1")
end
print("PASS: workspace roots")
vim.cmd("qa!")
