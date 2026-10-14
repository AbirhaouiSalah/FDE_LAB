import React from 'react';
import {
  IconOverview, IconPipeline, IconQueue, IconQuality,
  IconFairness, IconOperations, IconGovernance, IconRubric,
} from './icons';
import type { Page, Role } from '../../auth/rbac';
import { canAccess } from '../../auth/rbac';

const ITEMS: { page: Page; label: string; Icon: React.FC<{ size?: number }> }[] = [
  { page: 'overview',    label: 'Overview',    Icon: IconOverview },
  { page: 'pipeline',    label: 'Pipeline',    Icon: IconPipeline },
  { page: 'queue',       label: 'Queue',       Icon: IconQueue },
  { page: 'quality',     label: 'Quality',     Icon: IconQuality },
  { page: 'fairness',    label: 'Fairness',    Icon: IconFairness },
  { page: 'operations',  label: 'Operations',  Icon: IconOperations },
  { page: 'governance',  label: 'Governance',  Icon: IconGovernance },
  { page: 'rubric',      label: 'Rubric',      Icon: IconRubric },
];

export interface LeftNavProps {
  current: Page;
  role: Role;
  onNavigate: (p: Page) => void;
  rubricVersion: string;
}

export function LeftNav({ current, role, onNavigate, rubricVersion }: LeftNavProps) {
  return (
    <nav className="nav" aria-label="Navigation principale">
      {ITEMS.map(({ page, label, Icon }) => {
        const allowed = canAccess(role, page);
        const active = current === page;
        return (
          <button
            key={page}
            className={`nav__item ${active ? 'nav__item--active' : ''}`}
            onClick={() => onNavigate(page)}
            disabled={!allowed}
            aria-current={active ? 'page' : undefined}
            title={!allowed ? `Accès refusé pour le rôle ${role}` : label}
          >
            <span className="nav__icon"><Icon /></span>
            <span className="nav__label">{label}</span>
          </button>
        );
      })}
      <div className="nav__footer">Rubric {rubricVersion}</div>
    </nav>
  );
}
