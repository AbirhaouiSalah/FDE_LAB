#!/usr/bin/env bash
# scripts/lots/build-lot-4.sh — L4 Shell & Routing
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" ${0:A:h}${0:A:h} pwd)"
source "${SCRIPT_DIR}/_lib.sh"

PIVOT="ats-lab/comp/shell/app-shell"
parse_common_args "$@"
log_init "L4"
require_clean_tree
checkout_branch "$PIVOT"

write_file "src/app/context.tsx" <<'EOF'
// L4 — contexte applicatif : role + client API.
import { createContext, useContext, type ReactNode } from "react";
import type { Role } from "../auth/rbac";
import { ApiClient } from "../api/client";

const RoleCtx = createContext<Role>("viewer");
const ClientCtx = createContext<ApiClient | null>(null);

export function AppContextProvider({
  role, client, children,
}: { role: Role; client: ApiClient; children: ReactNode }) {
  return (
    <RoleCtx.Provider value={role}>
      <ClientCtx.Provider value={client}>{children}</ClientCtx.Provider>
    </RoleCtx.Provider>
  );
}
export const useRole = () => useContext(RoleCtx);
export function useApiClient(): ApiClient {
  const c = useContext(ClientCtx);
  if (!c) throw new Error("ApiClient manquant dans le contexte");
  return c;
}
EOF

write_file "src/app/Header.tsx" <<'EOF'
import { t } from "../i18n";
export function Header({ role }: { role: string }) {
  return (
    <header className="app-header">
      <h1>{t("app.title")}</h1>
      <span className="app-role" aria-label="role">{role}</span>
    </header>
  );
}
EOF

write_file "src/app/LeftNav.tsx" <<'EOF'
import { t } from "../i18n";
import { canAccess, PAGES, type Page, type Role } from "../auth/rbac";

const NAV: readonly Page[] = ["dashboard", "sites", "kpis", "candidates", "audit", "settings", "users", "billing"];

export function LeftNav({ role, current }: { role: Role; current: Page }) {
  return (
    <nav className="app-nav" aria-label="primary">
      <ul>
        {NAV.filter(p => canAccess(role, p)).map(p => (
          <li key={p} aria-current={p === current ? "page" : undefined}>
            <a href={`#/${p}`}>{t(`nav.${p}`)}</a>
          </li>
        ))}
      </ul>
    </nav>
  );
}
EOF

write_file "src/app/AppShell.tsx" <<'EOF'
import type { ReactNode } from "react";
import type { Page } from "../auth/rbac";
import { useRole } from "./context";
import { Header } from "./Header";
import { LeftNav } from "./LeftNav";

export function AppShell({ current, children }: { current: Page; children: ReactNode }) {
  const role = useRole();
  return (
    <div className="app-shell">
      <Header role={role} />
      <div className="app-body">
        <LeftNav role={role} current={current} />
        <main className="app-main">{children}</main>
      </div>
      <footer className="app-footer">L'humain décide toujours.</footer>
    </div>
  );
}
EOF

write_file "src/app/routes.tsx" <<'EOF'
// L4 — table de routage statique (le routeur hôte est branché en L5).
import type { Page } from "../auth/rbac";
export interface RouteDef { readonly path: Page; readonly component: string; }
export const ROUTES: readonly RouteDef[] = [
  { path: "dashboard",  component: "Overview" },
  { path: "sites",      component: "Overview" },
  { path: "kpis",       component: "Quality" },
  { path: "candidates", component: "Queue" },
  { path: "audit",      component: "Governance" },
  { path: "settings",   component: "Rubric" },
  { path: "users",      component: "Operations" },
  { path: "billing",    component: "Operations" },
];
EOF

write_file "src/styles/global.css" <<'EOF'
:root { color-scheme: light; }
body { margin: 0; font-family: system-ui, sans-serif; }
.app-shell { display: flex; flex-direction: column; min-height: 100vh; }
.app-body  { display: grid; grid-template-columns: 220px 1fr; flex: 1; }
.app-main  { padding: 1rem; }
.app-footer { padding: .5rem 1rem; font-size: .8rem; color: #666; }
.kpi-card { border: 1px solid #ddd; padding: .75rem; border-radius: 6px; }
.alert-panel { border-left: 3px solid #c00; padding-left: .5rem; }
EOF

commit_all "feat(L4): shell & routing — app-shell + header + left-nav + styles"

if (( ! DRY_RUN )); then
  "${SCRIPT_DIR}/push-lot.sh" \
    --lot "$PIVOT" \
    --files "src/app/ src/styles/" \
    --message "feat(L4): shell & routing" \
    --yes || die "push-lot.sh a échoué pour L4"
fi

ok "L4 terminé"
