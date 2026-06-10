// BabyLog · 성장 카드 공유 (기능 2.4) — 인스타용 바이럴 카드 에디터
const { Icon, Badge, Chip, Photo, Card, PressBtn } = window;

const ASPECTS = { '4:5': 320 / 400, '1:1': 1, '9:16': 320 / 569 };

function ShareCardScreen({ ctx }) {
  const { child } = ctx;
  const [aspect, setAspect] = React.useState('4:5');
  const [pos, setPos] = React.useState('bl');
  const [fields, setFields] = React.useState({ ...window.BL_DATA.shareCardFields });
  const [blur, setBlur] = React.useState(false);
  const [wm, setWm] = React.useState(true);
  const toggle = k => setFields(f => ({ ...f, [k]: !f[k] }));

  const W = 300;
  const H = Math.round(W / ASPECTS[aspect]);
  const posStyle = {
    bl: { left: 16, bottom: 16, textAlign: 'left' }, br: { right: 16, bottom: 16, textAlign: 'right' },
    tl: { left: 16, top: 16, textAlign: 'left' }, bc: { left: 0, right: 0, bottom: 16, textAlign: 'center' },
  }[pos];

  return (
    <div style={{ minHeight: '100%', background: '#15110E', color: '#fff', display: 'flex', flexDirection: 'column' }}>
      {window.PushHeader({ title: '성장 카드', ctx, dark: true })}
      <div style={{ flex: 1, overflowY: 'auto', padding: '4px 20px 20px' }}>
        {/* preview */}
        <div style={{ display: 'grid', placeItems: 'center', padding: '6px 0 18px' }}>
          <div style={{ width: W, height: H, borderRadius: 18, overflow: 'hidden', position: 'relative', boxShadow: '0 20px 50px rgba(0,0,0,.5)' }}>
            <Photo seed={child.seed} radius={0} icon={null} style={{ position: 'absolute', inset: 0, filter: blur ? 'none' : 'none' }} />
            {blur && <div style={{ position: 'absolute', left: '50%', top: '34%', transform: 'translate(-50%,-50%)', width: 70, height: 70, borderRadius: 999, background: 'rgba(255,255,255,.25)', backdropFilter: 'blur(12px)', display: 'grid', placeItems: 'center', fontSize: 30 }}>🙂</div>}
            <div style={{ position: 'absolute', inset: 0, background: pos === 'tl' ? 'linear-gradient(180deg,rgba(0,0,0,.5),rgba(0,0,0,0) 45%)' : 'linear-gradient(180deg,rgba(0,0,0,0) 45%,rgba(0,0,0,.62))' }} />
            {pos !== 'none' && (
              <div style={{ position: 'absolute', color: '#fff', ...posStyle }}>
                {fields.milestone && <div style={{ display: 'inline-block', fontSize: 11, fontWeight: 700, background: 'rgba(255,255,255,.22)', backdropFilter: 'blur(4px)', padding: '3px 9px', borderRadius: 99, marginBottom: 8 }}>첫 걸음마</div>}
                <div style={{ fontSize: 23, fontWeight: 800, letterSpacing: '-0.02em', lineHeight: 1.1 }}>{child.name}</div>
                <div className="t-num" style={{ display: 'flex', gap: 10, marginTop: 6, justifyContent: pos === 'br' ? 'flex-end' : pos === 'bc' ? 'center' : 'flex-start', flexWrap: 'wrap' }}>
                  {fields.monthAge && <span style={{ fontSize: 13, fontWeight: 600 }}>{child.months}개월 · D+{child.dday}</span>}
                  {fields.height && <span style={{ fontSize: 13, fontWeight: 600 }}>{child.height}cm</span>}
                  {fields.weight && <span style={{ fontSize: 13, fontWeight: 600 }}>{child.weight}kg</span>}
                  {fields.percentile && <span style={{ fontSize: 13, fontWeight: 600 }}>상위 42%</span>}
                </div>
              </div>
            )}
            {wm && <div style={{ position: 'absolute', right: 12, top: 12, display: 'flex', alignItems: 'center', gap: 4, opacity: .9 }}><span style={{ width: 16, height: 16, borderRadius: 5, background: 'var(--primary)', display: 'grid', placeItems: 'center' }}><svg viewBox="0 0 24 24" width="10" height="10" fill="none"><path d="M12 21s-7-4.4-7-9.6C5 8.4 7.2 6.5 9.4 6.5c1.5 0 2.4.7 2.6 1.9.2-1.2 1.1-1.9 2.6-1.9C16.8 6.5 19 8.4 19 11.4 19 16.6 12 21 12 21z" fill="#fff"/></svg></span><span style={{ fontSize: 11, fontWeight: 800, color: '#fff', textShadow: '0 1px 3px rgba(0,0,0,.4)' }}>BabyLog</span></div>}
          </div>
        </div>

        {/* controls */}
        <CtrlGroup label="비율">
          {Object.keys(ASPECTS).map(a => <DChip key={a} on={aspect === a} onClick={() => setAspect(a)}>{a}</DChip>)}
        </CtrlGroup>
        <CtrlGroup label="데이터 위치">
          {[['bl', '좌하'], ['br', '우하'], ['tl', '좌상'], ['bc', '중하'], ['none', '없음']].map(([k, l]) => <DChip key={k} on={pos === k} onClick={() => setPos(k)}>{l}</DChip>)}
        </CtrlGroup>
        <CtrlGroup label="표시할 데이터">
          {[['height', '키'], ['weight', '몸무게'], ['monthAge', '월령·D+day'], ['percentile', '또래 백분위'], ['milestone', '이정표']].map(([k, l]) => <DChip key={k} on={fields[k]} onClick={() => toggle(k)}>{l}</DChip>)}
        </CtrlGroup>

        {/* privacy */}
        <div style={{ background: 'rgba(255,255,255,.06)', borderRadius: 16, padding: 4, marginTop: 18 }}>
          <DToggle label="얼굴 가리기" sub="블러로 비공개" on={blur} onClick={() => setBlur(!blur)} icon="user" />
          <div style={{ height: 1, background: 'rgba(255,255,255,.08)', margin: '0 14px' }} />
          <DToggle label="워터마크" sub={wm ? 'BabyLog 로고 표시 (무료)' : 'Pro · 로고 제거됨'} on={wm} onClick={() => setWm(!wm)} icon="sparkle" pro={!wm} />
        </div>

        <button className="bl-liquid" style={{ width: '100%', height: 54, borderRadius: 16, background: 'var(--primary)', color: '#fff', fontSize: 16, fontWeight: 700, fontFamily: 'inherit', marginTop: 18, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8 }}><Icon name="share" size={20} color="#fff" />공유하기</button>
        <div style={{ textAlign: 'center', fontSize: 11.5, color: 'rgba(255,255,255,.4)', marginTop: 12, lineHeight: '17px' }}>워터마크가 곧 자연 바이럴이 돼요.<br/>친구가 보고 "이 앱 뭐야?" → 동네 유입</div>
      </div>
    </div>
  );
}

function CtrlGroup({ label, children }) {
  return (
    <div style={{ marginTop: 16 }}>
      <div style={{ fontSize: 11, fontWeight: 700, color: 'rgba(255,255,255,.5)', letterSpacing: '.05em', textTransform: 'uppercase', marginBottom: 9 }}>{label}</div>
      <div style={{ display: 'flex', gap: 7, flexWrap: 'wrap' }}>{children}</div>
    </div>
  );
}
function DChip({ on, children, onClick }) {
  return <button onClick={onClick} style={{ height: 36, padding: '0 15px', borderRadius: 999, fontFamily: 'inherit', fontSize: 13.5, fontWeight: 600, background: on ? '#fff' : 'rgba(255,255,255,.08)', color: on ? '#15110E' : 'rgba(255,255,255,.7)', border: 'none' }}>{children}</button>;
}
function DToggle({ label, sub, on, onClick, icon, pro }) {
  return (
    <button onClick={onClick} style={{ width: '100%', display: 'flex', alignItems: 'center', gap: 12, padding: '12px 14px', background: 'none', fontFamily: 'inherit', textAlign: 'left' }}>
      <div style={{ width: 36, height: 36, borderRadius: 10, background: 'rgba(255,255,255,.08)', display: 'grid', placeItems: 'center', flex: 'none' }}><Icon name={icon} size={19} color="#E3B85C" /></div>
      <div style={{ flex: 1 }}><div style={{ fontSize: 14.5, fontWeight: 600, color: '#fff', display: 'flex', alignItems: 'center', gap: 6 }}>{label}{pro && <span style={{ fontSize: 9.5, fontWeight: 800, color: '#15110E', background: '#E3B85C', padding: '1px 6px', borderRadius: 99 }}>PRO</span>}</div><div style={{ fontSize: 12, color: 'rgba(255,255,255,.5)', marginTop: 1 }}>{sub}</div></div>
      <div style={{ width: 46, height: 28, borderRadius: 99, background: on ? 'var(--primary)' : 'rgba(255,255,255,.18)', padding: 3, transition: 'background .2s', flex: 'none' }}><div style={{ width: 22, height: 22, borderRadius: 99, background: '#fff', transform: on ? 'translateX(18px)' : 'translateX(0)', transition: 'transform .2s' }} /></div>
    </button>
  );
}

Object.assign(window, { ShareCardScreen });
