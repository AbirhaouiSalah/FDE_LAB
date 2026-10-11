import React from 'react';
import { IconBell, IconMoon, IconSun } from './icons';
import type { Role } from '../../auth/rbac';

const ROLES: { value: Role; label: string }[] = [
  { value: 'recruiter', label: 'Recruteur' },
  { value: 'hm',        label: 'Hiring Manager' },
  { value: 'hrd',       label: 'HRD' },
  { value: 'dpo',       label: 'DPO' },
  { value: 'mco',       label: 'MCO' },
];

export interface HeaderProps {
  role: Role;
  onRoleChange: (r: Role) => void;
  lang: 'fr' | 'en';
  onLangChange: (l: 'fr' | 'en') => void;
  theme: 'light' | 'dark';
  onThemeToggle: () => void;
  alertCount: number;
}

export function Header({ role, onRoleChange, lang, onLangChange, theme, onThemeToggle, alertCount }: HeaderProps) {
  return (
    <header className="header">
      <div className="header__brand">
        <div className="header__logo" aria-hidden="true">A</div>
        <span>ATS Copilot</span>
      </div>

      <div className="header__spacer" />

      <label className="header__control">
        <span style={{ color: 'var(--color-text-muted)' }}>Rôle</span>
        <select value={role} onChange={e => onRoleChange(e.target.value as Role)} style={{ border: 'none', background: 'transparent', color: 'inherit', fontWeight: 600 }}>
          {ROLES.map(r => <option key={r.value} value={r.value}>{r.label}</option>)}
        </select>
      </label>

      <div className="header__control" role="group" aria-label="Langue">
        <button
          onClick={() => onLangChange('fr')}
          style={{ border: 'none', background: 'transparent', padding: 2, fontWeight: lang === 'fr' ? 700 : 500, color: lang === 'fr' ? 'var(--color-accent)' : 'inherit' }}
          aria-pressed={lang === 'fr'}
        >FR</button>
        <span style={{ color: 'var(--color-border-strong)' }}>|</span>
        <button
          onClick={() => onLangChange('en')}
          style={{ border: 'none', background: 'transparent', padding: 2, fontWeight: lang === 'en' ? 700 : 500, color: lang === 'en' ? 'var(--color-accent)' : 'inherit' }}
          aria-pressed={lang === 'en'}
        >EN</button>
      </div>

      <button className="header__icon-btn" onClick={onThemeToggle} aria-label={`Basculer en mode ${theme === 'light' ? 'sombre' : 'clair'}`}>
        {theme === 'light' ? <IconMoon /> : <IconSun />}
      </button>

      <button className="header__icon-btn" aria-label={`${alertCount} alertes`}>
        <IconBell />
        {alertCount > 0 && <span className="header__badge">{alertCount}</span>}
      </button>

      <div className="header__avatar" aria-label="Utilisateur courant">SA</div>
    </header>
  );
}
