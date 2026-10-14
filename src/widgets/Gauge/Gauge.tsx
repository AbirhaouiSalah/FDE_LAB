
export function Gauge({ value, label, size = 140 }: { value: number; label: string; size?: number }) {
  const clamped = Math.max(0, Math.min(100, value));
  const r = 60, cx = size / 2, cy = 70;
  const angle = (clamped / 100) * Math.PI;
  const x = cx - r * Math.cos(angle);
  const y = cy - r * Math.sin(angle);
  const largeArc = 0;

  const color = clamped >= 85 ? 'var(--color-ok)' : clamped >= 70 ? 'var(--color-watch)' : 'var(--color-alert)';

  return (
    <div className="gauge-wrap">
      <div className="gauge" style={{ width: size }}>
        <svg viewBox={`0 0 ${size} 80`} width={size} height={80} aria-hidden="true">
          <path d={`M ${cx - r},${cy} A ${r},${r} 0 0 1 ${cx + r},${cy}`} fill="none" stroke="var(--color-border)" strokeWidth="10" strokeLinecap="round" />
          <path d={`M ${cx - r},${cy} A ${r},${r} 0 ${largeArc} 1 ${x},${y}`} fill="none" stroke={color} strokeWidth="10" strokeLinecap="round" />
        </svg>
        <div className="gauge__value" style={{ color }}>{clamped.toFixed(1)} %</div>
      </div>
      <div className="gauge__label">{label}</div>
    </div>
  );
}
