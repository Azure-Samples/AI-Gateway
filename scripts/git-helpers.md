# Git Helpers

## Excluding Files from PRs

To exclude sensitive files that shouldn't be committed:

```bash
# Add to .gitignore
echo "labs/private-connectivity/params.json" >> .gitignore

# Or exclude an already tracked file
git update-index --skip-worktree labs/private-connectivity/params.json

# To start tracking changes again
git update-index --no-skip-worktree labs/private-connectivity/params.json
```
