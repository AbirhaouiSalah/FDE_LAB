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
