#!/usr/bin/env bash
# scripts/lots/build-lot-2.sh
# L2 — Widgets RGPD & Data : SmallGroupGuard + KpiCard + QueueTable + AlertPanel
# Branche pivot : ats-lab/comp/widgets/small-group-guard
#
# Usage:
#   bash scripts/lots/build-lot-2.sh [--dry-run] [--yes] [--skip-tests] [--skip-push]

set -euo pipefail

# ─────────────────────────────────────────────────────────────
# Source helpers EN PREMIER (définit write_file, log_*, DRY_RUN, etc.)
# ─────────────────────────────────────────────────────────────
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

# ─────────────────────────────────────────────────────────────
# Config du lot
# ─────────────────────────────────────────────────────────────
LOT_ID="L2"
LOT_TAG="${LOT_ID}"; export LOT_TAG
LOT_NAME="Widgets RGPD & Data"
PIVOT_BRANCH="ats-lab/comp/widgets/small-group-guard"
SIBLING_BRANCHES=(
  "ats-lab/comp/widgets/kpi-card"
  "ats-lab/comp/widgets/queue-table"
  "ats-lab/comp/widgets/alert-panel"
)
LOT_FILES="src/widgets/SmallGroupGuard/ src/widgets/KpiCard/ src/widgets/QueueTable/ src/widgets/AlertPanel/"
COMMIT_MSG="feat(L2): widgets rgpd & data — SmallGroupGuard + KpiCard + QueueTable + AlertPanel"

# ─────────────────────────────────────────────────────────────
# Args (⚠ NE PAS faire `if ! parse_common_flags … then exit`)
# parse_common_* renvoie le nombre d'args consommés, PAS un code de succès.
# ─────────────────────────────────────────────────────────────
parse_common_flags "$@" || true

# ─────────────────────────────────────────────────────────────
# Pré-requis (défensif : n'existe pas forcément dans _lib.sh)
# ─────────────────────────────────────────────────────────────
if command -v check_prereqs >/dev/null 2>&1; then
  check_prereqs || true
else
  require_repo_root || true
fi

# ensure_branch peut échouer en dry-run si git fetch pose problème : tolérant
ensure_branch "$PIVOT_BRANCH" || true

log_init "${LOT_ID}"
log_step "${LOT_ID} — ${LOT_NAME}"
log_dim "pivot     : ${PIVOT_BRANCH}"
log_dim "siblings  : ${SIBLING_BRANCHES[*]}"
log_dim "files     : ${LOT_FILES}"
log_dim "mode      : $( [[ "${DRY_RUN}" == "1" ]] && echo DRY-RUN || echo APPLY )"

# ═══════════════════════════════════════════════════════════════════════════
# 1. SmallGroupGuard — garde RGPD (masque les agrégats trop petits)
# ═══════════════════════════════════════════════════════════════════════════

write_file "src/widgets/SmallGroupGuard/SmallGroupGuard.tsx" <<'EOF'
// src/widgets/SmallGroupGuard/SmallGroupGuard.tsx
// Garde RGPD : masque tout agrégat dont l'effectif n < k. Fail-closed.
import { type ReactNode } from "react";
import styles from "./SmallGroupGuard.module.css";

export interface SmallGroupGuardProps {
  /** Effectif de l'agrégat. `null`/`undefined`/non-entier => masqué. */
  n: number | null | undefined;
  /** Seuil de masquage. Défaut 5 (recommandation CNIL). */
  k?: number;
  children: ReactNode;
  /** Rendu alternatif si masqué. */
  maskedMessage?: ReactNode;
  /** Libellé de traçabilité (audit). */
  label?: string;
}

export function SmallGroupGuard({
  n, k = 5, children, maskedMessage, label,
}: SmallGroupGuardProps) {
  const safe =
    typeof n === "number" &&
    Number.isFinite(n) &&
    Number.isInteger(n) &&
    n >= k;

  if (safe) return <>{children}</>;

  // Pas d'affichage du chiffre exact quand masqué : on reste fail-closed.
  return (
    <div
      className={styles.masked}
      role="status"
      aria-label={label ? `Agrégat masqué : ${label}` : "Agrégat masqué"}
      data-guard="small-group"
      data-k={k}
    >
      {maskedMessage ?? (
        <span>
          Effectif insuffisant pour publication (seuil&nbsp;: {k}).
        </span>
      )}
    </div>
  );
}
EOF

write_file "src/widgets/SmallGroupGuard/SmallGroupGuard.module.css" <<'EOF'
/* src/widgets/SmallGroupGuard/SmallGroupGuard.module.css */
.masked {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 12px 16px;
  border: 1px dashed var(--c-border, #e3e6eb);
  border-radius: var(--radius-md, 8px);
  color: var(--c-text-muted, #5b6472);
  font-size: var(--fs-sm, 13px);
  background: var(--c-surface, #fff);
}
EOF

write_file "src/widgets/SmallGroupGuard/SmallGroupGuard.test.tsx" <<'EOF'
// src/widgets/SmallGroupGuard/SmallGroupGuard.test.tsx
import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import { SmallGroupGuard } from "./SmallGroupGuard";

describe("SmallGroupGuard", () => {
  it("affiche les enfants quand n >= k", () => {
    render(<SmallGroupGuard n={10} k={5}><span>OK</span></SmallGroupGuard>);
    expect(screen.getByText("OK")).toBeInTheDocument();
  });

  it("masque quand n < k", () => {
    render(<SmallGroupGuard n={3} k={5}><span>SECRET</span></SmallGroupGuard>);
    expect(screen.queryByText("SECRET")).not.toBeInTheDocument();
    expect(screen.getByRole("status")).toBeInTheDocument();
  });

  it("masque quand n est null (fail-closed)", () => {
    render(<SmallGroupGuard n={null}><span>SECRET</span></SmallGroupGuard>);
    expect(screen.queryByText("SECRET")).not.toBeInTheDocument();
  });

  it("masque quand n n'est pas un entier", () => {
    render(<SmallGroupGuard n={5.5} k={5}><span>SECRET</span></SmallGroupGuard>);
    expect(screen.queryByText("SECRET")).not.toBeInTheDocument();
  });

  it("utilise k=5 par défaut", () => {
    render(<SmallGroupGuard n={4}><span>SECRET</span></SmallGroupGuard>);
    expect(screen.queryByText("SECRET")).not.toBeInTheDocument();
  });
});
EOF

write_file "src/widgets/SmallGroupGuard/index.ts" <<'EOF'
export { SmallGroupGuard } from "./SmallGroupGuard";
export type { SmallGroupGuardProps } from "./SmallGroupGuard";
EOF

# ═══════════════════════════════════════════════════════════════════════════
# 2. KpiCard — carte d'indicateur (read-only, sans PII)
# ═══════════════════════════════════════════════════════════════════════════

write_file "src/widgets/KpiCard/KpiCard.tsx" <<'EOF'
// src/widgets/KpiCard/KpiCard.tsx
// Carte KPI read-only. Aucune décision automatique : affichage uniquement.
import { type ReactNode } from "react";
import { SmallGroupGuard } from "../SmallGroupGuard";
import styles from "./KpiCard.module.css";

export type KpiTrend = "up" | "down" | "flat";

export interface KpiCardProps {
  /** Libellé court, déjà traduit par l'appelant. */
  label: string;
  /** Valeur numérique principale (agrégat). */
  value: number | null | undefined;
  /** Variation optionnelle (ex. +3.2 pour +3.2%). */
  delta?: number;
  /** Tendance visuelle (accessoire, sans sémantique de décision). */
  trend?: KpiTrend;
  /** Effectif de l'agrégat — déclenche le masquage RGPD si < k. */
  sampleSize?: number | null;
  /** Seuil de masquage (défaut 5). */
  k?: number;
  /** Unité affichée (%, pts, etc.). */
  unit?: string;
  /** Contenu additionnel (footer). */
  footer?: ReactNode;
}

function fmt(v: number | null | undefined, unit?: string): string {
  if (v === null || v === undefined || !Number.isFinite(v)) return "—";
  const s = Math.abs(v) >= 100 ? v.toFixed(0) : v.toFixed(1);
  return unit ? `${s}${unit}` : s;
}

export function KpiCard({
  label, value, delta, trend = "flat", sampleSize, k = 5, unit, footer,
}: KpiCardProps) {
  const body = (
    <div className={styles.card} data-widget="kpi-card">
      <div className={styles.label}>{label}</div>
      <div className={styles.value} aria-live="polite">{fmt(value, unit)}</div>
      {typeof delta === "number" && Number.isFinite(delta) && (
        <div className={styles.delta} data-trend={trend}>
          {delta > 0 ? "+" : ""}{delta.toFixed(1)}
        </div>
      )}
      {footer && <div className={styles.footer}>{footer}</div>}
    </div>
  );

  if (sampleSize === undefined) return body;

  return (
    <SmallGroupGuard n={sampleSize} k={k} label={label}>
      {body}
    </SmallGroupGuard>
  );
}
EOF

write_file "src/widgets/KpiCard/KpiCard.module.css" <<'EOF'
/* src/widgets/KpiCard/KpiCard.module.css */
.card {
  display: flex;
  flex-direction: column;
  gap: 4px;
  padding: 16px;
  background: var(--c-surface, #fff);
  border: 1px solid var(--c-border, #e3e6eb);
  border-radius: var(--radius-md, 8px);
  min-width: 140px;
}
.label { font-size: var(--fs-sm, 13px); color: var(--c-text-muted, #5b6472); }
.value { font-size: var(--fs-xl, 20px); font-weight: 600; }
.delta { font-size: var(--fs-sm, 13px); }
.delta[data-trend="up"] { color: #2f7d32; }
.delta[data-trend="down"] { color: #b3261e; }
.delta[data-trend="flat"] { color: var(--c-text-muted, #5b6472); }
.footer { font-size: var(--fs-sm, 13px); color: var(--c-text-muted, #5b6472); margin-top: 4px; }
EOF

write_file "src/widgets/KpiCard/KpiCard.test.tsx" <<'EOF'
// src/widgets/KpiCard/KpiCard.test.tsx
import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import { KpiCard } from "./KpiCard";

describe("KpiCard", () => {
  it("affiche la valeur formatée", () => {
    render(<KpiCard label="Candidats" value={42.7} />);
    expect(screen.getByText("42.7")).toBeInTheDocument();
  });

  it("affiche — si valeur non finie", () => {
    render(<KpiCard label="Candidats" value={null} />);
    expect(screen.getByText("—")).toBeInTheDocument();
  });

  it("affiche l'unité", () => {
    render(<KpiCard label="Taux" value={12.5} unit="%" />);
    expect(screen.getByText("12.5%")).toBeInTheDocument();
  });

  it("masque la carte si sampleSize < k", () => {
    render(<KpiCard label="Candidats" value={42} sampleSize={3} k={5} />);
    expect(screen.queryByText("42")).not.toBeInTheDocument();
    expect(screen.getByRole("status")).toBeInTheDocument();
  });

  it("affiche la carte si sampleSize >= k", () => {
    render(<KpiCard label="Candidats" value={42} sampleSize={10} k={5} />);
    expect(screen.getByText("42")).toBeInTheDocument();
  });

  it("affiche le delta signé", () => {
    render(<KpiCard label="Candidats" value={42} delta={3.2} trend="up" />);
    expect(screen.getByText("+3.2")).toBeInTheDocument();
  });
});
EOF

write_file "src/widgets/KpiCard/index.ts" <<'EOF'
export { KpiCard } from "./KpiCard";
export type { KpiCardProps, KpiTrend } from "./KpiCard";
EOF

# ═══════════════════════════════════════════════════════════════════════════
# 3. QueueTable — file d'attente (read-only, tri + pas de PII)
# ═══════════════════════════════════════════════════════════════════════════

write_file "src/widgets/QueueTable/QueueTable.tsx" <<'EOF'
// src/widgets/QueueTable/QueueTable.tsx
// Table read-only de la file d'attente. L'humain décide, la table affiche.
import styles from "./QueueTable.module.css";

export interface QueueRow {
  /** Identifiant technique (opaque, non-PII). */
  id: string;
  /** Libellé affiché (déjà traduit). */
  label: string;
  /** Statut textuel. */
  status: string;
  /** Priorité numérique (plus petit = plus prioritaire). */
  priority?: number;
  /** Date ISO de mise à jour (traçabilité). */
  updatedAt?: string;
}

export interface QueueTableProps {
  rows: readonly QueueRow[];
  /** Callback déclenché au clic d'une ligne (informatif). */
  onSelect?: (id: string) => void;
  /** Message vide. */
  emptyMessage?: string;
  caption?: string;
}

export function QueueTable({
  rows, onSelect, emptyMessage = "Aucun élément", caption,
}: QueueTableProps) {
  if (rows.length === 0) {
    return <div className={styles.empty} role="status">{emptyMessage}</div>;
  }
  return (
    <table className={styles.table} data-widget="queue-table">
      {caption && <caption className={styles.caption}>{caption}</caption>}
      <thead>
        <tr>
          <th scope="col">Élément</th>
          <th scope="col">Statut</th>
          <th scope="col">Priorité</th>
          <th scope="col">Mise à jour</th>
        </tr>
      </thead>
      <tbody>
        {rows.map((r) => (
          <tr
            key={r.id}
            onClick={onSelect ? () => onSelect(r.id) : undefined}
            className={onSelect ? styles.clickable : undefined}
          >
            <td>{r.label}</td>
            <td>{r.status}</td>
            <td>{r.priority ?? "—"}</td>
            <td>{r.updatedAt ? r.updatedAt.slice(0, 10) : "—"}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}
EOF

write_file "src/widgets/QueueTable/QueueTable.module.css" <<'EOF'
/* src/widgets/QueueTable/QueueTable.module.css */
.table {
  width: 100%;
  border-collapse: collapse;
  font-size: var(--fs-sm, 13px);
  background: var(--c-surface, #fff);
}
.table th, .table td {
  text-align: left;
  padding: 8px 12px;
  border-bottom: 1px solid var(--c-border, #e3e6eb);
}
.table th { font-weight: 600; color: var(--c-text-muted, #5b6472); }
.clickable { cursor: pointer; }
.clickable:hover { background: color-mix(in oklab, var(--c-accent, #2f6feb) 6%, transparent); }
.empty {
  padding: 16px;
  color: var(--c-text-muted, #5b6472);
  font-size: var(--fs-sm, 13px);
  text-align: center;
}
.caption { caption-side: top; text-align: left; padding: 4px 0; font-size: var(--fs-sm, 13px); color: var(--c-text-muted, #5b6472); }
EOF

write_file "src/widgets/QueueTable/QueueTable.test.tsx" <<'EOF'
// src/widgets/QueueTable/QueueTable.test.tsx
import { describe, it, expect, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { QueueTable } from "./QueueTable";

const rows = [
  { id: "a", label: "Candidat A", status: "En attente", priority: 1, updatedAt: "2026-10-14T10:00:00Z" },
  { id: "b", label: "Candidat B", status: "Relu", priority: 2, updatedAt: "2026-10-13T09:00:00Z" },
];

describe("QueueTable", () => {
  it("affiche une ligne par entrée", () => {
    render(<QueueTable rows={rows} />);
    expect(screen.getAllByRole("row")).toHaveLength(3); // header + 2
  });

  it("affiche un état vide", () => {
    render(<QueueTable rows={[]} emptyMessage="Vide" />);
    expect(screen.getByText("Vide")).toBeInTheDocument();
  });

  it("tronque la date à YYYY-MM-DD", () => {
    render(<QueueTable rows={rows} />);
    expect(screen.getByText("2026-10-14")).toBeInTheDocument();
  });

  it("appelle onSelect au clic", async () => {
    const onSelect = vi.fn();
    render(<QueueTable rows={rows} onSelect={onSelect} />);
    await userEvent.click(screen.getByText("Candidat A"));
    expect(onSelect).toHaveBeenCalledWith("a");
  });
});
EOF

write_file "src/widgets/QueueTable/index.ts" <<'EOF'
export { QueueTable } from "./QueueTable";
export type { QueueTableProps, QueueRow } from "./QueueTable";
EOF

# ═══════════════════════════════════════════════════════════════════════════
# 4. AlertPanel — panneau d'alerte informatif (aucune décision auto)
# ═══════════════════════════════════════════════════════════════════════════

write_file "src/widgets/AlertPanel/AlertPanel.tsx" <<'EOF'
// src/widgets/AlertPanel/AlertPanel.tsx
// Panneau d'information. Ne prend AUCUNE décision : l'humain agit.
import { type ReactNode } from "react";
import styles from "./AlertPanel.module.css";

export type AlertLevel = "info" | "warning" | "critical";

export interface AlertPanelProps {
  level?: AlertLevel;
  title: string;
  children: ReactNode;
  /** Actions proposées à l'humain (boutons, liens). */
  actions?: ReactNode;
  /** Id technique pour la traçabilité. */
  id?: string;
}

export function AlertPanel({
  level = "info", title, children, actions, id,
}: AlertPanelProps) {
  const role = level === "critical" ? "alert" : "status";
  return (
    <section
      className={styles.panel}
      data-level={level}
      data-widget="alert-panel"
      data-alert-id={id}
      role={role}
      aria-live={level === "critical" ? "assertive" : "polite"}
    >
      <header className={styles.header}>
        <span className={styles.icon} aria-hidden>●</span>
        <h3 className={styles.title}>{title}</h3>
      </header>
      <div className={styles.body}>{children}</div>
      {actions && <footer className={styles.actions}>{actions}</footer>}
    </section>
  );
}
EOF

write_file "src/widgets/AlertPanel/AlertPanel.module.css" <<'EOF'
/* src/widgets/AlertPanel/AlertPanel.module.css */
.panel {
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding: 12px 16px;
  border-radius: var(--radius-md, 8px);
  border-left: 4px solid var(--c-accent, #2f6feb);
  background: color-mix(in oklab, var(--c-accent, #2f6feb) 8%, #fff);
}
.panel[data-level="warning"] {
  border-left-color: #b26a00;
  background: #fff7e6;
}
.panel[data-level="critical"] {
  border-left-color: #b3261e;
  background: #fdecea;
}
.header { display: flex; align-items: center; gap: 8px; }
.icon { color: inherit; font-size: 10px; }
.title { margin: 0; font-size: var(--fs-md, 14px); font-weight: 600; }
.body { font-size: var(--fs-sm, 13px); }
.actions { display: flex; gap: 8px; margin-top: 4px; }
EOF

write_file "src/widgets/AlertPanel/AlertPanel.test.tsx" <<'EOF'
// src/widgets/AlertPanel/AlertPanel.test.tsx
import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import { AlertPanel } from "./AlertPanel";

describe("AlertPanel", () => {
  it("affiche le titre et le contenu", () => {
    render(<AlertPanel title="Info"><p>Détail</p></AlertPanel>);
    expect(screen.getByText("Info")).toBeInTheDocument();
    expect(screen.getByText("Détail")).toBeInTheDocument();
  });

  it("utilise role=alert pour critical", () => {
    render(<AlertPanel level="critical" title="Alerte">x</AlertPanel>);
    expect(screen.getByRole("alert")).toBeInTheDocument();
  });

  it("utilise role=status pour info/warning", () => {
    render(<AlertPanel level="warning" title="Attention">x</AlertPanel>);
    expect(screen.getByRole("status")).toBeInTheDocument();
  });

  it("expose le level en data-attr", () => {
    const { container } = render(<AlertPanel level="warning" title="x">y</AlertPanel>);
    expect(container.querySelector("[data-level='warning']")).toBeInTheDocument();
  });
});
EOF

write_file "src/widgets/AlertPanel/index.ts" <<'EOF'
export { AlertPanel } from "./AlertPanel";
export type { AlertPanelProps, AlertLevel } from "./AlertPanel";
EOF

# ═══════════════════════════════════════════════════════════════════════════
# 5. Barrel export — src/widgets/index.ts
# ═══════════════════════════════════════════════════════════════════════════

write_file "src/widgets/index.ts" <<'EOF'
export { SmallGroupGuard } from "./SmallGroupGuard";
export type { SmallGroupGuardProps } from "./SmallGroupGuard";

export { KpiCard } from "./KpiCard";
export type { KpiCardProps, KpiTrend } from "./KpiCard";

export { QueueTable } from "./QueueTable";
export type { QueueTableProps, QueueRow } from "./QueueTable";

export { AlertPanel } from "./AlertPanel";
export type { AlertPanelProps, AlertLevel } from "./AlertPanel";
EOF

# ═══════════════════════════════════════════════════════════════════════════
# 6. Tests (optionnels selon flags)
# ═══════════════════════════════════════════════════════════════════════════

if [[ "${DRY_RUN}" != "1" ]] && [[ "${SKIP_TESTS:-0}" != "1" ]]; then
  log_step "${LOT_ID} — tests"
  run_vitest "src/widgets" || warn "certains tests ont échoué (non bloquant)"
fi

# ═══════════════════════════════════════════════════════════════════════════
# 7. Résumé
# ═══════════════════════════════════════════════════════════════════════════

FILES_WRITTEN="$(
  git -C "$REPO_ROOT" status --porcelain src/widgets 2>/dev/null \
    | /usr/bin/wc -l | tr -d ' '
)"
lot_summary "${LOT_ID}" "${FILES_WRITTEN:-0}" "4 widgets + tests + barrel"
log_ok "${LOT_ID} — complete"