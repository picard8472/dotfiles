#!/bin/bash
# SSH with automatic tmux connection, fails over to normal shell if no tmux is present
# This one liner does:
# - Checks if tmux is present
# - Attachs or connnects to tmux
# - If tmux is not present, starts a normal shell

function better_ssh()
{
    /usr/bin/ssh "$@".rpcpool.wg -t /bin/sh "command -v tmux &>/dev/null || tmux new -A -s pp || $SHELL -l"
}

function prep_vault()
{
    if [ "$PWD" != "~/git/rpcpool" ]; then
        cd ~/git/rpcpool
    fi

    # this is a ridiculously complicated issue: how to get the current source file of the program?
    # https://gist.github.com/ptc-mrucci/61772387878ed53a6c717d51a21d9371
    # i picked something that could be sort of understood and seemed to work :) -LK
    DIRNAME=$(cd "$(dirname "$BASH_SOURCE")"; cd -P "$(dirname "$(readlink "$BASH_SOURCE" || echo .)")"; pwd)

    command -v vault >/dev/null 2>&1 || { echo "Vault is not in your path. Please install or add vault location to \$PATH.  Aborting." >&2; exit 1; }

    VAULT_SSH_USERNAME=${VAULT_SSH_USERNAME:="$VAULT_USERNAME"}
    VAULT_IDENTITY_FILE=${VAULT_IDENTITY_FILE:="${HOME}/.ssh/vault-identity.pub"}

    set -euo pipefail

    if [[ -n "$VAULT_USERNAME" ]]; then
        ./vault-login.sh
    fi

    ./vault-sign-ssh-cert.sh
}

prep_vault

# Call main function
better_ssh -i ${VAULT_IDENTITY_FILE} "$@"
