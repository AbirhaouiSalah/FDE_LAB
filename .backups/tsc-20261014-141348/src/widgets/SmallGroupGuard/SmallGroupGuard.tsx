import React from 'react';

export interface SmallGroupGuardProps {
  n: number;
  threshold?: number;
  children: React.ReactNode;
  fallback?: React.ReactNode;
  context?: string;
}

export function SmallGroupGuard(props: SmallGroupGuardProps) {
  const { n, threshold = 5, children, fallback, context } = props;
  if (n >= threshold) return <>{children}</>;

  const label = context
    ? `Agrégat masqué : groupe inférieur à ${threshold} (${context})`
    : `Agrégat masqué : groupe inférieur à ${threshold}`;

  return (
    <span
      data-testid="small-group-guard-fallback"
      role="note"
      aria-label={label}
      className="small-group"
    >
      {fallback ?? (
        <>
          <span aria-hidden="true">n&lt;{threshold}</span>
          <span className="sr-only">{label}</span>
        </>
      )}
    </span>
  );
}
