// BabyLog · Profile (내정보) · 뱃지 컬렉션 · Pro · 절대 원칙
const { Icon, Badge, Chip, Photo, Card, SectionHead, PressBtn } = window;

function ProfileScreen({ ctx }) {
  const [cat, setCat] = React.useState('전체');
  const badges = window.BL_DATA.badges;
  const cats = ['전체', '거래', '기록', '커뮤니티', '특별'];
  const shown = badges.filter(b => cat === '전체' || b.cat === cat);
  const earned = badges.filter(b => b.earned).length;
  return (
    <div style={{ paddingBottom: 28 }}>
      <div style={{ padding: `${ctx.inset}px 18px 4px`, display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div style={{ fontSize: 24, fontWeight: 800, letterSpacing: '-0.025em' }}>내 정보</div>
        <div style={{ width: 40, height: 40, borderRadius: 12, background: 'var(--surface)', boxShadow: 'var(--sh-1)', display: 'grid', placeItems: 'center' }}><Icon name="settings" size={20} color="var(--ink-2)" /></div>
      </div>

      <div style={{ padding: '12px 18px 0' }}>
        {/* profile card */}
        <Card pad={20} style={{ background: 'linear-gradient(180deg,#FFFFFF,#FBF7F0)' }}>
          <div style={{ display: 'flex', gap: 14, alignItems: 'center' }}>
            <Photo seed={3} radius={99} style={{ width: 60, height: 60, flex: 'none' }}><span style={{ fontSize: 26 }}>🧑</span></Photo>
            <div style={{ flex: 1 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}><span style={{ fontSize: 18, fontWeight: 800 }}>지호맘</span><Badge tone="purple" dot>믿음직한 맘</Badge></div>
              <div style={{ fontSize: 12.5, color: 'var(--ink-2)', marginTop: 4 }}>16개월 아이 · 서울 마포구 · 가입 5개월</div>
            </div>
            <Icon name="edit" size={19} color="var(--ink-3)" />
          </div>
          <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', margin: '16px 0' }}>
            <Badge tone="mint">나눔 천사</Badge><Badge tone="purple">육아고수</Badge><Badge tone="grey">초기 멤버</Badge>
          </div>
          <div style={{ display: 'flex', borderTop: '1px solid var(--line)', paddingTop: 14 }}>
            {[['18', '거래'], ['4.8', '평점'], ['3', '크루'], ['91%', '응답률']].map(([v, k], i) => (
              <div key={k} style={{ flex: 1, textAlign: 'center', borderRight: i < 3 ? '1px solid var(--line)' : 'none' }}>
                <div className="t-num" style={{ fontSize: 17, fontWeight: 800 }}>{v}</div><div style={{ fontSize: 10.5, color: 'var(--ink-3)', marginTop: 2 }}>{k}</div>
              </div>
            ))}
          </div>
        </Card>

        {/* tier progress */}
        <Card pad={16} style={{ marginTop: 12 }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
            <span style={{ fontSize: 13.5, fontWeight: 700 }}>골든 맘까지</span>
            <span className="t-num" style={{ fontSize: 12.5, color: 'var(--ink-3)' }}>거래 18 / 30회</span>
          </div>
          <div style={{ height: 10, borderRadius: 99, background: 'var(--surface-3)', overflow: 'hidden' }}><div style={{ width: '60%', height: '100%', borderRadius: 99, background: 'linear-gradient(90deg,#E3B85C,#B0832E)' }} /></div>
          <div style={{ fontSize: 12, color: 'var(--ink-3)', marginTop: 8 }}>12회만 더 거래하면 골든 맘 티어로 승급해요 ✨</div>
        </Card>

        {/* Pro upsell */}
        <PressBtn onClick={() => ctx.nav.go('pro')} style={{ display: 'block', width: '100%', marginTop: 12 }}>
          <div className="bl-liquid" style={{ background: 'linear-gradient(135deg,#2A2520,#1C1814)', borderRadius: 20, padding: 18, position: 'relative', overflow: 'hidden' }}>
            <div style={{ position: 'absolute', right: -10, top: -10, opacity: .2 }}><Icon name="sparkle" size={90} color="#E3B85C" /></div>
            <Badge tone="amber" style={{ background: 'rgba(227,184,92,.2)', color: '#E3B85C' }}>BabyLog Pro</Badge>
            <div style={{ fontSize: 17, fontWeight: 800, color: '#fff', marginTop: 10 }}>사진 무제한 · AI 일지 · 또래 비교</div>
            <div style={{ fontSize: 12.5, color: 'rgba(255,255,255,.6)', marginTop: 4 }}>월 3,900원 · 데이터는 영원히 내 것</div>
          </div>
        </PressBtn>

        {/* badge collection */}
        <div style={{ marginTop: 20 }}>
          <SectionHead title={`내 뱃지 ${earned}/${badges.length}`} icon="medal" />
          <div style={{ display: 'flex', gap: 7, overflowX: 'auto', paddingBottom: 12 }}>
            {cats.map(c => <Chip key={c} on={cat === c} onClick={() => setCat(c)} style={{ height: 32, fontSize: 13 }}>{c}</Chip>)}
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gap: 10 }}>
            {shown.map(b => <BadgeTile key={b.id} b={b} />)}
          </div>
        </div>

        {/* settings — 절대 원칙 */}
        <div style={{ marginTop: 22 }}>
          <SectionHead title="데이터 · 프라이버시" icon="shield" />
          <Card pad={0} style={{ overflow: 'hidden' }}>
            {[
              ['users', '가족 공유', '아빠 · 조부모 · 최대 6명', 'var(--badge-blue)', '#3B6FA8'],
              ['shield', '데이터는 절대 판매하지 않아요', '아동 데이터 비매각 — 약속', 'var(--primary-tint)', 'var(--primary)'],
              ['share', '내 데이터 내보내기', '표준 포맷으로 언제든', 'var(--badge-purple)', '#5B53B0'],
              ['heart', '양육자 역할 설정', '맘 · 파파 · 양육자 중립', 'var(--badge-pink)', '#B5478A'],
            ].map((r, i) => (
              <div key={r[1]} style={{ display: 'flex', alignItems: 'center', gap: 13, padding: '14px 15px', borderTop: i ? '1px solid var(--line)' : 'none' }}>
                <div style={{ width: 38, height: 38, borderRadius: 11, background: r[3], display: 'grid', placeItems: 'center', flex: 'none' }}><Icon name={r[0]} size={19} color={r[4]} /></div>
                <div style={{ flex: 1 }}><div style={{ fontSize: 14.5, fontWeight: 600 }}>{r[1]}</div><div style={{ fontSize: 12, color: 'var(--ink-3)', marginTop: 1 }}>{r[2]}</div></div>
                <Icon name="chevron" size={17} color="var(--ink-3)" />
              </div>
            ))}
          </Card>
          <div style={{ textAlign: 'center', fontSize: 11.5, color: 'var(--ink-3)', marginTop: 16, lineHeight: '17px' }}>BabyLog는 광고가 없어요. 데이터를 팔지 않고,<br/>무료 데이터도 영원히 보존합니다.</div>
        </div>
      </div>
    </div>
  );
}

function BadgeTile({ b }) {
  const [pop, setPop] = React.useState(false);
  return (
    <button onClick={() => b.earned && setPop(true)} style={{
      background: b.earned ? window.BADGE_BG[b.tone] : 'var(--surface-2)', borderRadius: 16, padding: '16px 8px 12px',
      border: b.earned ? 'none' : '1px dashed var(--line-2)', fontFamily: 'inherit', position: 'relative',
      display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8, opacity: b.earned ? 1 : 0.65,
      transform: pop ? 'scale(1.04)' : 'scale(1)', transition: 'transform .2s var(--ease-out)',
    }}>
      <div style={{ width: 42, height: 42, borderRadius: 999, background: b.earned ? '#fff' : 'var(--surface-3)', display: 'grid', placeItems: 'center' }}>
        {b.earned ? <Icon name={b.icon} size={22} color={window.BADGE_INK[b.tone]} /> : <Icon name="lock" size={18} color="var(--ink-3)" />}
      </div>
      <div style={{ fontSize: 11.5, fontWeight: 700, color: b.earned ? window.BADGE_INK[b.tone] : 'var(--ink-3)', textAlign: 'center', lineHeight: '14px' }}>{b.name}</div>
      <div style={{ fontSize: 9.5, color: 'var(--ink-3)', textAlign: 'center' }}>{b.cond}</div>
    </button>
  );
}

// ---- Pro screen ----
function ProScreen({ ctx }) {
  return (
    <div style={{ minHeight: '100%', background: '#1C1814', color: '#fff' }}>
      {window.PushHeader({ title: '', ctx, dark: true, transparent: true })}
      <div style={{ padding: '0 22px 28px', marginTop: -20 }}>
        <Badge tone="amber" style={{ background: 'rgba(227,184,92,.2)', color: '#E3B85C' }}>BabyLog Pro</Badge>
        <h1 style={{ fontSize: 28, fontWeight: 800, margin: '14px 0 6px', letterSpacing: '-0.02em' }}>더 깊고 따뜻한 기록</h1>
        <p style={{ fontSize: 14.5, color: 'rgba(255,255,255,.6)', margin: 0, lineHeight: '22px' }}>광고 없이, 데이터는 영원히 내 것. 더 좋은 경험만 더해요.</p>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12, margin: '24px 0' }}>
          {[['image', '사진 무제한 저장', '무료는 월 200장'], ['sparkle', 'AI 일지 캡션 초안', '사진 보고 자동으로 한 줄'], ['chart', '또래 비교 분석', '안심 톤으로, 등수 없이'], ['book', '가계부 심층 리포트', '월별 분석 + 또래 평균'], ['bag', '매물 등록 무제한', '무료는 월 5건']].map(f => (
            <div key={f[1]} style={{ display: 'flex', gap: 13, alignItems: 'center' }}>
              <div style={{ width: 44, height: 44, borderRadius: 13, background: 'rgba(255,255,255,.08)', display: 'grid', placeItems: 'center', flex: 'none' }}><Icon name={f[0]} size={22} color="#E3B85C" /></div>
              <div><div style={{ fontSize: 15, fontWeight: 700 }}>{f[1]}</div><div style={{ fontSize: 12.5, color: 'rgba(255,255,255,.5)', marginTop: 1 }}>{f[2]}</div></div>
            </div>
          ))}
        </div>
        <div style={{ display: 'flex', gap: 10 }}>
          <div style={{ flex: 1, borderRadius: 16, border: '1px solid rgba(255,255,255,.15)', padding: 14, textAlign: 'center' }}><div style={{ fontSize: 12, color: 'rgba(255,255,255,.5)' }}>월간</div><div className="t-num" style={{ fontSize: 19, fontWeight: 800, marginTop: 3 }}>3,900원</div></div>
          <div style={{ flex: 1, borderRadius: 16, border: '1.5px solid #E3B85C', background: 'rgba(227,184,92,.1)', padding: 14, textAlign: 'center', position: 'relative' }}><span style={{ position: 'absolute', top: -9, left: '50%', transform: 'translateX(-50%)', fontSize: 10, fontWeight: 800, color: '#1C1814', background: '#E3B85C', padding: '2px 8px', borderRadius: 99 }}>38% 할인</span><div style={{ fontSize: 12, color: 'rgba(255,255,255,.5)' }}>연간</div><div className="t-num" style={{ fontSize: 19, fontWeight: 800, marginTop: 3 }}>29,000원</div></div>
        </div>
        <button className="bl-liquid" style={{ width: '100%', height: 54, borderRadius: 16, background: '#E3B85C', color: '#1C1814', fontSize: 16, fontWeight: 800, fontFamily: 'inherit', marginTop: 16 }}>7일 무료로 시작하기</button>
        <div style={{ textAlign: 'center', fontSize: 11.5, color: 'rgba(255,255,255,.4)', marginTop: 12 }}>언제든 해지 가능 · 무료 기능은 계속 무료</div>
      </div>
    </div>
  );
}

Object.assign(window, { ProfileScreen, ProScreen });
