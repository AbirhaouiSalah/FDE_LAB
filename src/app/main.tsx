import React from 'react';
import { createRoot } from 'react-dom/client';
import { AppShell } from './shell/AppShell';

const container = document.getElementById('root');
if (!container) throw new Error('#root not found');
createRoot(container).render(
  <React.StrictMode>
    <AppShell>
      <h1>ATS Copilot</h1>
    </AppShell>
  </React.StrictMode>
);