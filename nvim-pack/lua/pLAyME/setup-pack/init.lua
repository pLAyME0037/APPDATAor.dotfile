-- nvim/lua/pLAyME/setup-pack/init.lua
local dir = vim.fs.dir(vim.fs.joinpath(vim.fn.stdpath("config"),
                       "lua", "pLAyME", "setup-pack"))

for name, ftype in dir do
    if ftype == "file" and name:match("%.lua$") and name ~= "init.lua" then
        local modname = "pLAyME.setup-pack." .. name:gsub("%.lua$", "")
        pcall(require, modname)
    end
end
