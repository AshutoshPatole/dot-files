return {
  {
    "stevearc/conform.nvim",
    -- event = 'BufWritePre', -- uncomment for format on save
    opts = require "configs.conform",
  },

  -- These are some examples, uncomment them if you want to see them work!
  {
    "neovim/nvim-lspconfig",
    config = function()
      require "configs.lspconfig"
    end,
  },

  -- test new blink
  -- { import = "nvchad.blink.lazyspec" },

  -- AI completions: inline ghost text, always on.
  -- nvim-cmp is kept on-demand (see spec below) so the two never fight.
  {
    "monkoose/neocodeium",
    event = "VeryLazy",
    config = function()
      local function cmp_visible()
        return package.loaded.cmp and require("cmp").visible()
      end

      require("neocodeium").setup {
        filter = function(bufnr)
          local name = vim.api.nvim_buf_get_name(bufnr)
          -- never ship secrets to the windsurf server
          local secret = name:match("%.env") or name:match("%.pem$")
            or name:match("id_rsa") or name:match("%.tfvars")
          if secret then
            return false
          end
          -- stay out of the way while the cmp menu is open
          return not cmp_visible()
        end,

        filetypes = {
          help = false,
          gitcommit = false,
          gitrebase = false,
          ["."] = false,
          TelescopePrompt = false,
          ["dap-repl"] = false,
          dotenv = false,
        },
      }

      -- drop the ghost text as soon as cmp takes over
      -- (deferred so nvim-cmp still loads lazily on InsertEnter)
      vim.api.nvim_create_autocmd("InsertEnter", {
        group = vim.api.nvim_create_augroup("NeoCodeiumCmp", { clear = true }),
        once = true,
        callback = function()
          require("cmp").event:on("menu_opened", function()
            require("neocodeium").clear()
          end)
        end,
      })
    end,
  },

  -- nvim-cmp on <C-Space> instead of auto-trigger, so inline AI text and the
  -- cmp popup never overlap. Everything else keeps the NvChad defaults.
  {
    "hrsh7th/nvim-cmp",
    opts = function()
      return vim.tbl_deep_extend("force", require "nvchad.configs.cmp", {
        completion = { autocomplete = false },
      })
    end,
  },

  {
  	"nvim-treesitter/nvim-treesitter",
  	branch = "master",
  	build = ":TSUpdate",
  	opts = {
  		ensure_installed = {
  			"vim", "lua", "vimdoc",
        "html", "css",
        -- openshift / k8s yaml, python, bash, env
        "yaml", "json", "toml",
        "python", "bash", "dockerfile",
        "dotenv", "ini",
        -- terraform / hcl
        "terraform", "hcl",
  		},
  	},
  },
}
