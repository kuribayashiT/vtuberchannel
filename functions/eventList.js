// ================================================
// eventList.json 生成ロジック（純粋関数のみ。Firebase に依存しない）
//
// eventList.json の形式（Flutter アプリ / vchannel-web 共通・変更禁止）:
//   [ { "M/D": [ { eventType: 'birthday' | 'createAt', channelId, channelThumbnail,
//                 name, office, birthday? , createdAt? }, ... ] } ]
// ================================================

const DAYS_IN_MONTH = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]; // 2月は29日まで許可

function isValidMonthDay(month, day) {
  return Number.isInteger(month) && Number.isInteger(day) &&
    month >= 1 && month <= 12 && day >= 1 && day <= DAYS_IN_MONTH[month - 1];
}

/**
 * 誕生日文字列を { month, day } に変換する。Date は使わない
 * （new Date('02/29') が 2001年扱いで 3/1 になるため）。
 * 受け付ける形式: MM-DD / MM/DD / M/D / MMDD / YYYY-MM-DD / YYYY/MM/DD / M月D日 / YYYY年M月D日
 * 解釈できない・存在しない日付・"-"（不明確定）は null。
 */
function parseMonthDay(raw) {
  if (raw === null || raw === undefined) return null;
  const s = String(raw).trim()
    .replace(/[０-９]/g, (c) => String.fromCharCode(c.charCodeAt(0) - 0xFEE0))
    .replace(/[／]/g, '/')
    .replace(/[－ー−]/g, '-');
  if (!s || s === '-') return null;

  let m;
  let month;
  let day;
  if ((m = /^(?:\d{4}[-/.])?(\d{1,2})[-/.](\d{1,2})$/.exec(s))) {
    month = Number(m[1]);
    day = Number(m[2]);
  } else if ((m = /^(?:\d{4}年)?\s*(\d{1,2})月\s*(\d{1,2})日$/.exec(s))) {
    month = Number(m[1]);
    day = Number(m[2]);
  } else if ((m = /^(\d{2})(\d{2})$/.exec(s))) {
    month = Number(m[1]);
    day = Number(m[2]);
  } else {
    return null;
  }
  return isValidMonthDay(month, day) ? { month, day } : null;
}

/**
 * 保存用に誕生日を正規化する。
 *  - 解釈できれば "MM-DD"
 *  - "-"（不明確定）はそのまま "-"
 *  - 空は ""
 *  - 解釈できない値は null（呼び出し側で書き換えずに警告する）
 */
function normalizeBirthday(raw) {
  if (raw === null || raw === undefined) return '';
  const s = String(raw).trim();
  if (s === '') return '';
  if (s === '-') return '-';
  const md = parseMonthDay(s);
  if (!md) return null;
  return `${String(md.month).padStart(2, '0')}-${String(md.day).padStart(2, '0')}`;
}

/**
 * デビュー日を { year, month, day } に変換する。年は必須。
 * 受け付ける形式: YYYY/MM/DD, YYYY-MM-DD, YYYY/M/D, YYYY年M月D日（前後空白可）
 */
function parseYmd(raw) {
  if (raw === null || raw === undefined) return null;
  const s = String(raw).trim();
  const m = /^(\d{4})[-/.年]\s*(\d{1,2})[-/.月]\s*(\d{1,2})日?$/.exec(s);
  if (!m) return null;
  const year = Number(m[1]);
  const month = Number(m[2]);
  const day = Number(m[3]);
  if (!isValidMonthDay(month, day)) return null;
  // うるう年でない 2/29 は実在しない日付
  if (month === 2 && day === 29 && !(year % 4 === 0 && (year % 100 !== 0 || year % 400 === 0))) return null;
  return { year, month, day };
}

function dayKey(month, day) {
  return `${month}/${day}`;
}

/**
 * RTDB の vtuber ノードから eventList を組み立てる。
 * @param {Object} vtuberDict      RTDB vtuber/*（key → VTuber）
 * @param {Object} opts
 * @param {Map<string,{title?:string,thumbnail?:string}>} [opts.channelInfo]  channelId → YouTube 情報（任意）
 * @param {(officeKey:string)=>string} [opts.mapOffice]                       officeKey → 表示名
 * @returns {{ eventList: Object, stats: { birthday:number, createAt:number, invalidBirthday:Array, invalidDebut:Array } }}
 */
function buildEventList(vtuberDict, opts = {}) {
  const channelInfo = opts.channelInfo || new Map();
  const mapOffice = opts.mapOffice || ((k) => k || '');
  const eventList = {};
  const stats = { birthday: 0, createAt: 0, invalidBirthday: [], invalidDebut: [] };
  const seen = new Set();

  const push = (key, ev) => {
    if (!eventList[key]) eventList[key] = [];
    eventList[key].push(ev);
  };

  for (const k of Object.keys(vtuberDict || {})) {
    if (k === 'updateTime') continue;
    const v = vtuberDict[k];
    const channelId = v && v.channeID;
    if (!channelId || seen.has(channelId)) continue; // 同一チャンネルの重複登録は1件にまとめる
    seen.add(channelId);

    const yt = channelInfo.get(channelId) || {};
    const base = {
      channelId,
      channelThumbnail: yt.thumbnail || v.thumbnailUrl || '',
      name: yt.title || v.name || '',
      office: mapOffice(v.office || ''),
    };

    const debutRaw = typeof v.debut === 'string' ? v.debut.trim() : '';
    if (debutRaw && debutRaw !== '-') {
      const d = parseYmd(debutRaw);
      if (d) {
        push(dayKey(d.month, d.day), { eventType: 'createAt', ...base, createdAt: debutRaw });
        stats.createAt++;
      } else {
        stats.invalidDebut.push({ key: k, name: v.name || '', value: debutRaw });
      }
    }

    const bRaw = typeof v.birthday === 'string' ? v.birthday.trim() : '';
    if (bRaw && bRaw !== '-') {
      const b = parseMonthDay(bRaw);
      if (b) {
        push(dayKey(b.month, b.day), { eventType: 'birthday', ...base, birthday: normalizeBirthday(bRaw) });
        stats.birthday++;
      } else {
        stats.invalidBirthday.push({ key: k, name: v.name || '', value: bRaw });
      }
    }
  }
  return { eventList, stats };
}

/** eventList.json（[ {...} ] 形式）のイベント総数を数える */
function countEvents(eventListJson) {
  let n = 0;
  for (const obj of Array.isArray(eventListJson) ? eventListJson : [eventListJson]) {
    for (const arr of Object.values(obj || {})) n += Array.isArray(arr) ? arr.length : 0;
  }
  return n;
}

/**
 * 上書きしてよいか判定する安全装置。
 * 既存が十分大きく、新規が既存の minRatio 未満に減った場合は上書きしない。
 */
function shouldWriteEventList(prevCount, nextCount, minRatio = 0.8) {
  if (nextCount === 0) return false;
  if (prevCount < 50) return true;
  return nextCount >= prevCount * minRatio;
}

module.exports = {
  parseMonthDay,
  normalizeBirthday,
  parseYmd,
  buildEventList,
  countEvents,
  shouldWriteEventList,
};
