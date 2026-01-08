# Issues & Ideas

Stuff I'm tracking - bugs, rough edges, and things we might add later

---

## Bugs

Memory leak on buffer wipe - the cleanup for `buffer_ns_ids` and `buffer_highlight_hashes` runs on `BufDelete` but misses `BufWipeout`. In long sessions with lots of oil buffers, stale entries could pile up

Race condition in async git status ? - if the cache TTL expires while a git status call is still running, a second call can sneak in and overwrite the cache with older data. Possible ??

Windows UNC paths might break - the path splitting logic uses `[/\\]` which probably doesn't handle UNC paths like `\\server\share` correctly. Haven't tested this myself

---

## Rough Edges

Cache TTL is hardcoded - it's set to 500ms which works for most cases, but some users might want to tweak it. Should probably expose this in config

Signcolumn detection is fragile - only checks for specific patterns like `:2`, `:3`, `:4`. Could be smarter about this

---

## Ideas for Later

- staged vs unstaged differentiation
- git worktree support
- submodule status
- custom status handlers
