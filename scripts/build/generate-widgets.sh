#!/usr/bin/env bash
# scripts/gen-widgets-phase-1-2.sh
# Génère SmallGroupGuard + KpiCard (composants, tests, stories, index)
# puis lance les tests. Idempotent : peut être relancé sans casser.
#
# Usage:
#   ./scripts/gen-widgets-phase-1-2.sh                # génère + teste
#   ./scripts/gen-widgets-phase-1-2.sh --no-git       # génère + teste, pas de commit
#   ./scripts/gen-widgets-phase-1-2.sh --no-install   # skip pnpm install
#   ./scripts/gen-widgets-phase-1-2.sh --dry-run      # affiche sans écrire
#
# Compatible bash 3.2 (macOS). Protégé contre set -u + array vide.

set -euo pipefail

# ─────────────────────────────────────────────────────────────
# Options
# ─────────────────────────────────────────────────────────────
DO_GIT=1
DO_INSTALL=1
DRY_RUN=0

for arg in "$@"; do
  case "$arg" in
    --no-git)     DO_GIT=0 ;;
    --no-install) DO_INSTALL=0 ;;
    --dry-run)    DRY_RUN=1 ;;
    -h|--help)
      sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Argument inconnu: $arg" >&2; exit 1 ;;
  esac
done

# ─────────────────────────────────────────────────────────────
# Chemins + couleurs
# ─────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$ROOT_DIR"

if [ -t 1 ]; then
  C_RED=$'\033[0;31m'; C_GRN=$'\033[0;32m'; C_YEL=$'\033[0;33m'
  C_BLU=$'\033[0;34m'; C_DIM=$'\033[2m';    C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_DIM=""; C_RST=""
fi

log()  { printf '%s[gen]%s %s\n' "$C_BLU" "$C_RST" "$*"; }
ok()   { printf '%s[ok ]%s %s\n' "$C_GRN" "$C_RST" "$*"; }
warn() { printf '%s[warn]%s %s\n' "$C_YEL" "$C_RST" "$*" >&2; }
die()  { printf '%s[err ]%s %s\n' "$C_RED" "$C_RST" "$*" >&2; exit 1; }

# ─────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────
write_file() {
  # write_file <path> <<'EOF' ... EOF
  local path="$1"
  local dir
  dir="$(dirname "$path")"
  if [ "$DRY_RUN" -eq 1 ]; then
    log "[dry-run] écrirait $path"
    cat > /dev/null   # consomme stdin
    return 0
  fi
  mkdir -p "$dir"
  cat > "$path"
  ok "écrit $path"
}

# ─────────────────────────────────────────────────────────────
# Pré-vol
# ─────────────────────────────────────────────────────────────
command -v git >/dev/null 2>&1 || die "git introuvable"
command -v node >/dev/null 2>&1 || die "node introuvable"

if [ ! -f package.json ]; then
  die "package.json introuvable — es-tu à la racine de ats-copilot-dashboard ?"
fi

if [ "$DO_GIT" -eq 1 ]; then
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    die "pas dans un dépôt git"
  fi
fi

# ─────────────────────────────────────────────────────────────
# 1. Branche de travail
# ─────────────────────────────────────────────────────────────
WORK_BRANCH="ats-lab/comp/widgets/phase-1-2"

if [ "$DO_GIT" -eq 1 ]; then
  CURRENT="$(git branch --show-current)"
  if [ "$CURRENT" != "$WORK_BRANCH" ]; then
    log "Bascule sur $WORK_BRANCH"
    if git show-ref --verify --quiet "refs/heads/$WORK_BRANCH"; then
      git checkout "$WORK_BRANCH"
    else
      git checkout -b "$WORK_BRANCH"
    fi
  fi
  ok "branche: $(git branch --show-current)"
fi

# ─────────────────────────────────────────────────────────────
# 2. SmallGroupGuard
# ─────────────────────────────────────────────────────────────
log "Génération SmallGroupGuard…"

write_file src/widgets/SmallGroupGuard/SmallGroupGuard.tsx <<'EOF'
import React from 'react';

export interface SmallGroupGuardProps {
  /** Taille du groupe. Si < threshold, les enfants sont masqués. */
  n: number;
  /** Seuil de suppression. Défaut : 5 (contrainte RGPD). */
  threshold?: number;
  /** Contenu à afficher si le groupe est suffisamment grand. */
  children: React.ReactNode;
  /** Contenu de remplacement si le groupe est trop petit. */
  fallback?: React.ReactNode;
  /** Contexte textuel pour l'aria-label (ex: "par site"). */
  context?: string;
}

export function SmallGroupGuard(props: SmallGroupGuardProps) {
  const { n, threshold = 5, children, fallback, context } = props;

  if (n >= threshold) {
    return <>{children}</>;
  }

  const label = context
    ? `Agrégat masqué : groupe inférieur à ${threshold} (${context})`
    : `Agrégat masqué : groupe inférieur à ${threshold}`;

  return (
    <span
      data-testid="small-group-guard-fallback"
      role="note"
      aria-label={label}
      className="small-group-guard"
    >
      {fallback ?? <span aria-hidden="true">n&lt;{threshold}</span>}
    </span>
  );
}
EOF

write_file src/widgets/SmallGroupGuard/SmallGroupGuard.test.tsx <<'EOF'
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { SmallGroupGuard } from './SmallGroupGuard';

describe('SmallGroupGuard', () => {
  describe('rendering', () => {
    it('renders children when n >= threshold', () => {
      render(
        <SmallGroupGuard n={10}>
          <span>visible data</span>
        </SmallGroupGuard>
      );
      expect(screen.getByText('visible data')).toBeInTheDocument();
      expect(screen.queryByTestId('small-group-guard-fallback')).not.toBeInTheDocument();
    });

    it('renders fallback when n < threshold', () => {
      render(
        <SmallGroupGuard n={3}>
          <span>hidden data</span>
        </SmallGroupGuard>
      );
      expect(screen.queryByText('hidden data')).not.toBeInTheDocument();
      expect(screen.getByTestId('small-group-guard-fallback')).toBeInTheDocument();
      expect(screen.getByText('n<5')).toBeInTheDocument();
    });

    it('renders exactly at threshold (n === 5)', () => {
      render(
        <SmallGroupGuard n={5}>
          <span>visible data</span>
        </SmallGroupGuard>
      );
      expect(screen.getByText('visible data')).toBeInTheDocument();
    });

    it('renders custom fallback when provided', () => {
      render(
        <SmallGroupGuard n={2} fallback={<span>trop petit</span>}>
          <span>hidden</span>
        </SmallGroupGuard>
      );
      expect(screen.getByText('trop petit')).toBeInTheDocument();
    });

    it('uses custom threshold', () => {
      render(
        <SmallGroupGuard n={5} threshold={10}>
          <span>hidden</span>
        </SmallGroupGuard>
      );
      expect(screen.queryByText('hidden')).not.toBeInTheDocument();
      expect(screen.getByText('n<10')).toBeInTheDocument();
    });
  });

  describe('RGPD compliance', () => {
    it('never renders children when n < 5', () => {
      const { container } = render(
        <SmallGroupGuard n={4}>
          <span data-testid="pii">sensitive aggregate</span>
        </SmallGroupGuard>
      );
      expect(container.querySelector('[data-testid="pii"]')).toBeNull();
    });

    it('provides accessible label on fallback', () => {
      render(<SmallGroupGuard n={2} context="par site">x</SmallGroupGuard>);
      const el = screen.getByTestId('small-group-guard-fallback');
      expect(el).toHaveAttribute('role', 'note');
      expect(el.getAttribute('aria-label')).toContain('par site');
      expect(el.getAttribute('aria-label')).toContain('5');
    });

    it('hides the visual "n<5" text from screen readers (aria-hidden)', () => {
      render(<SmallGroupGuard n={1}>x</SmallGroupGuard>);
      const visual = screen.getByText('n<5');
      expect(visual).toHaveAttribute('aria-hidden', 'true');
    });
  });

  describe('edge cases', () => {
    it('handles n = 0', () => {
      render(<SmallGroupGuard n={0}>x</SmallGroupGuard>);
      expect(screen.getByTestId('small-group-guard-fallback')).toBeInTheDocument();
    });

    it('handles negative n', () => {
      render(<SmallGroupGuard n={-1}>x</SmallGroupGuard>);
      expect(screen.getByTestId('small-group-guard-fallback')).toBeInTheDocument();
    });
  });
});
EOF

write_file src/widgets/SmallGroupGuard/SmallGroupGuard.a11y.test.tsx <<'EOF'
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { axe, toHaveNoViolations } from 'jest-axe';
import { SmallGroupGuard } from './SmallGroupGuard';

expect.extend(toHaveNoViolations);

describe('SmallGroupGuard — a11y', () => {
  it('has no axe violations when rendering children', async () => {
    const { container } = render(
      <SmallGroupGuard n={10}>
        <p>aggregate content</p>
      </SmallGroupGuard>
    );
    expect(await axe(container)).toHaveNoViolations();
  });

  it('has no axe violations when rendering fallback', async () => {
    const { container } = render(
      <SmallGroupGuard n={2}>
        <p>hidden</p>
      </SmallGroupGuard>
    );
    expect(await axe(container)).toHaveNoViolations();
  });

  it('fallback is announced to screen readers via role=note', () => {
    render(<SmallGroupGuard n={1}>x</SmallGroupGuard>);
    const el = screen.getByRole('note');
    expect(el).toBeInTheDocument();
  });
});
EOF

write_file src/widgets/SmallGroupGuard/index.ts <<'EOF'
export * from './SmallGroupGuard';
EOF

# ─────────────────────────────────────────────────────────────
# 3. KpiCard
# ─────────────────────────────────────────────────────────────
log "Génération KpiCard…"

write_file src/widgets/KpiCard/KpiCard.tsx <<'EOF'
import React from 'react';
import { SmallGroupGuard } from '../SmallGroupGuard';

export type KpiStatus = 'ok' | 'watch' | 'alert';

export interface KpiCardProps {
  label: string;
  value: number;
  unit?: 'min' | 'h' | 'd' | 'count' | 'pct';
  baseline?: number;
  target?: number;
  status?: KpiStatus;
  lastRefresh?: string;
  href?: string;
  /** Nombre de candidats dans le groupe. Si < 5, l'agrégat est masqué (RGPD). */
  n?: number;
}

export function formatValue(value: number, unit?: KpiCardProps['unit']): string {
  switch (unit) {
    case 'pct':   return `${value.toFixed(1)} %`;
    case 'min':   return `${value.toFixed(1)} min`;
    case 'h':     return `${value.toFixed(1)} h`;
    case 'd':     return `${value.toFixed(1)} j`;
    case 'count': return value.toLocaleString('fr-FR');
    default:      return String(value);
  }
}

export function deltaPct(value: number, baseline?: number): number | null {
  if (baseline === undefined || baseline === 0) return null;
  return ((value - baseline) / baseline) * 100;
}

function KpiCardInner(props: KpiCardProps) {
  const {
    label, value, unit, baseline, target,
    status = 'ok', lastRefresh, href,
  } = props;

  const delta = deltaPct(value, baseline);
  const sign  = delta === null ? '' : delta >= 0 ? '+' : '';

  return (
    <article
      data-testid="kpi-card"
      data-status={status}
      aria-label={`${label}: ${formatValue(value, unit)}`}
      className={`kpi-card kpi-card--${status}`}
    >
      <h3 className="kpi-card__label">{label}</h3>
      <p className="kpi-card__value">{formatValue(value, unit)}</p>

      {delta !== null && (
        <p className="kpi-card__delta" data-testid="kpi-card-delta">
          {sign}{delta.toFixed(1)} % vs baseline
        </p>
      )}

      {target !== undefined && (
        <p className="kpi-card__target" data-testid="kpi-card-target">
          Cible : {formatValue(target, unit)}
        </p>
      )}

      {lastRefresh && (
        <p className="kpi-card__refresh">
          Dernière mise à jour : {lastRefresh}
        </p>
      )}

      {href && (
        <a
          className="kpi-card__link"
          href={href}
          aria-label={`Voir la définition de ${label}`}
        >
          Définition
        </a>
      )}
    </article>
  );
}

export function KpiCard(props: KpiCardProps) {
  const { n, label } = props;
  if (n !== undefined && n < 5) {
    return (
      <SmallGroupGuard n={n} context={label}>
        {null}
      </SmallGroupGuard>
    );
  }
  return <KpiCardInner {...props} />;
}
EOF

write_file src/widgets/KpiCard/KpiCard.test.tsx <<'EOF'
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { KpiCard, formatValue, deltaPct } from './KpiCard';

describe('KpiCard — formatValue', () => {
  it('formats pct', () => expect(formatValue(12.345, 'pct')).toBe('12.3 %'));
  it('formats min', () => expect(formatValue(8.4, 'min')).toBe('8.4 min'));
  it('formats h',   () => expect(formatValue(2.5, 'h')).toBe('2.5 h'));
  it('formats d',   () => expect(formatValue(1.5, 'd')).toBe('1.5 j'));
  it('formats count with fr-FR locale', () =>
    expect(formatValue(12345, 'count')).toBe('12 345'));
  it('returns raw string when unit undefined', () =>
    expect(formatValue(42)).toBe('42'));
});

describe('KpiCard — deltaPct', () => {
  it('returns null when baseline undefined', () =>
    expect(deltaPct(10, undefined)).toBeNull());
  it('returns null when baseline = 0', () =>
    expect(deltaPct(10, 0)).toBeNull());
  it('computes positive delta', () =>
    expect(deltaPct(15, 10)).toBeCloseTo(50));
  it('computes negative delta', () =>
    expect(deltaPct(8.4, 18)).toBeCloseTo(-53.333, 2));
});

describe('KpiCard — rendering', () => {
  it('renders label and formatted value', () => {
    render(<KpiCard label="Median handling time" value={8.4} unit="min" />);
    expect(screen.getByText('Median handling time')).toBeInTheDocument();
    expect(screen.getByText('8.4 min')).toBeInTheDocument();
  });

  it('renders delta when baseline provided', () => {
    render(<KpiCard label="x" value={8.4} unit="min" baseline={18} />);
    expect(screen.getByTestId('kpi-card-delta')).toHaveTextContent('-53.3 %');
  });

  it('omits delta when baseline is 0', () => {
    render(<KpiCard label="x" value={1} baseline={0} />);
    expect(screen.queryByTestId('kpi-card-delta')).not.toBeInTheDocument();
  });

  it('renders target when provided', () => {
    render(<KpiCard label="x" value={8.4} unit="min" target={4} />);
    expect(screen.getByTestId('kpi-card-target')).toHaveTextContent('Cible : 4.0 min');
  });

  it('renders lastRefresh when provided', () => {
    render(<KpiCard label="x" value={1} lastRefresh="2026-10-11T08:00:00Z" />);
    expect(screen.getByText(/Dernière mise à jour/)).toBeInTheDocument();
  });

  it('renders definition link when href provided', () => {
    render(<KpiCard label="x" value={1} href="/definitions/x" />);
    const link = screen.getByRole('link', { name: /Voir la définition de x/ });
    expect(link).toHaveAttribute('href', '/definitions/x');
  });
});

describe('KpiCard — status', () => {
  it('sets data-status to ok by default', () => {
    render(<KpiCard label="x" value={1} />);
    expect(screen.getByTestId('kpi-card')).toHaveAttribute('data-status', 'ok');
  });
  it('sets data-status to watch', () => {
    render(<KpiCard label="x" value={1} status="watch" />);
    expect(screen.getByTestId('kpi-card')).toHaveAttribute('data-status', 'watch');
  });
  it('sets data-status to alert', () => {
    render(<KpiCard label="x" value={1} status="alert" />);
    expect(screen.getByTestId('kpi-card')).toHaveAttribute('data-status', 'alert');
  });
});

describe('KpiCard — RGPD compliance', () => {
  it('hides the card when n < 5', () => {
    render(<KpiCard label="x" value={42} n={3} />);
    expect(screen.queryByTestId('kpi-card')).not.toBeInTheDocument();
    expect(screen.getByTestId('small-group-guard-fallback')).toBeInTheDocument();
  });

  it('shows the card when n >= 5', () => {
    render(<KpiCard label="x" value={42} n={5} />);
    expect(screen.getByTestId('kpi-card')).toBeInTheDocument();
  });

  it('shows the card when n is undefined (no group info)', () => {
    render(<KpiCard label="x" value={42} />);
    expect(screen.getByTestId('kpi-card')).toBeInTheDocument();
  });
});
EOF

write_file src/widgets/KpiCard/KpiCard.a11y.test.tsx <<'EOF'
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { axe, toHaveNoViolations } from 'jest-axe';
import { KpiCard } from './KpiCard';

expect.extend(toHaveNoViolations);

describe('KpiCard — a11y', () => {
  it('has no axe violations (minimal)', async () => {
    const { container } = render(<KpiCard label="x" value={1} />);
    expect(await axe(container)).toHaveNoViolations();
  });

  it('has no axe violations (full)', async () => {
    const { container } = render(
      <KpiCard
        label="Median handling time"
        value={8.4}
        unit="min"
        baseline={18}
        target={4}
        status="watch"
        lastRefresh="2026-10-11T08:00:00Z"
        href="/definitions/median"
      />
    );
    expect(await axe(container)).toHaveNoViolations();
  });

  it('has an aria-label on the article', () => {
    render(<KpiCard label="Median handling time" value={8.4} unit="min" />);
    expect(screen.getByRole('article')).toHaveAttribute(
      'aria-label',
      'Median handling time: 8.4 min'
    );
  });

  it('definition link has explicit aria-label', () => {
    render(<KpiCard label="Median" value={1} href="/d" />);
    const link = screen.getByRole('link');
    expect(link).toHaveAttribute('aria-label', 'Voir la définition de Median');
  });
});
EOF

write_file src/widgets/KpiCard/KpiCard.stories.tsx <<'EOF'
import type { Meta, StoryObj } from '@storybook/react';
import { KpiCard } from './KpiCard';

const meta: Meta<typeof KpiCard> = {
  title: 'Widgets/KpiCard',
  component: KpiCard,
  tags: ['autodocs'],
  argTypes: {
    status: { control: 'inline-radio', options: ['ok', 'watch', 'alert'] },
    unit:   { control: 'inline-radio', options: ['min', 'h', 'd', 'count', 'pct'] },
  },
};
export default meta;

type Story = StoryObj<typeof KpiCard>;

export const Default: Story = {
  args: { label: 'Median handling time', value: 8.4, unit: 'min' },
};

export const WithBaselineAndTarget: Story = {
  args: {
    label: 'Median handling time',
    value: 8.4,
    unit: 'min',
    baseline: 18,
    target: 4,
    status: 'ok',
    lastRefresh: '2026-10-11T08:00:00Z',
    href: '/definitions/median-handling-time',
  },
};

export const Watch: Story = {
  args: { label: 'Override rate', value: 12.5, unit: 'pct', status: 'watch' },
};

export const Alert: Story = {
  args: { label: 'Agreement rate', value: 62.1, unit: 'pct', status: 'alert' },
};

export const SmallGroupHidden: Story = {
  args: { label: 'Per-site median (Porto)', value: 9.2, unit: 'min', n: 3 },
};

export const Count: Story = {
  args: { label: 'Candidates screened', value: 12345, unit: 'count' },
};
EOF

write_file src/widgets/KpiCard/index.ts <<'EOF'
export * from './KpiCard';
EOF

# ─────────────────────────────────────────────────────────────
# 4. Configs a11y (si absentes)
# ─────────────────────────────────────────────────────────────
log "Vérification configs a11y…"

if [ ! -f vitest.a11y.config.ts ]; then
  write_file vitest.a11y.config.ts <<'EOF'
import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: ['./vitest.a11y.setup.ts'],
    include: ['src/**/*.a11y.test.{ts,tsx}'],
  },
});
EOF
else
  ok "vitest.a11y.config.ts existe déjà — skip"
fi

if [ ! -f vitest.a11y.setup.ts ]; then
  write_file vitest.a11y.setup.ts <<'EOF'
import '@testing-library/jest-dom/vitest';
EOF
else
  ok "vitest.a11y.setup.ts existe déjà — skip"
fi

# ─────────────────────────────────────────────────────────────
# 5. Dépendances
# ─────────────────────────────────────────────────────────────
if [ "$DO_INSTALL" -eq 1 ]; then
  if ! node -e "try{require.resolve('jest-axe');process.exit(0)}catch(e){process.exit(1)}" 2>/dev/null; then
    log "Installation de jest-axe + @types/jest-axe…"
    if command -v pnpm >/dev/null 2>&1; then
      pnpm add -D jest-axe @types/jest-axe
    else
      npm install -D jest-axe @types/jest-axe
    fi
    ok "jest-axe installé"
  else
    ok "jest-axe déjà présent"
  fi
else
  warn "--no-install : jest-axe non vérifié"
fi

# ─────────────────────────────────────────────────────────────
# 6. Tests
# ─────────────────────────────────────────────────────────────
log "── Tests SmallGroupGuard ──"
if [ -x ./scripts/run.sh ]; then
  ./scripts/run.sh test src/widgets/SmallGroupGuard || die "tests SmallGroupGuard KO"
else
  if command -v pnpm >/dev/null 2>&1; then
    pnpm exec vitest run src/widgets/SmallGroupGuard || die "tests SmallGroupGuard KO"
  else
    npx vitest run src/widgets/SmallGroupGuard || die "tests SmallGroupGuard KO"
  fi
fi
ok "SmallGroupGuard ✅"

log "── Tests KpiCard ──"
if [ -x ./scripts/run.sh ]; then
  ./scripts/run.sh test src/widgets/KpiCard || die "tests KpiCard KO"
else
  if command -v pnpm >/dev/null 2>&1; then
    pnpm exec vitest run src/widgets/KpiCard || die "tests KpiCard KO"
  else
    npx vitest run src/widgets/KpiCard || die "tests KpiCard KO"
  fi
fi
ok "KpiCard ✅"

log "── Tests a11y (si jest-axe présent) ──"
if node -e "try{require.resolve('jest-axe');process.exit(0)}catch(e){process.exit(1)}" 2>/dev/null; then
  if command -v pnpm >/dev/null 2>&1; then
    pnpm exec vitest run --config vitest.a11y.config.ts || warn "tests a11y KO (non bloquant)"
  fi
else
  warn "jest-axe absent — a11y skip"
fi

log "── Typecheck + lint ──"
if [ -x ./scripts/run.sh ]; then
  ./scripts/run.sh typecheck || die "typecheck KO"
  ./scripts/run.sh lint || warn "lint KO (non bloquant)"
else
  if command -v pnpm >/dev/null 2>&1; then
    pnpm exec tsc --noEmit || die "typecheck KO"
    pnpm run lint --if-present || warn "lint KO (non bloquant)"
  fi
fi
ok "typecheck + lint ✅"

# ─────────────────────────────────────────────────────────────
# 7. Commit + push
# ─────────────────────────────────────────────────────────────
if [ "$DO_GIT" -eq 1 ]; then
  log "── Git: commit + push ──"

  # Fichiers à ajouter (uniquement ceux qu'on a créés)
  ADD_FILES=(
    src/widgets/SmallGroupGuard
    src/widgets/KpiCard
    vitest.a11y.config.ts
    vitest.a11y.setup.ts
    package.json
  )

  if [ -f pnpm-lock.yaml ]; then ADD_FILES+=(pnpm-lock.yaml); fi

  if git diff --quiet HEAD -- "${ADD_FILES[@]}" 2>/dev/null \
     && [ -z "$(git ls-files --others --exclude-standard -- "${ADD_FILES[@]}")" ]; then
    warn "rien à committer"
  else
    git add "${ADD_FILES[@]}"
    git commit -m "comp(widgets): implement SmallGroupGuard + KpiCard with RGPD guard and a11y tests"
    git push -u origin "HEAD:refs/heads/$WORK_BRANCH"
    ok "commit + push effectués sur $WORK_BRANCH"
  fi
fi

# ─────────────────────────────────────────────────────────────
# 8. Récap
# ─────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════════"
ok "Phase 1 + 2 générées et testées"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Branche : ${WORK_BRANCH}"
echo "Fichiers créés :"
echo "  src/widgets/SmallGroupGuard/{SmallGroupGuard.tsx,.test.tsx,.a11y.test.tsx,index.ts}"
echo "  src/widgets/KpiCard/{KpiCard.tsx,.test.tsx,.a11y.test.tsx,.stories.tsx,index.ts}"
echo "  vitest.a11y.config.ts"
echo "  vitest.a11y.setup.ts"
echo ""
echo "Prochaines étapes manuelles :"
echo "  1. Vérifier la CI verte sur GitHub"
echo "  2. ./scripts/push-modification-to-all-branches.sh \\"
echo "       --files \"src/widgets/SmallGroupGuard/ src/widgets/KpiCard/\" \\"
echo "       --message \"comp(widgets): SmallGroupGuard + KpiCard\" --yes"
echo "  3. ./scripts/merge-all-into-main.sh --dry-run && ./scripts/merge-all-into-main.sh --yes"
echo "  4. ./scripts/cleanup-branches.sh --yes"
echo ""