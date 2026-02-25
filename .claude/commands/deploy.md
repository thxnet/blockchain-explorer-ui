Build the Docker image locally and push to GHCR.

Steps:
1. Run `git submodule update --init --recursive` to ensure polkadapt submodule is checked out
2. Login to GHCR: `echo $(gh auth token) | docker login ghcr.io -u $(gh api user --jq .login) --password-stdin`
3. Build: `docker build --platform linux/amd64 -t ghcr.io/thxnet/blockchain-explorer-ui:latest -t ghcr.io/thxnet/blockchain-explorer-ui:$(git rev-parse --short HEAD) .`
4. Push both tags: `docker push ghcr.io/thxnet/blockchain-explorer-ui:latest` and `docker push ghcr.io/thxnet/blockchain-explorer-ui:$(git rev-parse --short HEAD)`
5. Verify with: `gh api orgs/thxnet/packages/container/blockchain-explorer-ui/versions --jq '.[0:3][] | {id, tags: .metadata.container.tags, created_at}'`

If push fails with "permission_denied: token does not match expected scopes", run `gh auth refresh -h github.com -s write:packages` first, then re-login and retry.
