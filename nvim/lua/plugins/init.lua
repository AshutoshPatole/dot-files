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
