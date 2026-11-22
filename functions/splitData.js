// ================================================
// 巨大 JSON（officedataList.json 約20MB / allvideos.json 約18MB）を
// Web サイト用の小さなファイルに分割して GCS に書き出す。
//
// 背景: Next.js の fetch キャッシュは 2MB 超を保持できないため、巨大ファイルは
// サーバーインスタンスごとに毎回ダウンロードされ、GCS の外部転送料が月数千円に
// なっていた。分割後の各ファイルは 2MB 未満に収まり、Vercel 側で共有キャッシュされる。
//
// 出力（すべて gzip 保存。fetch は自動で解凍する）:
//   vtuberIndex.json              officedataList から videos / 推移を除いたもの（事務所→配列、並び順は元と同じ）
//                                 各要素に latestTransitionDate（登録者推移の最終日 "YYYY-MM-DD"）を追加
//   vtuberDetail/{00..63}.json    { [channelId]: { videos, youtubeSubscriberCountTransition(直近30日) } }
//   videoShards/{00..63}.json     { [videoID]: RawVideo }（allvideos を videoID で分割）
//   streamVideos.json             配信スケジュール用（前日0時JST以降〜9日後 ＋ それ以前の新しい順100件）
//
// シャード番号 = ID の UTF-16 コード単位の合計 % 64 を 2 桁ゼロ埋め（フロントと同一ロジック）
// 内容が前回書き込みと同じシャードはスキップする（GCS 書き込み回数の削減）
// ================================================
const crypto = require('crypto');

const SHARD_COUNT = 64;
const TRANSITION_DAYS = 30;
const STREAM_PAST_LIMIT = 100;
const STREAM_FUTURE_DAYS = 9;
const WEEKLY_TOP_LIMIT = 500;
const STREAM_FIELDS =['videoID', 'title', 'channelId', 'channelTitle', 'thumbnail', 'comparisonDay'];

// ファイル名 → 前回書き込んだ内容のハッシュ（インスタンス内のみ。コールドスタート時は全件書く）
const lastHashes = new Map();

function shardOf(id) {
  let sum = 0;
  for (let i = 0; i < id.length; i++) sum += id.charCodeAt(i);
  return String(sum % SHARD_COUNT).padStart(2, '0');
}

/** 公開 JSON を gzip で保存する。内容が前回と同じならスキップ */
async function saveJsonGz(bucket, fileName, data, { cacheControl = 'public, max-age=3600', skipUnchanged = false } = {}) {
  const body = JSON.stringify(data);
  const hash = crypto.createHash('sha1').update(body).digest('hex');
  if (skipUnchanged && lastHashes.get(fileName) === hash) return false;
  await bucket.file(fileName).save(body, {
    gzip: true,
    resumable: false,
    metadata: { contentType: 'application/json', cacheControl },
  });
  lastHashes.set(fileName, hash);
  return true;
}

function lastEntries(obj, n) {
  return Object.fromEntries(
    Object.entries(obj || {}).sort(([a], [b]) => a.localeCompare(b)).slice(-n),
  );
}

function channelIdOf(v) {
  return v.channeID || v.channelId || v.youtubeChId || '';
}

function jstMidnightUtcMs(now, dayOffset) {
  const jst = new Date(now + 9 * 3600_000);
  return Date.UTC(jst.getUTCFullYear(), jst.getUTCMonth(), jst.getUTCDate() + dayOffset) - 9 * 3600_000;
}

function buildVTuberFiles(officeList) {
  const index = {};
  const shards = {};
  for (const [office, list] of Object.entries(officeList || {})) {
    index[office] = (list || []).map((v) => {
      // Web で使わない項目は落とす（Next.js はキャッシュ時に base64 化するため実質 1.5MB が上限）
      // eslint-disable-next-line no-unused-vars
      const { videos, youtubeSubscriberCountTransition, twitterSubscriberCountTransition,
        youtubeChId, createdAt, updateTime, twicasID, twitterID, twitterName, ...rest } = v;
      const transition = lastEntries(youtubeSubscriberCountTransition, TRANSITION_DAYS);
      const dates = Object.keys(transition);
      const id = channelIdOf(v);
      if (id) {
        const s = shardOf(id);
        (shards[s] ||= {})[id] = { videos: videos || {}, youtubeSubscriberCountTransition: transition };
      }
      return { ...rest, channeID: id, latestTransitionDate: dates.length ? dates[dates.length - 1] : '' };
    });
  }
  return { index, shards };
}

function buildVideoShards(allvideos) {
  const shards = {};
  for (const v of allvideos || []) {
    const id = v && (v.videoID || v.videoId);
    if (!id) continue;
    (shards[shardOf(id)] ||= {})[id] = v;
  }
  return shards;
}

function buildStreamVideos(allvideos, now = Date.now()) {
  const from = jstMidnightUtcMs(now, -1);
  const to = jstMidnightUtcMs(now, STREAM_FUTURE_DAYS);
  const recent = [];
  const older = [];
  for (const v of allvideos || []) {
    const t = Date.parse(v && v.comparisonDay);
    if (!Number.isFinite(t) || t >= to) continue;
    const slim = {};
    for (const f of STREAM_FIELDS) if (v[f] !== undefined) slim[f] = v[f];
    (t >= from ? recent : older).push([t, slim]);
  }
  older.sort((a, b) => b[0] - a[0]);
  return recent.concat(older.slice(0, STREAM_PAST_LIMIT)).map(([, v]) => v);
}

async function writeAllShards(bucket, dir, shards) {
  let written = 0;
  for (let i = 0; i < SHARD_COUNT; i++) {
    const s = String(i).padStart(2, '0');
    if (await saveJsonGz(bucket, `${dir}/${s}.json`, shards[s] || {}, { skipUnchanged: true })) written++;
  }
  return written;
}

/** officedataList 由来の分割ファイルを書き出す */
async function writeVTuberSplitFiles(bucket, officeList) {
  const { index, shards } = buildVTuberFiles(officeList);
  await saveJsonGz(bucket, 'vtuberIndex.json', index, { skipUnchanged: true });
  const n = await writeAllShards(bucket, 'vtuberDetail', shards);
  console.log(`[splitData] vtuberIndex 更新, vtuberDetail ${n}/${SHARD_COUNT} シャード書き込み`);
}

/** allvideos 由来の分割ファイルを書き出す */
async function writeVideoSplitFiles(bucket, allvideos) {
  await saveJsonGz(bucket, 'streamVideos.json', buildStreamVideos(allvideos), {
    cacheControl: 'public, max-age=300',
  });
  const n = await writeAllShards(bucket, 'videoShards', buildVideoShards(allvideos));
  console.log(`[splitData] streamVideos 更新, videoShards ${n}/${SHARD_COUNT} シャード書き込み`);
}

/** weeklyLiveViewRanking の同時視聴者数上位だけを Web 用に書き出す（元ファイルは 2MB 近くありキャッシュできない） */
async function writeWeeklyLiveViewTop(bucket, ranking) {
  const top = [...(ranking || [])]
    .sort((a, b) => (parseInt(b.concurrent_viewers, 10) || 0) - (parseInt(a.concurrent_viewers, 10) || 0))
    .slice(0, WEEKLY_TOP_LIMIT);
  await saveJsonGz(bucket, 'weeklyLiveViewTop.json', top, {
    cacheControl: 'public, max-age=60',
    skipUnchanged: true,
  });
}

module.exports = {
  writeWeeklyLiveViewTop,
  SHARD_COUNT,
  shardOf,
  saveJsonGz,
  buildVTuberFiles,
  buildVideoShards,
  buildStreamVideos,
  writeVTuberSplitFiles,
  writeVideoSplitFiles,
};
