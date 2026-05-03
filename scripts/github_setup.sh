#!/usr/bin/env bash
# github_setup.sh — initialize and push gladys to GitHub via SSH
#
# Prerequisites:
#   1. Create the repo manually at https://github.com/new
#      - Name: gladys
#      - Description: Personality-aware governance for the booLang CIC float pipeline
#      - Public, no README (we have one), no .gitignore (we have one)
#   2. Run this script — SSH key is already configured and verified
#
# Usage: bash scripts/github_setup.sh

set -euo pipefail

REPO_ROOT="/Volumes/TOSHIBA EXT/projects/gladys"
GITHUB_USER="coy247"
REPO_NAME="gladys"
SSH_REMOTE="git@github.com:${GITHUB_USER}/${REPO_NAME}.git"

cd "$REPO_ROOT"

echo "═══════════════════════════════════════════════════════"
echo "  Gladys — GitHub Setup (SSH)"
echo "═══════════════════════════════════════════════════════"

# ── 1. Verify SSH key works ───────────────────────────────
echo "→ Verifying SSH key..."
SSH_CHECK=$(ssh -T git@github.com \
  -i "/Volumes/Macintosh NVMe/edgarzaro/.ssh/id_ed25519_work" \
  -o StrictHostKeyChecking=no \
  -o BatchMode=yes 2>&1 || true)
if echo "$SSH_CHECK" | grep -q "successfully authenticated"; then
  echo "  ✓ SSH authenticated as coy247"
else
  echo "  ✗ SSH check failed: $SSH_CHECK"
  exit 1
fi

# ── 2. Scan for secrets ───────────────────────────────────
echo "→ Scanning for secrets..."
SECRET_HITS=$(grep -rn \
  "password\|private_key\|api_key\|mnemonic\|seed_phrase\|wallet_address" \
  --include="*.ts" --include="*.boo" --include="*.json" --include="*.md" \
  --exclude-dir=node_modules --exclude-dir=.claude \
  . 2>/dev/null | grep -v "example\|placeholder\|policy\|anchor\|reporting" | wc -l | tr -d ' ')
if [ "$SECRET_HITS" -gt 0 ]; then
  echo "  ✗ Potential secrets found — review before pushing:"
  grep -rn "password\|private_key\|api_key\|mnemonic\|seed_phrase\|wallet_address" \
    --include="*.ts" --include="*.boo" --include="*.json" \
    --exclude-dir=node_modules --exclude-dir=.claude .
  exit 1
fi
echo "  ✓ No secrets detected"

# ── 3. git init ───────────────────────────────────────────
if [ ! -d ".git" ]; then
  echo "→ Initializing git repository..."
  git init
  git branch -M main
else
  echo "  git already initialized ($(git branch --show-current))"
fi

# ── 4. Stage tracked files ────────────────────────────────
echo "→ Staging files..."
git add README.md LICENSE CONTRIBUTING.md SECURITY.md .gitignore deno.json
git add compiler/personality_types.boo
git add compiler/tm_twigs.boo
git add compiler/math_governor.boo
git add src/personality_types.boo.ts
git add src/tm_twigs.boo.ts
git add src/personality_governor.boo.ts
git add src/math_governor.boo.ts
git add .github/ISSUE_TEMPLATE/bug_report.md
git add .github/ISSUE_TEMPLATE/feature_request.md
git add .github/pull_request_template.md
git add scripts/github_setup.sh

echo "  Staged:"
git status --short

# ── 5. Initial commit ─────────────────────────────────────
if git log --oneline -1 &>/dev/null; then
  echo "  commit already exists — skipping"
else
  echo "→ Creating initial commit..."
  git commit -m "$(cat <<'COMMITMSG'
Initial release — personality-aware booLang governance system

Three native .boo compiler files (personality_types, tm_twigs, math_governor)
plus TypeScript reference implementations. 16 MBTI types reduced to 8 base
types + isExtrovert boolean; population-weighted signal drives governance
modifiers across treasury, game, and mining domains.

Gladys is INTJ-A, typeIndex=7, always the default anchor.
COMMITMSG
)"
fi

# ── 6. Set remote and push ────────────────────────────────
echo "→ Setting remote: $SSH_REMOTE"
if git remote get-url origin &>/dev/null; then
  git remote set-url origin "$SSH_REMOTE"
else
  git remote add origin "$SSH_REMOTE"
fi

echo "→ Pushing to GitHub..."
GIT_SSH_COMMAND="ssh -i /Volumes/Macintosh\ NVMe/edgarzaro/.ssh/id_ed25519_work -o StrictHostKeyChecking=no" \
  git push -u origin main

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Done."
echo "  https://github.com/${GITHUB_USER}/${REPO_NAME}"
echo "═══════════════════════════════════════════════════════"
