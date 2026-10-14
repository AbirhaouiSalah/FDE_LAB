// AUTO-GENERATED par scripts/run-dashboard.sh — page de démonstration locale.
import React from 'react';
import { KpiCard } from '../widgets/KpiCard';
import { SmallGroupGuard } from '../widgets/SmallGroupGuard';
import { DEMO_KPIS, DEMO_META } from '../mock/dashboard-data';

const styles: Record<string, React.CSSProperties> = {
  page: {
    fontFamily: 'Inter, system-ui, -apple-system, sans-serif',
    background: '#f9fafb',
    color: '#111827',
    minHeight: '100vh',
    padding: '32px',
    margin: 0,
  },
  header: {
    maxWidth: 1200,
    margin: '0 auto 24px',
  },
  h1: {
    fontSize: 24,
    fontWeight: 700,
    margin: '0 0 8px',
  },
  sub: {
    fontSize: 14,
    color: '#6b7280',
    margin: 0,
  },
  banner: {
    maxWidth: 1200,
    margin: '0 auto 24px',
    padding: '12px 16px',
    background: '#fef3c7',
    border: '1px solid #f59e0b',
    borderRadius: 8,
    fontSize: 14,
    color: '#92400e',
  },
  grid: {
    maxWidth: 1200,
    margin: '0 auto',
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))',
    gap: 24,
  },
  card: {
    background: '#ffffff',
    borderRadius: 8,
    padding: 16,
    boxShadow: '0 1px 3px rgba(0,0,0,0.06), 0 1px 2px rgba(0,0,0,0.04)',
  },
  section: {
    maxWidth: 1200,
    margin: '40px auto 16px',
    fontSize: 18,
    fontWeight: 600,
  },
  footer: {
    maxWidth: 1200,
    margin: '48px auto 0',
    fontSize: 12,
    color: '#9ca3af',
    textAlign: 'center' as const,
  },
};

export function Demo() {
  return (
    <main style={styles.page}>
      <header style={styles.header}>
        <h1 style={styles.h1}>ATS Copilot — Démo locale</h1>
        <p style={styles.sub}>
          Rubric {DEMO_META.rubric_version} · Site {DEMO_META.site} ·
          Généré le {new Date(DEMO_META.generated_at).toLocaleString('fr-FR')}
        </p>
      </header>

      <div style={styles.banner} role="note">
        ⚠️ {DEMO_META.warning}
      </div>

      <h2 style={styles.section}>KPI principaux</h2>
      <section style={styles.grid} aria-label="KPI principaux">
        {DEMO_KPIS.slice(0, 4).map((kpi) => (
          <div key={kpi.label} style={styles.card}>
            <KpiCard
              label={kpi.label}
              value={kpi.value}
              unit={kpi.unit}
              baseline={kpi.baseline}
              target={kpi.target}
              status={kpi.status}
              lastRefresh={kpi.lastRefresh}
              href={kpi.href}
              n={kpi.n}
            />
          </div>
        ))}
      </section>

      <h2 style={styles.section}>Cas limites RGPD</h2>
      <section style={styles.grid} aria-label="Cas limites RGPD">
        <div style={styles.card}>
          <KpiCard
            label="Médiane Porto (n=3, masqué)"
            value={9.2}
            unit="min"
            n={3}
            status="ok"
            lastRefresh="2026-10-11T08:00:00Z"
          />
        </div>

        <div style={styles.card}>
          <SmallGroupGuard n={2} context="Fairness par site">
            <p style={{ margin: 0 }}>Cet agrégat ne devrait jamais apparaître.</p>
          </SmallGroupGuard>
        </div>

        <div style={styles.card}>
          <SmallGroupGuard n={42} context="Fairness par site">
            <p style={{ margin: 0 }}>Agrégat visible (n=42, seuil respecté).</p>
          </SmallGroupGuard>
        </div>
      </section>

      <h2 style={styles.section}>Tous les statuts</h2>
      <section style={styles.grid} aria-label="Tous les statuts">
        {(['ok', 'watch', 'alert'] as const).map((status) => (
          <div key={status} style={styles.card}>
            <KpiCard
              label={`Statut: ${status}`}
              value={status === 'ok' ? 8.4 : status === 'watch' ? 12.5 : 2}
              unit={status === 'alert' ? 'count' : 'pct'}
              status={status}
              baseline={20}
              target={5}
              lastRefresh="2026-10-11T08:00:00Z"
            />
          </div>
        ))}
      </section>

      <footer style={styles.footer}>
        ATS Copilot Dashboard · ALTEN FDE Lab · read-only · aucune décision automatique
      </footer>
    </main>
  );
}
