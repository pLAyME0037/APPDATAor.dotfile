local cmp = require("cmp")
local has_luasnip, luasnip = pcall(require, "luasnip")
local lspkind = require("lspkind")
local colorizer = require("tailwindcss-colorizer-cmp").formatter

local rhs = function(keys)
    return vim.keycode(keys)
end

local lsp_kinds = {
    Class         = " ",
    Color         = " ",
    Constant      = " ",
    Constructor   = " ",
    Enum          = " ",
    EnumMember    = " ",
    Event         = " ",
    Field         = " ",
    File          = " ",
    Folder        = " ",
    Function      = " ",
    Interface     = " ",
    Keyword       = " ",
    Method        = " ",
    Module        = " ",
    Operator      = " ",
    Property      = " ",
    Reference     = " ",
    Snippet       = " ",
    Struct        = " ",
    Text          = " ",
    TypeParameter = " ",
    Unit          = " ",
    Value         = " ",
    Variable      = " ",
}

local select_next_item = function(fallback)
    if cmp.visible() then
        cmp.select_next_item()
    else
        fallback()
    end
end

local select_prev_item = function(fallback)
    if cmp.visible() then
        cmp.select_prev_item()
    else
        fallback()
    end
end

local confirm = function(entry)
    local behavior = cmp.ConfirmBehavior.Replace
    if entry and entry.replace_range and entry.replace_range["end"] then
        local completion_item = entry.completion_item
        local newText = ""
        if completion_item.textEdit then
            newText = completion_item.textEdit.newText
        elseif type(completion_item.insertText) == "string" and completion_item.insertText ~= "" then
            newText = completion_item.insertText
        else
            if completion_item.word ~= nil then
                newText = completion_item.word
            else
                newText = completion_item.label
            end
        end
        local diff_after = math.max(0, entry.replace_range["end"].character + 1) - entry.context.cursor.col
        if diff_after > 0 and entry.context.cursor_after_line:sub(1, diff_after) ~= newText:sub(-diff_after) then
            behavior = cmp.ConfirmBehavior.Insert
        end
    end
    cmp.confirm({ select = true, behavior = behavior })
end

local ok, loader = pcall(require, "luasnip.loaders.from_vscode")
if ok then loader.lazy_load() end

cmp.setup({
    experimental = {
        ghost_text = false,
    },
    completion = {
        completeopt = "menu,menuone,noinsert",
    },
    window = {
        documentation = {
            border = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
        },
        completion = {
            border = { "┌", "─", "┐", "│", "┘", "─", "└", "│" },
        },
    },
    snippet = {
        expand = function(args)
            if has_luasnip then
                luasnip.lsp_expand(args.body)
            end
        end,
    },
    sources = cmp.config.sources({
        { name = "nvim_lsp", priority = 1000 },
        { name = "luasnip", priority = 750 },
        { name = "lazydev", priority = 650 },
        { name = "path", priority = 500 },
        { name = "buffer", priority = 250 },
        {
            name = "spell",
            priority = 250,
            option = {
                enable_in_context = function()
                    local ft = vim.bo.filetype
                    if ft == "markdown" then return true end
                    if ft == "text" then return true end
                    return false
                end,
            },
        },
    }),
    mapping = cmp.mapping.preset.insert({
        ["<C-e>"] = cmp.mapping.abort(),
        ["<C-d>"] = cmp.mapping(function()
            cmp.close_docs()
        end, { "i", "s" }),
        ["<C-f>"] = cmp.mapping.scroll_docs(4),
        ["<C-b>"] = cmp.mapping.scroll_docs(-4),
        ["<C-j>"] = cmp.mapping(select_next_item),
        ["<C-k>"] = cmp.mapping(select_prev_item),
        ["<C-n>"] = cmp.mapping(select_next_item),
        ["<C-p>"] = cmp.mapping(select_prev_item),
        ["<Down>"] = cmp.mapping(select_next_item),
        ["<Up>"] = cmp.mapping(select_prev_item),
        ["<C-y>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
                local entry = cmp.get_selected_entry()
                confirm(entry)
            else
                fallback()
            end
        end, { "i", "s" }),
        ["<CR>"] = cmp.mapping(function(fallback) fallback() end, { "i", "s" }),
        ["<S-Tab>"] = cmp.mapping(function(fallback) fallback() end, { "i", "s" }),
        ["<Tab>"] = cmp.mapping(function(fallback) fallback() end, { "i", "s" }),
    }),
    formatting = {
        format = function(entry, vim_item)
            local icon = lsp_kinds[vim_item.kind]
            if icon == nil then
                icon = ""
            end
            vim_item.kind = string.format("%s %s", icon, vim_item.kind)
            vim_item = lspkind.cmp_format({
                maxwidth = 25,
                ellipsis_char = "...",
            })(entry, vim_item)
            if entry.source.name == "nvim_lsp" then
                vim_item = colorizer(entry, vim_item)
            end
            return vim_item
        end,
    },
})

-- Search mode completion (/ and ?)
cmp.setup.cmdline({ "/", "?" }, {
    mapping = cmp.mapping.preset.cmdline({
        ["<C-j>"] = { c = select_next_item },
        ["<C-k>"] = { c = select_prev_item },
    }),
    sources = {
        { name = "buffer" },
    },
})

-- Command mode completion (:)
-- cmp.setup.cmdline(":", {
--     mapping = cmp.mapping.preset.cmdline({
--         ["<C-j>"] = { c = select_next_item },
--         ["<C-k>"] = { c = select_prev_item },
--     }),
--     sources = cmp.config.sources({
--         { name = "path" },
--     }, {
--         { name = "cmdline" },
--     }),
--     matching = { disallow_symbol_nonprefix_matching = false },
-- })
--
cmp.setup.filetype({ "sql", "mysql", "plsql" }, {
    sources = cmp.config.sources({
        { name = "vim-dadbod-completion" },
        { name = "buffer" },
    }),
})

