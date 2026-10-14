#!/usr/bin/env bash
# scripts/lots/build-lot-7.sh — L7 CI/CD & Qualité
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" ${0:A:h}${0:A:h} pwd)"
source "${SCRIPT_DIR}/_lib.sh"

PIVOT="ats-lab/chore/ci/frontend-pipeline"
parse_common_args "$@"
log_init "L7"
require_clean_tree
checkout_branch "$PIVOT"

write_file ".github/workflows/frontend.yml" <<'EOF'
name: frontend
on:
  pull_request:
  push:
    branches: [main, "ats-lab/**"]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20, cache: npm }
      - run: npm ci
      - run: npx tsc --noEmit
      - run: npx vitest run
      - run: npx tsx scripts/quality/check-i18n-parity.ts
EOF

write_file ".github/workflows/server.yml" <<'EOF'
name: server
on:
  pull_request:
  push:
    branches: [main, "ats-lab/**"]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: "3.12" }
      - run: pip install -r requirements.txt
      - run: pytest server/tests -q
EOF

write_file "scripts/quality/check-no-pii.sh" <<'EOF'
#!/usr/bin/env bash
# L7 — refuse tout commit contenant des motifs PII dans src/ et server/.
set -euo pipefail
PATTERNS='([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-z]{2,})|(\+33|0)[1-9]([ .-]?[0-9]{2}){4}'
if git grep -nE "$PATTERNS" -- src server 2>/dev/null; then
  echo "❌ Motifs PII détectés" >&2
  exit 1
fi
echo "✅ aucun motif PII détecté"
EOF

write_file "scripts/quality/check-readonly.sh" <<'EOF'
#!/usr/bin/env bash
# L7 — vérifie qu'aucun bouton d'action n'introduit de décision automatique.
set -euo pipefail
if git grep -nEi 'onClick=.*(accept|reject|decide|validate|refuse)' -- src 2>/dev/null; then
  echo "❌ Action de décision détectée (invariant read-only)" >&2
  exit 1
fi
echo "✅ read-only respecté"
EOF

write_file "scripts/quality/run-all.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
npx tsc --noEmit
npx vitest run
npx tsx scripts/quality/check-i18n-parity.ts
bash scripts/quality/check-no-pii.sh
bash scripts/quality/check-readonly.sh
pytest server/tests -q
EOF

commit_all "chore(L7): ci/cd & qualité — pipelines + checks"

if (( ! DRY_RUN )); then
  # chmod exécutable après commit
  git -C "$REPO_ROOT" update-index --chmod=+x scripts/quality/check-no-pii.sh scripts/quality/check-readonly.sh scripts/quality/run-all.sh 2>/dev/null || true
  "${SCRIPT_DIR}/push-lot.sh" \
    --lot "$PIVOT" \
    --files ".github/workflows/ scripts/quality/" \
    --message "chore(L7): ci/cd & qualité" \
    --yes || die "push-lot.sh a échoué pour L7"
fi

ok "L7 terminé"
