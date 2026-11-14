local has_dotnet, dotnet = pcall(require, "easy-dotnet")
local lualine = require("lualine")

local colors = {
    color0 = "#092236",
    color1 = "#ff5874",
    color2 = "#c3ccdc",
    color3 = "#1c1e26",
    color6 = "#a1aab8",
    color7 = "#828697",
    color8 = "#ae81ff",
}

local my_lualine_theme = {
    replace = {
        a = { fg = colors.color0, bg = colors.color1, gui = "bold" },
        b = { fg = colors.color2, bg = colors.color3 },
    },
    inactive = {
        a = { fg = colors.color6, bg = colors.color3, gui = "bold" },
        b = { fg = colors.color6, bg = colors.color3 },
        c = { fg = colors.color6, bg = colors.color3 },
    },
    normal = {
        a = { fg = colors.color0, bg = colors.color7, gui = "bold" },
        b = { fg = colors.color2, bg = colors.color3 },
        c = { fg = colors.color2, bg = colors.color3 },
    },
    visual = {
        a = { fg = colors.color0, bg = colors.color8, gui = "bold" },
        b = { fg = colors.color2, bg = colors.color3 },
    },
    insert = {
        a = { fg = colors.color0, bg = colors.color2, gui = "bold" },
        b = { fg = colors.color2, bg = colors.color3 },
    },
}

local mode = {
    'mode',
    fmt = function(str)
        return ' ' .. str
    end,
}

local diff = {
    'diff',
    colored = true,
    symbols = { added = ' ', modified = ' ', removed = ' ' },
}

local filename = {
    'filename',
    file_status = true,
    path = 0,
}

local branch = {'branch', icon = {'', color={fg='#A6D4DE'}}, '|'}

local lualine_a = { mode }

if has_dotnet and dotnet.lualine then
    table.insert(lualine_a, dotnet.lualine.jobs)
end

local lualine_x = {
    { "filetype" },
    {
        function()
            if type(_G.compile_perf_component) == "function" then
                return _G.compile_perf_component()
            end
            return ""
        end,
        color = { fg = "#cba6f7" },
    },
}

if has_dotnet and dotnet.lualine then
    table.insert(lualine_x, dotnet.lualine.active_project)
    table.insert(lualine_x, {
        dotnet.lualine.run_status,
        color = dotnet.lualine.run_status_color,
        on_click = dotnet.lualine.run_status_click,
    })
end

lualine.setup({
    icons_enabled = true,
    options = {
        theme = my_lualine_theme,
        component_separators = { left = "|", right = "|" },
        section_separators = { left = "|", right = "" },
        globalstatus = true, -- Single statusline for the entire Neovim window
    },
    sections = {
        lualine_a = lualine_a,
        lualine_b = { branch },
        lualine_c = { diff, filename },
        lualine_x = lualine_x,
    }
})
