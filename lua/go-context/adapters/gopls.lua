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

function M.before_init(params, config)
    local root = workspace.normalize(config.root_dir)

    if not root then
        return
    end

    local ok, value = pcall(store.get, root)

    if not ok then
        vim.schedule(function()
            vim.notify(tostring(value), vim.log.levels.WARN, { title = "go-context.nvim" })
        end)

        return
    end

    if not value then
        return
    end

    config.settings = config.settings or {}
    config.settings.gopls = config.settings.gopls or {}
    if config.settings.gopls.buildFlags == nil and params.initializationOptions then
        config.settings.gopls.buildFlags = vim.deepcopy(params.initializationOptions.buildFlags)
    end
    config.settings = M.apply_settings(config.settings, value)
    -- Neovim creates client.settings before invoking before_init.
    -- Initialization options also cover configurations without settings.
    params.initializationOptions = params.initializationOptions or {}
    params.initializationOptions.buildFlags = vim.deepcopy(config.settings.gopls.buildFlags)
end

function M.update(root, value)
    root = assert(workspace.normalize(root), "Go workspace root is required")
    value = context.normalize(value)

    for _, client in ipairs(vim.lsp.get_clients({ name = "gopls" })) do
        if workspace.normalize(client.config.root_dir) == root then
            client.settings = M.apply_settings(client.settings, value)

            local params = { settings = client.settings }
            local sent
            if vim.fn.has("nvim-0.11") == 1 then
                sent = client:notify("workspace/didChangeConfiguration", params)
            else
                sent = client.notify("workspace/didChangeConfiguration", params)
            end
            assert(sent ~= false, "Could not update gopls configuration")
        end
    end
end

return M
