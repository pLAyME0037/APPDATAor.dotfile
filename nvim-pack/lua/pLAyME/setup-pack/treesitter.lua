local ts_group = vim.api.nvim_create_augroup("TreesitterAutoStart", { clear = true })
vim.api.nvim_create_autocmd("FileType", {
    group = ts_group,
    desc = "Start Treesitter highlighting",
    callback = function(args)
        pcall(vim.treesitter.start, args.buf)
    end,
})

local ok, ts = pcall(require, "nvim-treesitter")
if ok and ts.setup then
    ts.setup({
        install_dir = vim.fn.stdpath("data") .. "/site",
    })
end
