local M = {}

local reserved = {}
for tag in ([[
    aix android darwin dragonfly freebsd hurd illumos ios js linux nacl netbsd
    openbsd plan9 solaris wasip1 windows zos
    386 amd64 amd64p32 arm armbe arm64 arm64be loong64 mips mipsle mips64
    mips64le mips64p32 mips64p32le ppc ppc64 ppc64le riscv riscv64 s390 s390x
    sparc sparc64 wasm
    unix cgo gc gccgo ignore
]]):gmatch("%S+") do
    reserved[tag] = true
end

function M.buffer(bufnr)
    bufnr = bufnr or 0
    local tags, seen = {}, {}

    for index = 0, vim.api.nvim_buf_line_count(bufnr) - 1 do
        local line = vim.api.nvim_buf_get_lines(bufnr, index, index + 1, false)[1]
        if line:match("^%s*package%s") then
            break
        end

        local expression = line:match("^%s*//go:build%s+(.+)$")
        if expression then
            for start, tag in expression:gmatch("()([%w_.]+)") do
                local prefix = expression:sub(1, start - 1)
                if not prefix:match("!%s*$")
                    and not reserved[tag]
                    and not tag:match("^go1%.%d+$")
                    and not seen[tag]
                then
                    tags[#tags + 1] = tag
                    seen[tag] = true
                end
            end
        end
    end

    return tags
end

return M
