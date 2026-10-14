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
