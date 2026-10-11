local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")

vim.opt.rtp:prepend(root)

local store = require("go-context.store")

local workspace = vim.fn.tempname()
vim.fn.mkdir(workspace, "p")

local function run()
    assert(store.get(workspace) == nil, "new workspace should not have saved context")

    local saved = store.set(workspace, {
        tags = { "integration", "smoke" },
    })

    assert(vim.deep_equal(saved, {
        tags = { "integration", "smoke" },
    }))

    local loaded = store.get(workspace)

    assert(vim.deep_equal(loaded, {
        tags = { "integration", "smoke" },
    }))

    local path = store.path(workspace)

    assert(vim.fn.filereadable(path) == 1, "state file should exist")

    local payload = vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))

    assert(payload.version == 1)
    assert(payload.root == (vim.uv.fs_realpath(workspace) or workspace))

    assert(vim.deep_equal(payload.context.tags, { "integration", "smoke" }))

    local other = workspace .. "/other"
    store.set(other, { tags = { "other" } })
    loaded.tags[1] = "mutated"
    assert(store.get(workspace).tags[1] == "integration")
    assert(store.get(other).tags[1] == "other")
    for _, raw in ipairs({
        "{",
        '{"version":2}',
        vim.json.encode({ version = 1, root = payload.root }),
        vim.json.encode({ version = 1, root = "another", context = { tags = {} } }),
        vim.json.encode({ version = 1, root = payload.root, context = { tags = "bad" } }),
    }) do
        vim.fn.writefile({ raw }, path)
        assert(not pcall(store.get, workspace), "Invalid state must fail")
    end
    store.set(workspace, saved)
    local rename = vim.uv.fs_rename
    vim.uv.fs_rename = function()
        return nil, "simulated rename failure"
    end
    assert(not pcall(store.set, workspace, { tags = { "replacement" } }))
    vim.uv.fs_rename = rename
    assert(store.get(workspace).tags[1] == "integration")
    assert(vim.fn.filereadable(path .. ".tmp." .. vim.fn.getpid()) == 0)
    local write = vim.fn.writefile
    vim.fn.writefile = function()
        error("simulated write failure")
    end
    assert(not pcall(store.set, workspace, saved))
    vim.fn.writefile = write
    local delete = vim.fn.delete
    vim.fn.delete = function()
        return -1
    end
    assert(not pcall(store.delete, workspace))
    vim.fn.delete = delete
    store.delete(workspace)

    assert(store.get(workspace) == nil, "deleted context should not be returned")

    assert(vim.fn.filereadable(path) == 0, "state file should be removed")
end

local ok, err = xpcall(run, debug.traceback)

vim.fn.delete(workspace, "rf")

if not ok then
    io.stderr:write(err .. "\n")
    vim.cmd("cquit 1")
end

print("PASS: context persistence")
vim.cmd("qa!")
