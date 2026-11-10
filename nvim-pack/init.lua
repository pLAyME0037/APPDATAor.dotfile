require("pLAyME")

vim.api.nvim_create_autocmd("UIEnter", {
    callback = function()
        local ok = pcall(require, "colorscheme")
        if not ok then
            vim.cmd.colorscheme("clear-as-night")
        end
    end,
})
