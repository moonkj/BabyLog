// BabyLog · Nearby infra + Emergency mode (dark high-contrast)
const { Icon, Badge, Chip, Photo, Card, SectionHead, PressBtn } = window;

function NearbyScreen({ ctx, embedded }) {
  const [cat, setCat] = React.useState('소아과');
  const [view, setView] = React.useState('list');
  const [filters, setFilters] = React.useState(['현재 영업중']);
  const cats = ['소아과', '약국', '키즈카페', '놀이터'];
  const filterOpts = cat === '소아과' ? ['현재 영업중', '야간진료', '공휴일진료'] : cat === '약국' ? ['현재 영업중', '24시간', '야간약국'] : cat === '키즈카페' ? ['0-2세', '3-5세', '6세+'] : ['실내', '실외'];
  const toggle = f => setFilters(p => p.includes(f) ? p.filter(x => x !== f) : [...p, f]);
  const list = window.BL_DATA.hospitals.filter(h => h.type === cat);
  return (
    <div style={{ paddingBottom: 24 }}>
      {embedded ? (
        <div style={{ display: 'flex', justifyContent: 'flex-end', padding: '0 18px 10px' }}>
          <div style={{ display: 'flex', gap: 6, background: 'var(--surface)', borderRadius: 12, padding: 3, boxShadow: 'var(--sh-1)' }}>
            {[['list', 'list'], ['map', 'map']].map(([k, ic]) => <button key={k} onClick={() => setView(k)} style={{ width: 38, height: 32, borderRadius: 9, background: view === k ? 'var(--ink)' : 'transparent', display: 'grid', placeItems: 'center', fontFamily: 'inherit' }}><Icon name={ic} size={18} color={view === k ? '#fff' : 'var(--ink-3)'} /></button>)}
          </div>
        </div>
      ) : (
      <div style={{ padding: `${ctx.inset}px 18px 12px`, display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div><div style={{ fontSize: 24, fontWeight: 800, letterSpacing: '-0.025em' }}>내 주변</div><div style={{ fontSize: 12.5, color: 'var(--ink-3)', marginTop: 2, display: 'flex', alignItems: 'center', gap: 4 }}><Icon name="pin" size={13} color="var(--ink-3)" />서울 마포구 망원동</div></div>
        <div style={{ display: 'flex', gap: 6, background: 'var(--surface)', borderRadius: 12, padding: 3, boxShadow: 'var(--sh-1)' }}>
          {[['list', 'list'], ['map', 'map']].map(([k, ic]) => <button key={k} onClick={() => setView(k)} style={{ width: 38, height: 32, borderRadius: 9, background: view === k ? 'var(--ink)' : 'transparent', display: 'grid', placeItems: 'center', fontFamily: 'inherit' }}><Icon name={ic} size={18} color={view === k ? '#fff' : 'var(--ink-3)'} /></button>)}
        </div>
      </div>
      )}

      {/* Emergency CTA */}
      <div style={{ padding: '0 18px 14px' }}>
        <PressBtn onClick={() => ctx.nav.go('emergency')} className="bl-liquid" style={{ display: 'block', width: '100%' }}>
          <div style={{ background: 'linear-gradient(135deg,#2A211D,#1A1512)', borderRadius: 18, padding: '14px 16px', display: 'flex', alignItems: 'center', gap: 13, boxShadow: '0 8px 20px rgba(40,33,24,.22)' }}>
            <div style={{ width: 44, height: 44, borderRadius: 12, background: 'var(--danger)', display: 'grid', placeItems: 'center', flex: 'none' }}><Icon name="vaccine" size={22} color="#fff" /></div>
            <div style={{ flex: 1 }}><div style={{ fontSize: 15.5, fontWeight: 800, color: '#fff' }}>응급 모드</div><div style={{ fontSize: 12.5, color: 'rgba(255,255,255,.6)', marginTop: 1 }}>지금 갈 수 있는 소아과를 한 번에</div></div>
            <Icon name="chevron" size={20} color="rgba(255,255,255,.5)" />
          </div>
        </PressBtn>
      </div>

      {/* category */}
      <div style={{ display: 'flex', gap: 8, padding: '0 18px 12px', overflowX: 'auto' }}>
        {cats.map(c => <Chip key={c} on={cat === c} onClick={() => { setCat(c); setFilters([filterOpts[0]]); }}>{c}</Chip>)}
      </div>
      {/* filters */}
      <div style={{ display: 'flex', gap: 7, padding: '0 18px 14px', overflowX: 'auto' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 5, height: 36, padding: '0 12px', borderRadius: 999, background: 'var(--surface-2)', border: '1px solid var(--line)', color: 'var(--ink-3)', fontSize: 13, fontWeight: 600, flex: 'none' }}><Icon name="filter" size={14} color="var(--ink-3)" /></div>
        {filterOpts.map(f => <Chip key={f} on={filters.includes(f)} onClick={() => toggle(f)} style={filters.includes(f) ? { background: 'var(--primary)', borderColor: 'var(--primary)' } : {}}>{f}</Chip>)}
      </div>

      {view === 'map' && <MapView list={list} ctx={ctx} />}
      {view === 'list' && (
        <div style={{ padding: '0 18px', display: 'flex', flexDirection: 'column', gap: 11 }}>
          <div style={{ fontSize: 12.5, color: 'var(--ink-3)', fontWeight: 600, padding: '0 2px 2px' }}>현재 영업중 {list.filter(h => h.open).length}곳 · 거리순</div>
          {list.map(h => <HospitalCard key={h.id} h={h} ctx={ctx} />)}
        </div>
      )}
    </div>
  );
}

function MapView({ list, ctx }) {
  return (
    <div style={{ padding: '0 18px' }}>
      <div style={{ position: 'relative', height: 260, borderRadius: 20, overflow: 'hidden', background: 'linear-gradient(160deg,#E8EDE6,#DDE6DC)', boxShadow: 'var(--sh-2)' }}>
        {/* stylized streets */}
        <svg viewBox="0 0 340 260" style={{ position: 'absolute', inset: 0, width: '100%', height: '100%' }}>
          <rect width="340" height="260" fill="#E6ECE4" />
          {[40, 110, 180, 230].map(y => <line key={y} x1="0" y1={y} x2="340" y2={y} stroke="#fff" strokeWidth="8" opacity=".7" />)}
          {[60, 150, 250, 310].map(x => <line key={x} x1={x} y1="0" x2={x} y2="260" stroke="#fff" strokeWidth="8" opacity=".7" />)}
          <rect x="150" y="110" width="100" height="40" fill="#DFE9DD" />
        </svg>
        {/* pins */}
        {[{ x: 58, y: 35, c: 'var(--danger)' }, { x: 70, y: 60, c: 'var(--primary)' }, { x: 56, y: 52, c: 'var(--primary)' }].map((p, i) => (
          <div key={i} style={{ position: 'absolute', left: p.x + '%', top: p.y + '%', transform: 'translate(-50%,-100%)' }}>
            <div style={{ width: 32, height: 32, borderRadius: '50% 50% 50% 0', background: p.c, transform: 'rotate(-45deg)', display: 'grid', placeItems: 'center', boxShadow: 'var(--sh-2)' }}><Icon name="pin" size={15} color="#fff" style={{ transform: 'rotate(45deg)' }} /></div>
          </div>
        ))}
        <div style={{ position: 'absolute', left: '50%', top: '72%', transform: 'translate(-50%,-50%)', width: 16, height: 16, borderRadius: 99, background: '#3B6FA8', border: '3px solid #fff', boxShadow: '0 0 0 6px rgba(59,111,168,.2)' }} />
      </div>
      <div style={{ marginTop: 12 }}><HospitalCard h={list[0]} ctx={ctx} /></div>
    </div>
  );
}

function HospitalCard({ h, ctx }) {
  return (
    <PressBtn onClick={() => ctx.nav.go('hospitalDetail', h)} scale={0.99} style={{ display: 'block', textAlign: 'left' }}>
      <Card pad={15}>
        <div style={{ display: 'flex', gap: 12 }}>
          <div style={{ width: 48, height: 48, borderRadius: 13, background: h.type === '키즈카페' ? 'var(--badge-pink)' : h.type === '약국' ? 'var(--badge-mint)' : 'var(--badge-coral)', display: 'grid', placeItems: 'center', flex: 'none' }}>
            <Icon name={h.type === '키즈카페' ? 'heart' : h.type === '약국' ? 'pillbox' : 'vaccine'} size={23} color={h.type === '키즈카페' ? '#B5478A' : h.type === '약국' ? '#2E7A5C' : '#B45840'} />
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 7 }}>
              <span style={{ fontSize: 15.5, fontWeight: 700 }}>{h.name}</span>
              {h.open ? <Badge tone="mint" dot small>영업중</Badge> : <Badge tone="grey" small>영업종료</Badge>}
            </div>
            <div className="t-num" style={{ fontSize: 12.5, color: 'var(--ink-2)', marginTop: 4, display: 'flex', alignItems: 'center', gap: 8 }}>
              <span>{h.dist}m</span><span>·</span><span style={{ display: 'flex', alignItems: 'center', gap: 2 }}><Icon name="star" size={12} color="var(--gold)" fill />{h.rating}</span>
              {h.night && <><span>·</span><span style={{ color: 'var(--badge-purple-ink)' }}>야간진료</span></>}
            </div>
            {h.confirm && (
              <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 8 }}>
                <Badge tone={h.trust === 'high' ? 'mint' : 'amber'} small><Icon name="clock" size={11} color={h.trust === 'high' ? '#2E7A5C' : '#98711E'} />{h.confirm} 확인</Badge>
                <span style={{ fontSize: 11, color: 'var(--ink-3)' }}>신뢰도 {h.trust === 'high' ? '높음' : '보통'}</span>
              </div>
            )}
          </div>
          <div onClick={e => { e.stopPropagation(); }} style={{ width: 44, height: 44, borderRadius: 13, background: 'var(--primary)', display: 'grid', placeItems: 'center', flex: 'none', alignSelf: 'center' }}><Icon name="phone" size={20} color="#fff" /></div>
        </div>
      </Card>
    </PressBtn>
  );
}

function HospitalDetail({ ctx, params }) {
  const h = params;
  return (
    <div style={{ minHeight: '100%', background: 'var(--canvas)' }}>
      {window.PushHeader({ title: '', ctx, transparent: true })}
      <div style={{ padding: '0 18px 28px', marginTop: -8 }}>
        <Photo seed={2} radius={20} icon="vaccine" iconColor="rgba(255,255,255,.8)" style={{ height: 150, marginBottom: 16 }} />
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}><h1 style={{ margin: 0, fontSize: 23, fontWeight: 800 }}>{h.name}</h1>{h.open && <Badge tone="mint" dot>영업중</Badge>}</div>
        <div className="t-num" style={{ fontSize: 13.5, color: 'var(--ink-2)', marginTop: 6 }}>{h.addr} · {h.dist}m</div>
        <div style={{ display: 'flex', gap: 10, marginTop: 16 }}>
          <ActionBtn icon="phone" label="전화" primary />
          <ActionBtn icon="map" label="길찾기" />
          <ActionBtn icon="bookmark" label="즐겨찾기" />
        </div>
        <Card pad={16} style={{ marginTop: 16 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}><span style={{ fontSize: 15, fontWeight: 700 }}>영업 정보</span><Badge tone="mint" small><Icon name="clock" size={11} color="#2E7A5C" />{h.confirm} 확인</Badge></div>
          {[['오늘', '09:00 - 21:00', true], ['야간진료', '~22:00', true], ['공휴일', '휴무', false]].map(([k, v, on]) => (
            <div key={k} style={{ display: 'flex', justifyContent: 'space-between', padding: '8px 0', borderBottom: '1px solid var(--line)' }}><span style={{ fontSize: 14, color: 'var(--ink-2)' }}>{k}</span><span className="t-num" style={{ fontSize: 14, fontWeight: 600, color: on ? 'var(--ink)' : 'var(--ink-3)' }}>{v}</span></div>
          ))}
          <button style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6, width: '100%', height: 42, marginTop: 12, borderRadius: 11, background: 'var(--surface-2)', border: '1px solid var(--line)', color: 'var(--ink-2)', fontSize: 13, fontWeight: 600, fontFamily: 'inherit' }}><Icon name="warning" size={15} color="var(--ink-3)" />지금 문 닫혔어요 신고</button>
        </Card>
        <div style={{ fontSize: 11.5, color: 'var(--ink-3)', lineHeight: '17px', marginTop: 14, textAlign: 'center' }}>영업 정보는 공공데이터 + 카카오맵 기반이며 실시간과 다를 수 있어요.<br/>방문 전 전화 확인을 권장합니다.</div>
      </div>
    </div>
  );
}

function ActionBtn({ icon, label, primary }) {
  return <button className={primary ? 'bl-liquid' : undefined} style={{ flex: 1, height: 64, borderRadius: 15, background: primary ? 'var(--primary)' : 'var(--surface)', boxShadow: primary ? 'none' : 'var(--sh-1)', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 4, fontFamily: 'inherit' }}><Icon name={icon} size={21} color={primary ? '#fff' : 'var(--ink-2)'} /><span style={{ fontSize: 12, fontWeight: 700, color: primary ? '#fff' : 'var(--ink-2)' }}>{label}</span></button>;
}

// ---------- EMERGENCY MODE (dark, high-contrast) ----------
function EmergencyScreen({ ctx }) {
  const list = window.BL_DATA.hospitals.filter(h => h.type === '소아과' && h.open);
  return (
    <div style={{ minHeight: '100%', background: '#15110E', color: '#fff', display: 'flex', flexDirection: 'column' }}>
      <div style={{ padding: `${ctx.inset + 8}px 20px 16px`, display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}><span style={{ width: 9, height: 9, borderRadius: 99, background: '#FF5C42', boxShadow: '0 0 0 5px rgba(255,92,66,.25)', animation: 'pulse 1.6s infinite' }} /><span style={{ fontSize: 13, fontWeight: 700, letterSpacing: '.04em', color: '#FF8A72' }}>응급 모드</span></div>
          <div style={{ fontSize: 27, fontWeight: 800, letterSpacing: '-0.02em', marginTop: 8 }}>지금 갈 수 있는 곳</div>
          <div style={{ fontSize: 14, color: 'rgba(255,255,255,.55)', marginTop: 5 }}>망원동 기준 · 현재 영업중 · 거리순</div>
        </div>
        <button onClick={() => ctx.nav.back()} style={{ width: 44, height: 44, borderRadius: 13, background: 'rgba(255,255,255,.1)', display: 'grid', placeItems: 'center', fontFamily: 'inherit' }}><Icon name="close" size={22} color="#fff" /></button>
      </div>

      <div style={{ flex: 1, padding: '8px 16px 24px', display: 'flex', flexDirection: 'column', gap: 14 }}>
        {list.map((h, i) => (
          <div key={h.id} style={{ background: i === 0 ? 'rgba(255,92,66,.12)' : 'rgba(255,255,255,.06)', border: i === 0 ? '1.5px solid rgba(255,138,114,.4)' : '1px solid rgba(255,255,255,.1)', borderRadius: 22, padding: 18 }}>
            <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between' }}>
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: 21, fontWeight: 800, letterSpacing: '-0.01em' }}>{h.name}</div>
                <div className="t-num" style={{ fontSize: 15, color: 'rgba(255,255,255,.7)', marginTop: 6, display: 'flex', alignItems: 'center', gap: 10 }}>
                  <span>🚶 {h.dist}m</span>{h.night && <span style={{ color: '#A9C8FF' }}>야간진료</span>}
                </div>
                <div style={{ display: 'inline-flex', alignItems: 'center', gap: 5, marginTop: 10, background: 'rgba(255,255,255,.08)', padding: '4px 10px', borderRadius: 99, fontSize: 12.5, color: 'rgba(255,255,255,.7)' }}><Icon name="clock" size={12} color="rgba(255,255,255,.7)" />{h.confirm} 확인 · 전화로 다시 확인하세요</div>
              </div>
              {i === 0 && <span style={{ fontSize: 11, fontWeight: 800, color: '#15110E', background: '#FF8A72', padding: '4px 9px', borderRadius: 99 }}>가장 가까움</span>}
            </div>
            <div style={{ display: 'flex', gap: 10, marginTop: 16 }}>
              <button className="bl-liquid" style={{ flex: 1, height: 60, borderRadius: 16, background: '#FF5C42', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 9, fontFamily: 'inherit', boxShadow: '0 6px 16px rgba(255,92,66,.35)' }}><Icon name="phone" size={24} color="#fff" /><span style={{ fontSize: 19, fontWeight: 800, color: '#fff' }}>전화하기</span></button>
              <button style={{ width: 60, height: 60, borderRadius: 16, background: 'rgba(255,255,255,.12)', display: 'grid', placeItems: 'center', fontFamily: 'inherit' }}><Icon name="map" size={24} color="#fff" /></button>
            </div>
          </div>
        ))}
        <button style={{ height: 54, borderRadius: 16, background: 'rgba(255,255,255,.07)', color: 'rgba(255,255,255,.85)', fontSize: 16, fontWeight: 700, fontFamily: 'inherit', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8 }}><Icon name="phone" size={20} color="#fff" />119 구급 상담</button>
        <div style={{ textAlign: 'center', fontSize: 12, color: 'rgba(255,255,255,.4)', lineHeight: '18px', marginTop: 4 }}>위급 상황 시 망설이지 말고 119에 연락하세요.<br/>영업 정보는 실시간과 다를 수 있어 전화 확인이 가장 정확합니다.</div>
      </div>
    </div>
  );
}

Object.assign(window, { NearbyScreen, HospitalDetail, EmergencyScreen });
