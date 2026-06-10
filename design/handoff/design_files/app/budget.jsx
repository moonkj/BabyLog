// BabyLog · Budget (육아 가계부 · 정부지원금)
const { Icon, Badge, Chip, Photo, Card, SectionHead, PressBtn } = window;

function Donut({ cats }) {
  const R = 52, sw = 20, C = 2 * Math.PI * R;
  let off = 0;
  return (
    <svg viewBox="0 0 140 140" width="140" height="140">
      <g transform="rotate(-90 70 70)">
        {cats.map(c => {
          const len = (c.pct / 100) * C;
          const el = <circle key={c.cat} cx="70" cy="70" r={R} fill="none" stroke={window.BADGE_INK[c.tone]} strokeOpacity="0.9" strokeWidth={sw} strokeDasharray={`${len} ${C - len}`} strokeDashoffset={-off} />;
          off += len; return el;
        })}
      </g>
      <text x="70" y="64" textAnchor="middle" fontSize="11" fill="var(--ink-3)" fontWeight="600">이번 달</text>
      <text x="70" y="82" textAnchor="middle" fontSize="19" fontWeight="800" fill="var(--ink)" fontFamily="var(--num)">48만원</text>
    </svg>
  );
}

function BudgetScreen({ ctx, asTab }) {
  const usersBtn = <Icon name="users" size={20} color="var(--ink-2)" />;
  return (
    <div style={{ minHeight: '100%', background: 'var(--canvas)' }}>
      {asTab
        ? window.TabHeader({ title: '가계부', ctx, right: <div style={{ width: 40, height: 40, display: 'grid', placeItems: 'center' }}>{usersBtn}</div> })
        : window.PushHeader({ title: '육아 가계부', ctx, right: usersBtn })}
      <div style={{ padding: '0 18px 28px', display: 'flex', flexDirection: 'column', gap: 14 }}>

        {/* 정부지원금 — 전면 배치 */}
        <div>
          <SectionHead title="정부지원금 놓치지 마세요" icon="gift" />
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {window.BL_DATA.subsidies.map(s => <SubsidyCard key={s.id} s={s} ctx={ctx} />)}
          </div>
        </div>

        {/* dashboard */}
        <Card pad={18}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <Donut cats={window.BL_DATA.budgetCats} />
            <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 7 }}>
              {window.BL_DATA.budgetCats.map(c => (
                <div key={c.cat} style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  <span style={{ width: 9, height: 9, borderRadius: 3, background: window.BADGE_INK[c.tone] }} />
                  <span style={{ fontSize: 12.5, color: 'var(--ink-2)', flex: 1 }}>{c.cat}</span>
                  <span className="t-num" style={{ fontSize: 12.5, fontWeight: 700 }}>{(c.amount / 10000).toFixed(1)}만</span>
                </div>
              ))}
            </div>
          </div>
          <div style={{ display: 'flex', justifyContent: 'space-around', borderTop: '1px solid var(--line)', paddingTop: 14, marginTop: 14 }}>
            <Mini v="480,000원" k="이번 달 총 지출" />
            <Mini v="-8%" k="전월 대비" tone="mint" />
            <Mini v="52,000원" k="또래 평균보다 ↓" />
          </div>
        </Card>

        {/* 월령별 예상 지출 가이드 */}
        <Card pad={16} flat style={{ background: 'linear-gradient(135deg,#EDEBFB,#F3E9F6)', border: 'none' }}>
          <div style={{ display: 'flex', gap: 12 }}>
            <div style={{ width: 44, height: 44, borderRadius: 13, background: '#fff', display: 'grid', placeItems: 'center', flex: 'none' }}><Icon name="chart" size={22} color="#5B53B0" /></div>
            <div><div style={{ fontSize: 14.5, fontWeight: 700 }}>16개월 예상 지출 가이드</div><div style={{ fontSize: 13, color: 'var(--ink-2)', marginTop: 3, lineHeight: '19px', textWrap: 'pretty' }}>이유식 재료비가 평균 8만원 추가돼요. 슬슬 유아식 준비도 시작될 시기예요.</div></div>
          </div>
        </Card>

        {/* 자동 수집 거래 */}
        <div>
          <SectionHead title="최근 지출" action="전체" />
          <Card pad={0} style={{ overflow: 'hidden' }}>
            {window.BL_DATA.expenses.map((e, i) => (
              <div key={e.id} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '13px 15px', borderTop: i ? '1px solid var(--line)' : 'none' }}>
                <div style={{ width: 40, height: 40, borderRadius: 11, background: window.BADGE_BG[e.tone], display: 'grid', placeItems: 'center', flex: 'none' }}><Icon name={e.icon} size={20} color={window.BADGE_INK[e.tone]} /></div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}><span style={{ fontSize: 14, fontWeight: 600, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{e.label}</span>{e.auto && <Badge tone="blue" small>자동</Badge>}</div>
                  <div style={{ fontSize: 12, color: 'var(--ink-3)', marginTop: 2 }}>{e.cat} · {e.date}</div>
                </div>
                <span className="t-num" style={{ fontSize: 14.5, fontWeight: 800 }}>{e.amount.toLocaleString()}</span>
              </div>
            ))}
          </Card>
          <div style={{ textAlign: 'center', fontSize: 12, color: 'var(--ink-3)', marginTop: 12, lineHeight: '18px' }}>마켓 거래·구독은 자동으로 기록돼요.<br/>큰 지출만 가끔 직접 추가하면 충분해요.</div>
        </div>
      </div>

      <button onClick={() => ctx.nav.go('addExpense')} className="bl-liquid" style={{ position: 'absolute', right: 18, bottom: 30, width: 56, height: 56, borderRadius: 999, background: 'var(--primary)', display: 'grid', placeItems: 'center', boxShadow: 'var(--sh-fab)', zIndex: 30, fontFamily: 'inherit' }}><Icon name="plus" size={26} color="#fff" stroke={2.4} /></button>
    </div>
  );
}

function Mini({ v, k, tone }) {
  return <div style={{ textAlign: 'center' }}><div className="t-num" style={{ fontSize: 15.5, fontWeight: 800, color: tone ? window.BADGE_INK[tone] : 'var(--ink)' }}>{v}</div><div style={{ fontSize: 10.5, color: 'var(--ink-3)', marginTop: 3 }}>{k}</div></div>;
}

function SubsidyCard({ s, ctx }) {
  const urgent = s.status === 'urgent';
  const done = s.status === 'done';
  return (
    <Card pad={15} flat style={urgent ? { background: 'linear-gradient(135deg,#FBF1DC,#F7E7C4)', border: 'none' } : { border: '1px solid var(--line)' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 13 }}>
        <div style={{ width: 46, height: 46, borderRadius: 13, background: done ? 'var(--primary-tint)' : '#fff', display: 'grid', placeItems: 'center', flex: 'none', boxShadow: urgent ? 'var(--sh-1)' : 'none' }}>
          <Icon name={done ? 'check' : 'gift'} size={23} color={done ? 'var(--primary)' : urgent ? '#98711E' : 'var(--ink-2)'} />
        </div>
        <div style={{ flex: 1 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 7 }}><span style={{ fontSize: 15.5, fontWeight: 700 }}>{s.name}</span>{urgent && <Badge tone="amber" small>{s.due}</Badge>}</div>
          <div style={{ fontSize: 13, color: 'var(--ink-2)', marginTop: 3 }}><b className="t-num">{s.amount}</b> · {s.cond}</div>
        </div>
        {done ? <span style={{ fontSize: 12.5, color: 'var(--ink-3)', fontWeight: 600 }}>수령완료</span>
          : <button className="bl-liquid" style={{ height: 38, padding: '0 16px', borderRadius: 11, background: urgent ? '#B0832E' : 'var(--ink)', color: '#fff', fontSize: 13.5, fontWeight: 700, fontFamily: 'inherit' }}>신청</button>}
      </div>
      {urgent && (
        <div style={{ display: 'flex', gap: 8, marginTop: 13, paddingTop: 13, borderTop: '1px solid rgba(152,113,30,.18)' }}>
          {['신청방법 안내', '필요서류 체크', '복지로 바로가기'].map(t => <div key={t} style={{ flex: 1, textAlign: 'center', fontSize: 11, fontWeight: 600, color: '#98711E', background: 'rgba(255,255,255,.5)', padding: '7px 4px', borderRadius: 9 }}>{t}</div>)}
        </div>
      )}
    </Card>
  );
}

Object.assign(window, { BudgetScreen });
