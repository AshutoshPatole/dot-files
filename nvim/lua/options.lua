require "nvchad.options"

-- add yours here!

-- .env* -> dotenv, OpenShift/K8s templates stay yaml
vim.filetype.add {
  filename = {
    [".env"] = "dotenv",
  },
  extension = {
    -- treat *.build files as bash globally (more reliable than pattern)
    build = "bash",
    -- treat *.env files as dotenv
    env = "dotenv",
  },
  pattern = {
    ["%.env%..*"] = "dotenv",
    ["%.env%..*%.local"] = "dotenv",
    -- fallback for paths like Makefile.build, deploy.build, etc.
    [".*%.build"] = "bash",
  },
}
