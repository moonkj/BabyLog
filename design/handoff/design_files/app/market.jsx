// BabyLog · Market (중고마켓·렌탈) + item detail + sell sheet
const { Icon, Badge, Chip, Photo, Card, SectionHead, PressBtn } = window;

const GRADE_TONE = { S: 'blue', A: 'mint', B: 'amber', C: 'coral' };

function MarketScreen({ ctx, embedded }) {
  const [cat, setCat] = React.useState('전체');
  const cats = ['전체', '의류', '수유용품', '이동수단', '완구', '식사'];
  const items = window.BL_DATA.market.filter(m => cat === '전체' || m.cat === cat);
  return (
    <div style={{ paddingBottom: 24 }}>
      {!embedded && (
      <div style={{ padding: '8px 18px 12px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div style={{ fontSize: 24, fontWeight: 800, letterSpacing: '-0.025em' }}>동네 마켓</div>
        <div style={{ display: 'flex', gap: 8 }}>
          <IconBtn icon="search" /><IconBtn icon="bell" dot />
        </div>
      </div>
      )}

      {/* 곧 필요해요 feed */}
      <div style={{ marginBottom: 6 }}>
        <SectionHead title="곧 필요해요" icon="sparkle" />
        <div style={{ display: 'flex', gap: 10, overflowX: 'auto', padding: '0 18px 4px' }}>
          {window.BL_DATA.needSoon.map(n => (
            <button key={n.id} style={{ flex: 'none', width: 124, fontFamily: 'inherit', textAlign: 'left', background: 'none' }}>
              <Photo seed={n.seed} radius={14} icon="bag" style={{ width: 124, height: 92 }} />
              <div style={{ fontSize: 13.5, fontWeight: 700, marginTop: 7 }}>{n.title}</div>
              <div style={{ fontSize: 11.5, color: 'var(--ink-3)', marginTop: 1 }}>{n.reason}</div>
            </button>
          ))}
        </div>
      </div>

      {/* category */}
      <div style={{ display: 'flex', gap: 8, padding: '10px 18px 14px', overflowX: 'auto' }}>
        {cats.map(c => <Chip key={c} on={cat === c} onClick={() => setCat(c)}>{c}</Chip>)}
      </div>

      <div style={{ padding: '0 18px', display: 'flex', flexDirection: 'column', gap: 12 }}>
        {items.map(it => <MarketCard key={it.id} it={it} ctx={ctx} />)}
      </div>
    </div>
  );
}

function IconBtn({ icon, dot }) {
  return <div style={{ width: 40, height: 40, borderRadius: 12, background: 'var(--surface)', boxShadow: 'var(--sh-1)', display: 'grid', placeItems: 'center', position: 'relative' }}><Icon name={icon} size={20} color="var(--ink-2)" />{dot && <span style={{ position: 'absolute', top: 9, right: 10, width: 8, height: 8, borderRadius: 99, background: 'var(--danger)', border: '1.5px solid #fff' }} />}</div>;
}

function MarketCard({ it, ctx }) {
  return (
    <PressBtn onClick={() => ctx.nav.go('itemDetail', it)} scale={0.99} style={{ display: 'block', textAlign: 'left' }}>
      <Card pad={0} style={{ overflow: 'hidden' }}>
        <div style={{ display: 'flex' }}>
          <Photo seed={it.seed} radius={0} icon="bag" style={{ width: 112, flex: 'none', alignSelf: 'stretch' }}>
            {it.recall && <div style={{ position: 'absolute', left: 8, top: 8 }}><Badge tone="coral" small><Icon name="warning" size={11} color="#B45840" />리콜</Badge></div>}
            {it.graduate && <div style={{ position: 'absolute', left: 8, bottom: 8 }}><Badge tone="mint" small>졸업템</Badge></div>}
          </Photo>
          <div style={{ flex: 1, padding: 14, minWidth: 0 }}>
            <div style={{ display: 'flex', gap: 5, marginBottom: 6 }}>
              <Badge tone={GRADE_TONE[it.grade]} small>{it.grade}등급</Badge>
              <Badge tone="grey" small>{it.months}</Badge>
            </div>
            <div style={{ fontSize: 15, fontWeight: 700, lineHeight: '20px', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{it.title}</div>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 7, marginTop: 6 }}>
              <span className="t-num" style={{ fontSize: 18, fontWeight: 800 }}>{it.free ? '무료나눔' : it.price.toLocaleString() + '원'}</span>
              {!it.free && it.orig && <span className="t-num" style={{ fontSize: 12, color: 'var(--ink-3)', textDecoration: 'line-through' }}>{it.orig.toLocaleString()}</span>}
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 9 }}>
              <span style={{ fontSize: 12, color: 'var(--ink-2)', fontWeight: 600 }}>{it.seller}</span>
              <Badge tone={it.tier} small>{it.tierName}</Badge>
              {it.subName && <Badge tone={it.sub} small>{it.subName}</Badge>}
            </div>
            <div style={{ fontSize: 11, color: 'var(--ink-3)', marginTop: 7, display: 'flex', alignItems: 'center', gap: 4 }}><Icon name="pin" size={11} color="var(--ink-3)" />{it.dist} · 관심 {it.fav}</div>
          </div>
        </div>
      </Card>
    </PressBtn>
  );
}

function ItemDetail({ ctx, params }) {
  const it = params;
  return (
    <div style={{ minHeight: '100%', background: 'var(--canvas)', paddingBottom: 88 }}>
      {window.PushHeader({ title: '', ctx, transparent: true })}
      <Photo seed={it.seed} radius={0} icon="bag" iconColor="rgba(255,255,255,.8)" style={{ height: 280, marginTop: -52 }} />
      <div style={{ padding: '18px 18px 0' }}>
        {/* seller */}
        <Card pad={14} flat style={{ marginBottom: 16 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 11 }}>
            <Photo seed={1} radius={99} style={{ width: 42, height: 42, flex: 'none' }}><span style={{ fontSize: 18 }}>{it.seller[0]}</span></Photo>
            <div style={{ flex: 1 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}><span style={{ fontSize: 14.5, fontWeight: 700 }}>{it.seller}</span><Badge tone={it.tier} small>{it.tierName}</Badge></div>
              <div className="t-num" style={{ fontSize: 12, color: 'var(--ink-3)', marginTop: 2 }}>{it.dist} · 거래 47회 · 응답률 94%</div>
            </div>
            <Icon name="chevron" size={18} color="var(--ink-3)" />
          </div>
        </Card>

        {it.recall && (
          <Card pad={14} flat style={{ background: 'var(--danger-tint)', border: '1px solid #F0C6BB', marginBottom: 16 }}>
            <div style={{ display: 'flex', gap: 11 }}>
              <Icon name="warning" size={22} color="var(--danger)" style={{ flex: 'none', marginTop: 1 }} />
              <div><div style={{ fontSize: 14, fontWeight: 700, color: '#9A3A29' }}>리콜 이력이 있는 모델이에요</div><div style={{ fontSize: 12.5, color: '#A8513F', marginTop: 3, lineHeight: '18px' }}>KATSA 리콜 DB 기준. 구매 전 제조사 무상 점검 여부를 꼭 확인하세요.</div></div>
            </div>
          </Card>
        )}

        <div style={{ display: 'flex', gap: 6, marginBottom: 10 }}>
          <Badge tone={GRADE_TONE[it.grade]}>{it.grade}등급 · {it.grade === 'S' ? '거의새것' : it.grade === 'A' ? '깨끗' : '사용감있음'}</Badge>
          <Badge tone="grey">{it.months}</Badge>
          {it.graduate && <Badge tone="mint">동네 졸업템</Badge>}
        </div>
        <h1 style={{ margin: '0 0 8px', fontSize: 21, fontWeight: 800, lineHeight: '28px' }}>{it.title}</h1>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 9 }}>
          <span className="t-num" style={{ fontSize: 26, fontWeight: 800 }}>{it.free ? '무료나눔' : it.price.toLocaleString() + '원'}</span>
          {!it.free && it.orig && <span className="t-num" style={{ fontSize: 14, color: 'var(--ink-3)' }}>정가 {it.orig.toLocaleString()}원</span>}
        </div>
        <p style={{ fontSize: 14.5, lineHeight: '23px', color: 'var(--ink-2)', marginTop: 16, textWrap: 'pretty' }}>
          {it.months} 동안 사용했어요. 큰 하자 없이 깨끗하게 썼고, 위생 상태 체크리스트 사진도 올렸어요. 같은 단지라 직거래 환영합니다 :)
        </p>
        {/* hygiene checklist */}
        <Card pad={14} style={{ marginTop: 16 }}>
          <div style={{ fontSize: 13.5, fontWeight: 700, marginBottom: 10 }}>위생 상태 셀프 체크</div>
          {['세척·소독 완료', '부품 누락 없음', '곰팡이·얼룩 없음'].map(c => (
            <div key={c} style={{ display: 'flex', alignItems: 'center', gap: 9, padding: '5px 0' }}><div style={{ width: 20, height: 20, borderRadius: 6, background: 'var(--primary-tint)', display: 'grid', placeItems: 'center' }}><Icon name="check" size={13} color="var(--primary)" /></div><span style={{ fontSize: 13.5, color: 'var(--ink-2)' }}>{c}</span></div>
          ))}
        </Card>
      </div>

      {/* bottom bar */}
      <div style={{ position: 'absolute', left: 0, right: 0, bottom: 0, padding: '12px 18px 26px', background: 'var(--surface)', borderTop: '1px solid var(--line)', display: 'flex', alignItems: 'center', gap: 12 }}>
        <button style={{ width: 48, height: 48, borderRadius: 13, border: '1px solid var(--line)', display: 'grid', placeItems: 'center', background: 'none', fontFamily: 'inherit' }}><Icon name="heart" size={22} color="var(--ink-2)" /></button>
        <button onClick={() => ctx.nav.go('chat', it)} className="bl-liquid" style={{ flex: 1, height: 50, borderRadius: 14, background: 'var(--primary)', color: '#fff', fontSize: 16, fontWeight: 700, fontFamily: 'inherit', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 7 }}><Icon name="chat" size={20} color="#fff" />채팅하기</button>
      </div>
    </div>
  );
}

// ---------- Sell sheet (성장 졸업 트리거 + AI 자동등록) ----------
function SellSheet({ ctx, onClose }) {
  const [step, setStep] = React.useState(0);
  return (
    <window.SheetShell onClose={onClose}>
      <div style={{ padding: '4px 20px 16px' }}>
        {step === 0 && (<>
          <div style={{ fontSize: 19, fontWeight: 800, marginBottom: 4 }}>무엇을 정리할까요?</div>
          <div style={{ fontSize: 13.5, color: 'var(--ink-2)', marginBottom: 16 }}>지호가 졸업한 물건이에요. 사진을 올리면 AI가 자동 분류해드려요.</div>
          <Photo seed={0} radius={18} icon={null} style={{ height: 180, marginBottom: 14 }}>
            <div style={{ textAlign: 'center', color: '#fff' }}><Icon name="camera" size={34} color="rgba(255,255,255,.95)" style={{ margin: '0 auto 8px' }} /><div style={{ fontSize: 13.5, fontWeight: 600, textShadow: '0 1px 4px rgba(0,0,0,.3)' }}>사진 추가 (최소 2장)</div></div>
          </Photo>
          <Card pad={13} flat style={{ background: 'var(--primary-tint)', border: '1px solid #CDEADD', marginBottom: 14 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}><Icon name="sparkle" size={20} color="var(--primary)" /><div style={{ flex: 1 }}><div style={{ fontSize: 13.5, fontWeight: 700 }}>AI 자동 인식</div><div style={{ fontSize: 12, color: 'var(--ink-2)', marginTop: 1 }}>식사 의자 · 6개월+ 로 분류했어요</div></div><Badge tone="mint" small>온디바이스</Badge></div>
          </Card>
          <button onClick={() => setStep(1)} className="bl-liquid" style={{ width: '100%', height: 52, borderRadius: 15, background: 'var(--primary)', color: '#fff', fontSize: 16, fontWeight: 700, fontFamily: 'inherit' }}>다음</button>
        </>)}
        {step === 1 && (<>
          <div style={{ fontSize: 19, fontWeight: 800, marginBottom: 14 }}>상태와 가격</div>
          <div style={{ fontSize: 12.5, fontWeight: 700, color: 'var(--ink-3)', marginBottom: 8 }}>상태 등급</div>
          <div style={{ display: 'flex', gap: 8, marginBottom: 16 }}>
            {['S', 'A', 'B', 'C'].map((g, i) => <button key={g} style={{ flex: 1, height: 56, borderRadius: 13, border: i === 0 ? '1.5px solid var(--ink)' : '1px solid var(--line)', background: i === 0 ? 'var(--ink)' : 'var(--surface)', color: i === 0 ? '#fff' : 'var(--ink-2)', fontFamily: 'inherit', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 2 }}><span style={{ fontSize: 17, fontWeight: 800 }}>{g}</span><span style={{ fontSize: 10 }}>{['거의새것', '깨끗', '사용감', '하자'][i]}</span></button>)}
          </div>
          <div style={{ fontSize: 12.5, fontWeight: 700, color: 'var(--ink-3)', marginBottom: 8 }}>가격 · AI 시세 제안</div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, height: 56, border: '1px solid var(--line)', borderRadius: 14, padding: '0 16px', marginBottom: 8 }}><span className="t-num" style={{ fontSize: 22, fontWeight: 800 }}>95,000</span><span style={{ fontSize: 15, color: 'var(--ink-2)' }}>원</span><span style={{ marginLeft: 'auto' }}><Badge tone="mint" small>비슷한 매물 평균</Badge></span></div>
          <button onClick={() => { onClose(); }} className="bl-liquid" style={{ width: '100%', height: 52, borderRadius: 15, background: 'var(--primary)', color: '#fff', fontSize: 16, fontWeight: 700, fontFamily: 'inherit', marginTop: 8 }}>등록하기</button>
        </>)}
      </div>
    </window.SheetShell>
  );
}

// ---------- Simple chat ----------
function ChatScreen({ ctx, params }) {
  const it = params;
  return (
    <div style={{ minHeight: '100%', background: 'var(--canvas)', display: 'flex', flexDirection: 'column' }}>
      {window.PushHeader({ title: it.seller, ctx, subtitle: it.tierName })}
      <div style={{ flex: 1, padding: '8px 18px', display: 'flex', flexDirection: 'column', gap: 10 }}>
        <Card pad={10} flat style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
          <Photo seed={it.seed} radius={10} icon="bag" style={{ width: 44, height: 44 }} />
          <div style={{ flex: 1 }}><div style={{ fontSize: 13, fontWeight: 600 }}>{it.title}</div><div className="t-num" style={{ fontSize: 14, fontWeight: 800 }}>{it.free ? '무료나눔' : it.price.toLocaleString() + '원'}</div></div>
        </Card>
        <Bubble me>안녕하세요! 혹시 직거래 가능할까요?</Bubble>
        <Bubble>네 가능해요 :) 같은 단지시면 더 편하실 거예요</Bubble>
        <Bubble>오늘 저녁 7시에 정문 앞 어떠세요?</Bubble>
        <Bubble me>좋아요! 그때 뵐게요 😊</Bubble>
        <div style={{ textAlign: 'center', margin: '6px 0' }}><Badge tone="blue"><Icon name="shield" size={12} color="#3B6FA8" />주민센터 앞 안심 거래존 추천</Badge></div>
      </div>
      <div style={{ padding: '10px 16px 26px', background: 'var(--surface)', borderTop: '1px solid var(--line)', display: 'flex', gap: 10, alignItems: 'center' }}>
        <div style={{ flex: 1, height: 44, borderRadius: 999, background: 'var(--surface-2)', border: '1px solid var(--line)', display: 'flex', alignItems: 'center', padding: '0 16px', color: 'var(--ink-3)', fontSize: 14 }}>메시지 보내기</div>
        <button style={{ width: 44, height: 44, borderRadius: 999, background: 'var(--primary)', display: 'grid', placeItems: 'center', fontFamily: 'inherit' }}><Icon name="arrowR" size={20} color="#fff" /></button>
      </div>
    </div>
  );
}
function Bubble({ children, me }) {
  return <div style={{ alignSelf: me ? 'flex-end' : 'flex-start', maxWidth: '78%', background: me ? 'var(--primary)' : 'var(--surface)', color: me ? '#fff' : 'var(--ink)', padding: '10px 14px', borderRadius: me ? '18px 18px 5px 18px' : '18px 18px 18px 5px', fontSize: 14.5, lineHeight: '20px', boxShadow: me ? 'none' : 'var(--sh-1)' }}>{children}</div>;
}

Object.assign(window, { MarketScreen, ItemDetail, SellSheet, ChatScreen });
