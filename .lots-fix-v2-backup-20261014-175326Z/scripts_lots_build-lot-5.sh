#!/usr/bin/env zsh
# scripts/lots/build-lot-5.sh — L5 Pages (overview + 7 sous-lots)
set -euo pipefail
SCRIPT_DIR="${0:A:h}"
source "${SCRIPT_DIR}/_lib.sh"

PIVOT="ats-lab/comp/overview/page"
parse_common_args "$@"
log_init "L5"
require_clean_tree
checkout_branch "$PIVOT"

# ---------- _shared ----------
write_file "src/pages/_shared/PageLayout.tsx" <<'EOF'
import type { ReactNode } from "react";
export function PageLayout({ title, actions, children }: {
  title: string; actions?: ReactNode; children: ReactNode;
}) {
  return (
    <section className="page-layout">
      <header><h2>{title}</h2>{actions ? <div className="page-actions">{actions}</div> : null}</header>
      <div className="page-body">{children}</div>
    </section>
  );
}
EOF

write_file "src/pages/_shared/PageState.tsx" <<'EOF'
import { t } from "../../i18n";
export function Loading() { return <div role="status">{t("state.loading")}</div>; }
export function Empty()   { return <div>{t("state.empty")}</div>; }
export function Forbidden() { return <div role="alert">{t("error.forbidden")}</div>; }
export function Failed({ message }: { message: string }) {
  return <div role="alert">{t("error.server")} — {message}</div>;
}
EOF

write_file "src/pages/_shared/RequireRole.tsx" <<'EOF'
import type { ReactNode } from "react";
import { canAccess, type Page, type Role } from "../../auth/rbac";
import { Forbidden } from "./PageState";
export function RequireRole({ role, page, children }: {
  role: Role; page: Page; children: ReactNode;
}) {
  if (!canAccess(role, page)) return <Forbidden />;
  return <>{children}</>;
}
EOF

write_file "src/pages/_shared/usePageData.ts" <<'EOF'
import { useEffect, useState } from "react";
import type { ApiClient, ApiEnvelope } from "../../api/client";
import type { ApiError } from "../../api/types";

type State<T> =
  | { status: "loading" }
  | { status: "error"; error: ApiError }
  | { status: "ready"; envelope: ApiEnvelope<T> };

export function usePageData<T>(
  fetcher: (c: ApiClient) => Promise<ApiEnvelope<T>>,
  client: ApiClient,
): State<T> {
  const [state, setState] = useState<State<T>>({ status: "loading" });
  useEffect(() => {
    let alive = true;
    setState({ status: "loading" });
    fetcher(client)
      .then((envelope) => alive && setState({ status: "ready", envelope }))
      .catch((error) => alive && setState({ status: "error", error }));
    return () => { alive = false; };
  }, [client, fetcher]);
  return state;
}
EOF

# ---------- Overview (pivot) ----------
write_file "src/pages/Overview/index.tsx" <<'EOF'
import { RequireRole } from "../_shared/RequireRole";
import { usePageData } from "../_shared/usePageData";
import { Loading, Failed, Empty } from "../_shared/PageState";
import { PageLayout } from "../_shared/PageLayout";
import { KpiCard } from "../../widgets/KpiCard";
import { SmallGroupGuard } from "../../widgets/SmallGroupGuard";
import { AlertPanel } from "../../widgets/AlertPanel";
import { useApiClient, useRole } from "../../app/context";
import { t } from "../../i18n";
import type { Site } from "../../api/types";

export default function OverviewPage() {
  const role = useRole();
  const client = useApiClient();
  const state = usePageData<readonly Site[]>((c) => c.getSites(), client);

  return (
    <RequireRole role={role} page="dashboard">
      <PageLayout title={t("nav.dashboard")}>
        {state.status === "loading" && <Loading />}
        {state.status === "error"   && <Failed message={state.error.message} />}
        {state.status === "ready" && state.envelope.data.length === 0 && <Empty />}
        {state.status === "ready" && state.envelope.data.length > 0 && (
          <>
            <AlertPanel alerts={[]} />
            <section aria-label="kpis">
              {state.envelope.data.flatMap((site) =>
                site.kpis.map((kpi) => (
                  <SmallGroupGuard key={`${site.id}-${kpi.id}`} n={kpi.value}>
                    <KpiCard label={t(kpi.label)} value={kpi.value} unit={kpi.unit} confidence={kpi.confidence} />
                  </SmallGroupGuard>
                )),
              )}
            </section>
          </>
        )}
      </PageLayout>
    </RequireRole>
  );
}
EOF

# ---------- Pipeline ----------
write_file "src/pages/Pipeline/index.tsx" <<'EOF'
import { RequireRole } from "../_shared/RequireRole";
import { PageLayout } from "../_shared/PageLayout";
import { FunnelChart } from "../../widgets/FunnelChart";
import { useRole } from "../../app/context";
import { t } from "../../i18n";

export default function PipelinePage() {
  const role = useRole();
  const stages = [
    { label: "Sourced", count: 120 },
    { label: "Screened", count: 84 },
    { label: "Interview", count: 32 },
    { label: "Offer", count: 9 },
  ];
  return (
    <RequireRole role={role} page="candidates">
      <PageLayout title="Pipeline">
        <FunnelChart stages={stages} />
        <p>{t("disclaimer.human_decides")}</p>
      </PageLayout>
    </RequireRole>
  );
}
EOF

# ---------- Queue ----------
write_file "src/pages/Queue/index.tsx" <<'EOF'
import { RequireRole } from "../_shared/RequireRole";
import { PageLayout } from "../_shared/PageLayout";
import { QueueTable, type QueueRow } from "../../widgets/QueueTable";
import { useRole } from "../../app/context";

export default function QueuePage() {
  const role = useRole();
  const rows: readonly QueueRow[] = [
    { id: "S-001", stage: "screening", ageDays: 2, confidence: "high" },
    { id: "S-002", stage: "screening", ageDays: 5, confidence: "medium" },
    { id: "S-003", stage: "review",    ageDays: 8, confidence: "low" },
  ];
  return (
    <RequireRole role={role} page="candidates">
      <PageLayout title="File d'attente">
        <QueueTable rows={rows} />
      </PageLayout>
    </RequireRole>
  );
}
EOF

# ---------- Quality ----------
write_file "src/pages/Quality/index.tsx" <<'EOF'
import { RequireRole } from "../_shared/RequireRole";
import { PageLayout } from "../_shared/PageLayout";
import { Gauge } from "../../widgets/Gauge";
import { TimeSeries } from "../../widgets/TimeSeries";
import { useRole } from "../../app/context";

export default function QualityPage() {
  const role = useRole();
  const points = [
    { t: "2025-01", v: 0.82 }, { t: "2025-02", v: 0.85 },
    { t: "2025-03", v: 0.79 }, { t: "2025-04", v: 0.88 },
  ];
  return (
    <RequireRole role={role} page="kpis">
      <PageLayout title="Qualité">
        <Gauge value={0.88} label="score qualité" />
        <TimeSeries points={points} label="évolution qualité" />
      </PageLayout>
    </RequireRole>
  );
}
EOF

# ---------- Fairness ----------
write_file "src/pages/Fairness/index.tsx" <<'EOF'
import { RequireRole } from "../_shared/RequireRole";
import { PageLayout } from "../_shared/PageLayout";
import { Heatmap, type HeatCell } from "../../widgets/Heatmap";
import { useRole } from "../../app/context";

export default function FairnessPage() {
  const role = useRole();
  const cells: HeatCell[] = [];
  for (const r of ["A", "B", "C"]) for (const c of ["X", "Y", "Z"])
    cells.push({ row: r, col: c, v: Math.round((Math.random() - 0.5) * 100) / 100 });
  return (
    <RequireRole role={role} page="audit">
      <PageLayout title="Fairness">
        <Heatmap cells={cells} />
      </PageLayout>
    </RequireRole>
  );
}
EOF

# ---------- Operations ----------
write_file "src/pages/Operations/index.tsx" <<'EOF'
import { RequireRole } from "../_shared/RequireRole";
import { PageLayout } from "../_shared/PageLayout";
import { useRole } from "../../app/context";

export default function OperationsPage() {
  const role = useRole();
  return (
    <RequireRole role={role} page="settings">
      <PageLayout title="Opérations">
        <p>Vue opérationnelle (lecture seule).</p>
      </PageLayout>
    </RequireRole>
  );
}
EOF

# ---------- Governance ----------
write_file "src/pages/Governance/index.tsx" <<'EOF'
import { RequireRole } from "../_shared/RequireRole";
import { PageLayout } from "../_shared/PageLayout";
import { useRole } from "../../app/context";

export default function GovernancePage() {
  const role = useRole();
  return (
    <RequireRole role={role} page="audit">
      <PageLayout title="Gouvernance">
        <p>Journal d'audit et conformité (lecture seule).</p>
      </PageLayout>
    </RequireRole>
  );
}
EOF

# ---------- Rubric ----------
write_file "src/pages/Rubric/index.tsx" <<'EOF'
import { RequireRole } from "../_shared/RequireRole";
import { PageLayout } from "../_shared/PageLayout";
import { useRole } from "../../app/context";

export default function RubricPage() {
  const role = useRole();
  return (
    <RequireRole role={role} page="settings">
      <PageLayout title="Rubric">
        <p>Grille d'évaluation — consultation uniquement.</p>
      </PageLayout>
    </RequireRole>
  );
}
EOF

# ---------- Tests ----------
write_file "src/pages/_shared/RequireRole.test.tsx" <<'EOF'
import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import { RequireRole } from "./RequireRole";

describe("RequireRole", () => {
  it("affiche le contenu si autorisé", () => {
    render(<RequireRole role="admin" page="users"><span>OK</span></RequireRole>);
    expect(screen.getByText("OK")).toBeDefined();
  });
  it("masque si refusé", () => {
    render(<RequireRole role="viewer" page="users"><span>KO</span></RequireRole>);
    expect(screen.queryByText("KO")).toBeNull();
  });
  it("fail-closed sur rôle inconnu", () => {
    // @ts-expect-error test
    render(<RequireRole role="ghost" page="dashboard"><span>KO</span></RequireRole>);
    expect(screen.queryByText("KO")).toBeNull();
  });
});
EOF

commit_all "feat(L5): pages — overview + pipeline + queue + quality + fairness + operations + governance + rubric"

if (( ! DRY_RUN )); then
  "${SCRIPT_DIR}/push-lot.sh" \
    --lot "$PIVOT" \
    --files "src/pages/" \
    --message "feat(L5): pages" \
    --yes || die "push-lot.sh a échoué pour L5"
fi

ok "L5 terminé"