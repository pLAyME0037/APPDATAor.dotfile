local headline_colors = {
    "#ff757f",
    "#4fd6be",
    "#7dcfff",
    "#ff9e64",
    "#7aa2f7",
    "#c0caf5",
}

for idx, fg in ipairs(headline_colors) do
    vim.api.nvim_set_hl(0, "Headline" .. idx .. "Fg", { fg = fg, bg = "#1F2335", bold = true })
    vim.api.nvim_set_hl(0, "Headline" .. idx .. "Bg", { bg = "#1F2335" })
end

-- vim.cmd(string.format([[highlight Headline1Fg guibg=%s guifg=%s gui=bold]], "#1F2335", "#ff757f"))
-- vim.cmd(string.format([[highlight Headline2Fg guibg=%s guifg=%s gui=bold]], "#1F2335", "#4fd6be"))
-- vim.cmd(string.format([[highlight Headline3Fg guibg=%s guifg=%s gui=bold]], "#1F2335", "#7dcfff"))
-- vim.cmd(string.format([[highlight Headline4Fg guibg=%s guifg=%s gui=bold]], "#1F2335", "#ff9e64"))
-- vim.cmd(string.format([[highlight Headline5Fg guibg=%s guifg=%s gui=bold]], "#1F2335", "#7aa2f7"))
-- vim.cmd(string.format([[highlight Headline6Fg guibg=%s guifg=%s gui=bold]], "#1F2335", "#c0caf5"))

require("render-markdown").setup({
    heading = {
        sign = false,
        icons = { "󰎤 ", "󰎧 ", "󰎪 ", "󰎭 ", "󰎱 ", "󰎳 " },
        backgrounds = {
            "Headline1Bg",
            "Headline2Bg",
            "Headline3Bg",
            "Headline4Bg",
            "Headline5Bg",
            "Headline6Bg",
        },
        foregrounds = {
            "Headline1Fg",
            "Headline2Fg",
            "Headline3Fg",
            "Headline4Fg",
            "Headline5Fg",
            "Headline6Fg",
        },
    },
    code = {
        sign = false,
        width = "block",
        right_pad = 1,
    },
    bullet = {
        enabled = true,
    },
    checkbox = {
        enabled = true,
        unchecked = {
            icon = "   󰄱 ",
            highlight = "RenderMarkdownUnchecked",
            scope_highlight = nil,
        },
        checked = {
            icon = "   󰱒 ",
            highlight = "RenderMarkdownChecked",
            scope_highlight = nil,
        },
    },
})
