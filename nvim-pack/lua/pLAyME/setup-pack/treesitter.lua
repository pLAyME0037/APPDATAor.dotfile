local parser_dir = vim.fs.joinpath(vim.fn.stdpath("data"), "site")
vim.opt.runtimepath:append(parser_dir)

local ok, configs = pcall(require, "nvim-treesitter.configs")
if ok then
    configs.setup({
        parser_install_dir = parser_dir,
        highlight = {
            enable = true,
            additional_vim_regex_highlighting = false
        }
    })
end
