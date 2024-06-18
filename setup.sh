#!/bin/bash


curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz
sudo rm -rf /opt/nvim
sudo tar -C /opt -xzf nvim-linux64.tar.gz

# Start tailscale
# @TODO add check
tailscale up --accept-routes --ssh --authkey $TAILSCALE_KEY

# vault settings
export VAULT_USERNAME=linuskendall

# ssh
mkdir -p $HOME/.ssh/
ln -s .ssh $HOME/.ssh/

ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -P ""

eval $(ssh-agent -s)
ssh-add ~/.ssh/id_rsa

