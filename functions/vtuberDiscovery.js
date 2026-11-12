// ================================================
// VTuber 自動発見・自動登録
//
//  Holodex の VTuber 一覧（登録者数の多い順）から未登録のチャンネルを探し、
//  YouTube API で登録者数を確認したうえで、誤登録防止チェックを通ったものだけを
//  RTDB `vtuber` に自動登録する。所属事務所が未登録なら事務所も自動で追加する。
//
//  ■ 登録条件（すべて満たすこと）
//    1. Holodex で type=vtuber かつ inactive でない（卒業・活動終了を除外）
//    2. YouTube API の登録者数が minSubscribers 以上（登録者数非公開は除外）
//    3. 未登録（チャンネル ID・Twitter ID のどちらも既存と重複しない）
//    4. 本人確認シグナルが 1 つ以上ある
//         - Wikidata に YouTube チャンネル ID (P2397) で項目がある
//         - 所属が既知の事務所（登録済み VTuber の所属から学習 > 自動作成時の学習 > 静的マップ）
//         - チャンネル名・概要・キーワードに VTuber 関連語がある
//    5. 個人勢・新規事務所はチャンネル名か概要にかな・カナを含む（日本語圏に限定）
//    6. 名前に「切り抜き」「まとめ」「翻訳」などが無い
//  事務所が運用するチャンネル（名前に「公式」、または名前がほぼ事務所名だけ）は officeFlg=true で登録する。
//  条件 4・6 を満たさない、Twitter が重複する、所属メンバーが 1 人だけの未知の事務所、
//  個人勢なのに「公式」を名乗るものなど、
//  人の判断が要るものは `vtuberDiscovery/pending` に保留する（登録しない）。
//
//  ■ RTDB（いずれも公開読み取り不可。database.rules.json の既定 false）
//    vtuberDiscovery/config      … 任意の設定上書き（DEFAULT_CONFIG を参照）。enabled=false で停止
//    vtuberDiscovery/orgMapping  … Holodex org → officeKey（自動作成した事務所を学習）
//    vtuberDiscovery/offices     … 自動作成した事務所のメタ情報（表示名の見直し用）
//    vtuberDiscovery/pending     … 保留中の候補（毎回作り直す）
//    vtuberDiscovery/runs        … 実行結果の記録（直近 30 件）
// ================================================
const axios = require('axios');
const admin = require('firebase-admin');

const DEFAULT_CONFIG = {
  enabled: true,
  minSubscribers: 50000,
  // 1 回の実行で登録する上限。初回に大量登録されるのを防ぎ、超過分は翌日以降に回す
  maxRegisterPerRun: 30,
  maxNewOfficesPerRun: 3,
  // 未知の事務所を新規作成するのに必要な、条件を満たすメンバー数
  minMembersForNewOffice: 2,
};

// Holodex の org → RTDB の officeKey（綴りは既存データに合わせる）
const HOLODEX_ORG_TO_OFFICE_KEY = {
  'Hololive': 'hololive',
  'Nijisanji': 'nijisannji',
  'VSpo': 'vsupo',
  'Nori Pro': 'noripuro',
  'Nanashi Inc.': 'nanashiinc',
  '774inc': 'nanashiinc',
  'Aogiri Highschool': 'aogirigakuen',
  'HoloStars': 'holostars',
  'Kizuna Ai Inc.': 'KizunaAI',
  'VShojo': 'Vshojo',
  '.LIVE': 'dotLIVE',
  'H.Live': 'hlive',
  'NIJISANJI EN': 'nijisannji',
  'NIJISANJI KR': 'nijisannji',
  'NIJISANJI ID': 'nijisannji',
  'Algorhythm Project': 'algorhythm',
  'AKA Virtual': 'aka_virtual',
  'Brave Group': 'brave_group',
  'HIMEHINA': 'himehina',
  'Palette Project': 'palette_project',
  'suzumia': 'suzumia',
  'Independents': 'personal',
  'Twitch Independents': 'personal',
};
const PERSONAL_OFFICE_KEY = 'personal';

const VTUBER_KEYWORD_RE = /vtuber|v-tuber|ブイチューバー|バーチャル|virtual\s*(youtuber|liver|streamer)|vライバー|バーチャルライバー|新人vtuber/i;
const JAPANESE_KANA_RE = /[぀-ヿ]/;
const JAPANESE_KANA_G_RE = /[぀-ヿ]/g;
// 概要欄で日本語圏と見なす、かな・カナの最低文字数（韓国語・英語のチャンネルが数文字の日本語で通らないように）
const MIN_KANA_IN_DESCRIPTION = 30;
// 切り抜き・まとめ・翻訳など、本人ではない可能性が高いもの（保留）
const CLIP_NAME_RE = /切り抜き|切抜き|clips?\b|まとめ|翻訳/i;
// 「公式」「official」は事務所チャンネルの目印（事務所所属なら officeFlg=true で登録、個人勢なら保留）
const OFFICIAL_NAME_RE = /公式|official/i;
// 事務所チャンネル判定で、事務所名を取り除いた後に無視する汎用語
const OFFICE_GENERIC_WORDS = ['vtubergroup', 'vtuber', 'group', 'channel', 'チャンネル', 'ch', 'studio', 'production', 'project', 'inc',
  'english', 'indonesia', 'korea', 'japan', 'global', 'en', 'id', 'jp', 'kr'];
const RTDB_KEY_OK_RE = /^[^.$#\[\]\/]+$/;

const HOLODEX_PAGE_SIZE = 100;
const HOLODEX_MAX_PAGES = 60;
const YOUTUBE_BATCH = 50;
const WIKIDATA_BATCH = 50;
const RUN_HISTORY_LIMIT = 30;
// Wikimedia の User-Agent ポリシーにより、連絡先 URL を入れることが推奨されている
const WIKIDATA_USER_AGENT = 'vtuber-discovery-bot/1.0 (Firebase Cloud Functions)';

const sleep = (ms) => new Promise(r => setTimeout(r, ms));
const chunk = (arr, n) => {
  const out = [];
  for (let i = 0; i < arr.length; i += n) out.push(arr.slice(i, i + n));
  return out;
};

// ---------- 外部 API ----------

async function fetchHolodexVtubers(holodexApiKey, minSubscribers) {
  const result = [];
  for (let page = 0; page < HOLODEX_MAX_PAGES; page++) {
    const res = await axios.get('https://holodex.net/api/v2/channels', {
      headers: { 'X-APIKEY': holodexApiKey },
      params: {
        type: 'vtuber',
        sort: 'subscriber_count',
        order: 'desc',
        limit: HOLODEX_PAGE_SIZE,
        offset: page * HOLODEX_PAGE_SIZE,
      },
      timeout: 20000,
    });
    const items = Array.isArray(res.data) ? res.data : [];
    let reachedBelow = false;
    for (const ch of items) {
      if ((ch.subscriber_count || 0) < minSubscribers) { reachedBelow = true; break; }
      result.push(ch);
    }
    if (reachedBelow || items.length < HOLODEX_PAGE_SIZE) break;
    await sleep(300);
  }
  return result;
}

async function fetchYoutubeChannels(youtubeApiKey, channelIds) {
  const map = {};
  for (const ids of chunk(channelIds, YOUTUBE_BATCH)) {
    try {
      const res = await axios.get('https://www.googleapis.com/youtube/v3/channels', {
        params: { part: 'snippet,statistics,brandingSettings', id: ids.join(','), key: youtubeApiKey, maxResults: YOUTUBE_BATCH },
        timeout: 20000,
      });
      for (const item of res.data.items || []) map[item.id] = item;
    } catch (e) {
      console.error('[Discovery] YouTube API error:', e.message);
    }
  }
  return map;
}

// Wikidata で YouTube チャンネル ID (P2397) を持つ項目を引く。{ channelId: 'Q123' }
async function fetchWikidataItems(channelIds) {
  const map = {};
  for (const ids of chunk(channelIds, WIKIDATA_BATCH)) {
    const values = ids.filter(id => /^UC[\w-]{22}$/.test(id)).map(id => `"${id}"`).join(' ');
    if (!values) continue;
    const query = `SELECT ?ch ?item WHERE { VALUES ?ch { ${values} } ?item wdt:P2397 ?ch . }`;
    for (let attempt = 1; attempt <= 3; attempt++) {
      try {
        // GET だと URL が長くなり 502 になるため POST で送る
        const body = new URLSearchParams({ query, format: 'json' }).toString();
        const res = await axios.post('https://query.wikidata.org/sparql', body, {
          headers: {
            'User-Agent': WIKIDATA_USER_AGENT,
            Accept: 'application/sparql-results+json',
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          timeout: 30000,
        });
        for (const b of res.data?.results?.bindings || []) {
          const ch = b.ch?.value;
          const item = (b.item?.value || '').split('/').pop();
          if (ch && item) map[ch] = item;
        }
        break;
      } catch (e) {
        // Wikidata が落ちていても他のシグナルで判定を続ける
        console.warn(`[Discovery] Wikidata query error (attempt ${attempt}):`, e.message);
        await sleep(2000 * attempt);
      }
    }
    await sleep(500);
  }
  return map;
}

// ---------- 判定 ----------

function slugifyOfficeKey(org) {
  const slug = String(org).toLowerCase().normalize('NFKC')
    .replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '');
  if (slug) return slug;
  // 英数字を含まない org 名はハッシュで作る
  let h = 0;
  for (const c of String(org)) h = (h * 31 + c.codePointAt(0)) >>> 0;
  return `org_${h.toString(36)}`;
}

// Holodex の suborg から地域タグを取り出す（例: hololive の「a English (Myth)」→ EN）
function regionTag(group) {
  const s = String(group || '');
  if (/english|\ben\b/i.test(s)) return 'EN';
  if (/indonesia|\bid\b/i.test(s)) return 'ID';
  if (/korea|\bkr\b/i.test(s)) return 'KR';
  return '';
}
// Holodex の所属グループ（例: hololive の「English -Promise-」「DEV_IS ReGLOSS」）。API の項目名は `group`
const holodexGroup = (ch) => ch.group || ch.suborg || '';
// 個人勢の org。所属の学習対象にしない（常に personal）
const INDEPENDENT_ORGS = new Set(['Independents', 'Twitch Independents']);

// 登録済みの VTuber が Holodex でどの org / group に属しているかを数え、既存 officeKey への対応を学習する。
// 静的マップより実データを優先し、ホロライブ EN/ID（holoEN/holoID）などの既存キーに正しく寄せる。
// 誤学習を防ぐため:
//   - 個人勢の org は学習しない（VShojo 解散後に Twitch Independents へ移ったメンバーなどに引きずられない）
//   - 実在の事務所を personal として学習しない（既存データで個人扱いになっている事務所メンバーに引きずられない）
//   - group 単位・地域単位は 2 票以上かつ 2/3 以上の一致、org 全体は 5 票以上・8 割以上・2 グループ以上からの票が必要
//     （例: Brave Group で登録済みが HIMEHINA だけなら、Brave Group 全体を himehina とは学習しない）
function learnOrgMappingFromRegistered(holodexChannels, officeByChannelId) {
  const votes = { byGroup: {}, byOrgRegion: {}, byOrg: {} };
  const groupsByOrgOffice = {};
  const add = (m, k, v) => { (m[k] ||= {})[v] = (m[k][v] || 0) + 1; };
  for (const ch of holodexChannels) {
    const office = officeByChannelId[ch.id];
    if (!office || !ch.org || INDEPENDENT_ORGS.has(ch.org) || office === PERSONAL_OFFICE_KEY) continue;
    const group = holodexGroup(ch);
    add(votes.byOrg, ch.org, office);
    ((groupsByOrgOffice[`${ch.org}|${office}`] ||= new Set())).add(group);
    if (group) add(votes.byGroup, `${ch.org}|${group}`, office);
    const tag = regionTag(group);
    if (tag) add(votes.byOrgRegion, `${ch.org}|${tag}`, office);
  }
  const pick = (m, minVotes, minShare, extra = () => true) => {
    const out = {};
    for (const [k, v] of Object.entries(m)) {
      const total = Object.values(v).reduce((a, b) => a + b, 0);
      const [office, n] = Object.entries(v).sort((a, b) => b[1] - a[1])[0];
      if (n >= minVotes && n / total >= minShare && extra(k, office)) out[k] = office;
    }
    return out;
  };
  return {
    byGroup: pick(votes.byGroup, 2, 2 / 3),
    byOrgRegion: pick(votes.byOrgRegion, 2, 2 / 3),
    byOrg: pick(votes.byOrg, 5, 0.8, (org, office) => (groupsByOrgOffice[`${org}|${office}`]?.size || 0) >= 2),
  };
}

function resolveOffice(ch, { orgMapping, officeMapping, learned }) {
  const org = ch.org;
  if (!org || INDEPENDENT_ORGS.has(org)) return { officeKey: PERSONAL_OFFICE_KEY, known: true };
  const group = holodexGroup(ch);
  const tag = regionTag(group);
  const mapped = (group && learned.byGroup[`${org}|${group}`])
    || (tag && learned.byOrgRegion[`${org}|${tag}`])
    || orgMapping[org]
    || learned.byOrg[org]
    || HOLODEX_ORG_TO_OFFICE_KEY[org];
  if (mapped) return { officeKey: mapped, known: true };
  // officeMapping に同名（大文字小文字無視）の事務所があればそれを使う
  const lower = org.toLowerCase();
  for (const [key, name] of Object.entries(officeMapping)) {
    if (typeof name === 'string' && name.toLowerCase() === lower) return { officeKey: key, known: true };
  }
  const slug = slugifyOfficeKey(org);
  if (officeMapping[slug]) return { officeKey: slug, known: true };
  return { officeKey: slug, known: false };
}

// チャンネル名がほぼ事務所名だけ（例: 「ミリプロ - MillionProduction -」）なら事務所の公式アカウントとみなす
const normalizeForCompare = (s) => String(s || '').toLowerCase().normalize('NFKC').replace(/[^\p{L}\p{N}]+/gu, '');
// officeNames には Holodex の org 名と officeMapping の表示名（例: 'Hololive', 'ホロライブ'）を渡す
function looksLikeOfficeAccount(title, officeNames) {
  const names = officeNames.map(normalizeForCompare).filter(n => n.length >= 4 && n !== 'independents' && n !== 'twitchindependents');
  // 汎用語（vtuber 等）は事務所名の途中に挟まることがある（例: 「Aogiri Vtuber High School」）ので、
  // 名前と汎用語の両方から取り除いて比べる
  const stripGeneric = (s) => OFFICE_GENERIC_WORDS.reduce((acc, w) => acc.split(w).join(''), s);
  const nameVariants = [...new Set(names.flatMap(n => [n, stripGeneric(n)]))].filter(n => n.length >= 4)
    .sort((a, b) => b.length - a.length);
  let t = normalizeForCompare(title);
  if (!nameVariants.some(n => t.includes(n) || stripGeneric(t).includes(n))) return false;
  for (const n of nameVariants) t = t.split(n).join('');
  t = stripGeneric(t);
  for (const n of nameVariants) t = t.split(n).join('');
  return t.length <= 4;
}

function evaluateCandidate(ch, yt, wikidataId, ctx) {
  const { config, registeredIds, registeredTwitters } = ctx;
  const out = { channelId: ch.id, name: ch.name, org: ch.org || '', holodexSubscribers: ch.subscriber_count || 0 };

  if (registeredIds.has(ch.id)) return { ...out, status: 'skip', reason: 'already_registered' };
  if (ch.inactive) return { ...out, status: 'skip', reason: 'inactive' };
  if (!yt) return { ...out, status: 'skip', reason: 'youtube_not_found' };
  if (yt.statistics?.hiddenSubscriberCount) return { ...out, status: 'skip', reason: 'hidden_subscribers' };

  const subscribers = Number(yt.statistics?.subscriberCount || 0);
  if (subscribers < config.minSubscribers) return { ...out, status: 'skip', reason: 'below_threshold', subscribers };

  const title = yt.snippet?.title || ch.name || '';
  const description = yt.snippet?.description || '';
  const keywords = yt.brandingSettings?.channel?.keywords || '';
  const office = resolveOffice(ch, ctx);
  const isPersonal = office.officeKey === PERSONAL_OFFICE_KEY;
  const hasJapanese = JAPANESE_KANA_RE.test(`${title}\n${ch.name || ''}`)
    || (description.match(JAPANESE_KANA_G_RE) || []).length >= MIN_KANA_IN_DESCRIPTION;

  // 事務所が運用するチャンネル（例: 「hololive ホロライブ - VTuber Group」「ぶいすぽっ!【公式】」）
  const isOfficeAccount = !isPersonal && (
    OFFICIAL_NAME_RE.test(title)
    || looksLikeOfficeAccount(title, [ch.org, ctx.officeMapping[office.officeKey]])
  );
  const signals = {
    wikidata: wikidataId || null,
    knownOffice: office.known && !isPersonal,
    keyword: VTUBER_KEYWORD_RE.test(`${title}\n${description}\n${keywords}`),
  };
  const base = {
    ...out,
    name: title,
    subscribers,
    officeKey: office.officeKey,
    newOffice: !office.known,
    isOfficeAccount,
    twitter: ch.twitter || '',
    thumbnailUrl: yt.snippet?.thumbnails?.high?.url || yt.snippet?.thumbnails?.default?.url || ch.photo || '',
    description,
    signals,
  };

  // 個人勢・新規事務所は日本語圏のみ（既知の事務所は海外支部も含める）
  if ((isPersonal || !office.known) && !hasJapanese) return { ...base, status: 'skip', reason: 'non_japanese' };

  const holdReasons = [];
  if (CLIP_NAME_RE.test(title)) holdReasons.push('clip_channel');
  if (isPersonal && OFFICIAL_NAME_RE.test(title)) holdReasons.push('official_without_office');
  if (base.twitter && registeredTwitters.has(base.twitter.toLowerCase())) holdReasons.push('twitter_duplicate');
  // Holodex の extra_ids は同じタレントの別チャンネル。どれかが登録済みならサブチャンネルとみなす
  if ((ch.extra_ids || []).some(id => registeredIds.has(id))) holdReasons.push('sub_channel_of_registered');
  if (!signals.wikidata && !signals.knownOffice && !signals.keyword) holdReasons.push('no_verification_signal');
  if (holdReasons.length) return { ...base, status: 'pending', reasons: holdReasons };

  return { ...base, status: 'register' };
}

// ---------- 本体 ----------

/**
 * @param {object} opts
 * @param {string} opts.youtubeApiKey
 * @param {string} opts.holodexApiKey
 * @param {boolean} [opts.dryRun=false] true なら RTDB に一切書き込まず、結果だけ返す
 */
async function runVtuberDiscovery({ youtubeApiKey, holodexApiKey, dryRun = false }) {
  const db = admin.database();
  const startedAt = new Date();

  const [configSnap, vtuberSnap, officeMappingSnap, officeSnap, orgMappingSnap, excludedSnap] = await Promise.all([
    db.ref('vtuberDiscovery/config').once('value'),
    db.ref('vtuber').once('value'),
    db.ref('officeMapping').once('value'),
    db.ref('office').once('value'),
    db.ref('vtuberDiscovery/orgMapping').once('value'),
    // 管理画面（/admin）で削除・却下したチャンネル。再登録しない
    db.ref('vtuberDiscovery/excluded').once('value'),
  ]);
  const config = { ...DEFAULT_CONFIG, ...(configSnap.val() || {}) };
  if (!config.enabled && !dryRun) {
    console.log('[Discovery] disabled by vtuberDiscovery/config/enabled');
    return { disabled: true };
  }

  const vtuberDict = vtuberSnap.val() || {};
  const officeMapping = officeMappingSnap.val() || {};
  const orgMapping = Object.fromEntries(
    Object.entries(orgMappingSnap.val() || {}).map(([k, v]) => [decodeRtdbKey(k), v])
  );
  const officeRaw = officeSnap.val();
  const officeList = Array.isArray(officeRaw)
    ? officeRaw.filter(v => typeof v === 'string')
    : Object.values(officeRaw || {}).filter(v => typeof v === 'string');

  const registeredIds = new Set();
  const registeredTwitters = new Set();
  const officeByChannelId = {};
  let maxKey = 0;
  for (const [key, v] of Object.entries(vtuberDict)) {
    const n = parseInt(key, 10);
    if (!isNaN(n) && n > maxKey) maxKey = n;
    if (!v || typeof v !== 'object') continue;
    if (v.channeID) registeredIds.add(v.channeID);
    if (v.channeID && v.office) officeByChannelId[v.channeID] = v.office;
    if (v.twitterName) registeredTwitters.add(String(v.twitterName).toLowerCase());
  }

  // 1. Holodex から候補を集め、未登録のものだけ YouTube / Wikidata で確認する
  const holodexChannels = await fetchHolodexVtubers(holodexApiKey, config.minSubscribers);
  const excludedIds = new Set(Object.keys(excludedSnap.val() || {}));
  const excludedCount = holodexChannels.filter(ch => ch.id && !registeredIds.has(ch.id) && excludedIds.has(ch.id)).length;
  const unregistered = holodexChannels.filter(ch => ch.id && !registeredIds.has(ch.id) && !excludedIds.has(ch.id));
  const ids = unregistered.map(ch => ch.id);
  const [ytMap, wikidataMap] = await Promise.all([
    fetchYoutubeChannels(youtubeApiKey, ids),
    fetchWikidataItems(ids),
  ]);

  // 2. 判定
  const learned = learnOrgMappingFromRegistered(holodexChannels, officeByChannelId);
  const ctx = { config, registeredIds, registeredTwitters, orgMapping, officeMapping, learned };
  const evaluated = unregistered.map(ch => evaluateCandidate(ch, ytMap[ch.id], wikidataMap[ch.id], ctx));
  // 同じ実行内での Twitter 重複（本人のサブチャンネルなど）は登録者数の多い方だけ残す
  const seenTwitter = new Set();
  for (const c of evaluated.filter(c => c.status === 'register').sort((a, b) => b.subscribers - a.subscribers)) {
    const t = (c.twitter || '').toLowerCase();
    if (!t) continue;
    if (seenTwitter.has(t)) { c.status = 'pending'; c.reasons = ['twitter_duplicate']; }
    seenTwitter.add(t);
  }

  // 3. 新規事務所: 条件を満たすタレント（事務所チャンネルは数えない）が minMembersForNewOffice 人以上いる org だけ作る
  const newOfficeMembers = {};
  for (const c of evaluated) {
    if (c.status === 'register' && c.newOffice) (newOfficeMembers[c.org] ||= []).push(c);
  }
  const newOffices = {};
  const talentCount = (members) => members.filter(m => !m.isOfficeAccount).length;
  for (const [org, members] of Object.entries(newOfficeMembers).sort((a, b) => talentCount(b[1]) - talentCount(a[1]))) {
    const talents = talentCount(members);
    const ok = talents >= config.minMembersForNewOffice
      && Object.keys(newOffices).length < config.maxNewOfficesPerRun;
    if (ok) {
      newOffices[org] = { officeKey: members[0].officeKey, officeName: org, memberCount: talents };
    } else if (talents < config.minMembersForNewOffice) {
      // メンバー 1 人だけの未知の事務所は、所属の誤判定の恐れがあるので人の確認に回す
      for (const m of members) { m.status = 'pending'; m.reasons = ['new_office_too_few_members']; }
    } else {
      // 1 回あたりの事務所作成上限を超えた分は翌日以降に自動で処理する
      for (const m of members) { m.status = 'deferred'; }
    }
  }

  // 既知マップにあるが officeMapping に未作成の事務所（例: 静的マップのみに存在）も作る
  const missingKnownOffices = {};
  for (const c of evaluated) {
    // 既存 VTuber が使っているキー（`.LIVE` など officeMapping に無いもの）は既存事務所なので作らない
    const usedByExisting = Object.values(officeByChannelId).includes(c.officeKey);
    if (c.status === 'register' && !c.newOffice && !officeMapping[c.officeKey] && c.officeKey !== PERSONAL_OFFICE_KEY
      && !usedByExisting && RTDB_KEY_OK_RE.test(c.officeKey)) {
      missingKnownOffices[c.officeKey] = c.org || c.officeKey;
    }
  }

  // 4. 登録者数の多い順に上限まで登録。超過分は次回に回す
  const toRegister = evaluated.filter(c => c.status === 'register').sort((a, b) => b.subscribers - a.subscribers);
  const registering = toRegister.slice(0, config.maxRegisterPerRun);
  for (const c of toRegister.slice(config.maxRegisterPerRun)) { c.status = 'deferred'; }
  const deferred = evaluated.filter(c => c.status === 'deferred');

  const nowIso = startedAt.toISOString();
  const updates = {};
  const officeKeysToAdd = new Set();
  for (const [org, o] of Object.entries(newOffices)) {
    // 登録上限で全員が繰り越しになった事務所は作らない
    if (!registering.some(c => c.org === org)) continue;
    updates[`officeMapping/${o.officeKey}`] = o.officeName;
    // Holodex org → officeKey を学習（org は RTDB のキーに使えない文字を含むことがあるのでエンコード）
    updates[`vtuberDiscovery/orgMapping/${encodeRtdbKey(org)}`] = o.officeKey;
    updates[`vtuberDiscovery/offices/${o.officeKey}`] = {
      holodexOrg: org,
      officeName: o.officeName,
      memberCountAtCreation: o.memberCount,
      createdAt: nowIso,
      // 表示名は Holodex の英語名のまま作成する。日本語名にする場合は officeMapping を手で直す
      needsNameReview: true,
    };
    officeKeysToAdd.add(o.officeKey);
  }
  for (const [officeKey, name] of Object.entries(missingKnownOffices)) {
    if (!registering.some(c => c.officeKey === officeKey)) continue;
    updates[`officeMapping/${officeKey}`] = name;
    officeKeysToAdd.add(officeKey);
  }
  // `office` は officeKey の配列（RTDB では数値キーのオブジェクト）
  let officeIndex = officeList.length;
  for (const key of officeKeysToAdd) {
    if (!officeList.includes(key)) updates[`office/${officeIndex++}`] = key;
  }

  const registered = [];
  let nextKey = maxKey + 1;
  for (const c of registering) {
    const key = String(nextKey++);
    updates[`vtuber/${key}`] = {
      name: c.name,
      channeID: c.channelId,
      office: c.officeKey,
      officeFlg: !!c.isOfficeAccount,
      twitterName: c.twitter,
      thumbnailUrl: c.thumbnailUrl,
      description: c.description,
      birthday: '', // scheduledFillVtuberBirthdays が補完する
      debut: '',
      createdAt: nowIso,
      updateTime: nowIso,
      registeredBy: 'auto-discovery',
      discovery: {
        holodexOrg: c.org,
        subscribersAtRegistration: c.subscribers,
        wikidata: c.signals.wikidata || '',
        knownOffice: c.signals.knownOffice,
        keyword: c.signals.keyword,
      },
    };
    registered.push({ key, channelId: c.channelId, name: c.name, officeKey: c.officeKey, officeFlg: !!c.isOfficeAccount, subscribers: c.subscribers });
  }

  const pending = evaluated.filter(c => c.status === 'pending');
  const pendingNode = {};
  for (const c of pending) {
    pendingNode[c.channelId] = {
      name: c.name, org: c.org, officeKey: c.officeKey || '', subscribers: c.subscribers || 0,
      twitter: c.twitter || '', thumbnailUrl: c.thumbnailUrl || '', reasons: c.reasons, signals: c.signals || {},
      lastSeenAt: nowIso,
    };
  }

  const skipCounts = {};
  for (const c of evaluated.filter(c => c.status === 'skip')) skipCounts[c.reason] = (skipCounts[c.reason] || 0) + 1;

  const summary = {
    startedAt: nowIso,
    finishedAt: new Date().toISOString(),
    dryRun,
    minSubscribers: config.minSubscribers,
    holodexChecked: holodexChannels.length,
    unregistered: unregistered.length,
    excluded: excludedCount,
    registered,
    newOffices: Object.values(newOffices).filter(o => officeKeysToAdd.has(o.officeKey)),
    pendingCount: pending.length,
    deferredCount: deferred.length,
    skipCounts,
  };

  if (dryRun) {
    return { ...summary, pending: pendingNode, deferred: deferred.map(c => ({ channelId: c.channelId, name: c.name, officeKey: c.officeKey, officeFlg: !!c.isOfficeAccount, subscribers: c.subscribers })) };
  }

  // 5. 書き込み（vtuber / officeMapping / office は 1 回のマルチパス更新でまとめて反映）
  if (Object.keys(updates).length) await db.ref().update(updates);
  await db.ref('vtuberDiscovery/pending').set(pendingNode);
  const runKey = nowIso.replace(/[-:.TZ]/g, '').slice(0, 14);
  await db.ref(`vtuberDiscovery/runs/${runKey}`).set({ ...summary, registered: summary.registered.length ? summary.registered : null });
  await pruneRuns(db);

  console.log(`[Discovery] registered=${registered.length} newOffices=${summary.newOffices.length} pending=${pending.length} deferred=${deferred.length}`, skipCounts);
  return summary;
}

// RTDB のキーに使えない . $ # [ ] / をエスケープする
function encodeRtdbKey(s) {
  return String(s).replace(/[.$#\[\]\/%]/g, c => '%' + c.charCodeAt(0).toString(16).toUpperCase());
}
function decodeRtdbKey(s) {
  return String(s).replace(/%([0-9A-F]{2})/g, (_, h) => String.fromCharCode(parseInt(h, 16)));
}

async function pruneRuns(db) {
  const snap = await db.ref('vtuberDiscovery/runs').orderByKey().once('value');
  const keys = Object.keys(snap.val() || {}).sort();
  const remove = keys.slice(0, Math.max(0, keys.length - RUN_HISTORY_LIMIT));
  if (remove.length) await db.ref('vtuberDiscovery/runs').update(Object.fromEntries(remove.map(k => [k, null])));
}

module.exports = {
  runVtuberDiscovery,
  HOLODEX_ORG_TO_OFFICE_KEY,
  // テスト用
  _internal: { evaluateCandidate, looksLikeOfficeAccount, learnOrgMappingFromRegistered, regionTag, resolveOffice, slugifyOfficeKey, encodeRtdbKey, decodeRtdbKey, DEFAULT_CONFIG },
};
