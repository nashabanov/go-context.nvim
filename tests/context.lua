local root = vim.fn.fnamemodify(
    debug.getinfo(1, "S").source:sub(2),
    ":p:h:h"
)

vim.opt.rtp:prepend(root)

local context = require("go_context.context")

local function run()
    assert(vim.deep_equal(
        context.parse_tags("integration,smoke e2e"),
        { "integration", "smoke", "e2e" }
    ))

    assert(vim.deep_equal(
        context.parse_tags("integration integration,smoke"),
        { "integration", "smoke" }
    ))

    assert(vim.deep_equal(
        context.normalize({
            tags = { "integration", "smoke", "integration" },
        }),
        {
            tags = { "integration", "smoke" },
        }
    ))

    assert(vim.deep_equal(
        context.normalize({}),
        {
            tags = {},
        }
    ))

    assert(
        not pcall(context.parse_tags, "integration;rm"),
        "invalid tag should fail"
    )

    assert(
        not pcall(context.normalize, {
            tags = { "integration", "bad-tag" },
        }),
        "invalid normalized tag should fail"
    )
end

local ok, err = xpcall(run, debug.traceback)

if not ok then
    io.stderr:write(err .. "\n")
    vim.cmd("cquit 1")
end

print("PASS: context parsing and normalization")
vim.cmd("qa!")
