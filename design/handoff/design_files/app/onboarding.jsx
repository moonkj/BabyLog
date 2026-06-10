// BabyLog · Onboarding (게스트 둘러보기 · 기록 밀도 · 아이 등록 · 권한)
const { Icon, Badge, Photo, Card, PressBtn } = window;

function Onboarding({ onDone, tweaks, setMode }) {
  const [step, setStep] = React.useState(0);
  const [density, setDensity] = React.useState(null);
  const [birth, setBirth] = React.useState('');
  const [phase, setPhase] = React.useState('baby');
  const steps = 5;
  const next = () => setStep(s => Math.min(s + 1, steps));
  const finish = () => { setMode && setMode(phase); onDone(); };
  const tone = tweaks.onboardTone || 'warm'; // warm | minimal

  return (
    <div style={{ minHeight: '100%', background: 'var(--canvas)', display: 'flex', flexDirection: 'column' }}>
      {/* progress */}
      {step > 0 && step < steps && (
        <div style={{ display: 'flex', gap: 5, padding: '54px 22px 0' }}>
          {Array.from({ length: steps - 1 }).map((_, i) => <div key={i} style={{ flex: 1, height: 4, borderRadius: 99, background: i < step ? 'var(--primary)' : 'var(--surface-3)', transition: 'background .3s' }} />)}
        </div>
      )}

      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', padding: '0 22px' }}>
        {/* 0 — splash */}
        {step === 0 && (
          <div style={{ flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'center', alignItems: 'center', textAlign: 'center' }}>
            <div style={{ width: 84, height: 84, borderRadius: 26, background: 'linear-gradient(150deg,var(--primary),#3F6B55)', display: 'grid', placeItems: 'center', boxShadow: 'var(--sh-3)', marginBottom: 26 }}>
              <svg viewBox="0 0 24 24" width="46" height="46" fill="none"><path d="M12 21s-7-4.4-7-9.6C5 8.4 7.2 6.5 9.4 6.5c1.5 0 2.4.7 2.6 1.9.2-1.2 1.1-1.9 2.6-1.9C16.8 6.5 19 8.4 19 11.4 19 16.6 12 21 12 21z" fill="#fff"/><circle cx="12" cy="4.2" r="2" fill="#FAEEDA"/></svg>
            </div>
            <div style={{ fontSize: 32, fontWeight: 800, letterSpacing: '-0.03em' }}>Baby<span style={{ color: 'var(--primary)' }}>Log</span></div>
            <p style={{ fontSize: 18, color: 'var(--ink-2)', marginTop: 12, lineHeight: '26px' }}>우리 동네 육아의<br/>모든 것</p>
            <div style={{ width: '100%', marginTop: 'auto', paddingBottom: 40 }}>
              <Btn onClick={next}>시작하기</Btn>
              <button onClick={onDone} style={{ width: '100%', height: 46, color: 'var(--ink-3)', fontSize: 14, fontWeight: 600, fontFamily: 'inherit', background: 'none', marginTop: 6 }}>이미 계정이 있어요</button>
            </div>
          </div>
        )}

        {/* 1 — value preview (guest, 야간 소아과) */}
        {step === 1 && (
          <div style={{ flex: 1, display: 'flex', flexDirection: 'column', paddingTop: 24 }}>
            <h1 style={{ fontSize: 25, fontWeight: 800, letterSpacing: '-0.02em', lineHeight: '33px', margin: 0 }}>가입 전에 먼저,<br/>지금 도움이 될 거예요</h1>
            <p style={{ fontSize: 14.5, color: 'var(--ink-2)', marginTop: 10 }}>망원동 기준 · 지금 영업 중인 소아과예요</p>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10, marginTop: 18 }}>
              {window.BL_DATA.hospitals.filter(h => h.type === '소아과' && h.open).map(h => (
                <Card key={h.id} pad={14} flat>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                    <div style={{ width: 44, height: 44, borderRadius: 12, background: 'var(--badge-coral)', display: 'grid', placeItems: 'center', flex: 'none' }}><Icon name="vaccine" size={22} color="#B45840" /></div>
                    <div style={{ flex: 1 }}><div style={{ fontSize: 15, fontWeight: 700 }}>{h.name}</div><div className="t-num" style={{ fontSize: 12.5, color: 'var(--ink-2)', marginTop: 2 }}>{h.dist}m · {h.night ? '야간진료' : '진료중'}</div></div>
                    <Badge tone="mint" dot small>영업중</Badge>
                  </div>
                </Card>
              ))}
            </div>
            <Card pad={13} flat style={{ background: 'var(--primary-tint)', border: '1px solid #CDEADD', marginTop: 14 }}>
              <div style={{ fontSize: 13, color: 'var(--ink-2)', lineHeight: '19px' }}>💡 가입하지 않아도 둘러볼 수 있어요. 마음에 들면 그때 시작하세요.</div>
            </Card>
            <div style={{ marginTop: 'auto', paddingBottom: 36, paddingTop: 16 }}><Btn onClick={next}>좋아요, 시작할게요</Btn></div>
          </div>
        )}

        {/* 2 — record density */}
        {step === 2 && (
          <div style={{ flex: 1, display: 'flex', flexDirection: 'column', paddingTop: 24 }}>
            <h1 style={{ fontSize: 25, fontWeight: 800, letterSpacing: '-0.02em', margin: 0 }}>기록은 어떻게 할까요?</h1>
            <p style={{ fontSize: 14.5, color: 'var(--ink-2)', marginTop: 10 }}>나중에 언제든 바꿀 수 있어요</p>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 12, marginTop: 22 }}>
              {[['light', 'camera', '가볍게', '사진 한 장이면 충분해요. 바쁜 날도 부담 없이.'], ['rich', 'book', '꼼꼼히', '키·몸무게·이정표까지 풍부하게 남길래요.']].map(([k, ic, t, d]) => (
                <button key={k} onClick={() => setDensity(k)} style={{ textAlign: 'left', fontFamily: 'inherit', background: density === k ? 'var(--surface)' : 'var(--surface)', border: density === k ? '2px solid var(--primary)' : '2px solid transparent', borderRadius: 20, padding: 18, boxShadow: 'var(--sh-2)', display: 'flex', gap: 14, alignItems: 'center' }}>
                  <div style={{ width: 52, height: 52, borderRadius: 15, background: density === k ? 'var(--primary)' : 'var(--primary-tint)', display: 'grid', placeItems: 'center', flex: 'none', transition: 'background .2s' }}><Icon name={ic} size={26} color={density === k ? '#fff' : 'var(--primary)'} /></div>
                  <div style={{ flex: 1 }}><div style={{ fontSize: 17, fontWeight: 800 }}>{t}</div><div style={{ fontSize: 13, color: 'var(--ink-2)', marginTop: 3, lineHeight: '18px' }}>{d}</div></div>
                  <div style={{ width: 24, height: 24, borderRadius: 99, border: density === k ? 'none' : '2px solid var(--line-2)', background: density === k ? 'var(--primary)' : 'transparent', display: 'grid', placeItems: 'center', flex: 'none' }}>{density === k && <Icon name="check" size={15} color="#fff" stroke={2.6} />}</div>
                </button>
              ))}
            </div>
            <div style={{ marginTop: 'auto', paddingBottom: 36, paddingTop: 16 }}><Btn onClick={next} disabled={!density}>다음</Btn></div>
          </div>
        )}

        {/* 3 — child register */}
        {step === 3 && (
          <div style={{ flex: 1, display: 'flex', flexDirection: 'column', paddingTop: 24 }}>
            <h1 style={{ fontSize: 25, fontWeight: 800, letterSpacing: '-0.02em', margin: 0 }}>{phase === 'pregnancy' ? '임신을 축하해요' : '아이를 알려주세요'}</h1>
            <p style={{ fontSize: 14.5, color: 'var(--ink-2)', marginTop: 10 }}>{phase === 'pregnancy' ? '예정일만 있으면 시작할 수 있어요' : '생일만 있으면 시작할 수 있어요'}</p>
            {/* phase toggle */}
            <div style={{ display: 'flex', gap: 8, marginTop: 18 }}>
              {[['baby', '👶 출산했어요'], ['pregnancy', '🤰 임신 중이에요']].map(([k, l]) => (
                <button key={k} onClick={() => setPhase(k)} style={{ flex: 1, height: 52, borderRadius: 14, fontFamily: 'inherit', fontSize: 14.5, fontWeight: 700, border: phase === k ? '2px solid var(--primary)' : '2px solid var(--line)', background: phase === k ? 'var(--primary-tint)' : 'var(--surface)', color: phase === k ? 'var(--primary-press)' : 'var(--ink-2)' }}>{l}</button>
              ))}
            </div>
            <div style={{ display: 'grid', placeItems: 'center', margin: '22px 0' }}>
              <Photo seed={phase === 'pregnancy' ? 3 : 0} radius={26} style={{ width: 96, height: 96 }}><span style={{ fontSize: 40 }}>{phase === 'pregnancy' ? '🤰' : ''}</span>{phase !== 'pregnancy' && <Icon name="camera" size={30} color="rgba(255,255,255,.9)" />}</Photo>
              <span style={{ fontSize: 12.5, color: 'var(--ink-3)', marginTop: 10 }}>사진 추가 (선택)</span>
            </div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
              <OField label="이름 또는 태명"><input placeholder={phase === 'pregnancy' ? '튼튼이' : '지호'} style={inputCss} /></OField>
              <OField label={phase === 'pregnancy' ? '출산 예정일' : '생년월일'}><input type="date" value={birth} onChange={e => setBirth(e.target.value)} className="t-num" style={inputCss} /></OField>
            </div>
            {birth && <Card pad={13} flat style={{ background: phase === 'pregnancy' ? 'var(--badge-pink)' : 'var(--gold-tint)', border: 'none', marginTop: 14 }}><div style={{ fontSize: 13, color: phase === 'pregnancy' ? '#B5478A' : '#98711E', fontWeight: 600 }}>{phase === 'pregnancy' ? '🌸 임신 주차와 산전검진 일정이 자동으로 만들어졌어요' : `🎉 D+${Math.max(1, Math.round((Date.now() - new Date(birth)) / 864e5))}일 · 예방접종 타임라인이 자동으로 만들어졌어요`}</div></Card>}
            <div style={{ marginTop: 'auto', paddingBottom: 36, paddingTop: 16 }}>
              <Btn onClick={next}>다음</Btn>
              <button onClick={next} style={{ width: '100%', height: 44, color: 'var(--ink-3)', fontSize: 14, fontWeight: 600, fontFamily: 'inherit', background: 'none', marginTop: 4 }}>나중에 할게요</button>
            </div>
          </div>
        )}

        {/* 4 — permissions (pre-permission) */}
        {step === 4 && (
          <div style={{ flex: 1, display: 'flex', flexDirection: 'column', paddingTop: 24 }}>
            <h1 style={{ fontSize: 25, fontWeight: 800, letterSpacing: '-0.02em', margin: 0 }}>두 가지만 허락해주세요</h1>
            <p style={{ fontSize: 14.5, color: 'var(--ink-2)', marginTop: 10 }}>꼭 필요할 때만, 이유와 함께 요청해요</p>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 12, marginTop: 22 }}>
              {[['pin', '위치', '근처 소아과·약국을 보여드릴게요', 'var(--badge-blue)', '#3B6FA8'], ['bell', '알림', '접종일·지원금 마감을 놓치지 않게요', 'var(--gold-tint)', '#98711E']].map(p => (
                <Card key={p[1]} pad={16}>
                  <div style={{ display: 'flex', gap: 13, alignItems: 'center' }}>
                    <div style={{ width: 48, height: 48, borderRadius: 14, background: p[3], display: 'grid', placeItems: 'center', flex: 'none' }}><Icon name={p[0]} size={24} color={p[4]} /></div>
                    <div style={{ flex: 1 }}><div style={{ fontSize: 15.5, fontWeight: 700 }}>{p[1]}</div><div style={{ fontSize: 12.5, color: 'var(--ink-2)', marginTop: 2, lineHeight: '17px' }}>{p[2]}</div></div>
                  </div>
                </Card>
              ))}
            </div>
            <div style={{ marginTop: 'auto', paddingBottom: 36, paddingTop: 16 }}>
              <Btn onClick={finish}>BabyLog 시작하기</Btn>
              <button onClick={finish} style={{ width: '100%', height: 44, color: 'var(--ink-3)', fontSize: 14, fontWeight: 600, fontFamily: 'inherit', background: 'none', marginTop: 4 }}>나중에 설정할게요</button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

const inputCss = { width: '100%', height: 52, border: '1px solid var(--line)', borderRadius: 14, padding: '0 16px', fontSize: 16, fontFamily: 'inherit', background: 'var(--surface)', boxSizing: 'border-box' };
function OField({ label, children }) { return <div><div style={{ fontSize: 12.5, color: 'var(--ink-3)', fontWeight: 600, marginBottom: 6 }}>{label}</div>{children}</div>; }
function Btn({ children, onClick, disabled }) {
  return <PressBtn onClick={disabled ? undefined : onClick} className={disabled ? undefined : 'bl-liquid'} style={{ width: '100%', height: 54, borderRadius: 16, background: disabled ? 'var(--surface-3)' : 'var(--primary)', color: disabled ? 'var(--ink-3)' : '#fff', fontSize: 16.5, fontWeight: 700, fontFamily: 'inherit', boxShadow: disabled ? 'none' : 'var(--sh-1)' }}>{children}</PressBtn>;
}

Object.assign(window, { Onboarding });
