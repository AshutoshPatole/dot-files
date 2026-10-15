local options = {
  formatters_by_ft = {
    lua = { "stylua" },
    -- css = { "prettier" },
    -- html = { "prettier" },
    -- OpenShift / K8s YAML
    yaml = { "prettier", "yamlfmt", stop_after_first = true },
    yml = { "prettier", "yamlfmt", stop_after_first = true },
    json = { "prettier", stop_after_first = true },
    toml = { "taplo", stop_after_first = true },
    -- Python (prefer ruff_format, fall back to black)
    python = { "ruff_format", "black", stop_after_first = true },
    -- Bash / shell + .env (shfmt handles shell; dotenv has no real formatter)
    sh = { "shfmt" },
    bash = { "shfmt" },
    dotenv = {},
    -- Terraform (runs `terraform fmt`)
    terraform = { "terraform_fmt" },
  },

  -- format_on_save = {
  --   -- These options will be passed to conform.format()
  --   timeout_ms = 500,
  --   lsp_fallback = true,
  -- },
}

return options
