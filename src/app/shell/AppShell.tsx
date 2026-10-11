import React, { useEffect, useState } from 'react';
import { Header } from './Header';
import { LeftNav } from './LeftNav';
import type { Page, Role } from '../../auth/rbac';
import { canAccess } from '../../auth/rbac';
import { RUBRIC_META, ALERTS } from '../../mock/data';

import { Overview } from '../../pages/Overview';
import { Pipeline } from '../../pages/Pipeline';
import { Queue } from '../../pages/Queue';
import { Quality } from '../../pages/Quality';
import { Fairness } from '../../pages/Fairness';
import { Operations } from '../../pages/Operations';
import { Governance } from '../../pages/Governance';
import { Rubric } from '../../pages/Rubric';

const PAGES: Record<Page, React.FC> = {
  overview: Overview,
  pipeline: Pipeline,
  queue: Queue,
  quality: Quality,
  fairness: Fairness,
  operations: Operations,
  governance: Governance,
  rubric: Rubric,
};

function pageFromHash(): Page {
  const h = window.location.hash.replace(/^#\/?/, '');
  const all: Page[] = ['overview', 'pipeline', 'queue', 'quality', 'fairness', 'operations', 'governance', 'rubric'];
  return (all as string[]).includes(h) ? (h as Page) : 'overview';
}

export function AppShell() {
  const [page, setPage] = useState<Page>(pageFromHash);
  const [role, setRole] = useState<Role>('hrd');
  const [lang, setLang] = useState<'fr' | 'en'>('fr');
  const [theme, setTheme] = useState<'light' | 'dark'>(() =>
    (localStorage.getItem('ats-theme') as 'light' | 'dark') || 'light'
  );

  useEffect(() => {
    const onHash = () => setPage(pageFromHash());
    window.addEventListener('hashchange', onHash);
    return () => window.removeEventListener('hashchange', onHash);
  }, []);

  useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme);
    localStorage.setItem('ats-theme', theme);
  }, [theme]);

  useEffect(() => {
    document.documentElement.lang = lang;
  }, [lang]);

  const navigate = (p: Page) => {
    if (!canAccess(role, p)) return;
    window.location.hash = `#/${p}`;
    setPage(p);
  };

  // Si le rôle change et que la page courante devient interdite → rediriger
  useEffect(() => {
    if (!canAccess(role, page)) navigate('overview');
  }, [role]);

  const Current = PAGES[page];

  return (
    <div className="shell">
      <Header
        role={role} onRoleChange={setRole}
        lang={lang} onLangChange={setLang}
        theme={theme} onThemeToggle={() => setTheme(t => t === 'light' ? 'dark' : 'light')}
        alertCount={ALERTS.length}
      />
      <LeftNav current={page} role={role} onNavigate={navigate} rubricVersion={RUBRIC_META.version} />
      <main className="main">
        <Current />
      </main>
    </div>
  );
}
