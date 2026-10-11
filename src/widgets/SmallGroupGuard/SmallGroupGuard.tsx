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
