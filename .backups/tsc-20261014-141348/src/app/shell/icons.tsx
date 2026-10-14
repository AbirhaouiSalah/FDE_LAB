import React from 'react';
type P = { size?: number };
const base = (size = 18) => ({ width: size, height: size, viewBox: '0 0 24 24', fill: 'none', stroke: 'currentColor', strokeWidth: 1.8, strokeLinecap: 'round' as const, strokeLinejoin: 'round' as const });

export const IconOverview = ({ size }: P) => (<svg {...base(size)}><rect x="3" y="3" width="7" height="9"/><rect x="14" y="3" width="7" height="5"/><rect x="14" y="12" width="7" height="9"/><rect x="3" y="16" width="7" height="5"/></svg>);
export const IconPipeline = ({ size }: P) => (<svg {...base(size)}><path d="M3 5h18l-6 7v6l-6 3v-9z"/></svg>);
export const IconQueue = ({ size }: P) => (<svg {...base(size)}><circle cx="9" cy="8" r="3"/><path d="M3 20c0-3 3-5 6-5s6 2 6 5"/><path d="M16 11h5M16 15h5M16 7h3"/></svg>);
export const IconQuality = ({ size }: P) => (<svg {...base(size)}><path d="M9 12l2 2 4-4"/><circle cx="12" cy="12" r="9"/></svg>);
export const IconFairness = ({ size }: P) => (<svg {...base(size)}><path d="M12 3v18"/><path d="M5 8h14"/><path d="M5 8l-2 6a3 3 0 0 0 6 0z"/><path d="M19 8l-2 6a3 3 0 0 0 6 0z"/></svg>);
export const IconOperations = ({ size }: P) => (<svg {...base(size)}><circle cx="12" cy="12" r="3"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3M4.9 4.9l2.1 2.1M17 17l2.1 2.1M4.9 19.1L7 17M17 7l2.1-2.1"/></svg>);
export const IconGovernance = ({ size }: P) => (<svg {...base(size)}><path d="M4 4h12l4 4v12H4z"/><path d="M8 10h8M8 14h8"/></svg>);
export const IconRubric = ({ size }: P) => (<svg {...base(size)}><path d="M4 4h10a4 4 0 0 1 4 4v12H8a4 4 0 0 0-4 4z"/><path d="M8 8h6"/></svg>);
export const IconBell = ({ size }: P) => (<svg {...base(size)}><path d="M6 8a6 6 0 0 1 12 0c0 7 3 7 3 9H3c0-2 3-2 3-9"/><path d="M10 21a2 2 0 0 0 4 0"/></svg>);
export const IconMoon = ({ size }: P) => (<svg {...base(size)}><path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z"/></svg>);
export const IconSun = ({ size }: P) => (<svg {...base(size)}><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/></svg>);
