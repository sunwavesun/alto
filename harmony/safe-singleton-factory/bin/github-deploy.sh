#!/usr/bin/env bash

set -euo pipefail

itemuid="${GITHUB_DEPLOY_ITEMUID:-pvct2lcpjspsvgwbh2wk3riq3m}"

usage() {
    cat <<EOF
Deploy a Safe singleton factory to a new network.

This tool wraps the NPM scripts 'estimate-compile' and 'submit' and:
1. Parses the RPC URL from a GitHub issue
2. Fetches the deployer mnemonic from 1Password
3. Automatically creates the GitHub PR for adding the deployment

USAGE
    github-deploy.sh [ISSUE]

ARGUMENTS
    ISSUE       The GitHub issue number of the 'new-chain' issue to deploy the
                Safe singleton factory for. If no issue is specified, all
                GitHub issues that are ready to deploy will be listed.

EXAMPLES
    List all issues that can be deployed:
        github-deploy.sh

    Deploy Safe singleton factory for GitHub issue #42:
        github-deploy.sh 42
EOF
}

if [[ -f .env ]]; then
    echo "ERROR: Please remove '.env' file as it interferes with this script" 1>&2
    exit 1
fi
if [[ "$(git rev-parse --abbrev-ref HEAD)" != "main" ]]; then
    echo "ERROR: Please run this script from the 'main' branch" 1>&2
    exit 1
fi
if [[ -n "$(git status --porcelain)" ]]; then
    echo "ERROR: Dirty Git index, please commit all changes before continuing" 1>&2
    exit 1
fi
if ! command -v gh &> /dev/null; then
    echo "ERROR: Please install the 'gh' GitHub CLI" 1>&2
    exit 1
fi
if ! command -v op &> /dev/null; then
    echo "ERROR: Please install the 'op' 1Password CLI" 1>&2
    exit 1
fi

issue=0
case $# in
    0)
        gh issue list --label ready-to-deploy --json number,title --jq '.[] | "• #\(.number): \(.title)"'
        exit 0
        ;;
    1)
        if ! [[ $1 =~ ^[0-9]+$ ]]; then
            echo "ERROR: $1 is not a valid GitHub issue number" 1>&2
            usage
            exit 1
        fi
        issue=$1
        ;;
    *)
        usage
        exit 1
        ;;
esac

echo "### Fetching RPC URL"
rpc="$(gh issue view $issue | grep -E -o 'https?://[^ ]+' -m 1 | head -1)"
echo "=> $rpc"

echo "### Building Deployment Transaction"
mnemonic="$(op item get "$itemuid" --field password --reveal)"
MNEMONIC="$mnemonic" RPC="$rpc" npm run -s estimate-compile
commit=1
if [[ -n "$(git status --untracked-files=no --porcelain -- artifacts/)" ]]; then
    echo "WARN: Modified an existing deployment" 1>&2
    commit=0
fi

echo "### Submitting Transaction"
if [[ $commit -eq 1 ]]; then
    RPC="$rpc" npm run -s submit
else
    echo "WARN: Cannot automatically submit, to manually submit run:" 1>&2
    echo "      RPC='$rpc' npm run submit" 1>&2
fi

echo "### Creating PR"
git checkout -b "$issue-github-deployment"
git add artifacts/
git commit -m "$(cat <<EOF
$(gh issue view $issue --json title --jq .title)

Fixes #$issue
EOF
)"
if [[ $commit -eq 1 ]]; then
    git push --set-upstream origin "$issue-github-deployment"
    gh pr create --fill --reviewer safe-global/safe-protocol
    git checkout main
    git branch -D "$issue-github-deployment"
else
    echo "WARN: Cannot automatically create PR" 1>&2
fi
