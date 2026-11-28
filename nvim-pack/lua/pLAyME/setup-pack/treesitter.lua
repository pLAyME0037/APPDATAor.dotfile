local ts_pack_dir = vim.fs.joinpath(
    vim.fn.stdpath("data"),
    "site",
    "pack",
    "core",
    "opt",
    "nvim-treesitter"
)
local ts_runtime_dir = vim.fs.joinpath(ts_pack_dir, "runtime")

if vim.fn.isdirectory(ts_runtime_dir) == 1 then
    local rtp = vim.opt.runtimepath:get()
    local norm_ts_runtime = vim.fs.normalize(ts_runtime_dir)
    local vimruntime = vim.fs.normalize(vim.env.VIMRUNTIME or "")
    local has_ts_runtime = false
    for _, entry in ipairs(rtp) do
        if vim.fs.normalize(entry) == norm_ts_runtime then
            has_ts_runtime = true
            break
        end
    end
    if not has_ts_runtime then
        local inserted = false
        for idx, entry in ipairs(rtp) do
            if vim.fs.normalize(entry) == vimruntime then
                table.insert(rtp, idx, ts_runtime_dir)
                inserted = true
                break
            end
        end
        if not inserted then
            table.insert(rtp, ts_runtime_dir)
        end
        vim.opt.runtimepath = rtp
    end
end

local parser_dir = vim.fs.joinpath(vim.fn.stdpath("data"), "site")
vim.opt.runtimepath:prepend(parser_dir)

local ok_ts, ts = pcall(require, "nvim-treesitter")
if ok_ts then
    ts.setup({
        install_dir = parser_dir,
    })
end

local ts_auto_group = vim.api.nvim_create_augroup("TreesitterAutoStart", { clear = true })

vim.api.nvim_create_autocmd("FileType", {
    group = ts_auto_group,
    desc = "Auto-start treesitter highlighting for installed parsers",
    callback = function(args)
        local ft = vim.bo[args.buf].filetype
        if ft == "" then
            return
        end
        if ft == "html" then
            return
        end

        local lang = vim.treesitter.language.get_lang(ft)
        if lang == nil then
            lang = ft
        end

        local ok_add, has_lang = pcall(vim.treesitter.language.add, lang)
        if ok_add and has_lang then
            pcall(vim.treesitter.start, args.buf, lang)
        end
    end,
})
