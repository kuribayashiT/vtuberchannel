// ================================================
// Wikipedia（日本語版）/ Wikidata から VTuber の誕生日候補を探す
//
// 照合手順:
//   1. Wikidata で YouTube チャンネルID (P2397) が一致する項目を検索
//      → 一致した項目の jawiki 記事の Infobox から誕生日を取得（confidence: high）
//      → 記事に無ければ Wikidata の生年月日 (P569, 日精度) を使用（confidence: medium）
//   2. 1 で見つからなければ、VTuber 名と同名の jawiki 記事を確認
//      （曖昧さ回避・節へのリダイレクトは除外。VTuber 記事であることを確認）
//      → 記事内にチャンネルIDがあれば high、無ければ low
//
// confidence high/medium は birthdayJobs.js が自動で反映し、low は反映しない。
// Wikimedia の API 利用規約に従い、識別可能な User-Agent を付け、逐次・低頻度でアクセスする。
// ================================================

const { normalizeBirthday } = require('./eventList');

const USER_AGENT = 'VchannelBirthdayBot/1.0 (https://github.com/kuribayashiT; Firebase Cloud Functions)';
const WIKIDATA_API = 'https://www.wikidata.org/w/api.php';
const JAWIKI_API = 'https://ja.wikipedia.org/w/api.php';
const REQUEST_INTERVAL_MS = 500;

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const chunk = (arr, n) => {
  const out = [];
  for (let i = 0; i < arr.length; i += n) out.push(arr.slice(i, i + n));
  return out;
};

// 試行回数。毎晩 1:00 JST ごろは Wikidata が混み maxlag が続くため、Retry-After に従って長めに待つ。
// 最後の 1 回は maxlag を外して取得する（読み取りのみで負荷が小さいため）
const MAX_ATTEMPTS = 5;

async function mwGet(endpoint, params, attempt = 0) {
  const url = new URL(endpoint);
  const lastAttempt = attempt >= MAX_ATTEMPTS - 1;
  for (const [k, v] of Object.entries({ format: 'json', formatversion: '2', ...(lastAttempt ? {} : { maxlag: '5' }), ...params })) {
    url.searchParams.set(k, v);
  }
  await sleep(REQUEST_INTERVAL_MS);
  let res;
  try {
    res = await fetch(url, { headers: { 'User-Agent': USER_AGENT, 'Api-User-Agent': USER_AGENT } });
  } catch (e) {
    if (!lastAttempt) {
      await sleep(2000 * (attempt + 1));
      return mwGet(endpoint, params, attempt + 1);
    }
    throw e;
  }
  const retryAfter = Number(res.headers.get('retry-after')) || 0;
  const text = await res.text();
  let body = null;
  try {
    body = JSON.parse(text);
  } catch (_) {
    body = null;
  }
  // 429 / 5xx / maxlag は待って再試行
  if (res.status === 429 || res.status >= 500 || !body || (body.error && body.error.code === 'maxlag')) {
    if (!lastAttempt) {
      await sleep(Math.max(retryAfter * 1000, 5000 * (attempt + 1)));
      return mwGet(endpoint, params, attempt + 1);
    }
    throw new Error(`MediaWiki API error: HTTP ${res.status} ${body && body.error ? body.error.code : ''}`.trim());
  }
  if (body.error) throw new Error(`MediaWiki API error: ${body.error.code} ${body.error.info || ''}`.trim());
  return body;
}

const articleUrl = (title) => `https://ja.wikipedia.org/wiki/${encodeURIComponent(title.replace(/ /g, '_'))}`;

// ------------------------------------------------
// Infobox から誕生日を抜き出す
// ------------------------------------------------
const BIRTH_FIELD_RE = /^\s*\|\s*(?:birth_date|birthday|誕生日|生年月日)\s*=\s*(.*)$/gim;

/** wikitext の値部分から装飾を取り除き、MM-DD に正規化する */
function cleanBirthValue(value) {
  let s = String(value || '');
  s = s.replace(/<!--[\s\S]*?-->/g, '')
    .replace(/<ref[^>]*\/>/gi, '')
    .replace(/<ref[^>]*>[\s\S]*?<\/ref>/gi, '')
    .replace(/<br\s*\/?>/gi, ' ')
    .replace(/<[^>]+>/g, '');
  // {{birth date|YYYY|M|D}} / {{生年月日と年齢|YYYY|M|D}} / {{Birth date and age|YYYY|M|D}}
  const tpl = /\{\{\s*(?:birth date(?: and age)?|生年月日と年齢|生年月日)\s*\|\s*(\d{4})?\s*\|\s*(\d{1,2})\s*\|\s*(\d{1,2})/i.exec(s);
  if (tpl) return normalizeBirthday(`${tpl[2]}/${tpl[3]}`);
  s = s.replace(/\[\[(?:[^\]|]*\|)?([^\]]*)\]\]/g, '$1') // [[9月24日]] / [[a|b]] → 表示文字
    .replace(/\{\{[^{}]*\}\}/g, '')
    .replace(/'''?/g, '')
    .trim();
  const m = /(?:(\d{4})年\s*)?(\d{1,2})月\s*(\d{1,2})日/.exec(s);
  if (m) return normalizeBirthday(`${m[2]}/${m[3]}`);
  const n = normalizeBirthday(s);
  return n && n !== '-' ? n : null;
}

/** 記事の wikitext から最初に見つかった有効な誕生日（MM-DD）を返す */
function extractBirthdayFromWikitext(wikitext) {
  if (!wikitext) return null;
  BIRTH_FIELD_RE.lastIndex = 0;
  let m;
  while ((m = BIRTH_FIELD_RE.exec(wikitext))) {
    const v = cleanBirthValue(m[1]);
    if (v) return v;
  }
  return null;
}

const looksLikeVtuberArticle = (wikitext) =>
  /VTuber|バーチャルYouTuber|Vtuber|Infobox YouTube personality/i.test(wikitext || '');

/** Wikidata P569（生年月日）。日精度（precision >= 11）のときだけ MM-DD を返す */
function birthdayFromWikidataClaims(claims) {
  for (const c of (claims && claims.P569) || []) {
    const v = c.mainsnak && c.mainsnak.datavalue && c.mainsnak.datavalue.value;
    if (!v || !v.time || v.precision < 11) continue;
    const m = /^[+-]\d+-(\d{2})-(\d{2})T/.exec(v.time);
    if (m && m[1] !== '00' && m[2] !== '00') return normalizeBirthday(`${m[1]}/${m[2]}`);
  }
  return null;
}

// ------------------------------------------------
// API 呼び出し
// ------------------------------------------------

/** channelId[] → Map<channelId, { qid, jaTitle, wikidataBirthday }> */
async function findWikidataByChannelIds(channelIds) {
  const result = new Map();
  // 通信エラーで照合できなかったチャンネル ID（「見つからず」と区別し、翌日に再照合させる）
  result.failed = new Set();
  const ids = channelIds.filter((id) => /^UC[0-9A-Za-z_-]{22}$/.test(id));
  let down = false; // リトライし尽くして失敗したら、残りは問い合わせず翌日に回す（540 秒の制限時間を守るため）
  for (const group of chunk(ids, 20)) {
   if (down) { for (const id of group) result.failed.add(id); continue; }
   try {
    const search = await mwGet(WIKIDATA_API, {
      action: 'query',
      list: 'search',
      srsearch: `haswbstatement:${group.map((id) => `P2397=${id}`).join('|')}`,
      srlimit: '50',
      srnamespace: '0',
    });
    const qids = ((search.query && search.query.search) || []).map((x) => x.title);
    if (qids.length === 0) continue;
    for (const qGroup of chunk(qids, 50)) {
      const ent = await mwGet(WIKIDATA_API, {
        action: 'wbgetentities',
        ids: qGroup.join('|'),
        props: 'claims|sitelinks',
        sitefilter: 'jawiki',
      });
      for (const [qid, e] of Object.entries(ent.entities || {})) {
        const jaTitle = e.sitelinks && e.sitelinks.jawiki ? e.sitelinks.jawiki.title : null;
        const wikidataBirthday = birthdayFromWikidataClaims(e.claims);
        for (const c of (e.claims && e.claims.P2397) || []) {
          const cid = c.mainsnak && c.mainsnak.datavalue && c.mainsnak.datavalue.value;
          if (group.includes(cid) && !result.has(cid)) result.set(cid, { qid, jaTitle, wikidataBirthday });
        }
      }
    }
   } catch (e) {
    console.warn(`[Birthday] Wikidata 照合に失敗。残りは翌日に再照合:`, e.message);
    for (const id of group) result.failed.add(id);
    down = true;
   }
  }
  return result;
}

/**
 * jawiki 記事をまとめて取得する。
 * @returns {Map<requestedTitle, { title, wikitext, disambiguation, sectionRedirect }>}（存在しない記事は含まない）
 */
async function fetchJawikiPages(titles) {
  const out = new Map();
  // 通信エラーで取得できなかったタイトル
  out.failed = new Set();
  const uniq = [...new Set(titles.filter(Boolean))];
  let down = false;
  for (const group of chunk(uniq, 20)) {
    if (down) { for (const t of group) out.failed.add(t); continue; }
    let body;
    try {
      body = await mwGet(JAWIKI_API, {
      action: 'query',
      prop: 'revisions|pageprops',
      rvprop: 'content',
      rvslots: 'main',
      ppprop: 'disambiguation',
      redirects: '1',
      titles: group.join('|'),
      });
    } catch (e) {
      console.warn(`[Birthday] jawiki 記事の取得に失敗。残りは翌日に再照合:`, e.message);
      for (const t of group) out.failed.add(t);
      down = true;
      continue;
    }
    const q = body.query || {};
    // 要求タイトル → 最終タイトル（正規化・リダイレクトをたどる）
    const finalOf = new Map(group.map((t) => [t, { title: t, sectionRedirect: false }]));
    for (const n of q.normalized || []) {
      for (const [k, v] of finalOf) if (v.title === n.from) finalOf.set(k, { ...v, title: n.to });
    }
    for (const r of q.redirects || []) {
      for (const [k, v] of finalOf) {
        if (v.title === r.from) finalOf.set(k, { title: r.to, sectionRedirect: v.sectionRedirect || !!r.tofragment });
      }
    }
    const pages = new Map((q.pages || []).filter((p) => !p.missing && !p.invalid).map((p) => [p.title, p]));
    for (const [req, fin] of finalOf) {
      const p = pages.get(fin.title);
      if (!p) continue;
      const rev = p.revisions && p.revisions[0];
      out.set(req, {
        title: p.title,
        wikitext: (rev && rev.slots && rev.slots.main && rev.slots.main.content) || '',
        disambiguation: !!(p.pageprops && 'disambiguation' in p.pageprops),
        sectionRedirect: fin.sectionRedirect,
      });
    }
  }
  return out;
}

/**
 * VTuber 名（チャンネル名）から記事タイトル候補を作る。
 * 例: "弦月 藤士郎 / Genzuki Tojiro【にじさんじ】" → ["弦月 藤士郎", "弦月藤士郎"]
 *     "響木アオ-HibikiAo-" → ["響木アオ"]
 */
function titleCandidatesFromName(name) {
  let s = String(name || '').trim();
  s = s.replace(/【[^】]*】|\[[^\]]*\]|（[^）]*）|\([^)]*\)|『[^』]*』/g, ' ')
    .replace(/\s*(?:\/|／|\||｜).*$/, '')
    .replace(/\s*[-‐–―－]\s*[A-Za-z0-9 .]+[-‐–―－]?\s*$/, '') // 末尾の "-HibikiAo-" / "‐ ReGLOSS"
    .replace(/\s*(?:Ch\.|ch\.|channel|Channel|CHANNEL|チャンネル|ちゃんねる)\s*$/, '')
    .replace(/^\s*(?:Ch\.|ch\.)\s*/, '')
    .replace(/\s+/g, ' ')
    .trim();
  if (s.length < 2) return [];
  const out = [s];
  const noSpace = s.replace(/[\s　・]/g, '');
  if (/[^\x00-\x7F]/.test(s) && noSpace !== s && noSpace.length >= 2) out.push(noSpace);
  return out;
}

/**
 * 誕生日候補を探す。
 * @param {Array<{key:string, name:string, channelId:string}>} targets
 * @returns {Promise<Map<key, { found:boolean, value?:string, source?:string, method?:string, confidence?:string, wikiTitle?:string }>>}
 */
async function lookupBirthdays(targets) {
  const results = new Map();
  const byChannel = await findWikidataByChannelIds(targets.map((t) => t.channelId).filter(Boolean));

  // 1. Wikidata 経由（チャンネルID一致）
  const linkedTitles = [...new Set([...byChannel.values()].map((x) => x.jaTitle).filter(Boolean))];
  const linkedPages = await fetchJawikiPages(linkedTitles);
  const remaining = [];
  for (const t of targets) {
    if (byChannel.failed.has(t.channelId)) {
      results.set(t.key, { found: false, error: true });
      continue;
    }
    const wd = byChannel.get(t.channelId);
    if (wd && wd.jaTitle && linkedPages.failed.has(wd.jaTitle)) {
      results.set(t.key, { found: false, error: true });
      continue;
    }
    if (wd) {
      const page = wd.jaTitle ? linkedPages.get(wd.jaTitle) : null;
      const fromArticle = page && !page.sectionRedirect ? extractBirthdayFromWikitext(page.wikitext) : null;
      if (fromArticle) {
        results.set(t.key, { found: true, value: fromArticle, source: articleUrl(page.title), method: 'wikidata-channel', confidence: 'high', wikiTitle: page.title });
        continue;
      }
      if (wd.wikidataBirthday) {
        // Wikidata の生年月日は「中の人」やキャラ設定と混同されている例があるため medium 扱い
        results.set(t.key, { found: true, value: wd.wikidataBirthday, source: `https://www.wikidata.org/wiki/${wd.qid}`, method: 'wikidata-p569', confidence: 'medium', wikiTitle: wd.jaTitle || '' });
        continue;
      }
    }
    remaining.push(t);
  }

  // 2. 同名記事
  const titlesOf = new Map(remaining.map((t) => [t.key, titleCandidatesFromName(t.name)]));
  const namedPages = await fetchJawikiPages([...titlesOf.values()].flat());
  for (const t of remaining) {
    if ((titlesOf.get(t.key) || []).some((title) => namedPages.failed.has(title))) {
      results.set(t.key, { found: false, error: true });
      continue;
    }
    const page = (titlesOf.get(t.key) || [])
      .map((title) => namedPages.get(title))
      .find((p) => p && !p.disambiguation && !p.sectionRedirect && looksLikeVtuberArticle(p.wikitext));
    if (!page) {
      results.set(t.key, { found: false });
      continue;
    }
    const value = extractBirthdayFromWikitext(page.wikitext);
    if (!value) {
      results.set(t.key, { found: false });
      continue;
    }
    const channelMatched = !!t.channelId && page.wikitext.includes(t.channelId);
    results.set(t.key, {
      found: true,
      value,
      source: articleUrl(page.title),
      method: channelMatched ? 'title-channel' : 'title-match',
      confidence: channelMatched ? 'high' : 'low',
      wikiTitle: page.title,
    });
  }
  return results;
}

module.exports = {
  lookupBirthdays,
  extractBirthdayFromWikitext,
  cleanBirthValue,
  titleCandidatesFromName,
  birthdayFromWikidataClaims,
};
