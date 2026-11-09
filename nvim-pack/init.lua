require("pLAyME")

local ok = pcall(require, "colorscheme")
if not ok then
    vim.cmd.colorscheme("clear-as-night")
end
