#!/bin/bash

# if running bash
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
        . "$HOME/.bashrc"
    fi
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi

# Install neovim
curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz
sudo rm -rf /opt/nvim
sudo tar -C /opt -xzf nvim-linux64.tar.gz
sudo mv /opt/nvim-linux64 /opt/nvim
rm -fr nvim-linux64.tar.gz

export PATH=${PATH}:/opt/nvim/bin/

# Start tailscale
if [ -n "$TAILSCALE_KEY" ]; then
  echo "TAILSCALE_KEY is set automatically connecting to tailscale"
  # check if tailscale command exists or not
    if command -v tailscale &> /dev/null
    then
         sudo tailscale up --accept-routes --ssh --authkey $TAILSCALE_KEY
    fi
fi

# vault settings
export VAULT_USERNAME=linuskendall

# ssh
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -P ""
eval $(ssh-agent -s)
ssh-add ~/.ssh/id_rsa

