return {
  -- 1. Core Copilot Plugin
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    event = "InsertEnter",
    config = function()
      require("copilot").setup({
        panel = {
          enabled = false,
        },
        suggestion = {
          enabled = true,
          auto_trigger = false, -- Disables auto-suggestions
          keymap = {
            -- You still need a key to *accept* the suggestion once it appears
            accept = "<Tab>", 
            accept_word = false,
            accept_line = false,
            next = "<M-]>",
            prev = "<M-[>",
            dismiss = "<C-]>",
          },
        },
      })

      -- Keybind to manually trigger the suggestion in Insert mode
      vim.keymap.set("i", "<M-s>", function()
        require("copilot.suggestion").next()
      end, { desc = "Trigger Copilot Suggestion" })
    end,
  },

  -- 2. Copilot Chat (for the visual block prompting)
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    dependencies = {
      { "zbirenbaum/copilot.lua" }, -- Or github/copilot.vim
      { "nvim-lua/plenary.nvim", branch = "master" }, -- For curl, log wrapper
    },
    build = "make tiktoken", -- Only necessary on MacOS/Linux
    config = function(_, opts)
      local chat = require("CopilotChat")
      chat.setup(opts)

      -- Create the custom :Csb command for visual mode
      vim.api.nvim_create_user_command("Csb", function(args)
        chat.ask(args.args, { 
          selection = require("CopilotChat.select").visual 
        })
      end, { 
        nargs = "*", 
        range = true, 
        desc = "Copilot Suggest Block (Visual)" 
      })

      -- Abbreviation to allow lowercase `:csb` to trigger `:Csb`
      vim.cmd([[cnoreabbrev <expr> csb getcmdtype() == ":" && getcmdline() == "csb" ? "Csb" : "csb"]])
    end,
  },
}
