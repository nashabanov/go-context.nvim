local repo = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(repo)
local dir = vim.fn.tempname()
local go_context = require("go-context")
local client
local function run()
    vim.lsp.log.set_level("debug")
    assert(vim.fn.executable("gopls") == 1, "gopls must be on PATH")
    assert(vim.fn.executable("go") == 1, "Go must be on PATH")
    vim.fn.mkdir(dir, "p")
    dir = vim.uv.fs_realpath(dir)
    vim.fn.writefile({ "module example.com/smoke", "", "go 1.22" }, dir .. "/go.mod")
    vim.fn.writefile(
        { "//go:build integration", "", "package smoke", "", "const Tagged = 42" },
        dir .. "/tagged.go"
    )
    vim.fn.writefile({ "package smoke", "", "var Value = Tagged" }, dir .. "/main.go")
    go_context.set({ tags = { "integration" } }, { root = dir })
    vim.cmd.edit(vim.fn.fnameescape(dir .. "/main.go"))
    local buf = vim.api.nvim_get_current_buf()
    vim.bo[buf].filetype = "go"
    local capabilities = vim.lsp.protocol.make_client_capabilities()
    capabilities.workspace.didChangeWatchedFiles.dynamicRegistration = false
    local id = vim.lsp.start({
        capabilities = capabilities,
        name = "gopls",
        cmd = { "gopls" },
        root_dir = dir,
        before_init = go_context.before_init,
    })
    assert(id, "Could not start gopls")
    client = vim.lsp.get_client_by_id(id)
    assert(
        vim.wait(20000, function()
            return client.initialized
        end, 50),
        "gopls initialization timed out"
    )
    local params = {
        textDocument = { uri = vim.uri_from_bufnr(buf) },
        position = { line = 2, character = 14 },
    }
    local function definition()
        local response, err
        if vim.fn.has("nvim-0.11") == 1 then
            response, err = client:request_sync("textDocument/definition", params, 10000, buf)
        else
            response, err = client.request_sync("textDocument/definition", params, 10000, buf)
        end
        assert(response and not response.err, vim.inspect(err or response))
        return response.result
    end
    local result = definition()
    assert(
        type(result) == "table" and #result > 0,
        "Saved tags did not enable Tagged: " .. vim.inspect(result)
    )
    go_context.clear({ root = dir })
    assert(
        vim.wait(20000, function()
            for _, diagnostic in ipairs(vim.diagnostic.get(buf)) do
                if diagnostic.message:match("undefined: Tagged") then
                    return true
                end
            end
            return false
        end, 100),
        "Clearing tags did not invalidate Tagged"
    )
    go_context.set({ tags = { "integration" } }, { root = dir })
    assert(
        vim.wait(20000, function()
            return #vim.diagnostic.get(buf) == 0
        end, 100),
        "Runtime tags did not restore Tagged"
    )
    result = definition()
    assert(type(result) == "table" and #result > 0)
    go_context.clear({ root = dir })
end
local ok, err = xpcall(run, debug.traceback)
if client then
    if vim.fn.has("nvim-0.11") == 1 then
        client:stop(true)
    else
        client.stop(true)
    end
    vim.wait(5000, function()
        return vim.lsp.get_client_by_id(client.id) == nil
    end, 50)
end
vim.fn.delete(dir, "rf")
if not ok then
    io.stderr:write(err .. "\n")
    vim.cmd("cquit 1")
end
print("PASS: real gopls initialization, runtime updates and clearing")
vim.cmd("qa!")
