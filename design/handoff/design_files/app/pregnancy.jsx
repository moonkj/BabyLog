// BabyLog · 임신 기록 & 태아 일지 (기능 1) — 기록 탭의 임신 모드
const { Icon, Badge, Chip, Photo, Card, SectionHead, PressBtn } = window;

function PregWeightChart() {
  const W = 300, H = 120, padL = 26, padB = 18, padT = 8, padR = 8;
  const pts = [{ w: 0, v: 52 }, { w: 8, v: 53 }, { w: 14, v: 55 }, { w: 18, v: 56.5 }, { w: 24, v: 58.4 }];
  const xmax = 40, ymin = 50, ymax = 66;
  const xs = w => padL + (w / xmax) * (W - padL - padR);
  const ys = v => padT + (1 - (v - ymin) / (ymax - ymin)) * (H - padT - padB);
  const rec = [{ w: 0, v: 52 }, { w: 40, v: 64 }];
  const recLo = [{ w: 0, v: 51 }, { w: 40, v: 62 }];
  const line = a => a.map((p, i) => `${i ? 'L' : 'M'}${xs(p.w)} ${ys(p.v)}`).join(' ');
  return (
    <svg viewBox={`0 0 ${W} ${H}`} width="100%" style={{ display: 'block' }}>
      <path d={line(rec) + ' ' + recLo.slice().reverse().map(p => `L${xs(p.w)} ${ys(p.v)}`).join(' ') + ' Z'} fill="#B5478A" opacity="0.09" />
      {[55, 60, 65].map(v => <text key={v} x={padL - 5} y={ys(v) + 3} fontSize="8.5" fill="var(--ink-3)" textAnchor="end" fontFamily="var(--num)">{v}</text>)}
      <path d={line(pts)} fill="none" stroke="#B5478A" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round" />
      {pts.map(p => <circle key={p.w} cx={xs(p.w)} cy={ys(p.v)} r="2.3" fill="#fff" stroke="#B5478A" strokeWidth="1.6" />)}
    </svg>
  );
}

function PregnancyScreen({ ctx }) {
  const [seg, setSeg] = React.useState('fetus');
  const p = window.BL_DATA.pregnancy;
  return (
    <div style={{ minHeight: '100%', background: 'var(--canvas)' }}>
      <div style={{ padding: `${ctx.inset}px 18px 8px` }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div style={{ fontSize: 24, fontWeight: 800, letterSpacing: '-0.025em' }}>기록</div>
          <button onClick={() => ctx.nav.go('birthTransition')} style={{ display: 'flex', alignItems: 'center', gap: 5, height: 36, padding: '0 13px', borderRadius: 999, background: 'var(--badge-pink)', color: '#B5478A', fontSize: 13, fontWeight: 700, fontFamily: 'inherit' }}><Icon name="baby" size={15} color="#B5478A" />출산했어요</button>
        </div>
      </div>

      {/* hero pregnancy card */}
      <div style={{ padding: '8px 18px 14px' }}>
        <Card pad={0} style={{ overflow: 'hidden', background: 'linear-gradient(150deg,#FBE6EE,#F6D6E4)' }}>
          <div style={{ padding: 18, display: 'flex', alignItems: 'center', gap: 16 }}>
            <div style={{ width: 92, height: 92, borderRadius: 999, background: '#fff', display: 'grid', placeItems: 'center', flex: 'none', boxShadow: 'var(--sh-1)' }}>
              <span style={{ fontSize: 46 }}>{p.fruitEmoji}</span>
            </div>
            <div style={{ flex: 1 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 7 }}>
                <Badge tone="pink" dot>{p.trimester}</Badge>
                <span style={{ fontSize: 12.5, color: '#A8537E', fontWeight: 600 }}>{p.clinic}</span>
              </div>
              <div style={{ fontSize: 20, fontWeight: 800, marginTop: 8, letterSpacing: '-0.01em' }}>{p.nickname} · {p.week}주 {p.day}일</div>
              <div className="t-num" style={{ fontSize: 13.5, color: '#A8537E', marginTop: 3 }}>출산까지 D-{p.dday} · {p.fruit}만 해요 ({p.fetusLen}cm)</div>
            </div>
          </div>
        </Card>
      </div>

      {/* segment */}
      <div style={{ display: 'flex', gap: 4, padding: '0 18px 14px' }}>
        {[['fetus', '태아 가이드'], ['mom', '산모 기록'], ['checkup', '산전 검사']].map(([k, l]) => (
          <button key={k} onClick={() => setSeg(k)} style={{ flex: 1, height: 38, borderRadius: 11, fontFamily: 'inherit', fontSize: 14, fontWeight: 700, background: seg === k ? 'var(--ink)' : 'var(--surface)', color: seg === k ? '#fff' : 'var(--ink-2)', boxShadow: seg === k ? 'none' : 'var(--sh-1)' }}>{l}</button>
        ))}
      </div>

      {seg === 'fetus' && (
        <div style={{ padding: '0 18px 28px', display: 'flex', flexDirection: 'column', gap: 12 }}>
          <Card pad={18}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 12 }}>
              <Icon name="sparkle" size={16} color="#B5478A" /><span style={{ fontSize: 12.5, fontWeight: 700, color: '#B5478A' }}>{p.week}주차 태아 발달</span>
            </div>
            <div style={{ display: 'flex', gap: 10, marginBottom: 14 }}>
              <Mini2 v={`${p.fetusLen}cm`} k="키" /><Mini2 v={`${p.fetusWeight}g`} k="몸무게" /><Mini2 v={p.fruit} k="크기 비유" />
            </div>
            <p style={{ margin: 0, fontSize: 14.5, lineHeight: '22px', color: 'var(--ink)', textWrap: 'pretty' }}>{p.devNote}</p>
            <div style={{ fontSize: 11, color: 'var(--ink-3)', marginTop: 10 }}>※ 일반 정보이며 의료 상담을 대체하지 않아요</div>
          </Card>
          <SectionHead title="지난 주차" />
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10, marginTop: -4 }}>
            {p.weeklyTimeline.map(w => (
              <Card key={w.w} pad={13} flat>
                <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                  <div style={{ width: 42, height: 42, borderRadius: 12, background: 'var(--badge-pink)', display: 'grid', placeItems: 'center', flex: 'none' }}><span style={{ fontSize: 20 }}>{w.fruit === '망고' ? '🥭' : w.fruit === '파파야' ? '🫐' : '🌽'}</span></div>
                  <div style={{ flex: 1 }}><div style={{ fontSize: 14.5, fontWeight: 700 }}>{w.w}주 · {w.fruit}만 해요</div><div style={{ fontSize: 12.5, color: 'var(--ink-2)', marginTop: 2 }}>{w.note}</div></div>
                </div>
              </Card>
            ))}
          </div>
        </div>
      )}

      {seg === 'mom' && (
        <div style={{ padding: '0 18px 28px', display: 'flex', flexDirection: 'column', gap: 12 }}>
          {/* 태동 카운터 */}
          <Card pad={16}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <div><div style={{ fontSize: 14.5, fontWeight: 700 }}>오늘의 태동</div><div style={{ fontSize: 12.5, color: 'var(--ink-3)', marginTop: 2 }}>10회 목표 · 말기 건강 체크</div></div>
              <div style={{ display: 'flex', alignItems: 'baseline', gap: 3 }}><span className="t-num" style={{ fontSize: 28, fontWeight: 800, color: '#B5478A' }}>{p.movements}</span><span style={{ fontSize: 15, color: 'var(--ink-3)', fontWeight: 600 }}>/{p.movementGoal}</span></div>
            </div>
            <div style={{ display: 'flex', gap: 5, marginTop: 12 }}>
              {Array.from({ length: 10 }).map((_, i) => <div key={i} style={{ flex: 1, height: 8, borderRadius: 99, background: i < p.movements ? '#D96BA0' : 'var(--surface-3)' }} />)}
            </div>
            <button className="bl-liquid" style={{ width: '100%', height: 44, borderRadius: 12, background: '#B5478A', color: '#fff', fontSize: 14.5, fontWeight: 700, fontFamily: 'inherit', marginTop: 14 }}>＋ 태동 기록</button>
          </Card>

          {/* 체중 추이 */}
          <Card pad={16}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 4 }}>
              <span style={{ fontSize: 15, fontWeight: 700 }}>체중 변화</span>
              <span className="t-num" style={{ fontSize: 13, color: 'var(--ink-2)' }}>{p.momWeight}kg · +{p.momGain}kg</span>
            </div>
            <PregWeightChart />
            <div style={{ fontSize: 11.5, color: 'var(--ink-3)', marginTop: 4, textAlign: 'center' }}>권장 증가 범위 안에서 건강하게 늘고 있어요</div>
          </Card>

          {/* 배 사진 타임라인 */}
          <div>
            <SectionHead title="배 사진 (D라인)" action="추가" />
            <div style={{ display: 'flex', gap: 10, overflowX: 'auto', padding: '0 0 4px' }}>
              {p.bellyPhotos.map(b => (
                <div key={b.w} style={{ flex: 'none' }}>
                  <Photo seed={b.seed} radius={14} icon="baby" iconColor="rgba(255,255,255,.75)" style={{ width: 104, height: 132 }} label={`${b.w}주`} />
                </div>
              ))}
            </div>
            <div style={{ fontSize: 11.5, color: 'var(--ink-3)', marginTop: 8 }}>출산 후 아이 성장 사진으로 끊김 없이 이어져요</div>
          </div>

          {/* 증상 */}
          <Card pad={15} flat>
            <div style={{ fontSize: 13.5, fontWeight: 700, marginBottom: 10 }}>오늘 컨디션</div>
            <div style={{ display: 'flex', gap: 7, flexWrap: 'wrap' }}>{p.symptoms.map(s => <span key={s} style={{ fontSize: 13, color: 'var(--ink-2)', background: 'var(--surface-2)', border: '1px solid var(--line)', padding: '7px 12px', borderRadius: 99 }}>{s}</span>)}</div>
          </Card>
        </div>
      )}

      {seg === 'checkup' && (
        <div style={{ padding: '0 18px 28px', display: 'flex', flexDirection: 'column', gap: 10 }}>
          <Card pad={16} style={{ background: 'linear-gradient(135deg,#FBE6EE,#F6D6E4)' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
              <div style={{ width: 46, height: 46, borderRadius: 13, background: '#fff', display: 'grid', placeItems: 'center', flex: 'none' }}><Icon name="vaccine" size={22} color="#B5478A" /></div>
              <div style={{ flex: 1 }}><div style={{ fontSize: 15, fontWeight: 800 }}>임신성 당뇨 검사</div><div style={{ fontSize: 12.5, color: '#A8537E', marginTop: 2 }}>24~28주 · 공복 검사 · 미래여성병원</div></div>
              <span className="t-num" style={{ fontSize: 22, fontWeight: 800, color: '#B5478A' }}>D-3</span>
            </div>
          </Card>
          {window.BL_DATA.pregnancy.checkups.map(c => (
            <Card key={c.id} pad={14} flat>
              <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                <div style={{ width: 38, height: 38, borderRadius: 11, background: c.status === 'done' ? 'var(--badge-pink)' : 'var(--surface-3)', display: 'grid', placeItems: 'center', flex: 'none' }}><Icon name={c.status === 'done' ? 'check' : 'calendar'} size={19} color={c.status === 'done' ? '#B5478A' : 'var(--ink-3)'} /></div>
                <div style={{ flex: 1 }}><div style={{ fontSize: 14.5, fontWeight: 700 }}>{c.name}</div><div style={{ fontSize: 12.5, color: 'var(--ink-3)', marginTop: 2 }}>{c.week}{c.date ? ` · ${c.date}` : ''}</div></div>
                {c.status === 'done' ? <Badge tone="pink">완료</Badge> : c.status === 'soon' ? <Badge tone="amber">{c.due}</Badge> : <span className="t-num" style={{ fontSize: 13, color: 'var(--ink-3)', fontWeight: 700 }}>{c.due}</span>}
              </div>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}

function Mini2({ v, k }) {
  return <div style={{ flex: 1, background: 'var(--surface-2)', borderRadius: 12, padding: '10px 8px', textAlign: 'center' }}><div className="t-num" style={{ fontSize: 16, fontWeight: 800 }}>{v}</div><div style={{ fontSize: 10.5, color: 'var(--ink-3)', marginTop: 2 }}>{k}</div></div>;
}

// ── 출산 전환 ──
function BirthTransition({ ctx }) {
  const [done, setDone] = React.useState(false);
  const p = window.BL_DATA.pregnancy;
  if (done) return (
    <div style={{ minHeight: '100%', background: 'var(--canvas)' }}>
      {window.PushHeader({ title: '', ctx })}
      <div style={{ padding: '8px 22px 28px', textAlign: 'center' }}>
        <div style={{ width: 92, height: 92, borderRadius: 999, background: 'var(--primary-tint)', display: 'grid', placeItems: 'center', margin: '12px auto 18px', animation: 'pop .5s var(--ease-out)' }}><span style={{ fontSize: 46 }}>👶</span></div>
        <h1 style={{ margin: 0, fontSize: 24, fontWeight: 800 }}>세상에 온 걸 환영해요</h1>
        <p style={{ fontSize: 14.5, color: 'var(--ink-2)', marginTop: 10, lineHeight: '22px' }}>{p.nickname}의 태아 시절 기록은 그대로 보존했어요.<br/>이제 성장 기록으로 함께 이어가요.</p>
        <Card pad={14} flat style={{ marginTop: 22, textAlign: 'left' }}>
          {[['배 사진 → 성장 사진', '끊김 없는 하나의 타임라인'], ['예방접종 타임라인', '생년월일 기준 자동 생성'], ['가족 공유 유지', '아빠·조부모 그대로 연결']].map(r => (
            <div key={r[0]} style={{ display: 'flex', alignItems: 'center', gap: 11, padding: '9px 0' }}><div style={{ width: 26, height: 26, borderRadius: 8, background: 'var(--primary-tint)', display: 'grid', placeItems: 'center', flex: 'none' }}><Icon name="check" size={15} color="var(--primary)" /></div><div><div style={{ fontSize: 14, fontWeight: 600 }}>{r[0]}</div><div style={{ fontSize: 12, color: 'var(--ink-3)' }}>{r[1]}</div></div></div>
          ))}
        </Card>
        <button onClick={() => { ctx.setMode('baby'); ctx.nav.back(); ctx.nav.tab('record'); }} className="bl-liquid" style={{ width: '100%', height: 54, borderRadius: 16, background: 'var(--primary)', color: '#fff', fontSize: 16, fontWeight: 700, fontFamily: 'inherit', marginTop: 22 }}>성장 기록 시작하기</button>
      </div>
    </div>
  );
  return (
    <div style={{ minHeight: '100%', background: 'var(--canvas)' }}>
      {window.PushHeader({ title: '출산 전환', ctx })}
      <div style={{ padding: '8px 22px 28px' }}>
        <div style={{ display: 'grid', placeItems: 'center', margin: '8px 0 20px' }}>
          <div style={{ width: 88, height: 88, borderRadius: 999, background: 'linear-gradient(150deg,#FBE6EE,#DCEFE6)', display: 'grid', placeItems: 'center' }}><span style={{ fontSize: 42 }}>🤰</span></div>
        </div>
        <h1 style={{ margin: 0, fontSize: 23, fontWeight: 800, textAlign: 'center' }}>아기가 태어났나요?</h1>
        <p style={{ fontSize: 14, color: 'var(--ink-2)', marginTop: 10, lineHeight: '21px', textAlign: 'center' }}>{p.nickname}의 임신 기록을 아이 프로필로 이어드릴게요.</p>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12, marginTop: 24 }}>
          <Field2 label="아이 이름"><input placeholder={p.nickname} style={inCss} /></Field2>
          <Field2 label="실제 생년월일"><input type="date" className="t-num" style={inCss} /></Field2>
        </div>
        <button onClick={() => setDone(true)} className="bl-liquid" style={{ width: '100%', height: 54, borderRadius: 16, background: 'var(--primary)', color: '#fff', fontSize: 16, fontWeight: 700, fontFamily: 'inherit', marginTop: 22 }}>아이 프로필로 전환</button>
        <button onClick={() => ctx.nav.back()} style={{ width: '100%', height: 46, color: 'var(--ink-3)', fontSize: 14, fontWeight: 600, fontFamily: 'inherit', background: 'none', marginTop: 4 }}>아직이에요</button>
      </div>
    </div>
  );
}
const inCss = { width: '100%', height: 52, border: '1px solid var(--line)', borderRadius: 14, padding: '0 16px', fontSize: 16, fontFamily: 'inherit', background: 'var(--surface)', boxSizing: 'border-box' };
function Field2({ label, children }) { return <div><div style={{ fontSize: 12.5, color: 'var(--ink-3)', fontWeight: 600, marginBottom: 6 }}>{label}</div>{children}</div>; }

Object.assign(window, { PregnancyScreen, BirthTransition });
