local context = require("go-context.context")
local workspace = require("go-context.workspace")

local M = {}

local uv = vim.uv or vim.loop
local VERSION = 1

local function state_dir()
    return vim.fn.stdpath("state") .. "/go_context.nvim"
end

function M.path(root)
    root = assert(workspace.normalize(root), "Go workspace root is required")

    return state_dir() .. "/" .. vim.fn.sha256(root) .. ".json"
end

function M.get(root)
    root = assert(workspace.normalize(root), "Go workspace root is required")

    local path = M.path(root)

    local stat, err, code = uv.fs_stat(path)
    if not stat and code == "ENOENT" then
        return nil
    end
    assert(stat, "Could not read go-context state: " .. tostring(err))
    assert(stat.type == "file", "Go context state is not a file")

    local raw = table.concat(vim.fn.readfile(path), "\n")
    local payload = vim.json.decode(raw)

    assert(
        type(payload) == "table" and payload.version == VERSION,
        "Unsupported go-context state format"
    )

    assert(payload.root == root, "Go context state belongs to another workspace")

    assert(type(payload.context) == "table", "Invalid Go context state")
    return context.normalize(payload.context)
end

function M.set(root, value)
    root = assert(workspace.normalize(root), "Go workspace root is required")
    value = context.normalize(value)

    local dir = state_dir()
    local path = M.path(root)

    assert(
        vim.fn.mkdir(dir, "p") == 1 or vim.fn.isdirectory(dir) == 1,
        "Could not create go-context state directory"
    )

    local payload = vim.json.encode({
        version = VERSION,
        root = root,
        context = value,
    })

    local temp = path .. ".tmp." .. tostring(vim.fn.getpid())

    local written, result = pcall(vim.fn.writefile, { payload }, temp)
    if not written or result ~= 0 then
        vim.fn.delete(temp)
        error("Could not write go-context state: " .. tostring(result))
    end

    local ok, err = uv.fs_rename(temp, path)

    if not ok then
        vim.fn.delete(temp)
        error("Could not save go-context state: " .. tostring(err))
    end

    return value
end

function M.delete(root)
    local path = M.path(root)

    local stat, err, code = uv.fs_stat(path)
    if not stat and code == "ENOENT" then
        return
    end
    assert(stat, "Could not access go-context state: " .. tostring(err))
    assert(stat.type == "file", "Go context state is not a file")

    assert(vim.fn.delete(path) == 0, "Could not delete go-context state")
end

return M
