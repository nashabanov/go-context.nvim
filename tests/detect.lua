local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(root)
local detect = require("go-context.detect")

local function run()
    local buf = vim.api.nvim_create_buf(false, true)
    local cases = {
        { "", {} },
        { "integration", { "integration" } },
        { "integration && postgres", { "integration", "postgres" } },
        { "postgres && postgres", { "postgres" } },
        { "linux && windows && darwin && integration", { "integration" } },
        { "amd64 || arm64 || wasm || loong64 || custom", { "custom" } },
        { "unix", {} }, { "cgo", {} }, { "gc", {} },
        { "gccgo", {} }, { "ignore", {} },
        { "go1.23 && go1.100 && go1.custom", { "go1.custom" } },
        { "!enterprise", {} }, { "! enterprise && smoke", { "smoke" } },
        { "postgres || sqlite", { "postgres", "sqlite" } },
        { "!enterprise || enterprise", { "enterprise" } },
    }
    for _, case in ipairs(cases) do
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
            "// Header", "//go:build " .. case[1], "", "package foo",
            "//go:build after_package",
        })
        assert(vim.deep_equal(detect.buffer(buf), case[2]), case[1])
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "// +build legacy", "package foo" })
    assert(vim.deep_equal(detect.buffer(buf), {}))
    vim.api.nvim_buf_delete(buf, { force = true })
end
local ok, err = xpcall(run, debug.traceback)
if not ok then
    io.stderr:write(err .. "\n")
    vim.cmd("cquit 1")
end
print("PASS: buffer build tag detection")
vim.cmd("qa!")
