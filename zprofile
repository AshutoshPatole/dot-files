
# Setting PATH for Python 3.14
# The original version is saved in .zprofile.pysave
PATH="/Library/Frameworks/Python.framework/Versions/3.14/bin:${PATH}"
export PATH

export NVM_DIR="$HOME/.nvm"

# Lazy-load nvm: nvm.sh is heavy (~150-250ms); defer it until first use of
# nvm/node/npm/npx/pnpm/yarn to keep shell startup fast. Each shim unloads
# itself, loads nvm, then dispatches to the real command.
_lazy_load_nvm() {
  unfunction nvm node npm npx pnpm yarn 2>/dev/null
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion" 2>/dev/null
}
nvm()  { _lazy_load_nvm; nvm "$@"; }
node() { _lazy_load_nvm; node "$@"; }
npm()  { _lazy_load_nvm; npm "$@"; }
npx()  { _lazy_load_nvm; npx "$@"; }
pnpm() { _lazy_load_nvm; pnpm "$@"; }
yarn() { _lazy_load_nvm; yarn "$@"; }
export PATH="$HOME/develop/flutter/bin:$PATH"
export CPPFLAGS="-I/opt/homebrew/opt/openjdk/include"



# Added by Antigravity CLI installer
export PATH="/Users/ashutosh/.local/bin:$PATH"

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init.zsh 2>/dev/null || :
