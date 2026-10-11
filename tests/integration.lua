local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")

vim.opt.rtp:prepend(root)

local go_context = require("go-context")
local workspace = require("go-context.workspace")
local store = require("go-context.store")
local gopls = require("go-context.adapters.gopls")

local original_root = workspace.root
local original_normalize = workspace.normalize
local original_get = store.get
local original_set = store.set
local original_delete = store.delete
local original_update = gopls.update

local project = "/tmp/go-context-test"

local saved = nil
local updates = {}
local events = {}

workspace.normalize = function(value)
    return value
end

workspace.root = function(bufnr)
    assert(bufnr == 0)
    return project
end

store.get = function(root)
    assert(root == project)
    return saved and vim.deepcopy(saved) or nil
end

store.set = function(root, value)
    assert(root == project)
    saved = vim.deepcopy(value)
    return value
end

store.delete = function(root)
    assert(root == project)
    saved = nil
end

gopls.update = function(root, value)
    assert(root == project)

    updates[#updates + 1] = vim.deepcopy(value)
end

vim.api.nvim_create_autocmd("User", {
    pattern = "GoContextChanged",
    callback = function(event)
        events[#events + 1] = vim.deepcopy(event.data)
    end,
})

local function run()
    local result = go_context.set({
        tags = {
            "integration",
            "smoke",
            "integration",
        },
    })

    assert(vim.deep_equal(result, {
        tags = { "integration", "smoke" },
    }))

    assert(vim.deep_equal(saved, {
        tags = { "integration", "smoke" },
    }))

    assert(vim.deep_equal(updates[1], {
        tags = { "integration", "smoke" },
    }))

    assert(vim.deep_equal(go_context.get(), {
        tags = { "integration", "smoke" },
    }))

    assert(vim.deep_equal(go_context.tags(), { "integration", "smoke" }))

    assert(#events == 1)
    assert(events[1].root == project)

    assert(vim.deep_equal(events[1].context, {
        tags = { "integration", "smoke" },
    }))

    result.tags[1] = "changed"
    local copy = go_context.get({ root = project, bufnr = 99 })
    copy.tags[1] = "changed"
    local tags = go_context.tags({ root = project })
    tags[1] = "changed"
    assert(saved.tags[1] == "integration")
    local before = #events
    store.delete = function()
        error("delete failed")
    end
    assert(not pcall(go_context.clear, { root = project }))
    assert(#events == before and #updates == 1)
    assert(saved.tags[1] == "integration")
    store.delete = function()
        saved = nil
    end
    local write = store.set
    store.set = function()
        error("save failed")
    end
    assert(not pcall(go_context.set, { tags = { "new" } }, { root = project }))
    assert(#events == before and #updates == 1)
    store.set = write
    store.get = function()
        error("read failed")
    end
    local missing, read_err = go_context.get({ root = project })
    assert(missing == nil and read_err:match("read failed"))
    assert(vim.deep_equal(go_context.tags({ root = project }), {}))
    store.get = function()
        return saved and vim.deepcopy(saved)
    end
    workspace.root = function(bufnr)
        assert(bufnr == 42)
        return project
    end
    assert(go_context.root({ bufnr = 42 }) == project)
    workspace.root = function()
        return nil, "unavailable"
    end
    missing, read_err = go_context.get()
    assert(missing == nil and read_err == "unavailable")
    assert(not pcall(go_context.set, { tags = {} }))
    workspace.root = function()
        return project
    end
    go_context.clear()

    assert(saved == nil, "clear should remove persisted context")

    assert(vim.deep_equal(updates[2], {
        tags = {},
    }))

    assert(#events == 2)

    assert(vim.deep_equal(events[2].context, {
        tags = {},
    }))

    assert(vim.deep_equal(go_context.tags(), {}))
end

local ok, err = xpcall(run, debug.traceback)

workspace.root = original_root
workspace.normalize = original_normalize
store.get = original_get
store.set = original_set
store.delete = original_delete
gopls.update = original_update

if not ok then
    io.stderr:write(err .. "\n")
    vim.cmd("cquit 1")
end

print("PASS: public context lifecycle")
vim.cmd("qa!")
