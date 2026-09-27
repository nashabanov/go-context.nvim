local M = {}

local uv = vim.uv or vim.loop

function M.normalize(root)
    if not root then
        return nil
    end

    return uv.fs_realpath(root) or vim.fs.normalize(root)
end

function M.root(bufnr)
    bufnr = bufnr or 0

    local roots = {}

    for _, client in ipairs(vim.lsp.get_clients({
        bufnr = bufnr,
        name = "gopls",
    })) do
        local root = M.normalize(client.config.root_dir)

        if root then
            roots[root] = true
        end
    end

    local candidates = vim.tbl_keys(roots)

    if #candidates == 1 then
        return candidates[1]
    end

    if #candidates > 1 then
        return nil, "Multiple Go workspaces are attached to the current buffer"
    end

    local root = vim.fs.root(bufnr, { "go.work", "go.mod" })

    if not root then
        return nil, "No Go workspace found"
    end

    return M.normalize(root)
end

return M
