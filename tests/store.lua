local root = vim.fn.fnamemodify(
    debug.getinfo(1, "S").source:sub(2),
    ":p:h:h"
)

vim.opt.rtp:prepend(root)

local store = require("go-context.store")

local workspace = vim.fn.tempname()
vim.fn.mkdir(workspace, "p")

local function run()
    assert(
        store.get(workspace) == nil,
        "new workspace should not have saved context"
    )

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

    assert(
        vim.fn.filereadable(path) == 1,
        "state file should exist"
    )

    local payload = vim.json.decode(
        table.concat(vim.fn.readfile(path), "\n")
    )

    assert(payload.version == 1)
    assert(payload.root == (vim.uv.fs_realpath(workspace) or workspace))

    assert(vim.deep_equal(
        payload.context.tags,
        { "integration", "smoke" }
    ))

    store.delete(workspace)

    assert(
        store.get(workspace) == nil,
        "deleted context should not be returned"
    )

    assert(
        vim.fn.filereadable(path) == 0,
        "state file should be removed"
    )
end

local ok, err = xpcall(run, debug.traceback)

vim.fn.delete(workspace, "rf")

if not ok then
    io.stderr:write(err .. "\n")
    vim.cmd("cquit 1")
end

print("PASS: context persistence")
vim.cmd("qa!")
