local context = require("go_context.context")
local workspace = require("go_context.workspace")
local store = require("go_context.store")
local gopls = require("go_context.adapters.gopls")

local M = {}

local function resolve_root(opts)
    opts = opts or {}

    if opts.root then
        return workspace.normalize(opts.root)
    end

    return workspace.root(opts.bufnr or 0)
end

local function emit_changed(root, value)
    vim.api.nvim_exec_autocmds("User", {
        pattern = "GoContextChanged",
        data = {
            root = root,
            context = vim.deepcopy(value)
        }
    })
end

function M.root(opts)
    return resolve_root(opts)
end

function M.get(opts)
    local root, err = resolve_root(opts)

    if not root then
        return nil, err
    end

    local ok, value = pcall(store.get, root)

    if not ok then
        return nil, tostring(value)
    end

    return value
end

function M.set(value, opts)
    local root, err = resolve_root(opts)

    assert(root, err or "No Go workspace found")

    value = context.normalize(value)

    store.set(root, value)
    gopls.update(root, value)
    emit_changed(root, value)

    return value
end

function M.clear(opts)
    local root, err = resolve_root(opts)

    assert(root, err or "No Go workspace found")

    local value = {
        tags = {},
    }

    -- First remove the active build flags from running clients.
    gopls.update(root, value)

    -- No reason to persist an empty context.
    store.delete(root)

    emit_changed(root, value)

    return value
end

function M.tags(opts)
    local value = M.get(opts)

    if not value then
        return {}
    end

    return vim.deepcopy(value.tags)
end

function M.before_init(...)
    return gopls.before_init(...)
end

function M.setup()
    require("go_context.commands").setup()
end

return M
