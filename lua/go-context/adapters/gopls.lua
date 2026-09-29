local store = require("go-context.store")
local workspace = require("go-context.workspace")
local context = require("go-context.context")

local M = {}

function M.apply_settings(settings, value)
    settings = settings or {}
    settings.gopls = settings.gopls or {}

    value = context.normalize(value)

    local flags = {}
    local skip_next = false

    for _, flag in ipairs(settings.gopls.buildFlags or {}) do
        if skip_next then
            skip_next = false
        elseif flag == "-tags" then
            skip_next = true
        elseif not flag:match("^%-tags=") then
            flags[#flags + 1] = flag
        end
    end

    if #value.tags > 0 then
        flags[#flags + 1] = "-tags=" .. table.concat(value.tags, ",")
    end

    settings.gopls.buildFlags = flags

    return settings
end

function M.before_init(_, config)
    local root = workspace.normalize(config.root_dir)

    if not root then
        return
    end

    local ok, value = pcall(store.get, root)

    if not ok then
        vim.schedule(function()
            vim.notify(
                tostring(value),
                vim.log.levels.WARN,
                { title = "go-context.nvim" }
            )
        end)

        return
    end

    if not value then
        return
    end

    config.settings = M.apply_settings(config.settings, value)
end

function M.update(root, value)
    root = assert(workspace.normalize(root), "Go workspace root is required")
    value = context.normalize(value)

    for _, client in ipairs(vim.lsp.get_clients({ name = "gopls" })) do
        if workspace.normalize(client.config.root_dir) == root then
            client.settings = M.apply_settings(client.settings, value)

            client:notify("workspace/didChangeConfiguration", {
                settings = client.settings,
            })
        end
    end
end

return M
