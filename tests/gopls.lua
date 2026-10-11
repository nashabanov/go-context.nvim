local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")

vim.opt.rtp:prepend(root)

local gopls = require("go-context.adapters.gopls")
local store = require("go-context.store")

local dir = vim.fn.tempname()

local first = dir .. "/first"
local second = dir .. "/second"

vim.fn.mkdir(first, "p")
vim.fn.mkdir(second, "p")

local function run()
    -- Existing build flags must survive.
    local settings = {
        gopls = {
            buildFlags = {
                "-mod=mod",
                "-tags",
                "old",
            },
        },
    }

    local original = settings

    local result = gopls.apply_settings(settings, {
        tags = { "integration", "smoke" },
    })

    assert(result == original, "existing settings table should be mutated")

    assert(vim.deep_equal(result.gopls.buildFlags, {
        "-mod=mod",
        "-tags=integration,smoke",
    }))

    -- -tags=value form must also be replaced.
    local equals_form = {
        gopls = {
            buildFlags = {
                "-mod=readonly",
                "-tags=old",
            },
        },
    }

    gopls.apply_settings(equals_form, {
        tags = { "e2e" },
    })

    assert(vim.deep_equal(equals_form.gopls.buildFlags, {
        "-mod=readonly",
        "-tags=e2e",
    }))

    -- Empty context removes build tags but keeps unrelated flags.
    gopls.apply_settings(equals_form, {
        tags = {},
    })

    assert(vim.deep_equal(equals_form.gopls.buildFlags, {
        "-mod=readonly",
    }))

    -- before_init should load persisted context.
    local original_get = store.get

    store.get = function(requested_root)
        assert(requested_root == (vim.uv.fs_realpath(first) or first))

        return {
            tags = { "integration", "smoke" },
        }
    end

    local config = {
        root_dir = first,
        settings = {
            gopls = {
                buildFlags = { "-mod=mod" },
            },
        },
    }

    gopls.before_init({}, config)

    assert(vim.deep_equal(config.settings.gopls.buildFlags, {
        "-mod=mod",
        "-tags=integration,smoke",
    }))

    local params = {
        initializationOptions = {
            buildFlags = { "-mod=readonly", "-tags=old" },
            staticcheck = true,
        },
    }
    local empty_config = { root_dir = first }
    gopls.before_init(params, empty_config)
    assert(params.initializationOptions.staticcheck == true)
    assert(
        vim.deep_equal(
            params.initializationOptions.buildFlags,
            { "-mod=readonly", "-tags=integration,smoke" }
        )
    )
    store.get = function()
        return nil
    end
    local unchanged =
        { root_dir = first, settings = { gopls = { buildFlags = { "-tags=manual" } } } }
    gopls.before_init({}, unchanged)
    assert(unchanged.settings.gopls.buildFlags[1] == "-tags=manual")
    local notify, schedule = vim.notify, vim.schedule
    local warnings = {}
    vim.schedule = function(callback)
        callback()
    end
    vim.notify = function(message)
        warnings[#warnings + 1] = message
    end
    store.get = function()
        error("corrupt state")
    end
    gopls.before_init({}, unchanged)
    assert(#warnings == 1 and warnings[1]:match("corrupt state"))
    assert(unchanged.settings.gopls.buildFlags[1] == "-tags=manual")
    vim.notify, vim.schedule = notify, schedule
    store.get = original_get

    -- Live update must affect only clients from the requested workspace.
    local notices = {}

    local clients = {
        {
            config = { root_dir = first },
            settings = {
                gopls = {
                    buildFlags = { "-mod=mod" },
                },
            },
        },
        {
            config = { root_dir = second },
            settings = {
                gopls = {
                    buildFlags = { "-tags=other" },
                },
            },
        },
    }

    clients[3] = {
        config = { root_dir = first .. "/" },
        settings = { gopls = { buildFlags = { "-race", "-tags=old" } } },
    }
    for index, client in ipairs(clients) do
        local function notify(method, params)
            assert(method == "workspace/didChangeConfiguration")
            notices[index] = vim.deepcopy(params.settings)
            return true
        end
        client.notify = vim.fn.has("nvim-0.11") == 1
                and function(_, method, params)
                    return notify(method, params)
                end
            or notify
    end

    local original_get_clients = vim.lsp.get_clients

    vim.lsp.get_clients = function(filter)
        assert(filter.name == "gopls")
        return clients
    end

    gopls.update(first, {
        tags = { "e2e", "smoke" },
    })

    gopls.update(first, { tags = {} })
    assert(vim.deep_equal(clients[1].settings.gopls.buildFlags, { "-mod=mod" }))
    assert(vim.deep_equal(clients[3].settings.gopls.buildFlags, { "-race" }))
    -- Reapply to keep the snapshot assertions below meaningful.
    gopls.update(first, { tags = { "e2e", "smoke" } })
    clients[1].notify = function()
        return false
    end
    assert(not pcall(gopls.update, first, { tags = { "e2e", "smoke" } }))
    vim.lsp.get_clients = original_get_clients

    assert(vim.deep_equal(notices[1].gopls.buildFlags, {
        "-mod=mod",
        "-tags=e2e,smoke",
    }))

    assert(notices[2] == nil, "context leaked into another workspace")

    assert(vim.deep_equal(clients[2].settings.gopls.buildFlags, { "-tags=other" }))
end

local ok, err = xpcall(run, debug.traceback)

vim.fn.delete(dir, "rf")

if not ok then
    io.stderr:write(err .. "\n")
    vim.cmd("cquit 1")
end

print("PASS: gopls build flags and workspace isolation")
vim.cmd("qa!")
