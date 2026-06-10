// BabyLog · Crew (동네 육아 크루 · 게시판) + cold-start empty state
const { Icon, Badge, Chip, Photo, Card, SectionHead, PressBtn } = window;

function CrewScreen({ ctx, embedded }) {
  const cold = ctx.tweaks.crewDensity === 'cold';
  if (cold) return <CrewEmpty ctx={ctx} embedded={embedded} />;
  return (
    <div style={{ minHeight: '100%', background: 'var(--canvas)' }}>
      {!embedded && window.PushHeader({ title: '동네 크루', ctx, right: <Icon name="map" size={20} color="var(--ink-2)" /> })}
      <div style={{ padding: '0 18px 28px', display: 'flex', flexDirection: 'column', gap: 16 }}>

        {/* 같이 가요 */}
        <div>
          <SectionHead title="같이 가요" icon="users" action="모임 만들기" />
          <div style={{ display: 'flex', flexDirection: 'column', gap: 11 }}>
            {window.BL_DATA.meetups.map(m => (
              <Card key={m.id} pad={15}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 13 }}>
                  <div style={{ width: 50, height: 50, borderRadius: 14, background: m.type === '공원' ? 'var(--primary-tint)' : 'var(--badge-pink)', display: 'grid', placeItems: 'center', flex: 'none' }}><Icon name={m.type === '공원' ? 'sun' : 'heart'} size={24} color={m.type === '공원' ? 'var(--primary)' : '#B5478A'} /></div>
                  <div style={{ flex: 1 }}>
                    <div style={{ fontSize: 15, fontWeight: 700 }}>{m.place}</div>
                    <div style={{ fontSize: 12.5, color: 'var(--ink-2)', marginTop: 3 }}>{m.when} · {m.host} <Badge tone={m.tier} small>{m.tier === 'amber' ? '골든 맘' : '따뜻한 이웃'}</Badge></div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 5, marginTop: 7 }}>
                      <div style={{ display: 'flex' }}>{Array.from({ length: Math.min(m.joined, 4) }).map((_, i) => <span key={i} style={{ width: 22, height: 22, borderRadius: 99, background: window.PHOTO_GRADS[i], border: '1.5px solid #fff', marginLeft: i ? -7 : 0 }} />)}</div>
                      <span style={{ fontSize: 11.5, color: 'var(--ink-3)' }}>{m.joined}/{m.cap}명</span>
                    </div>
                  </div>
                  <button className="bl-liquid" style={{ height: 38, padding: '0 16px', borderRadius: 11, background: 'var(--ink)', color: '#fff', fontSize: 13.5, fontWeight: 700, fontFamily: 'inherit' }}>참가</button>
                </div>
              </Card>
            ))}
          </div>
        </div>

        {/* 크루 찾기 */}
        <div>
          <SectionHead title="비슷한 또래 크루" icon="users" />
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {window.BL_DATA.crew.map(c => (
              <Card key={c.id} pad={14} flat>
                <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                  <div style={{ width: 44, height: 44, borderRadius: 13, background: 'var(--badge-blue)', display: 'grid', placeItems: 'center', flex: 'none' }}><Icon name="users" size={22} color="#3B6FA8" /></div>
                  <div style={{ flex: 1 }}>
                    <div style={{ fontSize: 14.5, fontWeight: 700 }}>{c.name}</div>
                    <div className="t-num" style={{ fontSize: 12, color: 'var(--ink-3)', marginTop: 2 }}>{c.members}명 · {c.dist} · {c.age}</div>
                    <div style={{ display: 'flex', gap: 5, marginTop: 7 }}>{c.tags.map(t => <span key={t} style={{ fontSize: 11, color: 'var(--ink-2)', background: 'var(--surface-2)', padding: '3px 8px', borderRadius: 99 }}>{t}</span>)}</div>
                  </div>
                  <Icon name="chevron" size={18} color="var(--ink-3)" />
                </div>
              </Card>
            ))}
          </div>
        </div>

        {/* 게시판 */}
        <div>
          <SectionHead title="동네 게시판" icon="chat" action="전체" />
          <Card pad={0} style={{ overflow: 'hidden' }}>
            {window.BL_DATA.posts.map((p, i) => (
              <div key={p.id} style={{ padding: '13px 15px', borderTop: i ? '1px solid var(--line)' : 'none' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 7, marginBottom: 5 }}>
                  <Badge tone={p.cat === '고민상담' ? 'coral' : p.cat === '같이해요' ? 'mint' : 'blue'} small>{p.cat}</Badge>
                  <span style={{ fontSize: 11.5, color: 'var(--ink-3)' }}>{p.author} · {p.time}</span>
                </div>
                <div style={{ fontSize: 14.5, fontWeight: 600, lineHeight: '20px' }}>{p.title}</div>
                <div style={{ display: 'flex', gap: 14, marginTop: 8 }}>
                  <span style={{ display: 'flex', alignItems: 'center', gap: 4, fontSize: 12, color: 'var(--ink-3)' }}><Icon name="chat" size={14} color="var(--ink-3)" />{p.replies}</span>
                  <span style={{ display: 'flex', alignItems: 'center', gap: 4, fontSize: 12, color: 'var(--ink-3)' }}><Icon name="heart" size={14} color="var(--ink-3)" />{p.likes}</span>
                </div>
              </div>
            ))}
          </Card>
        </div>
      </div>
    </div>
  );
}

// ---- Cold-start empty state = 기대감 UI ----
function CrewEmpty({ ctx, embedded }) {
  return (
    <div style={{ minHeight: '100%', background: 'var(--canvas)' }}>
      {!embedded && window.PushHeader({ title: '동네 크루', ctx })}
      <div style={{ padding: '20px 22px 28px', textAlign: 'center' }}>
        <div style={{ width: 96, height: 96, borderRadius: 999, background: 'linear-gradient(135deg,#DCEFE6,#E1F5EE)', display: 'grid', placeItems: 'center', margin: '12px auto 20px' }}><Icon name="users" size={44} color="var(--primary)" /></div>
        <h1 style={{ margin: 0, fontSize: 22, fontWeight: 800 }}>망원동, 거의 다 모였어요</h1>
        <p style={{ fontSize: 14, color: 'var(--ink-2)', marginTop: 8, lineHeight: '21px' }}>조금만 더 모이면 크루 기능이 열려요.<br/>친구를 초대하면 더 빨리 열린답니다.</p>

        <div style={{ margin: '26px 0 8px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 8 }}><span style={{ fontSize: 13, fontWeight: 700 }}>우리 동네 준비도</span><span className="t-num" style={{ fontSize: 13, fontWeight: 800, color: 'var(--primary)' }}>78%</span></div>
          <div style={{ height: 12, borderRadius: 99, background: 'var(--surface-3)', overflow: 'hidden' }}><div style={{ width: '78%', height: '100%', borderRadius: 99, background: 'linear-gradient(90deg,#5E9B7C,#4E8268)' }} /></div>
          <div style={{ fontSize: 12, color: 'var(--ink-3)', marginTop: 8 }}>22명 더 모이면 오픈돼요</div>
        </div>

        <button className="bl-liquid" style={{ width: '100%', height: 54, borderRadius: 16, background: 'var(--ink)', color: '#fff', fontSize: 16, fontWeight: 700, fontFamily: 'inherit', marginTop: 18, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8 }}><Icon name="share" size={20} color="#fff" />친구 초대하고 빨리 열기</button>
        <button style={{ width: '100%', height: 50, borderRadius: 16, background: 'var(--surface)', boxShadow: 'var(--sh-1)', color: 'var(--ink)', fontSize: 15, fontWeight: 700, fontFamily: 'inherit', marginTop: 10, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8 }}><Icon name="bell" size={19} color="var(--ink-2)" />오픈 알림 신청</button>

        <Card pad={15} flat style={{ marginTop: 20, textAlign: 'left', background: 'var(--gold-tint)', border: 'none' }}>
          <div style={{ display: 'flex', gap: 11 }}><Icon name="trophy" size={22} color="#98711E" style={{ flex: 'none' }} /><div><div style={{ fontSize: 13.5, fontWeight: 700, color: '#98711E' }}>초기 멤버 혜택</div><div style={{ fontSize: 12.5, color: '#A8813A', marginTop: 3, lineHeight: '18px' }}>지금 합류하면 영구 뱃지 + Pro 체험 + 마켓 수수료 면제를 드려요.</div></div></div>
        </Card>
      </div>
    </div>
  );
}

Object.assign(window, { CrewScreen });
