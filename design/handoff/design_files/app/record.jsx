// BabyLog · Record (timeline / growth chart / vaccines) + quick-record sheet
const { Icon, Badge, Chip, Photo, Card, SectionHead, PressBtn } = window;

// ---------- Growth chart ----------
function GrowthChart() {
  const d = window.BL_DATA.growthChart;
  const W = 300, H = 168, padL = 28, padB = 22, padT = 8, padR = 8;
  const xmax = 16, ymin = 2, ymax = 13;
  const xs = m => padL + (m / xmax) * (W - padL - padR);
  const ys = v => padT + (1 - (v - ymin) / (ymax - ymin)) * (H - padT - padB);
  const line = pts => pts.map((p, i) => `${i ? 'L' : 'M'}${xs(p.m).toFixed(1)} ${ys(p.v).toFixed(1)}`).join(' ');
  const band = (a, b) => line(a) + ' ' + b.slice().reverse().map(p => `L${xs(p.m).toFixed(1)} ${ys(p.v).toFixed(1)}`).join(' ') + ' Z';
  return (
    <svg viewBox={`0 0 ${W} ${H}`} width="100%" style={{ display: 'block' }}>
      {[4, 6, 8, 10, 12].map(v => (
        <g key={v}>
          <line x1={padL} y1={ys(v)} x2={W - padR} y2={ys(v)} stroke="var(--line)" strokeWidth="1" />
          <text x={padL - 6} y={ys(v) + 3} fontSize="9" fill="var(--ink-3)" textAnchor="end" fontFamily="var(--num)">{v}</text>
        </g>
      ))}
      {[0, 4, 8, 12, 16].map(m => <text key={m} x={xs(m)} y={H - 6} fontSize="9" fill="var(--ink-3)" textAnchor="middle" fontFamily="var(--num)">{m}m</text>)}
      <path d={band(d.p85, d.p15)} fill="var(--primary)" opacity="0.08" />
      <path d={line(d.p50)} fill="none" stroke="var(--primary)" strokeWidth="1.3" strokeDasharray="3 3" opacity="0.5" />
      <path d={line(d.weight)} fill="none" stroke="var(--primary)" strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round" />
      {d.weight.map(p => <circle key={p.m} cx={xs(p.m)} cy={ys(p.v)} r="2.6" fill="#fff" stroke="var(--primary)" strokeWidth="1.8" />)}
      {(() => { const last = d.weight[d.weight.length - 1]; return <circle cx={xs(last.m)} cy={ys(last.v)} r="4.5" fill="var(--primary)" stroke="#fff" strokeWidth="2" />; })()}
    </svg>
  );
}

function RecordScreen({ ctx, params, asTab }) {
  const [tab, setTab] = React.useState(params?.tab || 'timeline');
  const { child } = ctx;
  const days = [...new Set(window.BL_DATA.records.map(r => r.day))];
  const shareBtn = <button onClick={() => ctx.nav.go('shareCard')} style={{ width: 40, height: 40, display: 'grid', placeItems: 'center', background: 'none', fontFamily: 'inherit' }}><Icon name="share" size={20} color="var(--ink-2)" /></button>;
  return (
    <div style={{ minHeight: '100%', background: 'var(--canvas)' }}>
      {asTab
        ? window.TabHeader({ title: '기록', ctx, right: shareBtn })
        : window.PushHeader({ title: '성장 기록', ctx, right: shareBtn })}
      {/* segmented */}
      <div style={{ display: 'flex', gap: 4, padding: '4px 18px 14px' }}>
        {[['timeline', '타임라인'], ['chart', '성장차트'], ['vaccine', '예방접종']].map(([k, l]) => (
          <button key={k} onClick={() => setTab(k)} style={{ flex: 1, height: 38, borderRadius: 11, fontFamily: 'inherit', fontSize: 14, fontWeight: 700, background: tab === k ? 'var(--ink)' : 'var(--surface)', color: tab === k ? '#fff' : 'var(--ink-2)', boxShadow: tab === k ? 'none' : 'var(--sh-1)', transition: 'all .15s' }}>{l}</button>
        ))}
      </div>

      {tab === 'timeline' && (
        <div style={{ padding: '0 18px 28px' }}>
          {days.map(day => (
            <div key={day} style={{ marginBottom: 8 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10, margin: '6px 0 12px' }}>
                <span style={{ fontSize: 13, fontWeight: 800, color: 'var(--ink-2)' }}>{day}</span>
                <div style={{ flex: 1, height: 1, background: 'var(--line)' }} />
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
                {window.BL_DATA.records.filter(r => r.day === day).map(r => <TimelineCard key={r.id} r={r} />)}
              </div>
            </div>
          ))}
          <div style={{ textAlign: 'center', padding: '18px 0 0', fontSize: 13, color: 'var(--ink-3)' }}>지호의 152개 순간이 기록되었어요 💛</div>
        </div>
      )}

      {tab === 'chart' && (
        <div style={{ padding: '0 18px 28px', display: 'flex', flexDirection: 'column', gap: 12 }}>
          <Card pad={18} flat style={{ background: 'var(--primary-tint)', border: '1px solid #CDEADD' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
              <Icon name="heart" size={22} color="var(--primary)" fill />
              <div><div style={{ fontSize: 15, fontWeight: 700 }}>또래와 비슷하게 잘 크고 있어요</div><div style={{ fontSize: 12.5, color: 'var(--ink-2)', marginTop: 2 }}>걱정 마세요 — 정밀 수치는 아래에서 확인할 수 있어요</div></div>
            </div>
          </Card>
          <Card pad={16}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 6 }}>
              <span style={{ fontSize: 15, fontWeight: 700 }}>몸무게</span>
              <div style={{ display: 'flex', gap: 6 }}><Chip on style={{ height: 28, fontSize: 12.5 }}>몸무게</Chip><Chip style={{ height: 28, fontSize: 12.5 }}>키</Chip><Chip style={{ height: 28, fontSize: 12.5 }}>머리둘레</Chip></div>
            </div>
            <GrowthChart />
            <div style={{ display: 'flex', justifyContent: 'space-around', borderTop: '1px solid var(--line)', paddingTop: 14, marginTop: 6 }}>
              <Stat v={`${child.weight}kg`} k="현재 몸무게" />
              <Stat v="58%" k="WHO 백분위" />
              <Stat v="+0.6kg" k="최근 2개월" />
            </div>
          </Card>
        </div>
      )}

      {tab === 'vaccine' && <VaccineList ctx={ctx} inline />}
    </div>
  );
}

function Stat({ v, k }) {
  return <div style={{ textAlign: 'center' }}><div className="t-num" style={{ fontSize: 18, fontWeight: 800 }}>{v}</div><div style={{ fontSize: 11.5, color: 'var(--ink-3)', marginTop: 2 }}>{k}</div></div>;
}

function TimelineCard({ r }) {
  if (r.type === 'photo') return (
    <Card pad={0} style={{ overflow: 'hidden' }}>
      <Photo seed={r.seed} radius={0} icon={null} style={{ height: 200 }}>
        {r.milestone && <div style={{ position: 'absolute', left: 12, top: 12 }}><Badge tone="amber"><Icon name="star" size={12} color="#98711E" fill />{r.milestone}</Badge></div>}
      </Photo>
      <div style={{ padding: '12px 15px 14px' }}>
        {r.caption && <p style={{ margin: 0, fontSize: 14.5, lineHeight: '21px', textWrap: 'pretty' }}>{r.caption}</p>}
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginTop: 10 }}>
          <span style={{ fontSize: 12, color: 'var(--ink-3)' }}>{r.mins}</span>
          <span style={{ display: 'flex', alignItems: 'center', gap: 4, fontSize: 12, color: 'var(--ink-3)' }}><Icon name="heart" size={14} color="var(--ink-3)" />{r.likes || 0}</span>
        </div>
      </div>
    </Card>
  );
  if (r.type === 'growth') return (
    <Card pad={14}><div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
      <div style={{ width: 46, height: 46, borderRadius: 13, background: 'var(--badge-blue)', display: 'grid', placeItems: 'center', flex: 'none' }}><Icon name="ruler" size={22} color="#3B6FA8" /></div>
      <div style={{ flex: 1 }}><div style={{ fontSize: 14.5, fontWeight: 700 }}>성장 측정</div><div className="t-num" style={{ fontSize: 13, color: 'var(--ink-2)', marginTop: 2 }}>키 {r.height}cm · 몸무게 {r.weight}kg</div></div>
      <span style={{ fontSize: 12, color: 'var(--ink-3)' }}>{r.mins}</span>
    </div></Card>
  );
  return (
    <Card pad={14}><div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
      <div style={{ width: 46, height: 46, borderRadius: 13, background: 'var(--badge-coral)', display: 'grid', placeItems: 'center', flex: 'none' }}><Icon name="vaccine" size={22} color="#B45840" /></div>
      <div style={{ flex: 1 }}><div style={{ fontSize: 14.5, fontWeight: 700 }}>{r.vaccine} 접종</div><div style={{ fontSize: 13, color: 'var(--ink-2)', marginTop: 2 }}>{r.hospital}</div></div>
      <span style={{ fontSize: 12, color: 'var(--ink-3)' }}>{r.mins}</span>
    </div></Card>
  );
}

// ---------- Vaccine list ----------
function VaccineList({ ctx, inline }) {
  const body = (
    <div style={{ padding: inline ? '0 18px 28px' : '0 18px 28px', display: 'flex', flexDirection: 'column', gap: 10 }}>
      <Card pad={16} style={{ background: 'linear-gradient(135deg,#FBF1DC,#F7E7C4)' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{ width: 46, height: 46, borderRadius: 13, background: '#fff', display: 'grid', placeItems: 'center', flex: 'none' }}><Icon name="vaccine" size={22} color="#98711E" /></div>
          <div style={{ flex: 1 }}><div style={{ fontSize: 15, fontWeight: 800 }}>DTaP 4차가 다가와요</div><div style={{ fontSize: 12.5, color: 'var(--ink-2)', marginTop: 2 }}>질병관리청 스케줄 기준 · D-7 알림 설정됨</div></div>
          <span className="t-num" style={{ fontSize: 22, fontWeight: 800, color: '#98711E' }}>D-4</span>
        </div>
      </Card>
      {window.BL_DATA.vaccines.map(v => (
        <Card key={v.id} pad={14} flat>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <div style={{ width: 38, height: 38, borderRadius: 11, background: v.status === 'done' ? 'var(--primary-tint)' : 'var(--surface-3)', display: 'grid', placeItems: 'center', flex: 'none' }}>
              <Icon name={v.status === 'done' ? 'check' : 'vaccine'} size={19} color={v.status === 'done' ? 'var(--primary)' : 'var(--ink-3)'} />
            </div>
            <div style={{ flex: 1 }}><div style={{ fontSize: 14.5, fontWeight: 700 }}>{v.name}</div><div style={{ fontSize: 12.5, color: 'var(--ink-3)', marginTop: 2 }}>{v.age}{v.date ? ` · ${v.date} 접종` : ''}</div></div>
            {v.status === 'done' ? <Badge tone="mint">완료</Badge> : v.status === 'soon' ? <Badge tone="amber">{v.due}</Badge> : <span className="t-num" style={{ fontSize: 13, color: 'var(--ink-3)', fontWeight: 700 }}>{v.due}</span>}
          </div>
        </Card>
      ))}
    </div>
  );
  if (inline) return body;
  return <div style={{ minHeight: '100%', background: 'var(--canvas)' }}>{window.PushHeader({ title: '예방접종', ctx })}{body}</div>;
}

// ---------- Quick record sheet (초경량 ↔ 상세) ----------
function QuickRecordSheet({ ctx, onClose }) {
  const [detail, setDetail] = React.useState(ctx.tweaks.recordMode === 'detail');
  const [saved, setSaved] = React.useState(false);
  const [milestone, setMilestone] = React.useState(null);
  const { child } = ctx;
  if (saved) return (
    <SheetShell onClose={onClose}>
      <div style={{ padding: '20px 22px 8px', textAlign: 'center' }}>
        <div style={{ width: 76, height: 76, borderRadius: 999, background: 'var(--primary-tint)', display: 'grid', placeItems: 'center', margin: '8px auto 16px', animation: 'pop .5s var(--ease-out)' }}><Icon name="heart" size={38} color="var(--primary)" fill /></div>
        <div style={{ fontSize: 21, fontWeight: 800 }}>{child.name}의 153번째 순간</div>
        <div style={{ fontSize: 14, color: 'var(--ink-2)', marginTop: 6 }}>소중한 오늘이 타임라인에 담겼어요</div>
        <button onClick={() => { onClose(); ctx.nav.go('record'); }} className="bl-liquid" style={{ marginTop: 20, width: '100%', height: 50, borderRadius: 15, background: 'var(--ink)', color: '#fff', fontSize: 15, fontWeight: 700, fontFamily: 'inherit' }}>타임라인에서 보기</button>
        <button onClick={onClose} style={{ marginTop: 8, width: '100%', height: 44, color: 'var(--ink-3)', fontSize: 14, fontWeight: 600, fontFamily: 'inherit', background: 'none' }}>닫기</button>
      </div>
    </SheetShell>
  );
  return (
    <SheetShell onClose={onClose}>
      <div style={{ padding: '4px 20px 16px' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 16 }}>
          <span style={{ fontSize: 18, fontWeight: 800 }}>오늘 기록</span>
          <Badge tone={detail ? 'purple' : 'mint'} dot>{detail ? '자세히 모드' : '초경량 · 2탭'}</Badge>
        </div>
        {/* photo dropzone */}
        <Photo seed={1} radius={18} icon={null} style={{ height: detail ? 150 : 210, marginBottom: 14 }}>
          <div style={{ position: 'absolute', inset: 0, display: 'grid', placeItems: 'center' }}>
            <div style={{ textAlign: 'center', color: '#fff' }}><Icon name="camera" size={34} color="rgba(255,255,255,.95)" style={{ margin: '0 auto 8px' }} /><div style={{ fontSize: 13.5, fontWeight: 600, textShadow: '0 1px 4px rgba(0,0,0,.3)' }}>사진 1장이면 기록 완료</div></div>
          </div>
        </Photo>

        {/* milestones quick row */}
        <div style={{ display: 'flex', gap: 7, overflowX: 'auto', paddingBottom: 4, marginBottom: detail ? 14 : 16 }}>
          {window.BL_DATA.milestones.slice(0, 6).map(m => (
            <button key={m} onClick={() => setMilestone(milestone === m ? null : m)} style={{ flex: 'none', height: 34, padding: '0 13px', borderRadius: 999, border: milestone === m ? '1px solid var(--gold)' : '1px solid var(--line)', background: milestone === m ? 'var(--gold-tint)' : 'var(--surface)', color: milestone === m ? '#98711E' : 'var(--ink-2)', fontSize: 13, fontWeight: 600, fontFamily: 'inherit' }}>{m}</button>
          ))}
        </div>

        {detail && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10, marginBottom: 8, animation: 'fadeIn .25s' }}>
            <textarea placeholder="한 줄 메모 (선택)" style={{ width: '100%', minHeight: 56, border: '1px solid var(--line)', borderRadius: 13, padding: 12, fontSize: 14.5, fontFamily: 'inherit', resize: 'none', background: 'var(--surface-2)', boxSizing: 'border-box' }} />
            <div style={{ display: 'flex', gap: 10 }}>
              <Field label="키 (cm)" ph="78.5" />
              <Field label="몸무게 (kg)" ph="10.2" />
            </div>
            <button style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6, height: 44, borderRadius: 12, border: '1px dashed var(--line-2)', background: 'var(--surface-2)', color: 'var(--ink-2)', fontSize: 13.5, fontWeight: 600, fontFamily: 'inherit' }}><Icon name="sparkle" size={16} color="var(--gold)" />AI로 캡션 초안 만들기 · Pro</button>
          </div>
        )}

        <button onClick={() => setSaved(true)} className="bl-liquid" style={{ width: '100%', height: 52, borderRadius: 15, background: 'var(--primary)', color: '#fff', fontSize: 16, fontWeight: 700, fontFamily: 'inherit', marginTop: 6 }}>저장하기</button>
        <button onClick={() => setDetail(!detail)} style={{ width: '100%', height: 44, color: 'var(--ink-3)', fontSize: 14, fontWeight: 600, fontFamily: 'inherit', background: 'none', marginTop: 4 }}>{detail ? '간단하게 ▲' : '자세히 입력 ▾'}</button>
      </div>
    </SheetShell>
  );
}

function Field({ label, ph }) {
  return <div style={{ flex: 1 }}><div style={{ fontSize: 11.5, color: 'var(--ink-3)', fontWeight: 600, marginBottom: 4 }}>{label}</div><input placeholder={ph} className="t-num" style={{ width: '100%', height: 44, border: '1px solid var(--line)', borderRadius: 12, padding: '0 12px', fontSize: 15, fontFamily: 'var(--num)', background: 'var(--surface-2)', boxSizing: 'border-box' }} /></div>;
}

function SheetShell({ children, onClose }) {
  return (
    <div onClick={onClose} style={{ position: 'absolute', inset: 0, zIndex: 80, background: 'rgba(28,24,19,.42)', display: 'flex', alignItems: 'flex-end', animation: 'fadeIn .2s' }}>
      <div onClick={e => e.stopPropagation()} style={{ width: '100%', background: 'var(--surface)', borderRadius: '28px 28px 0 0', paddingBottom: 30, animation: 'slideUp .3s var(--ease-out)', maxHeight: '92%', overflowY: 'auto' }}>
        <div style={{ width: 40, height: 5, borderRadius: 99, background: 'var(--line-2)', margin: '10px auto 8px' }} />
        {children}
      </div>
    </div>
  );
}

Object.assign(window, { RecordScreen, VaccineList, QuickRecordSheet, SheetShell, Field });
