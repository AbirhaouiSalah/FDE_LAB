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
