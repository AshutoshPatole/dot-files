require("nvchad.configs.lspconfig").defaults()

local servers = { "html", "cssls", "yaml-language-server", "pyright", "bashls", "terraformls", "tflint" }

-- OpenShift / Kubernetes YAML
local yaml_config = {
  cmd = { "yaml-language-server", "--stdio" },
  filetypes = { "yaml", "yaml.docker-compose", "yaml.gitlab", "yaml.helm-values" },
  root_markers = { ".git" },
  settings = {
    redhat = { telemetry = { enabled = false } },
    yaml = {
      validate = true,
      hover = true,
      completion = true,
      format = { enable = false }, -- use conform/prettier instead
      schemas = {
        -- Kubernetes + OpenShift (both are k8s-style manifests)
        ["https://raw.githubusercontent.com/yannh/kubernetes-json-schema/master/v1.32.2-standalone-strict/all.json"] = {
          "*.k8s.yaml",
          "*.k8s.yml",
          "deployment*.yaml",
          "deployment*.yml",
          "service*.yaml",
          "route*.yaml",
          "dc*.yaml",
          "bc*.yaml",
          "is*.yaml",
          "templates/*.yaml",
          "openshift/*.yaml",
          "openshift/*.yml",
          "k8s/*.yaml",
        },
        -- GitHub workflows, etc. still validate generically
        ["https://json.schemastore.org/github-workflow.json"] = ".github/workflows/*",
      },
      -- tolerate CloudFormation / Tekton / OpenShift custom tags
      customTags = {
        "!And",
        "!If",
        "!Not",
        "!Equals",
        "!Or",
        "!FindInMap sequence",
        "!Base64",
        "!Cidr",
        "!Ref",
        "!Sub",
        "!GetAtt",
        "!GetAZs",
        "!ImportValue",
        "!Select",
        "!Split",
        "!Join sequence",
      },
    },
  },
}

vim.lsp.config("yaml-language-server", yaml_config)
vim.lsp.config("yamlls", yaml_config)

-- Python
vim.lsp.config("pyright", {
  settings = {
    python = {
      analysis = {
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
        diagnosticMode = "openFilesOnly",
        typeCheckingMode = "basic",
      },
    },
  },
})

-- Bash + .env (bashls also attaches to .env when filetype allows)
vim.lsp.config("bashls", {
  filetypes = { "sh", "bash", "zsh" },
  settings = {
    bashIde = {
      shellcheckPath = "",
      globPattern = "*@(.sh|.inc|.bash|.command|.build|.env|.env.*)",
    },
  },
})

-- Terraform: terraform-ls for intelligence, tflint for linting
-- (both attach to *.tf; terraform-vars covers *.tfvars)
vim.lsp.config("terraformls", {
  filetypes = { "terraform", "terraform-vars" },
  root_markers = { ".terraform", ".git" },
})

vim.lsp.enable(servers)

-- read :h vim.lsp.config for changing options of lsp servers 
