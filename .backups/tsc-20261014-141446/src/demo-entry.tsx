import React from 'react';
import { createRoot } from 'react-dom/client';
import { Demo } from './pages/Demo';

const container = document.getElementById('root');
if (!container) throw new Error('#root not found');
createRoot(container).render(
  <React.StrictMode>
    <Demo />
  </React.StrictMode>
);
