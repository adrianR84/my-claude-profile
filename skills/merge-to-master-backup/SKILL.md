---
name: merge-to-master-backup
description: Merge the current branch into master with a timestamped backup tag, or restore master from a backup tag. Triggers when the user asks to merge to master, backup a branch, or restore from a backup tag.
disable-model-invocation: true
---

## Option: backup (default)

Runs when the user says "merge to master", "backup", or doesn't specify an option.

### Before you start

- **You must be on a branch other than `master`** — if already on `master`, abort and tell the user.
- **Warn about uncommitted changes** — if `git status` shows any uncommitted files, stop and ask the user to commit or stash them first. Do not proceed with uncommitted changes.

### Step 1 — Create the backup tag

```bash
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
DATE=$(date +%Y%m%d)
BASE_TAG="backup-before-${CURRENT_BRANCH}-${DATE}"

# If the user provided a custom suffix, append it; otherwise append a counter if the tag already exists
if [ -n "USER_TAG_SUFFIX" ]; then
  TAG_NAME="${BASE_TAG}-${USER_TAG_SUFFIX}"
else
  TAG_NAME="$BASE_TAG"
  COUNTER=1
  while git rev-parse -q --verify "refs/tags/$TAG_NAME" >/dev/null 2>&1; do
    TAG_NAME="${BASE_TAG}-${COUNTER}"
    COUNTER=$((COUNTER + 1))
  done
fi

git tag "$TAG_NAME"
echo "Created tag: $TAG_NAME"
```

- If the user provided a custom suffix (e.g. "v2" or "hotfix-login"), append it directly to the tag name.
- If no suffix was given and the base tag already exists, auto-append a counter (`-1`, `-2`, …) until an unused name is found.
- The tag is a lightweight tag pointing to master's current commit.

### Step 2 — Switch to master and merge

```bash
git checkout master
git merge "$CURRENT_BRANCH"
```

### Step 3 — Check for conflicts

After the merge, check `git status` or look for `U` (unmerged) entries in `git diff --name-status --diff-filter=U`.

**If there are NO conflicts**, proceed to Step 4 (Ask about pushing).

**If there ARE conflicts**, report them and present choices. Run:

```bash
git diff --name-status --diff-filter=U
git diff --numstat --diff-filter=U
```

Then tell the user:

> "Merge conflicts detected in the following files:
> - (list files)
>
> How would you like to resolve them?
>
> **1 (recommended)** — Abort the merge and keep your current branch as-is. You can resolve conflicts there and try again.
> **2** — Keep master's version (ours) for all conflicting files. The branch changes for those files will be lost.
> **3** — Keep the branch's version (theirs) for all conflicting files. Master's changes for those files will be lost.
> **4** — Open the conflicted files in your editor so you can resolve them manually. (You'll need to run `git add` and `git commit` when done, then say 'done' to continue.)
> **5** — Walk through each conflict one by one. I'll show each conflicted file and its diff, ask which version to keep, and stage it immediately. Progress is shown as you go.
>
> Which option do you want? (1/2/3/4/5)

After each **Option 5** file is resolved, `git add` the file. After all files are resolved, `git commit` to complete the merge, then continue to Step 4.

Wait for the user's reply, then:

- **Option 1 (abort)**: `git merge --abort`, then report "Merge aborted. Your branch is unchanged."
- **Option 2 (ours)**: `git checkout --ours -- .` (or specify conflicted files), `git add -A`, `git commit -m "Merge $CURRENT_BRANCH — resolved with ours"`, then continue to Step 4.
- **Option 3 (theirs)**: `git checkout --theirs -- .` (or specify conflicted files), `git add -A`, `git commit -m "Merge $CURRENT_BRANCH — resolved with theirs"`, then continue to Step 4.
- **Option 4 (manual)**: Tell the user "Open the conflicted files in your editor. When you've resolved all conflicts and committed (git add + git commit), say 'done' and I'll ask about pushing."
- **Option 5 (one-by-one)**: First capture the full list of conflicted files into a variable. Then loop through them one by one, showing progress (e.g. "Conflict 1 of N: `<filename>`"). For each file:
  1. Show `git diff BASE OURS THEIRS` (3-way view)
  2. Ask: "Choose: **(o)urs** — keep master's version, **(t)heirs** — keep branch's version, **(s)kip** — leave unresolved for later?"
  3. Run `git checkout --ours -- <filename>` or `git checkout --theirs -- <filename>` based on choice
  4. Run `git add <filename>` to stage the resolved file
  5. Continue to next file
  After all files are processed (or skipped), `git commit` to complete the merge if no unresolved files remain, otherwise tell the user they need to resolve the remaining ones manually before the merge can complete.

### Step 4 — Ask about pushing

After the merge (and any conflict resolution) completes, ask the user:

> "Merge complete. Push master and the backup tag `TAG_NAME` to origin? (yes/no)"

- **yes**: `git push origin master TAG_NAME`
- **no**: show the tag name so they can push later if needed

---

## Option: restore

Runs when the user says "restore" or "restore from backup".

### Before you start

- **You must be on `master`** — if not on master, abort and tell the user to switch to master first.
- **Warn about uncommitted changes** — if `git status` shows any uncommitted files, stop and ask the user to commit or stash them first.

### Step 1 — List available backup tags

```bash
git tag -l "backup-before-*"
```

Show the list to the user and ask:

> "Which backup tag do you want to restore? (copy the exact tag name)"

Wait for their reply.

### Step 2 — Reset master to the backup tag

```bash
git reset --hard TAG_NAME
```

### Step 3 — Ask about pushing

After the reset, ask the user:

> "Restore complete. Force-push master to origin? This will overwrite the remote history. (yes/no)"

- **yes**: `git push --force origin master`
- **no**: show the current commit so they can push later if needed
