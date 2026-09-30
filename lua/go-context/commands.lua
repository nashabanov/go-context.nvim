local context = require("go-context.context")

local M = {}

local function notify(message, level)
    vim.notify(message, level, {
        title = "Go build tags",
    })
end

local function current_root(go_context)
    local root, err = go_context.root({ bufnr = 0 })

    if not root then
        notify(err or "No Go workspace found", vim.log.levels.WARN)
        return nil
    end

    return root
end

local function set_tags(go_context, root, value)
    local ok, err = pcall(function()
        go_context.set({
            tags = context.parse_tags(value),
        }, {
            root = root,
        })
    end)

    if not ok then
        notify(tostring(err), vim.log.levels.ERROR)
        return
    end

    local tags = go_context.tags({ root = root })

    notify(
        "Tags: "
        .. (#tags > 0 and table.concat(tags, ", ") or "none"),
        vim.log.levels.INFO
    )
end

function M.setup()
    local go_context = require("go-context")

    vim.api.nvim_create_user_command("GoContext", function(opts)
        local root = current_root(go_context)

        if not root then
            return
        end

        if opts.bang then
            local ok, err = pcall(go_context.clear, {
                root = root,
            })

            if not ok then
                notify(tostring(err), vim.log.levels.ERROR)
                return
            end

            notify("Tags cleared", vim.log.levels.INFO)
            return
        end

        if opts.args ~= "" then
            set_tags(go_context, root, opts.args)
            return
        end

        local current, err = go_context.get({
            root = root,
        })

        if err then
            notify(err, vim.log.levels.ERROR)
            return
        end

        require("go-context.ui").input({
            default = table.concat(
                current and current.tags or {},
                ", "
            ),
        }, function(value)
            if value == nil then
                return
            end

            set_tags(go_context, root, value)
        end)
    end, {
        nargs = "*",
        bang = true,
        desc = "Set Go build context for the current workspace",
    })

    vim.api.nvim_create_user_command("GoContextClear", function()
        local root = current_root(go_context)

        if not root then
            return
        end

        local ok, err = pcall(go_context.clear, {
            root = root,
        })

        if not ok then
            notify(tostring(err), vim.log.levels.ERROR)
            return
        end

        notify("Tags cleared", vim.log.levels.INFO)
    end, {
        desc = "Clear Go build context for the current workspace",
    })
end

return M
