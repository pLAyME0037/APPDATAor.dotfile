local M                       = {}

local colors = {
    background                = "#181825",
    background_darker         = "#11111b",
    background_highlight      = "#1e1e2e",
    foreground                = "#cdd6f4",
    foreground_muted          = "#a6adc8",
    foreground_subtle         = "#6c7086",
    selection_bg              = "#4b4e68",
    keyword                   = "#ca9ee6",
    func                      = "#b4befe",
    type                      = "#f9e2af",
    string                    = "#a6da95",
    constant                  = "#cba6f7",
    comment                   = "#6b6e82",
    variable                  = "#f2d5cf",
    operator                  = "#bac2de",
    template                  = "#eebebe",
    error                     = "#ed8796",
    warning                   = "#f5a97f",
    info                      = "#7287fd",
    success                   = "#40a02b",
    git_added                 = "#a6da95",
    git_modified              = "#ca9ee6",
    git_deleted               = "#f7768e",
}

local groups = {
    Normal                    = { fg = colors.foreground, bg = colors.background },
    NormalFloat               = { fg = colors.foreground, bg = colors.background_darker },
    Cursor                    = { fg = colors.background, bg = colors.foreground },
    CursorLine                = { bg = colors.background_highlight },
    CursorColumn              = { bg = colors.background_highlight },
    LineNr                    = { fg = colors.foreground_subtle },
    CursorLineNr              = { fg = colors.foreground_muted },
    SignColumn                = { bg = colors.background },
    ColorColumn               = { bg = colors.background_highlight },
    Folded                    = { fg = colors.func, bg = colors.foreground_subtle },
    FoldColumn                = { fg = colors.foreground_subtle },
    VertSplit                 = { fg = colors.foreground_subtle },
    Comment                   = { fg = colors.comment, italic = true },
    Constant                  = { fg = colors.constant },
    String                    = { fg = colors.string },
    Character                 = { fg = colors.string },
    Number                    = { fg = colors.constant },
    Boolean                   = { fg = colors.constant },
    Float                     = { fg = colors.constant },
    Function                  = { fg = colors.func },
    Statement                 = { fg = colors.keyword },
    Keyword                   = { fg = colors.keyword },
    Special                   = { fg = colors.keyword },
    Type                      = { fg = colors.type },
    TemplateStringPlaceholder = { fg = colors.template },
    Exception                 = { fg = colors.template },
    Typedef                   = { fg = colors.template },
    Operator                  = { fg = colors.operator },
    Identifier                = { fg = colors.variable },
    Conditional               = { fg = colors.keyword },
    Repeat                    = { fg = colors.keyword },
    Label                     = { fg = colors.keyword },
    Include                   = { fg = colors.keyword },
    Define                    = { fg = colors.keyword },
    Macro                     = { fg = colors.keyword },
    PreCondit                 = { fg = colors.keyword },
    StorageClass              = { fg = colors.type },
    Structure                 = { fg = colors.type },
    SpecialChar               = { fg = colors.string },
    Tag                       = { fg = colors.type },
    Delimiter                 = { fg = colors.foreground },
    SpecialComment            = { fg = colors.comment, italic = true },
    Debug                     = { fg = colors.warning },
    PreProc                   = { fg = colors.keyword },
    DiagnosticError           = { fg = colors.error },
    DiagnosticWarn            = { fg = colors.warning },
    DiagnosticInfo            = { fg = colors.info },
    DiagnosticHint            = { fg = colors.success },
    DiagnosticUnderlineError  = { sp = colors.error, undercurl = true },
    DiagnosticUnderlineWarn   = { sp = colors.warning, undercurl = true },
    DiagnosticUnderlineInfo   = { sp = colors.info, undercurl = true },
    DiagnosticUnderlineHint   = { sp = colors.success, undercurl = true },
    GitSignsAdd               = { fg = colors.git_added },
    GitSignsChange            = { fg = colors.git_modified },
    GitSignsDelete            = { fg = colors.git_deleted },

    -- Tree-sitter: Variables & Members
    ["@variable"]             = { fg = colors.variable },
    ["@variable.builtin"]     = { link = "Special" },
    ["@variable.parameter"]   = { fg = colors.template },
    ["@parameter"]            = { link = "@variable.parameter" },
    ["@variable.member"]      = { fg = colors.operator },       -- struct fields: point.x, ptr->y
    ["@property"]             = { link = "@variable.member" },

    -- Tree-sitter: Functions
    ["@function"]             = { fg = colors.func },
    ["@function.call"]        = { fg = colors.func },
    ["@function.builtin"]     = { fg = colors.func, italic = true },
    ["@function.macro"]       = { fg = colors.func },

    -- Tree-sitter: Types (C typedefs, primitives, qualifiers)
    ["@type"]                 = { fg = colors.type },
    ["@type.builtin"]         = { fg = colors.type },           -- int, char, void, size_t
    ["@type.definition"]      = { fg = colors.type },
    ["@type.qualifier"]       = { fg = colors.keyword },        -- const, static, volatile

    -- Tree-sitter: Keywords & Directives (C Preprocessor)
    ["@keyword"]              = { fg = colors.keyword },
    ["@keyword.directive"]    = { fg = colors.keyword },        -- #include, #ifdef, #endif
    ["@keyword.directive.define"] = { fg = colors.keyword },    -- #define
    ["@keyword.conditional"]  = { fg = colors.keyword },
    ["@keyword.repeat"]       = { fg = colors.keyword },
    ["@keyword.return"]       = { fg = colors.keyword, italic = true },
    ["@keyword.type"]         = { fg = colors.type },

    -- Tree-sitter: Constants & Literals
    ["@constant"]             = { fg = colors.constant },
    ["@constant.builtin"]     = { fg = colors.constant },       -- NULL, true, false
    ["@constant.macro"]       = { fg = colors.constant },       -- UPPER_CASE macros
    ["@string"]               = { fg = colors.string },
    ["@string.escape"]        = { fg = colors.template },       -- \n, \t
    ["@number"]               = { fg = colors.constant },
    ["@boolean"]              = { fg = colors.variable },

    -- Tree-sitter: Operators & Delimiters
    ["@operator"]             = { fg = colors.operator },
    ["@punctuation.delimiter"]= { fg = colors.foreground_muted },
    ["@punctuation.bracket"]  = { fg = colors.foreground_muted },
    ["@punctuation.special"]  = { fg = colors.operator },

    -- Tree-sitter: Comments
    ["@comment"]              = { fg = colors.comment, italic = true },
    ["@comment.documentation"]= { fg = colors.comment, italic = true },

    -- LSP Semantic Tokens (Applied when clangd attaches)
    ["@lsp.type.class"]       = { link = "@type" },
    ["@lsp.type.type"]        = { link = "@type" },
    ["@lsp.type.function"]    = { link = "@function" },
    ["@lsp.type.macro"]       = { link = "@constant.macro" },
    ["@lsp.type.parameter"]   = { link = "@variable.parameter" },
    ["@lsp.type.property"]    = { link = "@property" },
    ["@lsp.type.variable"]    = { link = "@variable" },
}

function M.setup()
    vim.cmd("highlight clear")
    if vim.fn.exists("syntax_on") == 1 then
        vim.cmd("syntax reset")
    end

    vim.g.colors_name = "clear-as-night"

    for group, settings in pairs(groups) do
        vim.api.nvim_set_hl(0, group, settings)
    end

    vim.defer_fn(function()
        for group, settings in pairs(groups) do
            vim.api.nvim_set_hl(0, group, settings)
        end
    end, 100)
end

-- Must call M.setup() directly so :colorscheme runs it on source
M.setup()

return M
