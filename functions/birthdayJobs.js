// ================================================
// eventList.json の自動更新 と 誕生日の Wikipedia 自動補完（すべて Functions の定期実行で完結）
//
//  ┌ RTDB vtuber/{key} 書き込み
//  │   └ onVtuberWriteForEventList: 誕生日を MM-DD に正規化
//  │                                関連フィールドが変われば meta/eventListDirty を立てる
//  ├ scheduledRebuildEventList（10分ごと）: dirty の時だけ eventList.json を再生成
//  ├ rebuildEventList（HTTP）: 手動再生成（?force=1 で件数ガードを無視）
//  │
//  ├ scheduledFillVtuberBirthdays（毎日 1:00 JST）
//  │   ├ 1回だけ: 旧 GPT 補完が記入例をそのまま返した "06-21" をクリア（バックアップあり）
//  │   └ 誕生日が空の VTuber を Wikipedia/Wikidata で照合
//  │       confidence high/medium → vtuber/{key}/birthday に自動反映（→ トリガー経由で eventList に反映）
//  │       confidence low         → 反映せず記録のみ（同名記事のみの一致は誤りがあり得るため）
//  └ fillVtuberBirthdays（HTTP）: 上記の照合を手動実行（?limit=N）
//
// RTDB:
//   meta/eventListDirty        : 最後に関連フィールドが変わった時刻（ms）
//   meta/eventListLastBuild    : { at, birthday, createAt, total, prevTotal, reason, skipped? }
//   meta/migrations/clearGpt0621: 06-21 クリアの実行記録（存在すれば二度と実行しない）
//   birthdayLookup/{key}       : { status: applied|lowconfidence|notfound, value, source, method,
//                                  confidence, wikiTitle, name, channelId, checkedAt }
//   birthdayBackup/{ts}        : 06-21 クリア前の値（復元用。key → 元の値）
// ================================================

const {
  normalizeBirthday,
  buildEventList,
  countEvents,
  shouldWriteEventList,
} = require('./eventList');
const { lookupBirthdays } = require('./wikipediaBirthday');

const BUCKET = 'vtuber-335811.appspot.com';
const EVENT_LIST_FILE = 'eventList.json';
const CHANNEL_INFO_FILE = 'allChannelYoutubeApiInfo.json';
const EVENT_FIELDS = ['birthday', 'debut', 'name', 'channeID', 'office', 'thumbnailUrl'];
const AUTO_APPLY_CONFIDENCE = ['high', 'medium'];
const RETRY_MS = 30 * 24 * 60 * 60 * 1000; // 見つからなかった/信頼度が低かった人は30日後に再照合
const DAILY_LOOKUP_LIMIT = 400; // 1回の実行時間（上限540秒）に収めるため。残りは翌日以降
const SUSPECT_GPT_BIRTHDAY = '06-21'; // 旧 GPT プロンプトの記入例。372件がこの値になっていた

function setCors(res) {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');
}

module.exports = function createBirthdayJobs({ functions, db, storage, getChannelInfoCache }) {
  const bucket = () => storage.bucket(BUCKET);

  // ------------------------------------------------
  // eventList 再生成
  // ------------------------------------------------
  async function loadChannelInfo(channelInfoList) {
    let list = channelInfoList || (getChannelInfoCache && getChannelInfoCache());
    if (!list) {
      try {
        const [buf] = await bucket().file(CHANNEL_INFO_FILE).download();
        list = JSON.parse(buf.toString());
      } catch (e) {
        console.warn('[eventList] allChannelYoutubeApiInfo 読み込み失敗。RTDB の名前/サムネイルを使用:', e.message);
        list = [];
      }
    }
    const map = new Map();
    for (const ch of list || []) {
      if (!ch || ch.kind !== 'youtube#channel' || !ch.id) continue;
      map.set(ch.id, {
        title: (ch.snippet && ch.snippet.title) || '',
        thumbnail: (ch.snippet && ch.snippet.thumbnails && ch.snippet.thumbnails.high && ch.snippet.thumbnails.high.url) || '',
      });
    }
    return map;
  }

  async function readPrevEventCount() {
    try {
      const [buf] = await bucket().file(EVENT_LIST_FILE).download();
      return countEvents(JSON.parse(buf.toString()));
    } catch (e) {
      return 0;
    }
  }

  /**
   * RTDB から eventList.json を作り直す。YouTube API は呼ばない。
   * @param {{ force?: boolean, channelInfoList?: Array, reason?: string }} opts
   */
  async function rebuildEventListCore(opts = {}) {
    const [vtuberSnap, mappingSnap] = await Promise.all([
      db.ref('vtuber').once('value'),
      db.ref('officeMapping').once('value'),
    ]);
    const officeMapping = mappingSnap.val() || {};
    const channelInfo = await loadChannelInfo(opts.channelInfoList);
    const { eventList, stats } = buildEventList(vtuberSnap.val() || {}, {
      channelInfo,
      mapOffice: (k) => officeMapping[k] || k || '',
    });
    const total = stats.birthday + stats.createAt;
    const prevTotal = await readPrevEventCount();
    const summary = { at: Date.now(), birthday: stats.birthday, createAt: stats.createAt, total, prevTotal, reason: opts.reason || '' };

    if (stats.invalidBirthday.length || stats.invalidDebut.length) {
      console.warn('[eventList] 解釈できない日付:', JSON.stringify({ birthday: stats.invalidBirthday, debut: stats.invalidDebut }));
    }
    if (!opts.force && !shouldWriteEventList(prevTotal, total)) {
      console.error(`[eventList] 件数が大きく減少したため上書きを中止: ${prevTotal} → ${total}（?force=1 で強制）`);
      await db.ref('meta/eventListLastBuild').set({ ...summary, skipped: true });
      return { ...summary, skipped: true };
    }
    await bucket().file(EVENT_LIST_FILE).save(JSON.stringify([eventList], null, 2), {
      resumable: false,
      metadata: { contentType: 'application/json' },
    });
    await db.ref('meta/eventListLastBuild').set(summary);
    console.log(`[eventList] 更新完了 birthday=${stats.birthday} createAt=${stats.createAt}（前回 ${prevTotal}件）`);
    return { ...summary, skipped: false };
  }

  // RTDB 書き込みトリガー: 誕生日の正規化 + dirty フラグ
  const onVtuberWriteForEventList = functions.database.ref('/vtuber/{key}').onWrite(async (change, context) => {
    if (context.params.key === 'updateTime') return null;
    const before = change.before.exists() ? change.before.val() : null;
    const after = change.after.exists() ? change.after.val() : null;
    if ((before && typeof before !== 'object') || (after && typeof after !== 'object')) return null;

    // 誕生日を MM-DD に正規化（管理画面・CSV・API どの経路で書かれても揃える）
    if (after && typeof after.birthday === 'string') {
      const norm = normalizeBirthday(after.birthday);
      if (norm === null) {
        console.warn(`[eventList] vtuber/${context.params.key} の誕生日を解釈できません: "${after.birthday}"`);
      } else if (norm !== after.birthday) {
        // この書き込みで再度トリガーされるが、2回目は値が同じなので dirty を立てる側に進む
        await change.after.ref.child('birthday').set(norm);
        return null;
      }
    }

    const changed = !before || !after || EVENT_FIELDS.some((f) => (before[f] || '') !== (after[f] || ''));
    if (changed) await db.ref('meta/eventListDirty').set(Date.now());
    return null;
  });

  const scheduledRebuildEventList = functions
    .runWith({ timeoutSeconds: 120, memory: '512MB' })
    .pubsub.schedule('every 10 minutes')
    .timeZone('Asia/Tokyo')
    .onRun(async () => {
      const dirtyRef = db.ref('meta/eventListDirty');
      const dirtyAt = (await dirtyRef.once('value')).val();
      if (!dirtyAt) return null;
      await rebuildEventListCore({ reason: 'dirty' });
      // 再生成中に新しい変更が入っていなければフラグを下ろす
      await dirtyRef.transaction((cur) => (cur === dirtyAt ? null : cur));
      return null;
    });

  const rebuildEventList = functions
    .runWith({ timeoutSeconds: 120, memory: '512MB' })
    .https.onRequest(async (req, res) => {
      setCors(res);
      if (req.method === 'OPTIONS') return res.status(204).send('');
      try {
        const result = await rebuildEventListCore({ force: req.query.force === '1', reason: 'manual' });
        res.json({ success: true, ...result });
      } catch (e) {
        console.error('[eventList] 手動再生成エラー:', e);
        res.status(500).json({ success: false, error: e.message });
      }
    });

  // ------------------------------------------------
  // 1回限りの移行: GPT 由来の "06-21" をクリア
  // ------------------------------------------------
  async function clearGptBirthdaysOnce() {
    const markRef = db.ref('meta/migrations/clearGpt0621');
    if ((await markRef.once('value')).exists()) return null;

    const vtuberDict = (await db.ref('vtuber').once('value')).val() || {};
    const targets = Object.entries(vtuberDict)
      .filter(([key, v]) => key !== 'updateTime' && v && typeof v === 'object')
      .filter(([, v]) => normalizeBirthday(v.birthday) === SUSPECT_GPT_BIRTHDAY);

    const ts = Date.now();
    const updates = {};
    for (const [key, v] of targets) {
      updates[`birthdayBackup/${ts}/${key}`] = v.birthday;
      updates[`vtuber/${key}/birthday`] = ''; // 空に戻す → 直後の Wikipedia 照合の対象になる
      updates[`birthdayLookup/${key}`] = null;
    }
    updates['meta/migrations/clearGpt0621'] = { at: ts, count: targets.length, backupPath: `birthdayBackup/${ts}` };
    await db.ref().update(updates);
    console.log(`[Birthday] 移行: GPT 由来の "${SUSPECT_GPT_BIRTHDAY}" を ${targets.length}件クリア（バックアップ: birthdayBackup/${ts}）`);
    // 意図した件数減少なので、件数ガードを外してすぐに作り直す
    // （ガードに任せると 817→461 件の減少で上書きが止まったままになる）
    await rebuildEventListCore({ force: true, reason: 'migration:clearGpt0621' });
    return targets.length;
  }

  // ------------------------------------------------
  // 誕生日の Wikipedia 自動補完
  // ------------------------------------------------

  /** 照合対象: 事務所アカウント以外で、誕生日が空（"-" は不明確定なので除外）、かつ再照合待ち期間外 */
  function selectTargets(vtuberDict, lookupDict, now = Date.now()) {
    const targets = [];
    for (const [key, v] of Object.entries(vtuberDict || {})) {
      if (key === 'updateTime' || !v || typeof v !== 'object') continue;
      if (v.officeFlg === true || !v.name) continue;
      if ((v.birthday || '').trim() !== '') continue;
      const lk = lookupDict[key];
      if (lk && lk.status !== 'applied' && now - (lk.checkedAt || 0) < RETRY_MS) continue;
      targets.push({ key, name: v.name, channelId: v.channeID || '' });
    }
    return targets;
  }

  /** Wikipedia で照合し、信頼度 high/medium は vtuber/{key}/birthday に反映する */
  async function fillBirthdaysCore({ limit = 0, keys = null } = {}) {
    const [vtuberSnap, lookupSnap] = await Promise.all([
      db.ref('vtuber').once('value'),
      db.ref('birthdayLookup').once('value'),
    ]);
    let targets = selectTargets(vtuberSnap.val() || {}, lookupSnap.val() || {});
    if (keys) targets = targets.filter((t) => keys.includes(t.key));
    if (limit > 0) targets = targets.slice(0, limit);
    if (targets.length === 0) return { targets: 0, applied: 0, lowconfidence: 0, notfound: 0 };

    console.log(`[Birthday] Wikipedia 照合: ${targets.length}件`);
    const results = await lookupBirthdays(targets);
    const now = Date.now();
    const updates = {};
    const count = { applied: 0, lowconfidence: 0, notfound: 0 };
    for (const t of targets) {
      const r = results.get(t.key) || { found: false };
      const base = { name: t.name, channelId: t.channelId, checkedAt: now };
      if (!r.found) {
        updates[`birthdayLookup/${t.key}`] = { ...base, status: 'notfound' };
        count.notfound++;
        continue;
      }
      const detail = { value: r.value, source: r.source, method: r.method, confidence: r.confidence, wikiTitle: r.wikiTitle || '' };
      if (AUTO_APPLY_CONFIDENCE.includes(r.confidence)) {
        updates[`vtuber/${t.key}/birthday`] = r.value;
        updates[`vtuber/${t.key}/updateTime`] = new Date(now).toISOString();
        updates[`birthdayLookup/${t.key}`] = { ...base, ...detail, status: 'applied' };
        count.applied++;
        console.log(`[Birthday] ${t.name} → ${r.value}（${r.confidence} / ${r.source}）`);
      } else {
        updates[`birthdayLookup/${t.key}`] = { ...base, ...detail, status: 'lowconfidence' };
        count.lowconfidence++;
        console.log(`[Birthday] ${t.name} は信頼度が低いため未反映: ${r.value}（${r.source}）`);
      }
    }
    // vtuber の更新は onVtuberWriteForEventList 経由で 10分以内に eventList に反映される
    if (Object.keys(updates).length) await db.ref().update(updates);
    console.log(`[Birthday] 完了: 反映 ${count.applied} / 低信頼 ${count.lowconfidence} / 見つからず ${count.notfound}`);
    return { targets: targets.length, ...count };
  }

  const fillVtuberBirthdays = functions
    .runWith({ timeoutSeconds: 540, memory: '512MB' })
    .https.onRequest(async (req, res) => {
      setCors(res);
      if (req.method === 'OPTIONS') return res.status(204).send('');
      try {
        const cleared = await clearGptBirthdaysOnce();
        const result = await fillBirthdaysCore({ limit: Math.max(0, Number(req.query.limit) || DAILY_LOOKUP_LIMIT) });
        res.json({ success: true, clearedGpt0621: cleared, ...result });
      } catch (e) {
        console.error('[Birthday] 一括照合エラー:', e);
        res.status(500).json({ success: false, error: e.message });
      }
    });

  // 毎日 1:00 AM JST
  const scheduledFillVtuberBirthdays = functions
    .runWith({ timeoutSeconds: 540, memory: '512MB' })
    .pubsub.schedule('0 1 * * *')
    .timeZone('Asia/Tokyo')
    .onRun(async () => {
      await clearGptBirthdaysOnce();
      await fillBirthdaysCore({ limit: DAILY_LOOKUP_LIMIT });
      return null;
    });

  /** addVtuberData から呼ぶ: 新規登録1件だけ照合 */
  async function fillBirthdayForKey(key) {
    return fillBirthdaysCore({ keys: [key] });
  }

  return {
    rebuildEventListCore,
    fillBirthdayForKey,
    exports: {
      onVtuberWriteForEventList,
      scheduledRebuildEventList,
      rebuildEventList,
      fillVtuberBirthdays,
      scheduledFillVtuberBirthdays,
    },
  };
};
