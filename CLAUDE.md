# home-ops — instructions for Claude Code sessions

## Shared checkout: never do branch work here

Multiple Claude sessions (and the user) run against this one clone
concurrently. Git branch, index, and working-tree state are per-checkout, not
per-session — a `git checkout` in one session silently moves HEAD under every
other session, and commits pick up whatever happens to be in the shared index.
This has caused real cross-contaminated commits.

Rules for the main checkout (`G:\git\home-ops`):

- **Never** run `git commit`, `checkout`, `switch`, `reset`, `rebase`, or
  `merge` in it. It stays on `main` and only ever moves by `git pull`.
- For ANY branch work, first enter an isolated worktree — use the
  EnterWorktree tool, or create one manually in the session scratchpad:

  ```
  git -C G:\git\home-ops worktree add <scratchpad>\wt-<topic> -b <branch> origin/main
  ```

  Edit, commit, and push from the worktree, then remove it
  (`git worktree remove <path>`) once the PR is open.
- Never leave uncommitted changes sitting in the shared tree. If you find
  foreign dirty files or an unexpected branch there, another session is
  mid-flight: leave its state alone and say so instead of "fixing" it.
- If SSH to github.com:22 times out, push to the
  `https://github.com/Malpractis/home-ops.git` URL directly — the gh
  credential helper handles auth.

## Commit style

Conventional Commits (`type(scope):`) on every commit; PRs are opened with
`gh pr create` and merged by the user, not by sessions.
