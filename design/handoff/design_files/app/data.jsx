// BabyLog · mock data  (exports to window as BL_DATA)
const BL_DATA = {
  children: [
    { id: 'c1', name: '지호', emoji: '👶', gender: 'boy', birth: '2025-02-04', months: 16, dday: 491, height: 78.5, weight: 10.2, head: 46.1, seed: 0 },
    { id: 'c2', name: '서아', emoji: '🧒', gender: 'girl', birth: '2023-09-12', months: 33, dday: 1002, height: 92.0, weight: 13.4, head: 48.5, seed: 3 },
  ],
  // growth timeline records
  records: [
    { id: 'r1', day: '오늘', mins: '14:20', type: 'photo', seed: 1, milestone: '첫 걸음마', caption: '드디어 혼자 세 걸음! 너무 대견해 🥹', likes: 2 },
    { id: 'r2', day: '오늘', mins: '08:05', type: 'growth', height: 78.5, weight: 10.2 },
    { id: 'r3', day: '어제', mins: '19:40', type: 'photo', seed: 4, caption: '이유식 호박죽 완밥!', likes: 1 },
    { id: 'r4', day: '2일 전', mins: '11:10', type: 'photo', seed: 2, milestone: '첫 이앓이', caption: '아랫니가 빼꼼 났어요', likes: 3 },
    { id: 'r5', day: '3일 전', mins: '16:30', type: 'vaccine', vaccine: 'DTaP 3차', hospital: '행복소아과' },
    { id: 'r6', day: '4일 전', mins: '09:15', type: 'photo', seed: 5, caption: '아침 산책길에서' },
  ],
  // growth chart points (months -> weight, with WHO bands)
  growthChart: {
    weight: [
      { m: 0, v: 3.3 }, { m: 2, v: 5.6 }, { m: 4, v: 7.0 }, { m: 6, v: 7.9 },
      { m: 9, v: 8.9 }, { m: 12, v: 9.6 }, { m: 16, v: 10.2 },
    ],
    p50: [{ m: 0, v: 3.3 }, { m: 4, v: 7.0 }, { m: 8, v: 8.6 }, { m: 12, v: 9.6 }, { m: 16, v: 10.5 }],
    p15: [{ m: 0, v: 2.9 }, { m: 4, v: 6.2 }, { m: 8, v: 7.7 }, { m: 12, v: 8.6 }, { m: 16, v: 9.4 }],
    p85: [{ m: 0, v: 3.9 }, { m: 4, v: 7.9 }, { m: 8, v: 9.6 }, { m: 12, v: 10.8 }, { m: 16, v: 11.7 }],
  },
  vaccines: [
    { id: 'v1', name: 'DTaP 4차', age: '15~18개월', due: 'D-4', status: 'soon' },
    { id: 'v2', name: 'MMR 1차', age: '12~15개월', due: '완료', status: 'done', date: '4월 2일' },
    { id: 'v3', name: '일본뇌염 1차', age: '12~23개월', due: 'D-23', status: 'upcoming' },
    { id: 'v4', name: '수두', age: '12~15개월', due: '완료', status: 'done', date: '4월 2일' },
  ],
  milestones: ['첫 미소','첫 뒤집기','첫 옹알이','첫니','첫 앉기','첫 기기','첫 걸음마','첫 단어','첫 이유식','첫 외출'],
  hospitals: [
    { id: 'h1', name: '행복소아과의원', type: '소아과', open: true, night: true, dist: 320, rating: 4.8, reviews: 214, confirm: '3분 전', trust: 'high', addr: '마포구 망원로 12', phone: true },
    { id: 'h2', name: '연세365의원', type: '소아과', open: true, night: true, dist: 540, rating: 4.6, reviews: 88, confirm: '12분 전', trust: 'high', addr: '마포구 월드컵로 88' },
    { id: 'h3', name: '우리아이소아과', type: '소아과', open: false, night: false, dist: 210, rating: 4.9, reviews: 320, confirm: '1시간 전', trust: 'mid', addr: '마포구 성미산로 30' },
    { id: 'h4', name: '온누리약국', type: '약국', open: true, night: true, dist: 150, rating: 4.7, reviews: 41, confirm: '방금', trust: 'high', addr: '마포구 망원로 8' },
    { id: 'h5', name: '쑥쑥키즈카페', type: '키즈카페', open: true, age: '0-2세', dist: 680, rating: 4.5, reviews: 132, addr: '마포구 포은로 21' },
  ],
  market: [
    { id: 'm1', title: '스토케 트립트랩 의자', cat: '식사', grade: 'S', months: '6개월+', price: 95000, orig: 290000, seed: 0, dist: '같은 단지', seller: '김지수맘', tier: 'amber', tierName: '골든 맘', sub: 'mint', subName: '나눔 천사', graduate: true, fav: 12 },
    { id: 'm2', title: '맥클라렌 유모차 트라이엄프', cat: '이동수단', grade: 'A', months: '0-12개월', price: 68000, orig: 220000, seed: 4, dist: '망원동', seller: '박하늘맘', tier: 'mint', tierName: '따뜻한 이웃', sub: 'mint', subName: '빠른 답장', recall: false, fav: 7 },
    { id: 'm3', title: '브라이택스 카시트 듀얼픽스', cat: '이동수단', grade: 'A', months: '0-18개월', price: 130000, orig: 420000, seed: 2, dist: '합정동', seller: '이준맘', tier: 'purple', tierName: '믿음직한 맘', sub: 'purple', subName: '안심 판매자', recall: true, fav: 21 },
    { id: 'm4', title: '아기 바운서 (3개월 사용)', cat: '완구', grade: 'B', months: '0-6개월', price: 0, orig: 89000, seed: 3, dist: '서교동', seller: '최서연맘', tier: 'mint', tierName: '따뜻한 이웃', sub: 'mint', subName: '나눔 천사', free: true, fav: 34 },
    { id: 'm5', title: '봄가을 우주복 3종 세트', cat: '의류', grade: 'S', months: '3-6개월', price: 22000, orig: 78000, seed: 5, dist: '같은 단지', seller: '정유나맘', tier: 'grey', tierName: '새싹', sub: null, fav: 5 },
  ],
  needSoon: [
    { id: 'ns1', title: '보행기', reason: '곧 걷기 시작해요', seed: 1 },
    { id: 'ns2', title: '이유식 의자', reason: '이유식 시작 시기', seed: 5 },
    { id: 'ns3', title: '치발기', reason: '이앓이 시작', seed: 3 },
  ],
  expenses: [
    { id: 'e1', cat: '소모품', label: '하기스 기저귀 4박스', amount: 58000, date: '오늘', auto: false, icon: 'pillbox', tone: 'mint' },
    { id: 'e2', cat: '이동수단', label: '스토케 의자 (마켓 구매)', amount: 95000, date: '오늘', auto: true, icon: 'bag', tone: 'blue' },
    { id: 'e3', cat: '의료', label: '행복소아과 진료비', amount: 8500, date: '어제', auto: false, icon: 'vaccine', tone: 'coral' },
    { id: 'e4', cat: '소모품', label: '분유 2통', amount: 46000, date: '2일 전', auto: false, icon: 'drop', tone: 'amber' },
    { id: 'e5', cat: '교육', label: '문화센터 (월정액)', amount: 60000, date: '3일 전', auto: true, icon: 'book', tone: 'purple' },
  ],
  budgetCats: [
    { cat: '소모품', amount: 184000, pct: 38, tone: 'mint' },
    { cat: '이동수단', amount: 95000, pct: 20, tone: 'blue' },
    { cat: '교육', amount: 90000, pct: 19, tone: 'purple' },
    { cat: '의료', amount: 62000, pct: 13, tone: 'coral' },
    { cat: '의류', amount: 49000, pct: 10, tone: 'pink' },
  ],
  subsidies: [
    { id: 's1', name: '아동수당', amount: '월 10만원', cond: '8세 미만', due: 'D-4', status: 'urgent', applyText: '복지로에서 신청' },
    { id: 's2', name: '부모급여', amount: '월 50만원', cond: '0-23개월', due: '신청가능', status: 'available', applyText: '온라인 신청' },
    { id: 's3', name: '첫만남이용권', amount: '200만원', cond: '출생 후 1회', due: '수령완료', status: 'done' },
  ],
  crew: [
    { id: 'cr1', name: '망원동 17개월 모임', members: 6, dist: '0.4km', tags: ['산책 즐겨요','책 많이 읽어요'], age: '15-18개월' },
    { id: 'cr2', name: '합정 워킹맘 크루', members: 9, dist: '1.1km', tags: ['주말 모임','실내 선호'], age: '12-20개월' },
    { id: 'cr3', name: '성산동 첫째맘들', members: 4, dist: '0.8km', tags: ['놀이터','공동구매'], age: '14-19개월' },
  ],
  meetups: [
    { id: 'mu1', place: '쑥쑥키즈카페', when: '내일 오후 2시', host: '김지수맘', tier: 'amber', joined: 3, cap: 5, type: '키즈카페' },
    { id: 'mu2', place: '망원한강공원', when: '토요일 오전 10시', host: '박하늘맘', tier: 'mint', joined: 5, cap: 8, type: '공원' },
  ],
  posts: [
    { id: 'p1', cat: '정보공유', title: '이 동네 소아과 어디가 친절해요?', author: '서연맘', replies: 12, likes: 8, time: '20분 전' },
    { id: 'p2', cat: '같이해요', title: '분유 공동구매 하실 분 (3통 단위)', author: '준맘', replies: 5, likes: 14, time: '1시간 전' },
    { id: 'p3', cat: '고민상담', title: '16개월인데 아직 단어를 안 해요 ㅠㅠ', author: '유나맘', replies: 23, likes: 4, time: '2시간 전' },
  ],
  badges: [
    { id: 'b1', name: '나눔 천사', cat: '거래', tone: 'mint', icon: 'check', earned: true, cond: '무료나눔 3회+' },
    { id: 'b2', name: '빠른 답장', cat: '거래', tone: 'mint', icon: 'flame', earned: true, cond: '응답률 90%+' },
    { id: 'b3', name: '육아고수', cat: '기록', tone: 'purple', icon: 'book', earned: true, cond: '기록 50회+' },
    { id: 'b4', name: '안심 판매자', cat: '거래', tone: 'purple', icon: 'shield', earned: false, cond: '거래10+·분쟁0' },
    { id: 'b5', name: '30일 연속 기록', cat: '기록', tone: 'mint', icon: 'flame', earned: true, cond: '30일 연속' },
    { id: 'b6', name: '첫 크루 모임', cat: '커뮤니티', tone: 'blue', icon: 'users', earned: true, cond: '첫 모임 참여' },
    { id: 'b7', name: '안심 거래왕', cat: '거래', tone: 'amber', icon: 'trophy', earned: false, cond: '거래 50회+' },
    { id: 'b8', name: '동네 레전드', cat: '커뮤니티', tone: 'amber', icon: 'star', earned: false, cond: '모임 주선 20회+' },
    { id: 'b9', name: '첫돌 완주', cat: '기록', tone: 'pink', icon: 'heart', earned: true, cond: '돌까지 기록' },
    { id: 'b10', name: '베타 테스터', cat: '특별', tone: 'grey', icon: 'sparkle', earned: true, cond: '영구 · 박탈불가' },
    { id: 'b11', name: '초기 멤버', cat: '특별', tone: 'grey', icon: 'medal', earned: true, cond: '30일 내 가입' },
    { id: 'b12', name: '예방접종 완벽', cat: '기록', tone: 'purple', icon: 'vaccine', earned: false, cond: '접종 100% 완료' },
  ],
  ddayMemory: { years: 1, caption: '1년 전 오늘, 처음 뒤집기 성공한 날', seed: 2 },
  peerTip: '16개월 또래는 요즘 컵으로 물 마시기를 연습한대요. 흘려도 괜찮아요 — 손의 협응이 자라는 중이에요.',

  // ── 임신 기록 (기능 1) ──
  pregnancy: {
    nickname: '튼튼이', week: 24, day: 3, dday: 112, trimester: '중기', clinic: '미래여성병원', multiples: false,
    edd: '2026-10-01', momWeight: 58.4, momGain: 6.2,
    fruit: '옥수수', fruitEmoji: '🌽', fetusLen: 30, fetusWeight: 600,
    devNote: '이번 주 아기는 옥수수만 해요. 청각이 발달해 엄마 목소리를 들을 수 있어요. 얼굴 근육도 움직이며 표정을 연습하는 중이에요.',
    movements: 8, movementGoal: 10,
    bellyPhotos: [{ w: 24, seed: 3 }, { w: 20, seed: 4 }, { w: 16, seed: 5 }, { w: 12, seed: 1 }],
    symptoms: ['🤰 태동 활발', '🍊 입덧 거의 없음', '😴 가끔 피로'],
    checkups: [
      { id: 'pc1', name: '정밀 초음파', week: '20주', due: '완료', status: 'done', date: '5월 12일' },
      { id: 'pc2', name: '임신성 당뇨 검사', week: '24~28주', due: 'D-3', status: 'soon' },
      { id: 'pc3', name: '정기 검진', week: '26주', due: 'D-12', status: 'upcoming' },
      { id: 'pc4', name: '출산 가방 준비', week: '36주~', due: '말기', status: 'upcoming' },
    ],
    weeklyTimeline: [
      { w: 24, fruit: '옥수수', note: '청각 발달, 목소리 인식' },
      { w: 23, fruit: '망고', note: '폐 발달 시작' },
      { w: 22, fruit: '파파야', note: '눈썹·속눈썹 형성' },
    ],
  },
  shareCardFields: { height: true, weight: true, monthAge: true, percentile: false, milestone: true },
};

window.BL_DATA = BL_DATA;
