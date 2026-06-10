// BabyLog · shared icons + UI primitives  (exports to window)
// Line-icon set, 1.8 stroke, rounded. color via currentColor.
const { useState, useEffect, useRef } = React;

const ICONS = {
  home: 'M3 11.2 12 4l9 7.2M5.5 9.6V19a1 1 0 0 0 1 1H17.5a1 1 0 0 0 1-1V9.6',
  pin: 'M12 21s-6.5-5-6.5-10A6.5 6.5 0 0 1 18.5 11c0 5-6.5 10-6.5 10Z|c:12,11,2.4',
  bag: 'M6 8h12l1 12H5L6 8Z|M9 8a3 3 0 0 1 6 0',
  user: 'c:12,8,3.4|M5 20c0-3.6 3.1-5.2 7-5.2s7 1.6 7 5.2',
  plus: 'M12 5v14M5 12h14',
  camera: 'M4 8h3l1.5-2h7L17 8h3a1 1 0 0 1 1 1v9a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V9a1 1 0 0 1 1-1Z|c:12,13,3.2',
  heart: 'M12 20.5s-7-4.4-7-9.4C5 8.3 6.9 6.5 9.1 6.5c1.5 0 2.5.8 2.9 1.9.4-1.1 1.4-1.9 2.9-1.9 2.2 0 4.1 1.8 4.1 4.6 0 5-7 9.4-7 9.4Z',
  ruler: 'M4 14 14 4l6 6L10 20 4 14Z|M8 10l2 2M11 7l2 2M14 12l1.5 1.5',
  vaccine: 'M11 3l4 4M9 9l6 6M13 7l-7 7-2 5 5-2 7-7M4 20l1.5-1.5',
  phone: 'M5 4h4l1.5 4-2 1.5a11 11 0 0 0 5 5l1.5-2 4 1.5v4a1 1 0 0 1-1 1A16 16 0 0 1 4 5a1 1 0 0 1 1-1Z',
  chevron: 'M9 5l7 7-7 7',
  star: 'M12 3.5l2.6 5.3 5.9.9-4.3 4.1 1 5.8L12 16.9 6.8 19.6l1-5.8L3.5 9.7l5.9-.9z',
  shield: 'M12 3l7 3v5c0 4.2-3 7.4-7 8.5C8 18.4 5 15.2 5 11V6z|M9 12l2 2 4-4',
  bell: 'M6.5 9a5.5 5.5 0 0 1 11 0c0 5 2 6 2 6H4.5s2-1 2-6Z|M10 21h4',
  wallet: 'M4 7a2 2 0 0 1 2-2h11a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V7Z|M15 12h3M19 9v6a0 0 0 0 1 0 0h-4a1.5 1.5 0 0 1 0-3z',
  gift: 'M4 11h16v8a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1v-8Z|M3 8h18v3H3zM12 8v12|M12 8C8 8 7 4 9 4s3 4 3 4 1-4 3-4 1 4-3 4',
  users: 'c:9,8,3|c:17,9.5,2.2|M3 19c0-3 2.7-4.6 6-4.6M14 19c0-2.4 1.7-3.8 4-4',
  calendar: 'M5 6h14a1 1 0 0 1 1 1v12a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1Z|M4 10h16M9 4v3M15 4v3',
  search: 'c:11,11,6|M16 16l4 4',
  filter: 'M4 6h16M7 12h10M10 18h4',
  close: 'M6 6l12 12M18 6L6 18',
  check: 'M5 12l5 5 9-10',
  chart: 'M5 5v14h14|M8 15l3-4 3 2 4-6',
  moon: 'M20 14.5A8 8 0 0 1 9.5 4 8 8 0 1 0 20 14.5Z',
  sun: 'c:12,12,4|M12 3v2M12 19v2M3 12h2M19 12h2M5.6 5.6l1.4 1.4M17 17l1.4 1.4M18.4 5.6 17 7M7 17l-1.4 1.4',
  image: 'M4 5h16a1 1 0 0 1 1 1v12a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V6a1 1 0 0 1 1-1Z|c:8.5,9.5,1.6|M4 17l5-5 4 3 3-3 5 5',
  sparkle: 'M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8z|M19 4l.7 2 2 .7-2 .7-.7 2-.7-2-2-.7 2-.7z',
  lock: 'M7 11V8a5 5 0 0 1 10 0v3|M5 11h14v8a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1v-8Z|c:12,15,1.4',
  edit: 'M5 19h4L19 9l-4-4L5 15v4Z|M14 6l4 4',
  share: 'c:6,12,2.4|c:17,6,2.4|c:17,18,2.4|M8.2 11 14.8 7.2M8.2 13l6.6 3.8',
  arrowL: 'M19 12H5M11 6l-6 6 6 6',
  arrowR: 'M5 12h14M13 6l6 6-6 6',
  map: 'M9 4 4 6v14l5-2 6 2 5-2V4l-5 2-6-2Z|M9 4v14M15 6v14',
  clock: 'c:12,12,8|M12 8v4l3 2',
  won: 'M4 7l3 10 3-8 2 8 3-10M4 11h16',
  medal: 'c:12,9,5.5|M9 13.5 7 21l5-2.5L17 21l-2-7.5',
  trophy: 'M7 5h10v3a5 5 0 0 1-10 0V5Z|M7 7H4v1a3 3 0 0 0 3 3M17 7h3v1a3 3 0 0 1-3 3M9 17h6v3H9z',
  flame: 'M12 3s5 4 5 9a5 5 0 0 1-10 0c0-1.5.5-2.5 1-3 .3 1 1 1.5 1.8 1.5C11 11.5 9.5 8 12 3Z',
  book: 'M5 4h9a2 2 0 0 1 2 2v14H7a2 2 0 0 1-2-2V4Z|M16 6h3v14h-9',
  stroller: 'c:7,19,2|c:17,19,2|M5 11h11l-1 6H7l-2-9H3|M9 4a7 7 0 0 1 7 7',
  settings: 'c:12,12,3|M12 3v3M12 18v3M5 5l2 2M17 17l2 2M3 12h3M18 12h3M5 19l2-2M17 7l2-2',
  bookmark: 'M7 4h10a1 1 0 0 1 1 1v15l-6-4-6 4V5a1 1 0 0 1 1-1Z',
  grid: 'M4 4h7v7H4zM13 4h7v7h-7zM4 13h7v7H4zM13 13h7v7h-7z',
  list: 'M4 6h16M4 12h16M4 18h16',
  chat: 'M4 5h16a1 1 0 0 1 1 1v9a1 1 0 0 1-1 1H9l-4 4v-4H4a1 1 0 0 1-1-1V6a1 1 0 0 1 1-1Z',
  pillbox: 'M5 5h14v6H5zM5 11h14v8H5z|M9 14h6',
  drop: 'M12 3s6 6.5 6 11a6 6 0 0 1-12 0c0-4.5 6-11 6-11Z',
  baby: 'c:12,8,4.5|M9 7.5c.5.6 1.3 1 2 .5M13 7.5c.5.6 1.3 1 2 .5M10 11c1 .8 3 .8 4 0|M6 14c0 4 2.7 6 6 6s6-2 6-6',
  warning: 'M12 4 2.5 20h19L12 4Z|M12 10v4M12 17.2v.1',
  refresh: 'M4 12a8 8 0 0 1 14-5l2 2M20 12a8 8 0 0 1-14 5l-2-2|M19 4v5h-5M5 20v-5h5',
};

function Icon({ name, size = 22, color = 'currentColor', stroke = 1.8, fill = false, style }) {
  const def = ICONS[name];
  if (!def) return null;
  const parts = def.split('|');
  return (
    <svg viewBox="0 0 24 24" width={size} height={size} fill="none" style={{ display: 'block', ...style }}>
      {parts.map((p, i) => {
        if (p.startsWith('c:')) {
          const [cx, cy, r] = p.slice(2).split(',').map(Number);
          return <circle key={i} cx={cx} cy={cy} r={r} stroke={color} strokeWidth={stroke} fill={fill ? color : 'none'} />;
        }
        return <path key={i} d={p} stroke={color} strokeWidth={stroke} strokeLinecap="round" strokeLinejoin="round" fill={fill ? color : 'none'} />;
      })}
    </svg>
  );
}

// ---- Badge / tier chip ----
const BADGE_INK = { grey:'#877E6B', mint:'#2E7A5C', purple:'#5B53B0', amber:'#98711E', coral:'#B45840', pink:'#B5478A', blue:'#3B6FA8' };
const BADGE_BG = { grey:'#F1EFE8', mint:'#E1F5EE', purple:'#EEEDFE', amber:'#FAEEDA', coral:'#FAECE7', pink:'#FBEAF0', blue:'#E6F1FB' };
function Badge({ tone = 'grey', children, dot = false, small = false, style }) {
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: dot ? 5 : 4,
      height: small ? 21 : 25, padding: small ? '0 8px' : '0 10px', borderRadius: 999,
      background: BADGE_BG[tone], color: BADGE_INK[tone],
      fontSize: small ? 11 : 12.5, fontWeight: 700, letterSpacing: '-0.01em', whiteSpace: 'nowrap', ...style,
    }}>
      {dot && <span style={{ width: 6, height: 6, borderRadius: 3, background: 'currentColor', opacity: .85 }} />}
      {children}
    </span>
  );
}

// ---- Filter chip ----
function Chip({ on, children, onClick, style }) {
  return (
    <button onClick={onClick} style={{
      display: 'inline-flex', alignItems: 'center', gap: 6, height: 36, padding: '0 14px',
      borderRadius: 999, border: on ? '1px solid var(--ink)' : '1px solid var(--line)',
      background: on ? 'var(--ink)' : 'var(--surface)', color: on ? '#fff' : 'var(--ink-2)',
      fontSize: 14, fontWeight: 500, fontFamily: 'inherit', whiteSpace: 'nowrap', flex: 'none',
      transition: 'all .15s', ...style,
    }}>{children}</button>
  );
}

// ---- Photo placeholder (warm gradient + optional icon/label) ----
const PHOTO_GRADS = [
  'linear-gradient(145deg,#F3E4D2,#E7CDB6)',
  'linear-gradient(145deg,#DCEFE6,#BFE0D0)',
  'linear-gradient(145deg,#EDEBFB,#D8D4F2)',
  'linear-gradient(145deg,#FBE6EE,#F4C9DA)',
  'linear-gradient(145deg,#E6F1FB,#C7DDF2)',
  'linear-gradient(145deg,#FBF0D8,#F2DCA9)',
];
function Photo({ seed = 0, radius = 16, style, icon = 'baby', iconColor = 'rgba(255,255,255,.85)', label, children }) {
  return (
    <div style={{
      background: PHOTO_GRADS[seed % PHOTO_GRADS.length], borderRadius: radius,
      position: 'relative', overflow: 'hidden', display: 'grid', placeItems: 'center', ...style,
    }}>
      {!children && icon && <Icon name={icon} size={28} color={iconColor} stroke={1.6} />}
      {label && <span style={{ position: 'absolute', left: 10, bottom: 9, color: '#fff', fontSize: 12, fontWeight: 700, textShadow: '0 1px 4px rgba(0,0,0,.3)' }}>{label}</span>}
      {children}
    </div>
  );
}

// ---- Card ----
function Card({ children, pad = 18, flat = false, style, onClick }) {
  return (
    <div onClick={onClick} style={{
      background: 'var(--surface)', borderRadius: 22, padding: pad,
      boxShadow: flat ? 'none' : 'var(--sh-2)', border: flat ? '1px solid var(--line)' : 'none',
      ...style,
    }}>{children}</div>
  );
}

// ---- Section header ----
function SectionHead({ title, action, onAction, icon }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0 2px 12px' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
        {icon && <Icon name={icon} size={18} color="var(--ink-2)" />}
        <span style={{ fontSize: 18, fontWeight: 700, letterSpacing: '-0.01em' }}>{title}</span>
      </div>
      {action && <button onClick={onAction} style={{ fontSize: 13.5, fontWeight: 600, color: 'var(--ink-3)', fontFamily: 'inherit', display: 'flex', alignItems: 'center', gap: 2 }}>{action}<Icon name="chevron" size={14} color="var(--ink-3)" /></button>}
    </div>
  );
}

// ---- Press-scale button ----
function PressBtn({ children, onClick, style, scale = 0.97, className }) {
  const [p, setP] = useState(false);
  return (
    <button onClick={onClick} className={className}
      onPointerDown={() => setP(true)} onPointerUp={() => setP(false)} onPointerLeave={() => setP(false)}
      style={{ fontFamily: 'inherit', transition: 'transform .12s var(--ease)', transform: p ? `scale(${scale})` : 'scale(1)', ...style }}>
      {children}
    </button>
  );
}

Object.assign(window, { Icon, ICONS, Badge, BADGE_INK, BADGE_BG, Chip, Photo, PHOTO_GRADS, Card, SectionHead, PressBtn });
