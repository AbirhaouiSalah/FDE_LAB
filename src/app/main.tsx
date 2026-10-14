import React from 'react';
import { createRoot } from 'react-dom/client';
import { AppShell } from './shell/AppShell';
import '../styles/tokens.css';
import '../styles/layout.css';
import '../styles/components.css';

const container = document.getElementById('root');
if (!container) throw new Error('#root not found');
createRoot(container).render(
  <React.StrictMode>
    <AppShell />
  </React.StrictMode>
);
