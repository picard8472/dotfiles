#!/bin/bash

# Install neovim
curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz
sudo rm -rf /opt/nvim
sudo tar -C /opt -xzf nvim-linux64.tar.gz
rm -fr nvim-linux64.tar.gz

# Start tailscale
if [ -n "$TAILSCALE_KEY" ]; then
  echo "TAILSCALE_KEY is set automatically connecting to tailscale"
  # check if tailscale command exists or not
    if command -v tailscale &> /dev/null
    then
         tailscale up --accept-routes --ssh --authkey $TAILSCALE_KEY
    fi
fi

# vault settings
export VAULT_USERNAME=linuskendall

# ssh
mkdir -p $HOME/.ssh/
ln -s .ssh $HOME/.ssh/

rm -fr ~/.ssh/id_rsa
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -P ""

eval $(ssh-agent -s)
ssh-add ~/.ssh/id_rsa

