# Dotfiles

Terminal setup: iTerm2 + tmux + vim, unified on the Catppuccin Mocha palette.

Files here are stored without the leading dot (`vimrc` → `~/.vimrc`).

## Layout

| Repo path | Installs to | What |
|---|---|---|
| `vimrc` | `~/.vimrc` | vim: Vundle plugins, catppuccin_mocha, airline |
| `zshrc` | `~/.zshrc` | zsh: oh-my-zsh, fzf/zoxide/ranger nav |
| `gitmux.conf` | `~/.gitmux.conf` | git status segment styling (required by `gitmux-seg.sh`) |
| `config/tmux/tmux.conf` | `~/.config/tmux/tmux.conf` | tmux: TPM plugins, Catppuccin, status line |
| `config/tmux/gitmux-seg.sh` | `~/.config/tmux/gitmux-seg.sh` | status-right git segment (silent outside repos) |
| `config/tmux/battery-low.sh` | `~/.config/tmux/battery-low.sh` | status-right low-battery warning (silent on desktops) |

Legacy Linux configs (`i3/`, `i3status/`, `Xdefaults`, `xinitrc`, `Xmodmap`,
`bashrc`, `bash_profile`, `ranger/`) predate this setup and are kept for reference.

## Secrets

**Nothing in this repo contains credentials, and nothing should.**

API keys, tokens, and work-specific aliases live in `~/.zshrc.local`, which
`zshrc` sources if present and which is **never committed**. To set up a new
machine, create it by hand:

```sh
cat >> ~/.zshrc.local <<'EOF'
export SOME_API_KEY=...
EOF
chmod 600 ~/.zshrc.local
```

## Bootstrap a new machine

```sh
# packages
brew install tmux fzf zoxide ranger glow gitmux git gh
brew tap raine/workmux && brew install workmux
brew install --cask font-jetbrains-mono-nerd-font

# dotfiles
git clone https://github.com/ParthGanatra/scripts-and-config-files ~/cfg
cd ~/cfg/home
cp vimrc ~/.vimrc
cp zshrc ~/.zshrc
cp gitmux.conf ~/.gitmux.conf
mkdir -p ~/.config/tmux && cp -r config/tmux/* ~/.config/tmux/
chmod +x ~/.config/tmux/*.sh

# plugin managers
git clone https://github.com/VundleVim/Vundle.vim ~/.vim/bundle/Vundle.vim
git clone https://github.com/tmux-plugins/tpm ~/.config/tmux/plugins/tpm
vim +PluginInstall +qall
tmux new-session -d && ~/.config/tmux/plugins/tpm/bin/install_plugins
```

Then in iTerm2: set the font to **JetBrainsMono Nerd Font**, and import +
select the **Catppuccin Mocha** preset under Settings → Profiles → Colors.

## Notes

- vim needs `+termguicolors` (macOS system vim 9.1 has it; no brew vim required).
- `gitmux-seg.sh` requires `~/.gitmux.conf` — without it the git segment
  silently renders empty rather than erroring.
- `battery-low.sh` is a no-op on desktops with no battery.
