// BabyLog · Home screen  (3 layout variations via ctx.tweaks.homeLayout)
const { Icon, Badge, Chip, Photo, Card, SectionHead, PressBtn } = window;

function ChildSwitcher({ ctx }) {
  const { children, childId, setChildId, nav } = ctx;
  return (
    <div style={{ display: 'flex', gap: 8, alignItems: 'center', padding: '0 18px', marginBottom: 14 }}>
      {children.map(c => {
        const on = c.id === childId;
        return (
          <button key={c.id} onClick={() => setChildId(c.id)} style={{
            display: 'flex', alignItems: 'center', gap: 8, height: 40, padding: on ? '0 14px 0 6px' : '0 6px',
            borderRadius: 999, border: on ? '1px solid var(--line-2)' : '1px solid transparent',
            background: on ? 'var(--surface)' : 'transparent', fontFamily: 'inherit',
            boxShadow: on ? 'var(--sh-1)' : 'none', transition: 'all .2s',
          }}>
            <span style={{ width: 30, height: 30, borderRadius: 999, background: window.PHOTO_GRADS[c.seed % 6], display: 'grid', placeItems: 'center', fontSize: 15 }}>{c.emoji}</span>
            {on && <span style={{ fontSize: 14.5, fontWeight: 700 }}>{c.name}</span>}
          </button>
        );
      })}
      <button onClick={() => nav.go('addChild')} style={{ width: 40, height: 40, borderRadius: 999, border: '1px dashed var(--line-2)', background: 'transparent', display: 'grid', placeItems: 'center', fontFamily: 'inherit' }}>
        <Icon name="plus" size={18} color="var(--ink-3)" />
      </button>
    </div>
  );
}

// The single highest-priority card (priority engine output)
function PriorityCard({ ctx, compact }) {
  const { child, nav } = ctx;
  return (
    <PressBtn onClick={() => nav.go('vaccine')} style={{ display: 'block', width: '100%', textAlign: 'left' }}>
      <div style={{
        background: 'linear-gradient(135deg,#FBF1DC,#F7E7C4)', borderRadius: 24, padding: compact ? 16 : 20,
        position: 'relative', overflow: 'hidden', boxShadow: 'var(--sh-2)',
      }}>
        <div style={{ position: 'absolute', right: -20, top: -20, width: 120, height: 120, borderRadius: 999, background: 'rgba(255,255,255,.35)' }} />
        <div style={{ display: 'flex', alignItems: 'center', gap: 7, position: 'relative' }}>
          <Badge tone="amber"><Icon name="vaccine" size={13} color="#98711E" />지금 가장 중요해요</Badge>
        </div>
        <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', marginTop: 12, position: 'relative' }}>
          <div>
            <div style={{ fontSize: 21, fontWeight: 800, letterSpacing: '-0.02em' }}>DTaP 4차 접종</div>
            <div style={{ fontSize: 14, color: 'var(--ink-2)', marginTop: 3 }}>{child.name} · 행복소아과 · 예약 권장</div>
          </div>
          <div style={{ textAlign: 'right' }}>
            <div className="t-num" style={{ fontSize: 30, fontWeight: 800, color: '#98711E', lineHeight: 1 }}>D-4</div>
          </div>
        </div>
        <div style={{ display: 'flex', gap: 8, marginTop: 16, position: 'relative' }}>
          <div className="bl-liquid" style={{ flex: 1, height: 44, borderRadius: 13, background: '#B0832E', color: '#fff', display: 'grid', placeItems: 'center', fontSize: 15, fontWeight: 700 }}>접종 예약하기</div>
          <div style={{ width: 44, height: 44, borderRadius: 13, background: 'rgba(255,255,255,.6)', display: 'grid', placeItems: 'center' }}><Icon name="bell" size={20} color="#98711E" /></div>
        </div>
      </div>
    </PressBtn>
  );
}

function ModulePeer({ ctx }) {
  return (
    <Card pad={16} style={{ background: 'linear-gradient(135deg,#EDEBFB,#F3E9F6)' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 7, marginBottom: 10 }}>
        <Icon name="sparkle" size={16} color="#5B53B0" />
        <span style={{ fontSize: 12.5, fontWeight: 700, color: '#5B53B0', letterSpacing: '.02em' }}>오늘의 또래 이야기</span>
      </div>
      <p style={{ margin: 0, fontSize: 14.5, lineHeight: '22px', color: 'var(--ink)', textWrap: 'pretty' }}>{window.BL_DATA.peerTip}</p>
    </Card>
  );
}

function ModuleMemory({ ctx }) {
  const { nav } = ctx;
  const m = window.BL_DATA.ddayMemory;
  return (
    <PressBtn onClick={() => nav.go('record')} style={{ display: 'block', width: '100%', textAlign: 'left' }}>
      <Card pad={0} style={{ overflow: 'hidden' }}>
        <div style={{ display: 'flex', gap: 0 }}>
          <Photo seed={m.seed} radius={0} icon="heart" style={{ width: 104, flex: 'none' }} />
          <div style={{ padding: 16, flex: 1 }}>
            <Badge tone="pink"><Icon name="clock" size={12} color="#B5478A" />1년 전 오늘</Badge>
            <p style={{ margin: '10px 0 0', fontSize: 14.5, fontWeight: 600, lineHeight: '20px' }}>{m.caption}</p>
          </div>
        </div>
      </Card>
    </PressBtn>
  );
}

function ModuleNeighborhood({ ctx }) {
  const { nav } = ctx;
  const items = window.BL_DATA.market.slice(0, 2);
  return (
    <Card pad={16}>
      <SectionHead title="우리 동네 소식" icon="pin" action="더보기" onAction={() => nav.go('market')} />
      <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
        {items.map(it => (
          <button key={it.id} onClick={() => nav.go('itemDetail', it)} style={{ display: 'flex', alignItems: 'center', gap: 12, fontFamily: 'inherit', textAlign: 'left', background: 'none' }}>
            <Photo seed={it.seed} radius={12} icon="bag" style={{ width: 50, height: 50, flex: 'none' }} />
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: 14, fontWeight: 600, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{it.title}</div>
              <div style={{ fontSize: 12, color: 'var(--ink-3)', marginTop: 2 }}>{it.dist} · {it.grade}등급 · {it.months}</div>
            </div>
            <div style={{ fontSize: 14, fontWeight: 800 }}>{it.free ? '나눔' : (it.price/10000)+'만'}</div>
          </button>
        ))}
      </div>
    </Card>
  );
}

function ModuleBudget({ ctx }) {
  const { nav } = ctx;
  return (
    <PressBtn onClick={() => nav.go('budget')} style={{ display: 'block', width: '100%', textAlign: 'left' }}>
      <Card pad={16}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div>
            <div style={{ fontSize: 12.5, color: 'var(--ink-3)', fontWeight: 600 }}>이번 달 육아비</div>
            <div className="t-num" style={{ fontSize: 24, fontWeight: 800, marginTop: 3 }}>480,000<span style={{ fontSize: 15, fontWeight: 600, color: 'var(--ink-2)' }}>원</span></div>
          </div>
          <div style={{ textAlign: 'right' }}>
            <Badge tone="mint" dot>전월 -8%</Badge>
            <div style={{ fontSize: 11.5, color: 'var(--ink-3)', marginTop: 6 }}>아동수당 D-4 미신청</div>
          </div>
        </div>
        <div style={{ display: 'flex', height: 8, borderRadius: 99, overflow: 'hidden', marginTop: 14, gap: 2 }}>
          {window.BL_DATA.budgetCats.map(c => <div key={c.cat} style={{ width: c.pct + '%', background: window.BADGE_INK[c.tone], opacity: .85 }} />)}
        </div>
      </Card>
    </PressBtn>
  );
}

function ModuleRecordNudge({ ctx }) {
  const { child, nav } = ctx;
  return (
    <Card pad={16} flat style={{ background: 'var(--primary-tint)', border: '1px solid #CDEADD' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
        <div style={{ width: 44, height: 44, borderRadius: 13, background: '#fff', display: 'grid', placeItems: 'center', flex: 'none' }}><Icon name="camera" size={22} color="var(--primary)" /></div>
        <div style={{ flex: 1 }}>
          <div style={{ fontSize: 14.5, fontWeight: 700 }}>{child.name}의 오늘이 궁금해요</div>
          <div style={{ fontSize: 12.5, color: 'var(--ink-2)', marginTop: 2 }}>사진 한 장이면 기록 끝 — 2탭이면 돼요</div>
        </div>
        <button onClick={() => nav.go('quickRecord')} className="bl-liquid" style={{ height: 38, padding: '0 16px', borderRadius: 11, background: 'var(--primary)', color: '#fff', fontSize: 14, fontWeight: 700, fontFamily: 'inherit' }}>기록</button>
      </div>
    </Card>
  );
}

// ---- Header variants ----
function HeaderHero({ ctx }) {
  const { child } = ctx;
  const recent = window.BL_DATA.records.find(r => r.type === 'photo');
  return (
    <div style={{ padding: '0 18px', marginBottom: 16 }}>
      <Card pad={0} style={{ overflow: 'hidden', position: 'relative' }}>
        <Photo seed={recent.seed} radius={0} icon={null} style={{ height: 188 }}>
          <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(180deg,rgba(0,0,0,0) 40%,rgba(0,0,0,.55))' }} />
          <div style={{ position: 'absolute', left: 16, right: 16, bottom: 14, color: '#fff' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 7 }}>
              <span style={{ fontSize: 22, fontWeight: 800, letterSpacing: '-0.02em' }}>{child.name}</span>
              <span style={{ fontSize: 13, fontWeight: 600, opacity: .92, background: 'rgba(255,255,255,.22)', padding: '2px 9px', borderRadius: 99, backdropFilter: 'blur(4px)' }} className="t-num">D+{child.dday} · {child.months}개월</span>
            </div>
            <div style={{ fontSize: 13.5, opacity: .92, marginTop: 5 }}>{recent.caption || '오늘의 순간'}</div>
          </div>
        </Photo>
      </Card>
    </div>
  );
}

function HeaderCompact({ ctx }) {
  const { child } = ctx;
  return (
    <div style={{ padding: '0 18px', marginBottom: 16, display: 'flex', alignItems: 'center', gap: 13 }}>
      <Photo seed={child.seed} radius={16} style={{ width: 56, height: 56, flex: 'none' }}>
        <span style={{ fontSize: 26 }}>{child.emoji}</span>
      </Photo>
      <div style={{ flex: 1 }}>
        <div style={{ fontSize: 20, fontWeight: 800, letterSpacing: '-0.02em' }}>{child.name}</div>
        <div className="t-num" style={{ fontSize: 13, color: 'var(--ink-2)', marginTop: 2 }}>D+{child.dday} · {child.months}개월 · {child.weight}kg</div>
      </div>
      <div style={{ width: 44, height: 44, borderRadius: 13, background: 'var(--surface)', boxShadow: 'var(--sh-1)', display: 'grid', placeItems: 'center', position: 'relative' }}>
        <Icon name="bell" size={21} color="var(--ink-2)" />
        <span style={{ position: 'absolute', top: 10, right: 11, width: 8, height: 8, borderRadius: 99, background: 'var(--danger)', border: '1.5px solid #fff' }} />
      </div>
    </div>
  );
}

function HomeScreen({ ctx }) {
  if (ctx.mode === 'pregnancy') return <PregnancyHome ctx={ctx} />;
  const layout = ctx.tweaks.homeLayout || 'A';
  const greet = '좋은 오후예요 ☀️';
  return (
    <div style={{ paddingBottom: 28 }}>
      <div style={{ padding: `${ctx.inset}px 18px 14px`, display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div>
          <div style={{ fontSize: 12.5, color: 'var(--ink-3)', fontWeight: 600 }}>{greet}</div>
          <div style={{ fontSize: 24, fontWeight: 800, letterSpacing: '-0.025em', marginTop: 1 }}>우리 동네 육아</div>
        </div>
        <button onClick={() => ctx.nav.go('emergency')} className="bl-liquid" style={{ display: 'flex', alignItems: 'center', gap: 5, height: 38, padding: '0 13px', borderRadius: 999, background: 'var(--danger)', color: '#fff', fontSize: 13, fontWeight: 700, fontFamily: 'inherit', boxShadow: '0 4px 12px rgba(190,77,56,.3)' }}>
          <Icon name="vaccine" size={15} color="#fff" />응급
        </button>
      </div>

      <ChildSwitcher ctx={ctx} />

      {layout === 'A' && (<>
        <HeaderHero ctx={ctx} />
        <div style={{ padding: '0 18px', display: 'flex', flexDirection: 'column', gap: 12 }}>
          <PriorityCard ctx={ctx} />
          <ModuleRecordNudge ctx={ctx} />
          <ModulePeer ctx={ctx} />
          <ModuleMemory ctx={ctx} />
          <ModuleNeighborhood ctx={ctx} />
          <ModuleBudget ctx={ctx} />
        </div>
      </>)}

      {layout === 'B' && (<>
        <HeaderCompact ctx={ctx} />
        <div style={{ padding: '0 18px', display: 'flex', flexDirection: 'column', gap: 12 }}>
          <PriorityCard ctx={ctx} compact />
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
            <TileBudget ctx={ctx} />
            <TileCrew ctx={ctx} />
            <TileRecord ctx={ctx} />
            <TileVaccine ctx={ctx} />
          </div>
          <ModulePeer ctx={ctx} />
          <ModuleNeighborhood ctx={ctx} />
        </div>
      </>)}

      {layout === 'C' && (<>
        <HeaderCompact ctx={ctx} />
        <div style={{ padding: '0 18px', display: 'flex', flexDirection: 'column', gap: 12 }}>
          <PriorityCard ctx={ctx} compact />
          <ModulePeer ctx={ctx} />
          <SectionHead title="최근 기록" action="전체" onAction={() => ctx.nav.go('record')} />
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10, marginTop: -4 }}>
            {window.BL_DATA.records.slice(0, 4).map(r => <InlineRecord key={r.id} r={r} ctx={ctx} />)}
          </div>
        </div>
      </>)}
    </div>
  );
}

// Layout B tiles
function Tile({ children, onClick, bg }) {
  return <PressBtn onClick={onClick} style={{ display: 'block', textAlign: 'left' }}><div style={{ background: bg || 'var(--surface)', borderRadius: 20, padding: 16, boxShadow: 'var(--sh-2)', height: 116, display: 'flex', flexDirection: 'column', justifyContent: 'space-between' }}>{children}</div></PressBtn>;
}
function TileBudget({ ctx }) { return <Tile onClick={() => ctx.nav.go('budget')}><Icon name="wallet" size={24} color="#3B6FA8" /><div><div className="t-num" style={{ fontSize: 19, fontWeight: 800 }}>48만원</div><div style={{ fontSize: 12, color: 'var(--ink-3)' }}>이번 달 육아비</div></div></Tile>; }
function TileCrew({ ctx }) { return <Tile onClick={() => ctx.nav.go('crew')}><Icon name="users" size={24} color="#2E7A5C" /><div><div style={{ fontSize: 19, fontWeight: 800 }}>3개 크루</div><div style={{ fontSize: 12, color: 'var(--ink-3)' }}>내 주변 모임</div></div></Tile>; }
function TileRecord({ ctx }) { return <Tile onClick={() => ctx.nav.go('record')}><Icon name="camera" size={24} color="var(--primary)" /><div><div style={{ fontSize: 19, fontWeight: 800 }}>152개</div><div style={{ fontSize: 12, color: 'var(--ink-3)' }}>성장 기록</div></div></Tile>; }
function TileVaccine({ ctx }) { return <Tile onClick={() => ctx.nav.go('vaccine')} bg="linear-gradient(135deg,#FBF1DC,#F7E7C4)"><Icon name="vaccine" size={24} color="#98711E" /><div><div className="t-num" style={{ fontSize: 19, fontWeight: 800, color: '#98711E' }}>D-4</div><div style={{ fontSize: 12, color: 'var(--ink-2)' }}>DTaP 4차 접종</div></div></Tile>; }

function InlineRecord({ r, ctx }) {
  return (
    <button onClick={() => ctx.nav.go('record')} style={{ display: 'flex', gap: 12, alignItems: 'center', background: 'var(--surface)', borderRadius: 16, padding: 10, boxShadow: 'var(--sh-1)', fontFamily: 'inherit', textAlign: 'left' }}>
      {r.type === 'photo' ? <Photo seed={r.seed} radius={11} style={{ width: 54, height: 54, flex: 'none' }} /> :
       <div style={{ width: 54, height: 54, borderRadius: 11, background: r.type === 'growth' ? 'var(--badge-blue)' : 'var(--badge-coral)', display: 'grid', placeItems: 'center', flex: 'none' }}><Icon name={r.type === 'growth' ? 'ruler' : 'vaccine'} size={22} color={r.type === 'growth' ? '#3B6FA8' : '#B45840'} /></div>}
      <div style={{ flex: 1, minWidth: 0 }}>
        {r.milestone && <Badge tone="mint" small style={{ marginBottom: 4 }}>{r.milestone}</Badge>}
        <div style={{ fontSize: 14, fontWeight: 600, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{r.caption || (r.type === 'growth' ? `키 ${r.height} · 몸무게 ${r.weight}kg` : `${r.vaccine} 접종`)}</div>
        <div style={{ fontSize: 12, color: 'var(--ink-3)', marginTop: 2 }}>{r.day} · {r.mins}</div>
      </div>
    </button>
  );
}

// ── Pregnancy-mode home ──
function PregnancyHome({ ctx }) {
  const p = window.BL_DATA.pregnancy;
  return (
    <div style={{ paddingBottom: 28 }}>
      <div style={{ padding: `${ctx.inset}px 18px 14px` }}>
        <div style={{ fontSize: 12.5, color: 'var(--ink-3)', fontWeight: 600 }}>좋은 오후예요 🌸</div>
        <div style={{ fontSize: 24, fontWeight: 800, letterSpacing: '-0.025em', marginTop: 1 }}>{p.nickname}를 기다리며</div>
      </div>
      {/* hero */}
      <div style={{ padding: '0 18px 12px' }}>
        <Card pad={0} style={{ overflow: 'hidden', background: 'linear-gradient(150deg,#FBE6EE,#F6D6E4)' }}>
          <div style={{ padding: 18, display: 'flex', alignItems: 'center', gap: 16 }}>
            <div style={{ width: 84, height: 84, borderRadius: 999, background: '#fff', display: 'grid', placeItems: 'center', flex: 'none', boxShadow: 'var(--sh-1)' }}><span style={{ fontSize: 42 }}>{p.fruitEmoji}</span></div>
            <div style={{ flex: 1 }}>
              <Badge tone="pink" dot>{p.trimester} · {p.week}주</Badge>
              <div className="t-num" style={{ fontSize: 26, fontWeight: 800, marginTop: 8, letterSpacing: '-0.02em' }}>D-{p.dday}</div>
              <div style={{ fontSize: 13, color: '#A8537E', marginTop: 2 }}>{p.fruit}만 해요 · 출산까지</div>
            </div>
          </div>
        </Card>
      </div>
      <div style={{ padding: '0 18px', display: 'flex', flexDirection: 'column', gap: 12 }}>
        {/* priority: 검진 */}
        <PressBtn onClick={() => ctx.nav.tab('record')} style={{ display: 'block', width: '100%', textAlign: 'left' }}>
          <div style={{ background: 'linear-gradient(135deg,#FBE6EE,#F6D6E4)', borderRadius: 24, padding: 20, boxShadow: 'var(--sh-2)' }}>
            <Badge tone="pink"><Icon name="vaccine" size={13} color="#B5478A" />지금 가장 중요해요</Badge>
            <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', marginTop: 12 }}>
              <div><div style={{ fontSize: 21, fontWeight: 800 }}>임신성 당뇨 검사</div><div style={{ fontSize: 14, color: '#A8537E', marginTop: 3 }}>24~28주 · 공복 검사 권장</div></div>
              <div className="t-num" style={{ fontSize: 30, fontWeight: 800, color: '#B5478A', lineHeight: 1 }}>D-3</div>
            </div>
          </div>
        </PressBtn>
        {/* 주차 가이드 */}
        <Card pad={16} flat style={{ background: 'var(--surface)', border: '1px solid var(--line)' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 7, marginBottom: 10 }}><Icon name="sparkle" size={16} color="#B5478A" /><span style={{ fontSize: 12.5, fontWeight: 700, color: '#B5478A' }}>{p.week}주차 태아 이야기</span></div>
          <p style={{ margin: 0, fontSize: 14.5, lineHeight: '22px', textWrap: 'pretty' }}>{p.devNote}</p>
        </Card>
        <ModuleNeighborhood ctx={ctx} />
        <ModuleBudget ctx={ctx} />
      </div>
    </div>
  );
}

Object.assign(window, { HomeScreen, PregnancyHome });
