// BabyLog · App shell — navigation, tab bar, push/sheet stack, frames
const { Icon, Badge, Chip, PressBtn } = window;

// ---- Headers (shared) ----
function PushHeader({ title, subtitle, ctx, right, transparent, dark }) {
  const ink = dark ? '#fff' : 'var(--ink)';
  return (
    <div style={{
      paddingTop: ctx.inset + 6, paddingBottom: 10, paddingLeft: 10, paddingRight: 14,
      display: 'flex', alignItems: 'center', gap: 6,
      background: transparent ? 'transparent' : (dark ? 'transparent' : 'var(--canvas)'),
      position: transparent ? 'absolute' : 'sticky', top: 0, left: 0, right: 0, zIndex: 20,
    }}>
      <button onClick={() => ctx.nav.back()} style={{ width: 40, height: 40, borderRadius: 999, display: 'grid', placeItems: 'center', fontFamily: 'inherit', background: transparent ? (dark ? 'rgba(0,0,0,.35)' : 'rgba(255,255,255,.85)') : 'transparent', backdropFilter: transparent ? 'blur(8px)' : 'none', boxShadow: transparent ? 'var(--sh-1)' : 'none' }}>
        <Icon name="arrowL" size={22} color={transparent && !dark ? 'var(--ink)' : ink} />
      </button>
      <div style={{ flex: 1, minWidth: 0 }}>
        {title && <div style={{ fontSize: 17, fontWeight: 800, color: ink, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{title}</div>}
        {subtitle && <div style={{ fontSize: 11.5, color: dark ? 'rgba(255,255,255,.6)' : 'var(--ink-3)' }}>{subtitle}</div>}
      </div>
      {right && <div style={{ width: 40, height: 40, display: 'grid', placeItems: 'center' }}>{right}</div>}
    </div>
  );
}
window.PushHeader = (props) => <PushHeader {...props} />;

// large tab header (no back)
function TabHeader({ title, ctx, right, sub }) {
  return (
    <div style={{ padding: `${ctx.inset}px 18px 8px`, display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between' }}>
      <div>
        {sub && <div style={{ fontSize: 12.5, color: 'var(--ink-3)', fontWeight: 600 }}>{sub}</div>}
        <div style={{ fontSize: 24, fontWeight: 800, letterSpacing: '-0.025em' }}>{title}</div>
      </div>
      {right}
    </div>
  );
}
window.TabHeader = (props) => <TabHeader {...props} />;

// ---- Bottom tab bar (5 even tabs) ----
const TABS = [
  { k: 'home', ic: 'home', l: '홈' },
  { k: 'record', ic: 'book', l: '기록' },
  { k: 'dongne', ic: 'pin', l: '동네' },
  { k: 'budget', ic: 'wallet', l: '가계부' },
  { k: 'profile', ic: 'user', l: '내정보' },
];
function TabBar({ tab, ctx }) {
  return (
    <div style={{ position: 'absolute', left: 0, right: 0, bottom: 0, zIndex: 40 }}>
      <div style={{ background: 'rgba(255,255,255,.94)', backdropFilter: 'blur(16px)', borderTop: '1px solid var(--line)', display: 'flex', padding: '8px 4px', paddingBottom: ctx.platform === 'ios' ? 26 : 14 }}>
        {TABS.map(t => (
          <button key={t.k} onClick={() => ctx.nav.tab(t.k)} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4, background: 'none', fontFamily: 'inherit', padding: '2px 0' }}>
            <Icon name={t.ic} size={23} color={tab === t.k ? 'var(--primary)' : 'var(--ink-3)'} stroke={tab === t.k ? 2.1 : 1.8} fill={false} />
            <span style={{ fontSize: 10, fontWeight: tab === t.k ? 700 : 600, color: tab === t.k ? 'var(--primary)' : 'var(--ink-3)' }}>{t.l}</span>
          </button>
        ))}
      </div>
    </div>
  );
}

// ---- Floating quick-record FAB (bottom-right / left) ----
function FloatingFAB({ ctx }) {
  const [open, setOpen] = React.useState(false);
  const side = ctx.fabSide === 'left' ? { left: 18 } : { right: 18 };
  const bottom = ctx.platform === 'ios' ? 96 : 84;
  const actions = ctx.mode === 'pregnancy'
    ? [['heart', '태동', 'quickRecord'], ['image', '배 사진', 'quickRecord'], ['edit', '메모', 'quickRecord']]
    : [['ruler', '성장 측정', 'quickRecord'], ['camera', '사진', 'quickRecord'], ['edit', '메모', 'quickRecord']];
  return (
    <>
      {open && <div onClick={() => setOpen(false)} style={{ position: 'absolute', inset: 0, zIndex: 41, background: 'rgba(28,24,19,.18)' }} />}
      <div style={{ position: 'absolute', bottom, ...side, zIndex: 43, display: 'flex', flexDirection: 'column', alignItems: ctx.fabSide === 'left' ? 'flex-start' : 'flex-end', gap: 12 }}>
        {open && actions.map((a, i) => (
          <button key={a[1]} onClick={() => { setOpen(false); ctx.nav.go(a[2]); }} style={{ display: 'flex', alignItems: 'center', gap: 9, flexDirection: ctx.fabSide === 'left' ? 'row-reverse' : 'row', background: 'none', fontFamily: 'inherit', animation: 'fabIn .2s var(--ease-out) both', animationDelay: `${i * 0.03}s` }}>
            <span style={{ fontSize: 13, fontWeight: 700, background: 'var(--surface)', padding: '6px 11px', borderRadius: 99, boxShadow: 'var(--sh-2)' }}>{a[1]}</span>
            <span style={{ width: 44, height: 44, borderRadius: 999, background: 'var(--surface)', boxShadow: 'var(--sh-2)', display: 'grid', placeItems: 'center' }}><Icon name={a[0]} size={21} color="var(--primary)" /></span>
          </button>
        ))}
        <button onClick={() => setOpen(o => !o)} className="bl-liquid" style={{ width: 58, height: 58, borderRadius: 999, background: 'var(--primary)', display: 'grid', placeItems: 'center', boxShadow: 'var(--sh-fab)', fontFamily: 'inherit', transition: 'transform .2s var(--ease)', transform: open ? 'rotate(45deg)' : 'none' }}>
          <Icon name="plus" size={28} color="#fff" stroke={2.5} />
        </button>
      </div>
    </>
  );
}

// ---- 동네 통합 탭 (주변 / 마켓 / 크루) ----
function DongneScreen({ ctx, initialSeg }) {
  const [seg, setSeg] = React.useState(initialSeg || 'nearby');
  const ctxAction = {
    nearby: { l: '응급', ic: 'vaccine', tone: 'var(--danger)', go: () => ctx.nav.go('emergency') },
    market: { l: '팔기', ic: 'camera', tone: 'var(--ink)', go: () => ctx.nav.go('sell') },
    crew: { l: '모임 만들기', ic: 'plus', tone: 'var(--ink)', go: () => {} },
  }[seg];
  return (
    <div>
      <div style={{ padding: `${ctx.inset}px 18px 10px`, display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div>
          <div style={{ fontSize: 24, fontWeight: 800, letterSpacing: '-0.025em' }}>동네</div>
          <div style={{ fontSize: 12.5, color: 'var(--ink-3)', marginTop: 2, display: 'flex', alignItems: 'center', gap: 4 }}><Icon name="pin" size={13} color="var(--ink-3)" />서울 마포구 망원동</div>
        </div>
        <button onClick={ctxAction.go} className={seg === 'nearby' ? 'bl-liquid' : undefined} style={{ display: 'flex', alignItems: 'center', gap: 5, height: 38, padding: '0 14px', borderRadius: 999, background: ctxAction.tone, color: '#fff', fontSize: 13, fontWeight: 700, fontFamily: 'inherit', boxShadow: seg === 'nearby' ? '0 4px 12px rgba(190,77,56,.3)' : 'none' }}>
          <Icon name={ctxAction.ic} size={15} color="#fff" />{ctxAction.l}
        </button>
      </div>
      {/* segment */}
      <div style={{ display: 'flex', gap: 4, padding: '0 18px 14px' }}>
        {[['nearby', '주변'], ['market', '마켓'], ['crew', '크루']].map(([k, l]) => (
          <button key={k} onClick={() => setSeg(k)} style={{ flex: 1, height: 38, borderRadius: 11, fontFamily: 'inherit', fontSize: 14, fontWeight: 700, background: seg === k ? 'var(--ink)' : 'var(--surface)', color: seg === k ? '#fff' : 'var(--ink-2)', boxShadow: seg === k ? 'none' : 'var(--sh-1)' }}>{l}</button>
        ))}
      </div>
      {seg === 'nearby' && <window.NearbyScreen ctx={ctx} embedded />}
      {seg === 'market' && <window.MarketScreen ctx={ctx} embedded />}
      {seg === 'crew' && <window.CrewScreen ctx={ctx} embedded />}
    </div>
  );
}
window.DongneScreen = DongneScreen;

// ---- screen registry ----
const PUSH = {
  emergency: window.EmergencyScreen, itemDetail: window.ItemDetail, hospitalDetail: window.HospitalDetail,
  chat: window.ChatScreen, pro: window.ProScreen, birthTransition: window.BirthTransition, shareCard: window.ShareCardScreen,
};
const SHEETS = { quickRecord: window.QuickRecordSheet, sell: window.SellSheet };
const TAB_NAMES = ['home', 'record', 'dongne', 'budget', 'profile'];

function AppContent({ state, setState, platform, inset }) {
  const nav = {
    tab: (k) => setState(s => ({ ...s, tab: k, stack: [], dongneSeg: 'nearby', recordSeg: 'timeline' })),
    go: (name, params) => {
      if (SHEETS[name]) setState(s => ({ ...s, sheet: { name, params } }));
      else if (TAB_NAMES.includes(name)) setState(s => ({ ...s, tab: name, stack: [] }));
      else if (name === 'market' || name === 'nearby' || name === 'crew') setState(s => ({ ...s, tab: 'dongne', dongneSeg: name, stack: [] }));
      else if (name === 'vaccine' || name === 'record') setState(s => ({ ...s, tab: 'record', recordSeg: name === 'vaccine' ? 'vaccine' : 'timeline', stack: [] }));
      else setState(s => ({ ...s, stack: [...s.stack, { name, params }] }));
    },
    back: () => setState(s => s.stack.length ? { ...s, stack: s.stack.slice(0, -1) } : s),
  };
  const children = window.BL_DATA.children;
  const child = children.find(c => c.id === state.childId) || children[0];
  const ctx = {
    nav, platform, inset, tweaks: state.tweaks, child, children, childId: state.childId, mode: state.mode, fabSide: state.fabSide,
    setChildId: (id) => setState(s => ({ ...s, childId: id })),
    setMode: (m) => setState(s => ({ ...s, mode: m })),
  };

  let tabEl;
  if (state.tab === 'home') tabEl = <window.HomeScreen ctx={ctx} />;
  else if (state.tab === 'record') tabEl = state.mode === 'pregnancy' ? <window.PregnancyScreen ctx={ctx} /> : <window.RecordScreen ctx={ctx} asTab key={state.recordSeg} params={{ tab: state.recordSeg }} />;
  else if (state.tab === 'dongne') tabEl = <DongneScreen ctx={ctx} initialSeg={state.dongneSeg} key={state.dongneSeg} />;
  else if (state.tab === 'budget') tabEl = <window.BudgetScreen ctx={ctx} asTab />;
  else tabEl = <window.ProfileScreen ctx={ctx} />;

  const showFab = ['home', 'record', 'dongne'].includes(state.tab);

  return (
    <div style={{ position: 'relative', height: '100%', overflow: 'hidden', background: 'var(--canvas)' }}>
      <div className="bl-scroll" style={{ position: 'absolute', inset: 0, overflowY: 'auto', overflowX: 'hidden' }}>
        <div style={{ paddingBottom: 96 }}>{tabEl}</div>
      </div>

      {showFab && <FloatingFAB ctx={ctx} />}
      <TabBar tab={state.tab} ctx={ctx} />

      {state.stack.map((scr, i) => {
        const Comp = PUSH[scr.name];
        return (
          <div key={i} className="bl-push" style={{ position: 'absolute', inset: 0, zIndex: 50 + i, overflowY: 'auto', background: scr.name === 'emergency' || scr.name === 'pro' || scr.name === 'shareCard' ? '#15110E' : 'var(--canvas)', animation: 'pushIn .28s var(--ease-out)' }}>
            <Comp ctx={ctx} params={scr.params} />
          </div>
        );
      })}

      {state.sheet && (() => { const SheetComp = SHEETS[state.sheet.name]; return <SheetComp ctx={ctx} onClose={() => setState(s => ({ ...s, sheet: null }))} params={state.sheet.params} />; })()}
    </div>
  );
}

// ---- Root: control bar + iOS & Android frames ----
function Root() {
  const [onboarded, setOnboarded] = React.useState(true);
  const [platform, setPlatform] = React.useState('ios');
  const [state, setState] = React.useState({
    tab: 'home', stack: [], sheet: null, childId: 'c1', mode: 'baby', fabSide: 'right',
    dongneSeg: 'nearby', recordSeg: 'timeline',
    tweaks: { homeLayout: 'A', recordMode: 'light', crewDensity: 'active', onboardTone: 'warm' },
  });
  const setTweak = (k, v) => setState(s => ({ ...s, tweaks: { ...s.tweaks, [k]: v } }));
  const setMode = (m) => setState(s => ({ ...s, mode: m, tab: m === 'pregnancy' ? 'record' : 'home' }));
  const setFab = (v) => setState(s => ({ ...s, fabSide: v }));

  const frame = (plat) => {
    const inset = plat === 'ios' ? 48 : 12;
    const Device = plat === 'ios' ? window.IOSDevice : window.AndroidDevice;
    const inner = onboarded
      ? <AppContent state={state} setState={setState} platform={plat} inset={inset} />
      : <div style={{ height: '100%', overflow: 'auto' }}><window.Onboarding tweaks={state.tweaks} onDone={() => setOnboarded(true)} setMode={setMode} /></div>;
    return (
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 12 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 7, fontSize: 12, fontWeight: 700, color: 'var(--ink-3)', letterSpacing: '.04em' }}>
          <Icon name={plat === 'ios' ? 'heart' : 'grid'} size={13} color="var(--ink-3)" />{plat === 'ios' ? 'iOS' : 'ANDROID'}
        </div>
        <Device>{inner}</Device>
      </div>
    );
  };

  return (
    <div style={{ minHeight: '100vh', background: '#E8E3D9', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
      <ControlBar {...{ platform, setPlatform, state, setTweak, setMode, setFab, onboarded, setOnboarded }} />
      <div style={{ display: 'flex', gap: 40, padding: '24px 28px 64px', justifyContent: 'center', flexWrap: 'wrap', alignItems: 'flex-start' }}>
        {(platform === 'both' || platform === 'ios') && frame('ios')}
        {(platform === 'both' || platform === 'android') && frame('android')}
      </div>
    </div>
  );
}

function Seg({ opts, val, onChange }) {
  return (
    <div style={{ display: 'inline-flex', background: 'var(--surface-3)', borderRadius: 10, padding: 3, gap: 2 }}>
      {opts.map(([k, l]) => (
        <button key={k} onClick={() => onChange(k)} style={{ height: 28, padding: '0 11px', borderRadius: 8, fontSize: 12.5, fontWeight: 700, fontFamily: 'inherit', background: val === k ? 'var(--surface)' : 'transparent', color: val === k ? 'var(--ink)' : 'var(--ink-3)', boxShadow: val === k ? 'var(--sh-1)' : 'none' }}>{l}</button>
      ))}
    </div>
  );
}

function ControlBar({ platform, setPlatform, state, setTweak, setMode, setFab, onboarded, setOnboarded }) {
  const grp = (label, children) => (
    <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
      <span style={{ fontSize: 10.5, fontWeight: 700, color: 'var(--ink-3)', letterSpacing: '.05em', textTransform: 'uppercase' }}>{label}</span>
      {children}
    </div>
  );
  return (
    <div style={{ width: '100%', position: 'sticky', top: 0, zIndex: 100, background: 'rgba(244,239,230,.9)', backdropFilter: 'blur(14px)', borderBottom: '1px solid var(--line-2)' }}>
      <div style={{ maxWidth: 1180, margin: '0 auto', padding: '12px 24px', display: 'flex', alignItems: 'center', gap: 16, flexWrap: 'wrap' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 9 }}>
          <span style={{ width: 30, height: 30, borderRadius: 9, background: 'linear-gradient(150deg,var(--primary),#3F6B55)', display: 'grid', placeItems: 'center' }}>
            <svg viewBox="0 0 24 24" width="17" height="17" fill="none"><path d="M12 21s-7-4.4-7-9.6C5 8.4 7.2 6.5 9.4 6.5c1.5 0 2.4.7 2.6 1.9.2-1.2 1.1-1.9 2.6-1.9C16.8 6.5 19 8.4 19 11.4 19 16.6 12 21 12 21z" fill="#fff"/></svg>
          </span>
          <span style={{ fontSize: 16, fontWeight: 800, letterSpacing: '-0.02em' }}>BabyLog <span style={{ fontWeight: 600, color: 'var(--ink-3)', fontSize: 13 }}>프로토타입 v2</span></span>
        </div>
        <div style={{ flex: 1 }} />
        <div style={{ display: 'flex', alignItems: 'center', gap: 14, flexWrap: 'wrap' }}>
          {grp('기기', <Seg opts={[['both', '둘 다'], ['ios', 'iOS'], ['android', 'Android']]} val={platform} onChange={setPlatform} />)}
          {grp('모드', <Seg opts={[['baby', '육아중'], ['pregnancy', '임신중']]} val={state.mode} onChange={setMode} />)}
          {grp('홈', <Seg opts={[['A', '히어로'], ['B', '대시보드'], ['C', '타임라인']]} val={state.tweaks.homeLayout} onChange={v => setTweak('homeLayout', v)} />)}
          {grp('기록', <Seg opts={[['light', '초경량'], ['detail', '상세']]} val={state.tweaks.recordMode} onChange={v => setTweak('recordMode', v)} />)}
          {grp('크루', <Seg opts={[['active', '활성'], ['cold', '오픈전']]} val={state.tweaks.crewDensity} onChange={v => setTweak('crewDensity', v)} />)}
          {grp('FAB', <Seg opts={[['right', '우'], ['left', '좌']]} val={state.fabSide} onChange={setFab} />)}
          <button onClick={() => setOnboarded(!onboarded)} style={{ height: 32, padding: '0 14px', borderRadius: 9, background: onboarded ? 'var(--ink)' : 'var(--primary)', color: '#fff', fontSize: 12.5, fontWeight: 700, fontFamily: 'inherit' }}>{onboarded ? '온보딩 보기' : '앱으로'}</button>
        </div>
      </div>
    </div>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<Root />);
