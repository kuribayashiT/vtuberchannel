// ================================================
// VTuber の誕生日・デビュー日（周年）を Wiki から補完する
//
//  RTDB `vtuber` の birthday / debut が空のものだけを埋める（既存の値は上書きしない）。
//  取得元:
//    - 誕生日:     Wikidata（YouTube チャンネル ID (P2397) で特定、P569 の日単位の値）→ 無ければ Virtual YouTuber Wiki
//    - デビュー日: Virtual YouTuber Wiki のみ（debut_date の最初の日付。YouTube 初配信日で、既存データと一致しやすい）
//                  ※ Wikidata の P2031（活動開始日）は告知日やチャンネル開設日が入っていることが多く、
//                    検証でさくらみこ・大空スバル・常闇トワなどが数日〜数か月ずれたため使わない
//    Virtual YouTuber Wiki (virtualyoutuber.fandom.com) は名前で検索し、記事の channel 欄の
//    @handle / チャンネル ID が YouTube の customUrl / ID と一致した記事だけ採用する（同名の別人を防ぐ）
//  誕生日は birthdayJobs.js の scheduledFillVtuberBirthdays（1:00 JST、Wikipedia/Wikidata 照合）も補完する。
//  どちらも空欄だけを埋めるので併用できる。書き込むと onVtuberWriteForEventList 経由で eventList.json が 10 分以内に作り直される。
//
//  書き込む形式（既存データの多数派に合わせる）:
//    birthday: "MM-DD"（年は入れない。設定上の年齢が架空のことが多いため）
//    debut:    "YYYY/MM/DD"（eventList の周年計算で使う）
//    profileSource: { birthday: "wikidata:Q123" | "fandom:Page_Title", debut: ... } … 出典の記録
//
//  RTDB（公開読み取り不可）:
//    vtuberProfiles/checked/{channelId} … { at, birthday, debut }（Wiki で調べた日時と見つかったか）。
//                                         RECHECK_DAYS 日以内に調べたものは再検索しない
// ================================================
const axios = require('axios');
const admin = require('firebase-admin');

const USER_AGENT = 'vtuber-discovery-bot/1.0 (Firebase Cloud Functions)';
const FANDOM_API = 'https://virtualyoutuber.fandom.com/api.php';
const RECHECK_DAYS = 30;
const YOUTUBE_BATCH = 50;
const WIKIDATA_BATCH = 50;
const MIN_DEBUT_YEAR = 2016; // キズナアイ（2016/11）以前の日付は誤りとみなす

const sleep = (ms) => new Promise(r => setTimeout(r, ms));
const chunk = (arr, n) => {
  const out = [];
  for (let i = 0; i < arr.length; i += n) out.push(arr.slice(i, i + n));
  return out;
};
const pad2 = (n) => String(n).padStart(2, '0');

const MONTHS = {
  jan: 1, january: 1, feb: 2, february: 2, mar: 3, march: 3, apr: 4, april: 4, may: 5, jun: 6, june: 6,
  jul: 7, july: 7, aug: 8, august: 8, sep: 9, sept: 9, september: 9, oct: 10, october: 10,
  nov: 11, november: 11, dec: 12, december: 12,
};
const DAYS_IN_MONTH = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
const validMonthDay = (m, d) => m >= 1 && m <= 12 && d >= 1 && d <= DAYS_IN_MONTH[m - 1];

// ---------- 日付の正規化 ----------

/** "15 May" / "May 15" / "15 May 2000" / "5月15日" / "05/15" → "05-15"。読めなければ '' */
function parseBirthday(raw) {
  const s = cleanWikiValue(raw);
  if (!s) return '';
  let m, d;
  let x;
  if ((x = s.match(/(\d{1,2})\s+([A-Za-z]{3,9})\b/)) && MONTHS[x[2].toLowerCase()]) { d = +x[1]; m = MONTHS[x[2].toLowerCase()]; }
  else if ((x = s.match(/\b([A-Za-z]{3,9})\s+(\d{1,2})\b/)) && MONTHS[x[1].toLowerCase()]) { m = MONTHS[x[1].toLowerCase()]; d = +x[2]; }
  else if ((x = s.match(/(\d{1,2})月\s*(\d{1,2})日/))) { m = +x[1]; d = +x[2]; }
  else if ((x = s.match(/^(\d{1,2})[\/-](\d{1,2})$/))) { m = +x[1]; d = +x[2]; }
  else return '';
  return validMonthDay(m, d) ? `${pad2(m)}-${pad2(d)}` : '';
}

/** "Niconico: 2017/09/07" / "2D: 2021/01/31<br>3D: ..." / "7 September 2017" → "2017/09/07"（最初の日付）。読めなければ '' */
function parseDebut(raw) {
  const s = cleanWikiValue(raw);
  if (!s) return '';
  let y, m, d, x;
  if ((x = s.match(/(\d{4})[\/.\-年](\d{1,2})[\/.\-月](\d{1,2})/))) { y = +x[1]; m = +x[2]; d = +x[3]; }
  else if ((x = s.match(/(\d{1,2})\s+([A-Za-z]{3,9})\s+(\d{4})/)) && MONTHS[x[2].toLowerCase()]) { d = +x[1]; m = MONTHS[x[2].toLowerCase()]; y = +x[3]; }
  else if ((x = s.match(/([A-Za-z]{3,9})\s+(\d{1,2}),?\s+(\d{4})/)) && MONTHS[x[1].toLowerCase()]) { m = MONTHS[x[1].toLowerCase()]; d = +x[2]; y = +x[3]; }
  else return '';
  return isValidDebut(y, m, d) ? `${y}/${pad2(m)}/${pad2(d)}` : '';
}

function isValidDebut(y, m, d) {
  if (!validMonthDay(m, d) || y < MIN_DEBUT_YEAR) return false;
  return new Date(Date.UTC(y, m - 1, d)) <= new Date();
}

// Wiki の値から <ref>…</ref>、テンプレート、リンク記法を除く。空欄（次の行の "|height =" など）は ''
function cleanWikiValue(raw) {
  let s = String(raw || '');
  s = s.replace(/<ref[^>]*\/>/g, '').replace(/<ref[^>]*>[\s\S]*?<\/ref>/g, '');
  s = s.replace(/\{\{[^{}]*\}\}/g, '').replace(/\[\[(?:[^|\]]*\|)?([^\]]*)\]\]/g, '$1');
  s = s.split(/<br\s*\/?>/i)[0];
  s = s.trim();
  if (!s || s.startsWith('|') || /^(unknown|secret|n\/a|none|-|\?)$/i.test(s)) return '';
  return s;
}

// ---------- Wikidata ----------

// { channelId: { item, birthday, debut } }。日単位の精度（timePrecision = 11）の値だけ使う
async function fetchWikidataProfiles(channelIds) {
  const map = {};
  for (const ids of chunk(channelIds.filter(id => /^UC[\w-]{22}$/.test(id)), WIKIDATA_BATCH)) {
    const values = ids.map(id => `"${id}"`).join(' ');
    const query = `SELECT ?ch ?item ?dob ?dobPrec ?start ?startPrec WHERE {
      VALUES ?ch { ${values} }
      ?item wdt:P2397 ?ch .
      OPTIONAL { ?item p:P569/psv:P569 [ wikibase:timeValue ?dob ; wikibase:timePrecision ?dobPrec ] . }
      OPTIONAL { ?item p:P2031/psv:P2031 [ wikibase:timeValue ?start ; wikibase:timePrecision ?startPrec ] . }
    }`;
    for (let attempt = 1; attempt <= 3; attempt++) {
      try {
        const res = await axios.post('https://query.wikidata.org/sparql', new URLSearchParams({ query, format: 'json' }).toString(), {
          headers: { 'User-Agent': USER_AGENT, Accept: 'application/sparql-results+json', 'Content-Type': 'application/x-www-form-urlencoded' },
          timeout: 60000,
        });
        for (const b of res.data?.results?.bindings || []) {
          const ch = b.ch?.value;
          if (!ch) continue;
          const entry = (map[ch] ||= { item: (b.item?.value || '').split('/').pop(), birthday: '', debut: '' });
          if (b.dob && Number(b.dobPrec?.value) === 11 && !entry.birthday) {
            const [, mm, dd] = b.dob.value.match(/-(\d{2})-(\d{2})T/) || [];
            if (mm && validMonthDay(+mm, +dd)) entry.birthday = `${mm}-${dd}`;
          }
          if (b.start && Number(b.startPrec?.value) === 11 && !entry.debut) {
            const [, yy, mm, dd] = b.start.value.match(/^(\d{4})-(\d{2})-(\d{2})T/) || [];
            if (yy && isValidDebut(+yy, +mm, +dd)) entry.debut = `${yy}/${mm}/${dd}`;
          }
        }
        break;
      } catch (e) {
        console.warn(`[Profiles] Wikidata error (attempt ${attempt}):`, e.message);
        await sleep(2000 * attempt);
      }
    }
    await sleep(500);
  }
  return map;
}

// ---------- Virtual YouTuber Wiki (Fandom) ----------

async function fandomGet(params) {
  const res = await axios.get(FANDOM_API, { params: { ...params, format: 'json' }, headers: { 'User-Agent': USER_AGENT }, timeout: 20000 });
  return res.data;
}

// チャンネル名から検索語を作る（「Ch.」「チャンネル」【所属】などを除き、「/」区切りの各表記を試す）
function searchQueries(title) {
  const t = String(title || '')
    .replace(/【.*?】|\[.*?\]|\(.*?\)|（.*?）/g, ' ')
    // 「SoraCh.」「Hajime Ch.」「Ch.」などの接頭辞・接尾辞
    .replace(/\S*ch\.(?=\s|$)|\bch(?=\s|$)|チャンネル|channel/gi, ' ');
  const parts = t.split(/[\/／|｜]|\s[‐\-–—~〜]\s/)
    .map(p => p.replace(/^[\s\-‐ー~〜]+|[\s\-‐ー~〜]+$/g, '').replace(/\s+/g, ' ').trim())
    .filter(p => p.length >= 2);
  // 日本語名（漢字・かな）だけの部分を最優先で試す（英字の愛称より記事タイトルに当たりやすい）
  const japanese = (String(title || '').match(/[぀-ヿ㐀-鿿々ー・]{2,}/g) || [])
    .map(s => s.replace(/チャンネル|公式/g, '')).filter(s => s.length >= 2);
  return [...new Set([...japanese.slice(0, 1), ...parts])].slice(0, 3);
}

function infoboxField(wikitext, name) {
  const m = wikitext.match(new RegExp(`\\|[ \\t]*${name}[ \\t]*=[ \\t]*([^\\n]*)`));
  return m ? m[1] : '';
}

/** 記事が対象チャンネルのものなら { page, birthday, debut } を返す。見つからなければ null */
async function findFandomProfile({ channelId, title, customUrl }) {
  const handle = String(customUrl || '').toLowerCase();
  const tried = new Set();
  for (const q of searchQueries(title)) {
    const search = await fandomGet({ action: 'query', list: 'search', srsearch: q, srlimit: 3 });
    for (const hit of search?.query?.search || []) {
      const page = hit.title;
      if (page.includes('/') || tried.has(page)) continue; // "/Gallery" などのサブページは除く
      tried.add(page);
      const parsed = await fandomGet({ action: 'parse', page, prop: 'wikitext', section: 0, redirects: 1 });
      const wikitext = parsed?.parse?.wikitext?.['*'] || '';
      const channelField = infoboxField(wikitext, 'channel').toLowerCase();
      const sameChannel = channelField.includes(channelId.toLowerCase())
        || (handle && new RegExp(`youtube\\.com/${handle.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}(?![\\w.-])`).test(channelField));
      if (sameChannel) {
        return {
          page,
          birthday: parseBirthday(infoboxField(wikitext, 'birthday')),
          debut: parseDebut(infoboxField(wikitext, 'debut_date')),
        };
      }
      await sleep(300);
    }
    await sleep(300);
  }
  return null;
}

async function fetchYoutubeCustomUrls(youtubeApiKey, channelIds) {
  const map = {};
  for (const ids of chunk(channelIds, YOUTUBE_BATCH)) {
    try {
      const res = await axios.get('https://www.googleapis.com/youtube/v3/channels', {
        params: { part: 'snippet', id: ids.join(','), key: youtubeApiKey, maxResults: YOUTUBE_BATCH },
        timeout: 20000,
      });
      for (const item of res.data.items || []) map[item.id] = { title: item.snippet?.title || '', customUrl: item.snippet?.customUrl || '' };
    } catch (e) {
      console.error('[Profiles] YouTube API error:', e.message);
    }
  }
  return map;
}

// ---------- 本体 ----------

/**
 * @param {object} opts
 * @param {string} opts.youtubeApiKey
 * @param {boolean} [opts.dryRun=false] true なら RTDB に書き込まない
 * @param {number} [opts.timeBudgetMs=420000] Fandom 検索に使う時間の上限（Cloud Functions の 540 秒以内に収める）
 * @param {number} [opts.limit] 調べる人数の上限（試走用）
 */
async function runProfileFill({ youtubeApiKey, dryRun = false, timeBudgetMs = 420000, limit }) {
  const db = admin.database();
  const startedAt = Date.now();
  const [vtuberSnap, checkedSnap] = await Promise.all([
    db.ref('vtuber').once('value'),
    db.ref('vtuberProfiles/checked').once('value'),
  ]);
  const vtuberDict = vtuberSnap.val() || {};
  const checked = checkedSnap.val() || {};
  const recheckBefore = startedAt - RECHECK_DAYS * 24 * 3600 * 1000;

  // 対象: 事務所チャンネル以外で birthday か debut が空、かつ最近 Wiki で調べていないもの。新しく登録された順
  let targets = Object.entries(vtuberDict)
    .filter(([key, v]) => key !== 'updateTime' && v && v.channeID && v.officeFlg !== true)
    .filter(([, v]) => !String(v.birthday || '').trim() || !String(v.debut || '').trim())
    .filter(([, v]) => !(checked[v.channeID]?.at && Date.parse(checked[v.channeID].at) > recheckBefore))
    .sort((a, b) => String(b[1].createdAt || '').localeCompare(String(a[1].createdAt || '')));
  if (limit) targets = targets.slice(0, limit);

  const nowIso = new Date(startedAt).toISOString();
  const results = [];
  const updates = {};

  // 1. Wikidata（チャンネル ID で一括照会）
  const wikidata = await fetchWikidataProfiles(targets.map(([, v]) => v.channeID));

  // 2. Wikidata で埋まらなかった分を Fandom で検索
  const needFandom = targets.filter(([, v]) => {
    const w = wikidata[v.channeID] || {};
    return (!String(v.birthday || '').trim() && !w.birthday) || !String(v.debut || '').trim();
  });
  const ytInfo = await fetchYoutubeCustomUrls(youtubeApiKey, needFandom.map(([, v]) => v.channeID));

  let timedOut = false;
  for (const [key, v] of targets) {
    const ch = v.channeID;
    const needBirthday = !String(v.birthday || '').trim();
    const needDebut = !String(v.debut || '').trim();
    const w = wikidata[ch] || {};
    let birthday = needBirthday ? w.birthday || '' : '';
    let debut = ''; // デビュー日は Fandom のみ（Wikidata の P2031 は精度が低い）
    const source = {};
    if (birthday) source.birthday = `wikidata:${w.item}`;

    let fandomChecked = false;
    if ((needBirthday && !birthday) || (needDebut && !debut)) {
      if (Date.now() - startedAt > timeBudgetMs) { timedOut = true; break; } // 残りは次回
      try {
        const info = ytInfo[ch] || { title: v.name || '', customUrl: '' };
        const f = await findFandomProfile({ channelId: ch, title: info.title || v.name, customUrl: info.customUrl });
        fandomChecked = true;
        if (f) {
          if (needBirthday && !birthday && f.birthday) { birthday = f.birthday; source.birthday = `fandom:${f.page}`; }
          if (needDebut && !debut && f.debut) { debut = f.debut; source.debut = `fandom:${f.page}`; }
        }
      } catch (e) {
        console.warn(`[Profiles] Fandom error (${v.name}):`, e.message);
        continue; // 通信エラーは checked を付けず、次回もう一度調べる
      }
    }

    if (birthday) { updates[`vtuber/${key}/birthday`] = birthday; updates[`vtuber/${key}/profileSource/birthday`] = source.birthday; }
    if (debut) { updates[`vtuber/${key}/debut`] = debut; updates[`vtuber/${key}/profileSource/debut`] = source.debut; }
    // Wikidata だけで全部埋まった場合も、Fandom まで調べた場合も「調べ済み」にする
    if (fandomChecked || ((!needBirthday || birthday) && (!needDebut || debut))) {
      updates[`vtuberProfiles/checked/${ch}`] = { at: nowIso, birthday: !!birthday || !needBirthday, debut: !!debut || !needDebut };
    }
    if (birthday || debut) results.push({ key, name: v.name, birthday, debut, source });
  }

  const summary = {
    dryRun,
    targets: targets.length,
    filled: results.length,
    birthdays: results.filter(r => r.birthday).length,
    debuts: results.filter(r => r.debut).length,
    timedOut,
    elapsedSec: Math.round((Date.now() - startedAt) / 1000),
  };
  if (dryRun) return { ...summary, results };

  if (Object.keys(updates).length) await db.ref().update(updates);
  console.log('[Profiles]', summary);
  return summary;
}

module.exports = {
  runProfileFill,
  _internal: { parseBirthday, parseDebut, cleanWikiValue, searchQueries, findFandomProfile, fetchWikidataProfiles },
};
