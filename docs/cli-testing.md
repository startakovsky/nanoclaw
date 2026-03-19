# CLI Testing Guide

## Prerequisites

1. The nanoclaw service must be running (launchd or `npm run dev`)
2. The SQLite database must exist at `store/messages.db`
3. You're on the `feature/interactive-cli` branch

```bash
cd ~/code/nanoclaw
git checkout feature/interactive-cli
npm run build
```

## Test Matrix

### Test 1: One-shot message (backward compat)

```bash
./scripts/cli.sh "what time is it?"
```

**Expected behavior:**
- Prints: `Message sent. Watch logs: tail -f .../logs/nanoclaw.log`
- Exits immediately (does NOT wait for a response)
- Message is inserted into SQLite under `cli:main` group
- The launchd service picks it up and processes it

**Verify it landed:**
```bash
sqlite3 store/messages.db "SELECT id, content, chat_jid FROM messages ORDER BY timestamp DESC LIMIT 1;"
```
You should see your message with `chat_jid = cli:main`.

---

### Test 2: Interactive REPL (no arguments — prod)

```bash
./scripts/cli.sh
```

**Expected behavior:**
- Prints banner: `NanoClaw CLI — talking to cli:main`
- Prints: `Type a message and press Enter. Ctrl+D to exit.`
- Shows `You: ` prompt
- Type a message, press Enter
- CLI polls SQLite every 1s waiting for a bot response
- When the service responds, prints: `Andy: <response>`
- Shows `You: ` prompt again for next message
- Ctrl+D exits cleanly
- Empty lines are ignored (just re-prompts)
- If no response after 120s, prints timeout message and re-prompts

**Try these inputs:**
```
You: hello
You:                          ← (empty, should be ignored)
You: what's 2 + 2?
You: <Ctrl+D>                ← exits
```

---

### Test 3: Interactive REPL with group argument (dev)

**First, register the dev group (one-time):**
```bash
./scripts/register-dev-group.sh
```

**Expected:** Prints `Registered cli:dev group.` (or `cli:dev group is already registered.` if re-run).

**Then start the dev REPL:**
```bash
./scripts/cli.sh cli:dev
```

**Expected behavior:**
- Prints banner: `NanoClaw CLI — talking to cli:dev`
- Otherwise identical to Test 2
- Messages go to the `cli:dev` group (separate history from `cli:main`)
- The agent uses `groups/dev/CLAUDE.md` instructions

**Verify isolation — messages should be in different groups:**
```bash
sqlite3 store/messages.db "SELECT chat_jid, content FROM messages WHERE sender='cli:user' ORDER BY timestamp DESC LIMIT 5;"
```

---

### Test 4: Bot response storage (the core new feature)

After sending any message in interactive mode and getting a response:

```bash
sqlite3 store/messages.db "SELECT id, sender, content, is_bot_message FROM messages WHERE is_bot_message=1 ORDER BY timestamp DESC LIMIT 3;"
```

**Expected:** You should see rows with:
- `id` starting with `bot-`
- `sender` = `Andy`
- `is_bot_message` = `1`
- `content` = the response the agent gave you

This is the key change — previously bot responses were NOT stored.

---

### Test 5: Special characters in messages

```bash
# One-shot with quotes
./scripts/cli.sh "it's a test with 'quotes'"

# Interactive — type these at the prompt:
You: what's the deal with "quotes"?
You: how about $variables and $(commands)?
```

**Expected:** Messages should be stored correctly without SQL errors. Single quotes are escaped via `sed`.

---

### Test 6: Error cases

```bash
# No database
mv store/messages.db store/messages.db.bak
./scripts/cli.sh "test"
# Expected: "Error: Database not found..."

mv store/messages.db.bak store/messages.db
```

---

## Quick smoke test (copy-paste)

```bash
# 1. One-shot
./scripts/cli.sh "smoke test one-shot"

# 2. Verify it landed
sqlite3 store/messages.db "SELECT content FROM messages WHERE content LIKE '%smoke test%';"

# 3. Interactive (Ctrl+D to exit after one exchange)
./scripts/cli.sh

# 4. Check bot responses are stored
sqlite3 store/messages.db "SELECT id, content FROM messages WHERE is_bot_message=1 ORDER BY timestamp DESC LIMIT 1;"

# 5. Dev group
./scripts/register-dev-group.sh
./scripts/cli.sh cli:dev
```
