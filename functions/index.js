// office名を非同期で取得し、失敗時は同期マッピングで返すラッパー関数
async function mapOfficeStringSafeAsync(officeKey) {
  try {
    const result = await mapOfficeStringAsync(officeKey);
    if (result && typeof result === 'string' && result.trim() !== '') {
      return result;
    } else {
      return mapOfficeString(officeKey);
    }
  } catch (e) {
    return mapOfficeString(officeKey);
  }
}
// 事務所名を日本語などに変換するダミー関数（必要に応じて編集）

// Firebase Realtime DatabaseのofficeMappingをキャッシュし、officeKey→日本語名を返す
let officeMappingCache = null;
let officeMappingCachePromise = null;

// 非同期でofficeMappingを取得しキャッシュする
async function mapOfficeStringAsync(officeKey) {
  if (!officeMappingCache) {
    if (!officeMappingCachePromise) {
      officeMappingCachePromise = db.ref('officeMapping').once('value').then(snap => {
        officeMappingCache = snap.val() || {};
        return officeMappingCache;
      }).catch(e => {
        officeMappingCache = {};
        return officeMappingCache;
      });
    }
    await officeMappingCachePromise;
  }
  return officeMappingCache[officeKey] || officeKey || '';
}

// 既存の同期関数はキャッシュ参照のみ（未取得時は空文字）
function mapOfficeString(officeKey) {
  const map = {
    'hololive': 'ホロライブ',
    'nijisanji': 'にじさんじ',
    'VShojo': 'VShojo',
    'other': 'その他',
    'personal': '個人',
    // 必要に応じて追加
  };
  return map[officeKey] || officeKey || '';
}
// 日付をYYYY-MM-DD HH:mm:ss形式で返すユーティリティ
function formatDate(date) {
  if (!date) return '';
  const d = new Date(date);
  const pad = n => n.toString().padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`;
}
// ...require群...
const axios = require('axios');
const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');
admin.initializeApp();
const db = admin.database(); // ←これを追加
const firestoreDB = admin.firestore();

// NOTE:
// If you want to upload videos to a specific YouTube channel, provide a
// corresponding OAuth token file for that channel and set the environment
// variable YOUTUBE_TOKEN_FILE to the filename (placed in the functions/ dir)
// Example (local deploy):
//   export YOUTUBE_TOKEN_FILE="youtube_token_channel_A.json"
// Then deploy Cloud Functions so youtubeUpload will pick that token file.
// ...existing code...
// RSSパーサーをグローバルで初期化
const Parser = require('rss-parser');
const parser = new Parser({
  headers: {
    'User-Agent': 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)'
  }
});
const OpenAI = require('openai');
const storage = admin.storage();

// ...existing code...
// 既存VTuberデータにYouTube APIキャッシュからthumbnailUrl, name, descriptionを一括追加する管理者用バッチ関数
exports.addVtuberMetaBatch = functions.https.onRequest(async (req, res) => {
  try {
    // VTuberデータ全件取得
    const refVtuber = await db.ref('vtuber').once('value');
    const vtuberDict = refVtuber.val();

    // キャッシュ済みYouTube APIデータ取得
    const bucket = storage.bucket('vtuber-335811.appspot.com');
    let allChannelYoutubeApiInfo = bucket.file('allChannelYoutubeApiInfo.json');
    await new Promise((resolve, reject) => {
      allChannelYoutubeApiInfo.download((err, contents) => {
        if (err) {
          reject(err);
          return;
        }
        try {
          allChannelYoutubeApiInfo = JSON.parse(contents.toString());
          resolve();
        } catch (parseErr) {
          reject(parseErr);
        }
      });
    });

    // チャンネルID→YouTubeデータのMap作成
    const channelMap = {};
    for (const channel of allChannelYoutubeApiInfo) {
      if (channel && channel.kind === "youtube#channel") {
        channelMap[channel.id] = {
          thumbnailUrl: channel.snippet.thumbnails.high.url,
          name: channel.snippet.title,
          description: channel.snippet.description || ""
        };
      }
    }

    // 既存VTu Nberデータに3項目だけ追加
    let updateCount = 0;
    for (const key in vtuberDict) {
      if (key === "updateTime") continue;
      const chId = vtuberDict[key].channeID;
      if (channelMap[chId]) {
        await db.ref(`vtuber/${key}`).update({
          thumbnailUrl: channelMap[chId].thumbnailUrl,
          name: channelMap[chId].name,
          description: channelMap[chId].description
        });
        updateCount++;
      }
    }
    res.send(`Batch update completed. Updated ${updateCount} vtubers.`);
  } catch (err) {
    res.status(500).send(`Batch update failed: ${err}`);
  }
});
/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

// const {onRequest} = require("firebase-functions/v2/https");
// const logger = require("firebase-functions/logger");
// ...existing code...

exports.getOfficeData = functions.https.onRequest(async (request, response) => {
  response.set('Access-Control-Allow-Origin', '*');

  if (request.method === 'OPTIONS') {
    // Send response to OPTIONS requests
    response.set('Access-Control-Allow-Methods', 'GET');
    response.set('Access-Control-Allow-Headers', 'Content-Type');
    response.set('Access-Control-Max-Age', '3600');
    response.status(204).send('');
  } else {
    //response.send('Hello World!');
  }
  try {

    // 定期的なニュース取得

    //★★★★★★★★★★★★★★★
    const snapshot = await db.ref('vtuber').once('value');
    vtuberDataList = snapshot.val();
    //★★★★★★★★★★★★★★★
    // データをJSON形式でクライアントに返す
    response.status(200).json({ vtuberDataList });
  } catch (error) {
    console.error('Error:', error);
    response.status(500).json({ error: 'Something went wrong [vtuberDataList]' });
  }
});

exports.getFirebaseTwitterData = functions.https.onRequest(async (request, response) => {
  response.set('Access-Control-Allow-Origin', '*');

  if (request.method === 'OPTIONS') {
    // Send response to OPTIONS requests
    response.set('Access-Control-Allow-Methods', 'GET');
    response.set('Access-Control-Allow-Headers', 'Content-Type');
    response.set('Access-Control-Max-Age', '3600');
    response.status(204).send('');
  } else {
    //response.send('Hello World!');
  }
  try {
    // Realtime Databaseからデータを取得
    const snapshot = await db.ref('twitter').once('value');
    twitterDataList = snapshot.val();

    // データをJSON形式でクライアントに返す
    response.status(200).json({ twitterDataList });
  } catch (error) {
    console.error('Error:', error);
    response.status(500).json({ error: 'Something went wrong [twitterDataList]' });
  }
});

// ================================================  
// RTDBからYoutube Channelデータ作成
//  scheduled every 24 hours
//  memory: '1GB'
//  timeoutSeconds: 540
// ================================================
exports.scheduledRealTimeDBToAllChannelYoutubeApiInfo = functions
  .runWith({
    timeoutSeconds: 540, // タイムアウトを秒で指定
    memory: '1GB' // メモリを指定
  })
  .pubsub
  .schedule('every 24 hours')  // スケジュールを設定
  .timeZone('Asia/Tokyo') // タイムゾーンを設定
  .onRun(async (context) => {
    // キャッシュをクリアして必ず最新を取得
    officeMappingCache = null;
    officeMappingCachePromise = null;

    const refVtuber = await db.ref('vtuber').once('value');
    const apiKey = 'AIzaSyDEJ47ME_oxje2r5XX6hHtMf-F8W2zINSE';
    // 50(GET_YOUTUBE_DATA_NUM)名毎にYoutube channels() を叩く必要がる
    const GET_YOUTUBE_DATA_NUM = 50; // 例：一度に取得するチャンネルIDの数
    let vtuberIDList = []; // 例：VTuberのチャンネルIDのリスト
    // const snapshot = await refVtuber.once('value');
    const vtuberDict = refVtuber.val();
    let allChannelYoutubeApiInfo = [];

    for (const member in vtuberDict) {
      if (member === "updateTime") {
        continue;
      }
      vtuberIDList.push(vtuberDict[member]["channeID"]);

    }
    let membar_channel_id_List_str_List = [];
    for (let i = 0; i < vtuberIDList.length; i += GET_YOUTUBE_DATA_NUM) {
      membar_channel_id_List_str_List.push(vtuberIDList.slice(i, i + GET_YOUTUBE_DATA_NUM));
    }
    for (let i = 0; i < membar_channel_id_List_str_List.length; i++) {
      // Youtube channels() にむけたクエリを作成
      let membar_channel_id_List_str = "";
      for (let memNum = 0; memNum < membar_channel_id_List_str_List[i].length; memNum++) {
        let vtuberChanneID = membar_channel_id_List_str_List[i][memNum];
        // console.log(`${memNum}:${vtuberChanneID}`);
        membar_channel_id_List_str += vtuberChanneID + ",";
      }
      // console.log("========================================");
      // console.log("== allChannelYoutubeApiInfo: " + i);
      // console.log("========================================");
      try {
        let response = await axios.get('https://www.googleapis.com/youtube/v3/channels', {
          params: {
            part: 'snippet,statistics',
            id: membar_channel_id_List_str.slice(0, -1), // 最後のカンマを削除
            key: apiKey,
          },
        });
        allChannelYoutubeApiInfo = allChannelYoutubeApiInfo.concat(response.data.items);

        // ここでthumbnailUrlをRealtime Databaseに反映
        for (const item of response.data.items) {
          const channeID = item.id;
          const thumbnailUrl = item.snippet?.thumbnails?.high?.url || item.snippet?.thumbnails?.default?.url || "";
          if (channeID && thumbnailUrl) {
            // vtuberノードのchanneID一致するものにthumbnailUrlをupdate
            for (const key in vtuberDict) {
              if (vtuberDict[key]?.channeID === channeID) {
                await db.ref(`vtuber/${key}`).update({ thumbnailUrl });
                break;
              }
            }
          }
        }

      } catch (error) {
        console.error("エラー発生", error);
      }
      if (membar_channel_id_List_str_List.length - 1 == i) {
        const bucket = storage.bucket('vtuber-335811.appspot.com');
        const appendToFile = async (data, bucket, baseFileName) => {
          const fileName = `${baseFileName}.json`;
          // console.log(baseFileName+"ファイルアップロード");
          const file = bucket.file(fileName);
          const fileStream = file.createWriteStream({
            metadata: {
              contentType: 'application/json'
            },
            resumable: false,  // 追記するために必要
            timeout: 540000,  // タイムアウトを調整（ミリ秒単位）
          });

          fileStream.on('finish', () => {
            // console.log(`${fileName}: データの追記が完了しました:`,data);
          });

          fileStream.on('error', (error) => {
            // console.error(`${fileName}: データの追記中にエラーが発生しました:`, error);
            throw error;  // エラー発生時に終了
          });

          // データ全体を一つのJSON配列にまとめる
          const jsonArray = JSON.stringify(data, null, 2);
          // 配列全体を書き込む
          fileStream.write(jsonArray);
          fileStream.end();

          await new Promise((resolve, reject) => {
            fileStream.on('finish', resolve);
            fileStream.on('error', reject);
          });
        };
        try {
          //　allChannelYoutubeApiInfoのファイルアップロード
          await appendToFile(allChannelYoutubeApiInfo, bucket, 'allChannelYoutubeApiInfo');
          // console.log('allChannelYoutubeApiInfoのデータの追記が完了しました');
        } catch (error) {
          console.error('allChannelYoutubeApiInfoのデータの追記中にエラーが発生しました:', error);
        }
      }
    }
  }
  );

// ================================================  
// allChannelYoutubeApiInfoからYoutubeデータ作成
//  scheduled every 5 minutes
//  memory: '2GB'
//  timeoutSeconds: 540
// ================================================
exports.scheduledRealTimeDBToYoutubeData = functions
  .runWith({
    timeoutSeconds: 540, // タイムアウトを秒で指定
    memory: '2GB' // メモリを指定
  })
  .pubsub
  .schedule('every 5 minutes')  // スケジュールを設定
  .timeZone('Asia/Tokyo') // タイムゾーンを設定
  .onRun(async (context) => {
    const apiKey = 'AIzaSyDEJ47ME_oxje2r5XX6hHtMf-F8W2zINSE';
    const refVtuber = await db.ref('vtuber').once('value');;
    const threadRef = firestoreDB.collection('threads');
    const vtuberDict = refVtuber.val();
    let officeDataList = {};
    let officeNameList = ["personal"];
    let allYoutubeData = [];
    let allYoutubeDataObj = [];
    let vtuberVideoData = [];
    let vtuberVideoDataObj = [];
    let rankingYoutubeRegiData = [];
    let rankingVideoCountData = [];
    let eventList = {};
    // 今日の日付を取得して、YYYYMMDD形式に変換
    const d_today_utc = new Date();
    const year = d_today_utc.getUTCFullYear();
    const month = String(d_today_utc.getUTCMonth() + 1).padStart(2, '0');
    const day = String(d_today_utc.getUTCDate()).padStart(2, '0');
    const todayStr = `${year}${month}${day}`;

    let DB_REGISTERD_VIDEO_ID = []
    let youtubeSubscriberCountTransitionList = []; //youtubeSubscriberCountTransition情報を格納するdataFMT
    const { google } = require('googleapis');
    const Parser = require('rss-parser');
    const parser = new Parser({
      customFields: {
        item: [
          ['yt:videoId', 'yt:videoId'],
          ['yt:channelId', 'yt:channelId'],
          ['updated', 'updated'],
          ['published', 'published'],
          ['media:group', 'mediaGroup', { keepArray: true }],
          ['media:group.media:thumbnail', 'mediaThumbnail', { keepArray: true }],
          ['media:group.media:community', 'mediaCommunity', { keepArray: true }],
          ['media:group.media:community.media:statistics', 'mediaStatistics', { keepArray: true }],
          ['media:group.media:community.media:starRating', 'mediaStarRating', { keepArray: true }]
        ]
      }
    });

    const bucket = storage.bucket('vtuber-335811.appspot.com');  // バケット名を設定
    // console.log("========================================");
    // console.log("== allvideos");
    // console.log("========================================");
    let allvideos = bucket.file('allvideos.json'); // ダウンロードするJSONファイルのパスに置き換え
    let ongoingVideos = [];
    // ファイルの存在確認
    await new Promise((resolve, reject) => {
      allvideos.exists((err, exists) => {
        if (err) {
          console.error('ファイルの存在確認中にエラーが発生しました:', err);
          reject(err);
          return;
        }
        if (!exists) {
          // console.log("== allvideosが存在しないため新規作成");
          allvideos = [];
          resolve();
        } else {
          // ファイルが存在する場合、ダウンロード
          // console.log("== allvideosがファイルが存在するためダウンロード");
          allvideos.download((err, contents) => {
            if (err) {
              console.error('ファイルのダウンロード中にエラーが発生しました:', err);
              reject(err);
              return;
            }
            const jsonStr = contents.toString();
            let jsonData;
            try {
              jsonData = JSON.parse(jsonStr);
            } catch (parseErr) {
              console.error('JSONのパース中にエラーが発生しました:', parseErr);
              reject(parseErr);
              return;
            }
            // console.log("  == -jsonData:", jsonData);
            allvideos = jsonData;
            ongoingVideos = allvideos.filter(video => {
              const scheduledStartTime = video.scheduledStartTime ? new Date(video.scheduledStartTime).getTime() : null;
              const actualStartTime = video.actualStartTime ? new Date(video.actualStartTime).getTime() : null;
              const actualEndTime = video.actualEndTime ? new Date(video.actualEndTime).getTime() : null;
              const currentTime = Date.now();

              // 配信が終了していない、または配信がまだ始まっていない条件
              return (scheduledStartTime !== null && scheduledStartTime < currentTime) ||  // 配信予定日が未来
                (actualStartTime === null || actualStartTime === "") ||  // 配信が開始してない
                (actualStartTime !== null && actualStartTime <= currentTime &&  // 配信が開始済み and 配信が終了していない
                  (actualEndTime === null || actualEndTime === "" || actualEndTime > currentTime));
              //actualEndTime === ""));
            });

            // console.log(`   == allvideos -> ongoingVideos抽出`);
            // console.log(`   == ongoingVideos:`,ongoingVideos);
            resolve();
          });
        }
      });
    });
    // console.log("  == allvideos:",allvideos);
    // console.log("========================================");
    // console.log("== weeklyLiveViewRanking");
    // console.log("========================================");
    let weeklyLiveViewRanking = bucket.file('weeklyLiveViewRanking.json'); // ダウンロードするJSONファイルのパスに置き換え

    // ファイルの存在確認
    await new Promise((resolve, reject) => {
      weeklyLiveViewRanking.exists((err, exists) => {
        if (err) {
          console.error('ファイルの存在確認中にエラーが発生しました:', err);
          reject(err);
          return;
        }
        if (!exists) {
          // console.log("== weeklyLiveViewRankingが存在しないため新規作成");
          weeklyLiveViewRanking = [];
          resolve();
        } else {
          // ファイルが存在する場合、ダウンロード
          // console.log("== weeklyLiveViewRankingがファイルが存在するためダウンロード");
          weeklyLiveViewRanking.download((err, contents) => {
            if (err) {
              console.error('ファイルのダウンロード中にエラーが発生しました:', err);
              reject(err);
              return;
            }
            const jsonStr = contents.toString();
            let jsonData;
            try {
              jsonData = JSON.parse(jsonStr);
            } catch (parseErr) {
              console.error('JSONのパース中にエラーが発生しました:', parseErr);
              reject(parseErr);
              return;
            }
            // console.log("  == -jsonData:", jsonData);
            weeklyLiveViewRanking = jsonData;
            resolve();
          });
        }
      });
    });
    // console.log("  == weeklyLiveViewRanking:",weeklyLiveViewRanking);

    // console.log("========================================");
    // console.log("== youtubeSubscriberCountTransitionダウンロード");
    // console.log("========================================");
    // グラフ描画用のファイルをダウンロード
    let youtubeSubscriberCountTransition = bucket.file('youtubeSubscriberCountTransitionList.json'); // ダウンロードするJSONファイルのパスに置き換え

    // ファイルの存在確認
    await new Promise((resolve, reject) => {
      youtubeSubscriberCountTransition.exists((err, exists) => {
        if (err) {
          console.error('ファイルの存在確認中にエラーが発生しました:', err);
          reject(err);
          return;
        }
        if (!exists) {
          // console.log("== youtubeSubscriberCountTransitionが存在しないため新規作成");
          resolve();
        } else {
          // ファイルが存在する場合、ダウンロード
          // console.log("== youtubeSubscriberCountTransitionがファイルが存在するためダウンロード");
          youtubeSubscriberCountTransition.download((err, contents) => {
            if (err) {
              console.error('ファイルのダウンロード中にエラーが発生しました:', err);
              reject(err);
              return;
            }
            const jsonStr = contents.toString();
            let jsonData;
            try {
              jsonData = JSON.parse(jsonStr);
            } catch (parseErr) {
              console.error('JSONのパース中にエラーが発生しました:', parseErr);
              reject(parseErr);
              return;
            }
            // console.log("  == -jsonData:", jsonData);
            youtubeSubscriberCountTransitionList = jsonData;
            resolve();
          });
        }
      });
    });
    // console.log("  == youtubeSubscriberCountTransitionList:",youtubeSubscriberCountTransitionList);

    // console.log("========================================");
    // console.log("== allChannelYoutubeApiInfoダウンロード");
    // console.log("========================================");
    let allChannelYoutubeApiInfo = bucket.file('allChannelYoutubeApiInfo.json'); // ダウンロードするJSONファイルのパスに置き換え
    // ファイルの存在確認
    await new Promise((resolve, reject) => {
      allChannelYoutubeApiInfo.exists((err, exists) => {
        if (err) {
          // console.error('ファイルの存在確認中にエラーが発生しました:', err);
          reject(err);
          return;
        }
        if (!exists) {
          // console.log("== allChannelYoutubeApiInfoが存在しないため新規作成");
          resolve();
        } else {
          // ファイルが存在する場合、ダウンロード
          // console.log("== allChannelYoutubeApiInfoがファイルが存在するためダウンロード");
          allChannelYoutubeApiInfo.download((err, contents) => {
            if (err) {
              console.error('ファイルのダウンロード中にエラーが発生しました:', err);
              reject(err);
              return;
            }
            const jsonStr = contents.toString();
            let jsonData;
            try {
              jsonData = JSON.parse(jsonStr);
            } catch (parseErr) {
              console.error('JSONのパース中にエラーが発生しました:', parseErr);
              reject(parseErr);
              return;
            }
            // console.log("  == -jsonData:", jsonData);
            allChannelYoutubeApiInfo = jsonData;
            resolve();
          });
        }
      });
    });
    // console.log("  == vtuberDict:",vtuberDict);
    let channelMap = {};
    let vtuberNum = 0;
    for (let [mapIndex, channel] of allChannelYoutubeApiInfo.entries()) {
      if (channel && channel.kind === "youtube#channel") {
        for (const member in vtuberDict) {
          if (member === "updateTime") {
            continue;
          }
          if (channel.id == vtuberDict[member]["channeID"]) {
            channelMap[channel.id] = {
              title: channel.snippet.title,
              thumbnail: channel.snippet.thumbnails.default.url,
              officeKey: vtuberDict[member]["office"],
              officeFlg: vtuberDict[member]["officeFlg"],
              birthday: vtuberDict[member]["birthday"] || "",
              debut: vtuberDict[member]["debut"] || ""
            };
          }
          if (vtuberDict[member]["officeFlg"]) {
            // console.log("vtuberDict[member][officeFlg]", vtuberDict[member]["officeFlg"]);
            const officeName = vtuberDict[member]["office"];
            if (!officeNameList.includes(officeName)) {
              officeNameList.push(officeName);
            }
          }
        }
      }
      if (allChannelYoutubeApiInfo.length - 1 == mapIndex) {
        // console.log("  == officeNameList:",officeNameList);
        // console.log("  == allChannelYoutubeApiInfo -> channelMap:",channelMap);

        let memberName = "";
        let ENTRY_LIST = [];

        // channel情報をアップデート
        for (const [index, channel_result] of allChannelYoutubeApiInfo.entries()) {
          let membar_channel_id = "";
          if (channel_result && channel_result.kind === "youtube#channel") {
            membar_channel_id = String(channel_result.id);
            for (const member in vtuberDict) {
              if (member === "updateTime") {
                continue;
              }
              if (membar_channel_id === vtuberDict[member]["channeID"]) {
                vtuberNum = member;
                memberName = vtuberDict[member]["twitterName"];
                break;  // 見つかったらループを抜ける
              }
            }

            // //===========================
            // // chatの作成
            // //===========================
            // const querySnapshot = await threadRef.where('name', '==', channel_result.snippet.title).get();

            // if (querySnapshot.empty) {
            //   // スレッドが存在しない場合、新規作成
            //   const newThread = {
            //     name: channel_result.snippet.title,
            //     office: mapOfficeString(vtuberDict[vtuberNum]["office"]),
            //     createdAt: admin.firestore.FieldValue.serverTimestamp(),
            //   };
            //   const docRef = await threadRef.add(newThread);
            //   console.log(`New thread created with ID: ${docRef.id}`);
            // }

            // console.log("  ========================================");
            // console.log("  == channel情報をアップデート");
            // console.log("  ========================================");
            // console.log("  == 基本情報と更新時間 -> " + channel_result.snippet.title);
            // console.log("  == channelThumbnail -> " + channel_result.snippet.thumbnails.high.url);
            // console.log("  == membar_channel_id -> " + membar_channel_id);


            let d_today_utc_youtube_update_time = new Date().toISOString().slice(0, 16).replace('T', ' ');
            let todaysSubscriberCount = channel_result["statistics"]["subscriberCount"]
            const newSubscriberData = {
              [todayStr]: todaysSubscriberCount
            };

            // チャンネルIDのデータが存在しない場合は新規作成
            // データの追加または更新
            const channelDataIndex = youtubeSubscriberCountTransitionList.findIndex(item => Object.keys(item)[0] === membar_channel_id);

            if (channelDataIndex === -1) {
              // 新しいデータを追加
              const youtubeSubscriberCountTransition = { [membar_channel_id]: [newSubscriberData] };
              youtubeSubscriberCountTransitionList.push(youtubeSubscriberCountTransition);
              // console.log("  == 新しいデータを追加しました");
            } else {
              // 既存のデータを更新
              const dataList = youtubeSubscriberCountTransitionList[channelDataIndex][membar_channel_id];
              // console.log("   == dataList:", dataList);

              // 新しい日付が配列に存在するかチェック
              const newDateKey = Object.keys(newSubscriberData)[0];
              const exists = dataList.some(data => newDateKey in data);

              // 存在しない場合、新しいデータを追加
              if (!exists) {
                dataList.push(newSubscriberData);
              }
              // 30日以上前のデータを削除
              const thirtyDaysAgo = new Date();
              thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
              // console.log(" thirtyDaysAgo:",thirtyDaysAgo);

              const isOlderThanThirtyDays = (dateStr) => {
                // targetDateをDateオブジェクトに変換
                const year = dateStr.substring(0, 4);
                const month = dateStr.substring(4, 6) - 1; // 月は0から始まるので-1する
                const day = dateStr.substring(6, 8);
                const date = new Date(year, month, day);
                // console.log(" dateKey->date:",date);
                return date < thirtyDaysAgo;
              };

              for (let i = dataList.length - 1; i >= 0; i--) {
                const dateKey = Object.keys(dataList[i])[0];
                // console.log(" dateKey:",dateKey);
                if (isOlderThanThirtyDays(dateKey)) {
                  dataList.splice(i, 1);
                  // console.log("  == 30日以上前のデータを削除しました");
                }
              }
              // console.log("  == 既存のデータを更新しました");
            }
            // console.log("  ========================================");
            // console.log("  == vtuber情報をアップデート");
            // console.log("  ========================================");
            // console.log("  == 対象のvtuber情報 -> " + memberName + "(Twitter Name)");
            // console.log("  == name -> " + channel_result.snippet.title);
            // console.log("    ========================================");
            // console.log("    == 動画情報を取得");
            // console.log("    ========================================");
            try {
              // Videoデータを45個づつ全て取得
              let RSS_URL = 'https://www.youtube.com/feeds/videos.xml?channel_id=' + membar_channel_id;
              let feed;
              try {
                feed = await parser.parseURL(RSS_URL);
                // ...通常処理...
              } catch (error) {
                if (error.message && error.message.includes('Status code 404')) {
                  console.warn(`RSS not found for channel: ${membar_channel_id}`);
                  continue; // このチャンネルはスキップ
                } else {
                  console.error("Failed to parse RSS URL:", error);
                }
              }
              for (const [entryIndex, entry] of feed.items.entries()) {
                // const videoId = entry.id.split(':').pop();
                // 最新のentryからallvideosを更新
                allvideos.forEach(video => {
                  if (video.videoID === entry['yt:videoId']) {
                    const mediaGroup = entry.mediaGroup ? entry.mediaGroup[0] : null;
                    if (mediaGroup) {
                      if (mediaGroup['media:thumbnail']) {
                        video.thumbnail = mediaGroup['media:thumbnail'][0].$.url;
                      }
                      if (mediaGroup['media:community']) {
                        const mediaCommunity = mediaGroup['media:community'][0];
                        if (mediaCommunity['media:statistics']) {
                          video.viewCount = mediaCommunity['media:statistics'][0].$.views;
                        }
                        if (mediaCommunity['media:starRating']) {
                          video.goodCount = mediaCommunity['media:starRating'][0].$.count;
                        }
                      }
                    }
                  }
                });
                if (entryIndex <= 1) {
                  // console.log(`   == 対象の動画情報 -> ${memberName}:${videoId}`);
                  // ========================================
                  // すでに配信が終了し、アップデート情報がない場合は追加しない
                  // ========================================
                  // updateが30日以内かどうかをチェック
                  //console.log(`    == entry[updated] ->:`,entry['updated']);
                  //console.log(`    == entry[published] ->:`,entry['published']);
                  const publishedDate = new Date(entry['published']);
                  const currentDate = new Date();
                  const timeDifference = currentDate - publishedDate;
                  //console.log(`    == timeDifference:`,timeDifference);
                  const daysDifference = timeDifference / (1000 * 3600 * 24);
                  //console.log(`    == daysDifference:`,daysDifference);
                  if (daysDifference <= 30) {
                    // allvideosに無い、新規のVideoであれば追加。
                    const matchingVideos = allvideos.filter(video => {
                      return video.videoID === entry['yt:videoId'];
                    });
                    if (matchingVideos.length == 0) {
                      ENTRY_LIST.push(entry);
                      // console.log(`     == newVideo追加 ->:`,entry['yt:videoId']);
                    } else {
                      // allvideosにあるが、終了していなかったVideoであれば追加。
                      let ongoingVideoExists = ongoingVideos.some(video => video.videoID === entry['yt:videoId']);
                      if (ongoingVideoExists) {
                        ENTRY_LIST.push(entry);
                        // console.log(`     == ongoingVideo追加 ->:`,entry['yt:videoId']);
                      }
                    }
                  }
                }
                if (ENTRY_LIST.length > 47 || (index === allChannelYoutubeApiInfo.length - 1 && ENTRY_LIST.length > 0)) {
                  try {
                    // console.log(`    == ${ENTRY_LIST.length}件entryがたまったのでyoutube.videos()実行`);
                    let membar_video_id_List_str = ENTRY_LIST.map(entry => entry['yt:videoId']).join(',');
                    let video_response_from_youtubeapi = await axios.get('https://www.googleapis.com/youtube/v3/videos', {
                      params: {
                        part: 'contentDetails,liveStreamingDetails',//'snippet,statistics,contentDetails,liveStreamingDetails',
                        id: membar_video_id_List_str.slice(0, -1),
                        key: apiKey,
                      },
                    });
                    for (const [videoindex, entry] of ENTRY_LIST.entries()) {
                      // console.log("      ========================================");
                      // console.log("      == vtuber情報 -> 動画情報をアップデート"     );
                      // console.log("      ========================================");
                      // console.log("      == 対象のchannel情報 -> " + entry['yt:channelId']);
                      // console.log("      == 対象の動画情報 -> " + entry['yt:videoId']);
                      // console.log("      == entry:",entry); 

                      const mediaGroup = entry.mediaGroup ? entry.mediaGroup[0] : null;
                      let mediaThumbnail = null;
                      let views = null;
                      let goodCount = null;

                      if (mediaGroup) {
                        if (mediaGroup['media:thumbnail']) {
                          mediaThumbnail = mediaGroup['media:thumbnail'][0].$.url;
                        }
                        if (mediaGroup['media:community']) {
                          const mediaCommunity = mediaGroup['media:community'][0];
                          if (mediaCommunity['media:statistics']) {
                            views = mediaCommunity['media:statistics'][0].$.views;
                          }
                          if (mediaCommunity['media:starRating']) {
                            goodCount = mediaCommunity['media:starRating'][0].$.count;
                          }
                        }
                      }
                      let dbRegistFlg = DB_REGISTERD_VIDEO_ID.includes(entry['yt:videoId']);
                      if (!dbRegistFlg) {
                        DB_REGISTERD_VIDEO_ID.push(entry['yt:videoId']);
                      }
                      let duration = "";
                      let scheduledStartTime = "";
                      let actualStartTime = "";
                      let actualEndTime = "";
                      let concurrentViewers = "";
                      let channelThumbnail = null;
                      let channelName = null;
                      let channelOfficeKey = null;
                      let media_thumbnail = mediaThumbnail;//"https://i1.ytimg.com/vi/" + entry['yt:videoId'] +"/hqdefault.jpg";
                      for (const video_response of video_response_from_youtubeapi.data.items) {
                        if (video_response.kind === "youtube#video" && video_response.id === entry['yt:videoId']) {
                          if (video_response.contentDetails && video_response.contentDetails.duration) {
                            duration = video_response.contentDetails.duration;
                          }
                          // console.log("      == video_response.liveStreamingDetails:",video_response.liveStreamingDetails);
                          if (video_response.liveStreamingDetails) {
                            if (video_response.liveStreamingDetails.scheduledStartTime) {
                              scheduledStartTime = video_response.liveStreamingDetails.scheduledStartTime;
                            }
                            if (video_response.liveStreamingDetails.actualStartTime) {
                              actualStartTime = video_response.liveStreamingDetails.actualStartTime;
                            }
                            if (video_response.liveStreamingDetails.actualEndTime) {
                              actualEndTime = video_response.liveStreamingDetails.actualEndTime;
                            }
                            if (video_response.liveStreamingDetails.concurrentViewers) {
                              concurrentViewers = video_response.liveStreamingDetails.concurrentViewers;
                            }
                          }
                        }
                      }
                      // チャンネルのサムネイルと名前を取得
                      let channelData = channelMap[entry['yt:channelId']];
                      channelName = channelData.title;
                      channelThumbnail = channelData.thumbnail;
                      channelOfficeKey = channelData.officeKey;
                      // 比較用のDateオブジェクトを作成
                      const publishedAtDate = new Date(entry["pubDate"]);
                      const scheduledStartTimeDate = scheduledStartTime ? new Date(scheduledStartTime) : null;
                      const comparisonDay = scheduledStartTimeDate && scheduledStartTimeDate > publishedAtDate
                        ? scheduledStartTime
                        : entry["pubDate"];
                      // console.log("      == scheduledStartTimeDate:",scheduledStartTimeDate);
                      // console.log("      == publishedAtDate:",publishedAtDate);
                      // console.log("      == scheduledStartTime:",scheduledStartTime);
                      // console.log("      == entry[pubDate]:",entry["pubDate"]);
                      // console.log("      == comparisonDay:",comparisonDay);

                      const vtuberVideoValueAdd = Object.assign({}, {
                        [entry['yt:videoId']]: {
                          office: await mapOfficeStringSafeAsync(channelOfficeKey),
                          officeKey: channelOfficeKey,
                          videoID: entry['yt:videoId'],
                          channelTitle: channelName,
                          channelId: entry['yt:channelId'],
                          channelThumbnail: channelThumbnail,
                          title: entry.title,
                          thumbnail: media_thumbnail,
                          viewCount: views,
                          goodCount: goodCount,
                          comparisonDay: comparisonDay,
                          publishedAt: entry["pubDate"],
                          duration: duration,
                          scheduledStartTime: scheduledStartTime,
                          actualStartTime: actualStartTime,
                          actualEndTime: actualEndTime,
                          concurrent_viewers: concurrentViewers,
                        }
                      });
                      const vtuberVideobjOValueAdd = Object.assign({}, {
                        office: await mapOfficeStringSafeAsync(channelOfficeKey),
                        officeKey: channelOfficeKey,
                        videoID: entry['yt:videoId'],
                        channelTitle: channelName,
                        channelId: entry['yt:channelId'],
                        channelThumbnail: channelThumbnail,
                        title: entry.title,
                        thumbnail: media_thumbnail,
                        viewCount: views,
                        goodCount: goodCount,
                        comparisonDay: comparisonDay,
                        publishedAt: entry["pubDate"],
                        duration: duration,
                        scheduledStartTime: scheduledStartTime,
                        actualStartTime: actualStartTime,
                        actualEndTime: actualEndTime,
                        concurrent_viewers: concurrentViewers,

                      });
                      vtuberVideoDataObj.push(vtuberVideobjOValueAdd);
                      vtuberVideoData.push(vtuberVideoValueAdd);
                      // console.log("      == membar_channel_id:", membar_channel_id);

                    }
                  } catch (error) {
                    console.error("Error processing YouTube entries:", error);
                  }
                  ENTRY_LIST = [];
                }

              }
            } catch (error) {
              console.error("Failed to parse RSS URL:", error);
            }
            // allYoutubeDataに格納
            const youtubeValueAdd = Object.assign({}, {
              [membar_channel_id]: {
                channeID: membar_channel_id,
                name: channel_result.snippet.title,
                office: channelMap[membar_channel_id].officeKey,
                officeFlg: channelMap[membar_channel_id].officeFlg,
                birthday: channelMap[membar_channel_id].birthday,
                debut: channelMap[membar_channel_id].debut,
                officeName: await mapOfficeStringSafeAsync(channelMap[membar_channel_id].officeKey),
                youtubeChId: membar_channel_id,
                updateTime: d_today_utc_youtube_update_time,
                channelThumbnail: channel_result.snippet.thumbnails.high.url,
                title: channel_result.snippet.title,
                viewCount: channel_result.statistics.viewCount,
                videoCount: channel_result.statistics.videoCount,
                subscriberCount: channel_result.statistics.subscriberCount,
                createdAt: channel_result.snippet.publishedAt,
                twicasID: "",
                twitterID: "",
                twitterSubscriberCountTransition: {},
                youtubeSubscriberCountTransition: {},
                videos: {},
                twitterName: memberName,
                // 追加: YouTube APIキャッシュからdescription, thumbnailUrl, name
                thumbnailUrl: channel_result.snippet.thumbnails.high.url,
                description: channel_result.snippet.description || "",
                displayName: channel_result.snippet.title,
              }
            });
            const _youtubeValueAdd = Object.assign({}, {
              channeID: membar_channel_id,
              name: channel_result.snippet.title,
              office: await mapOfficeStringSafeAsync(channelMap[membar_channel_id].officeKey), // 正しいoffice名をセット
              officeKey: channelMap[membar_channel_id].officeKey,
              officeFlg: channelMap[membar_channel_id].officeFlg,
              officeName: await mapOfficeStringSafeAsync(channelMap[membar_channel_id].officeKey),
              birthday: channelMap[membar_channel_id].birthday,
              debut: channelMap[membar_channel_id].debut,
              youtubeChId: membar_channel_id,
              updateTime: d_today_utc_youtube_update_time,
              channelThumbnail: channel_result.snippet.thumbnails.high.url,
              title: channel_result.snippet.title,
              viewCount: channel_result.statistics.viewCount,
              videoCount: channel_result.statistics.videoCount,
              subscriberCount: channel_result.statistics.subscriberCount,
              createdAt: channel_result.snippet.publishedAt,
              twicasID: "",
              twitterID: "",
              twitterSubscriberCountTransition: {},
              youtubeSubscriberCountTransition: {},
              videos: {},
              twitterName: memberName,
            });
            allYoutubeDataObj.push(_youtubeValueAdd);
            allYoutubeData.push(youtubeValueAdd);

            // rankingYoutubeRegiDataに格納
            const rankingYoutubeRegi = Object.assign({}, {
              channelId: membar_channel_id,
              channelThumbnail: channel_result.snippet.thumbnails.high.url,
              name: channel_result.snippet.title,
              office: await mapOfficeStringSafeAsync(channelMap[membar_channel_id].officeKey),
              youtubeSubscriberCount: channel_result.statistics.subscriberCount

            });
            rankingYoutubeRegiData.push(rankingYoutubeRegi);
            // rankingVideoCountDataに格納
            const rankingVideoCount = Object.assign({}, {
              channelId: membar_channel_id,
              channelThumbnail: channel_result.snippet.thumbnails.high.url,
              name: channel_result.snippet.title,
              office: await mapOfficeStringSafeAsync(channelMap[membar_channel_id].officeKey),
              videoCount: channel_result.statistics.videoCount

            });
            rankingVideoCountData.push(rankingVideoCount);


            // eventの抽出
            const date = new Date(channelMap[membar_channel_id].debut);
            // 月日の文字列を作成 (例: "12/15")
            const formattedDate = `${date.getMonth() + 1}/${date.getDate()}`;
            // eventList にデータを追加
            if (!eventList[formattedDate]) {
              eventList[formattedDate] = [];
            }
            const _eventList = Object.assign({}, {
              eventType: "createAt",
              channelId: membar_channel_id,
              channelThumbnail: channel_result.snippet.thumbnails.high.url,
              name: channel_result.snippet.title,
              office: await mapOfficeStringSafeAsync(channelMap[membar_channel_id].officeKey),
              createdAt: channelMap[membar_channel_id].debut,
            });
            eventList[formattedDate].push(_eventList);

            // 誕生日の抽出
            const Bdate = new Date(channelMap[membar_channel_id].birthday);
            // 月日の文字列を作成 (例: "12/15")
            const formattedBDate = `${Bdate.getMonth() + 1}/${Bdate.getDate()}`;
            // eventList にデータを追加
            if (!eventList[formattedBDate]) {
              eventList[formattedBDate] = [];
            }
            const _eventBList = Object.assign({}, {
              eventType: "birthday",
              channelId: membar_channel_id,
              channelThumbnail: channel_result.snippet.thumbnails.high.url,
              name: channel_result.snippet.title,
              office: await mapOfficeStringSafeAsync(channelMap[membar_channel_id].officeKey),
              birthday: channelMap[membar_channel_id].birthday,
            });
            eventList[formattedBDate].push(_eventBList);
          }
          // 変換関数( List -> Obj)
          function convertTransitionArrayToObject(transitionArray) {
            const result = {};
            transitionArray.forEach(item => {
              const key = Object.keys(item)[0];
              result[key] = item[key];
            });
            return result;
          }
          // 最後のループに入ったら、ファイルを作成
          if (allChannelYoutubeApiInfo.length - 1 == index) {
            // console.log("    ========================================");
            // console.log("    == 全ての処理が終わったので、データ成形");
            // console.log("    ========================================");
            // console.log('== 最後のループに入ったら、ファイルを作成');

            // Live中データの作成
            const liveVideos = vtuberVideoDataObj.filter(video => {
              if (video) {
                // const actualStartTime = video.actualStartTime ? new Date(video.actualStartTime).getTime() : null;
                // // 空文字列を null に変換
                // const actualEndTime = video.actualEndTime ? new Date(video.actualEndTime).getTime() : null;
                // const currentTime = Date.now();
                // return actualStartTime !== null && actualStartTime <= currentTime &&
                //   (actualEndTime === null || actualEndTime === 0 || actualEndTime > currentTime);
                // concurrentViewers の有無でライブ中かを判定
                return video.concurrent_viewers !== undefined && video.concurrent_viewers !== null && video.concurrent_viewers !== "";

              }
              return false;
            });
            // 同時視聴者数順にソート
            liveVideos.sort((a, b) => {
              const viewersA = a.concurrent_viewers ? parseInt(a.concurrent_viewers, 10) : 0;
              const viewersB = b.concurrent_viewers ? parseInt(b.concurrent_viewers, 10) : 0;
              return viewersB - viewersA; // 降順でソート
            });
            // console.log("liveVideos:",liveVideos);
            // allvideosとvtuberVideoData/vtuberVideoDataObj をマージ
            for (const oldVideoData of allvideos) {
              let videoExists = vtuberVideoDataObj.some(video => video.videoID === oldVideoData.videoID);
              if (!videoExists) {
                // console.log('== videoExists、古いVideoData追加');
                vtuberVideoDataObj.push(oldVideoData)
                // console.log('== videoExists、古いVideoData追加 -> ',oldVideoData['videoID']);
                const _vtuberVideoValueAdd = Object.assign({}, {
                  [oldVideoData['videoID']]: {
                    office: oldVideoData['office'],
                    officeKey: oldVideoData['officeKey'],
                    videoID: oldVideoData['videoID'],
                    channelTitle: oldVideoData['channelTitle'],
                    channelId: oldVideoData['channelId'],
                    channelThumbnail: oldVideoData['channelThumbnail'],
                    title: oldVideoData['title'],
                    thumbnail: oldVideoData['thumbnail'],
                    viewCount: oldVideoData['viewCount'],
                    comparisonDay: oldVideoData['comparisonDay'],
                    publishedAt: oldVideoData['publishedAt'],
                    duration: oldVideoData['duration'],
                    scheduledStartTime: oldVideoData['scheduledStartTime'],
                    actualStartTime: oldVideoData['actualStartTime'],
                    actualEndTime: oldVideoData['actualEndTime'],
                    concurrent_viewers: oldVideoData['concurrent_viewers'],
                  }
                });
                vtuberVideoData.push(_vtuberVideoValueAdd);
              }
            }

            // 最後にcomparisonDay順にソート
            vtuberVideoDataObj.sort((a, b) => new Date(a.comparisonDay) - new Date(b.comparisonDay));
            vtuberVideoData.sort((a, b) => {
              const dateA = new Date(Object.values(a)[0].comparisonDay);
              const dateB = new Date(Object.values(b)[0].comparisonDay);
              return dateA - dateB;
            });

            //console.log('youtubeSubscriberCountTransitionList:',youtubeSubscriberCountTransitionList);
            const transitionListObj = youtubeSubscriberCountTransitionList.reduce((acc, item) => {
              const key = Object.keys(item)[0];
              acc[key] = item[key];
              return acc;
            }, {});
            // console.log('transitionListObj', transitionListObj);

            // チャネルIDごとにVideoDataを抽出して追加
            for (const youtubeData of allYoutubeData) {
              const channelId = Object.keys(youtubeData)[0];

              // filteredDataを取得
              const filteredData = vtuberVideoData.filter(video => {
                const videoKey = Object.keys(video)[0];
                return video[videoKey].channelId === channelId;
              });

              // filteredDataをpublishedAtでソート
              filteredData.sort((a, b) => {
                const dateA = new Date(Object.values(a)[0].comparisonDay);
                const dateB = new Date(Object.values(b)[0].comparisonDay);
                return dateA - dateB;
              });
              // 30件を超えた分を古い順に削除
              while (filteredData.length > 30) {
                const oldestVideo = filteredData.shift(); // 最も古い動画を削除
                const oldestVideoKey = Object.keys(oldestVideo)[0];

                // vtuberVideoDataからも削除
                const indexInOriginalArray = vtuberVideoData.findIndex(video => {
                  const videoKey = Object.keys(video)[0];
                  return videoKey === oldestVideoKey;
                });

                if (indexInOriginalArray !== -1) {
                  vtuberVideoData.splice(indexInOriginalArray, 1); // 大元の配列から削除
                }
              }

              // videosプロパティとして追加
              youtubeData[channelId]["videos"] = convertTransitionArrayToObject(filteredData);

              // チャネルIDごとにyoutubeSubscriberCountTransitionListを抽出して追加
              const membar_channel_id = Object.keys(youtubeData)[0];
              if (transitionListObj[membar_channel_id]) {
                youtubeData[membar_channel_id]["youtubeSubscriberCountTransition"] = convertTransitionArrayToObject(transitionListObj[membar_channel_id]);
              }
              for (const youtubeDataObj of allYoutubeDataObj) {
                // console.log(' == youtubeDataObj');
                // console.log(' == youtubeDataObj -> ',membar_channel_id);
                // console.log(' == youtubeDataObj["channeID"]',youtubeDataObj["channeID"]);
                if (youtubeDataObj["channeID"] == membar_channel_id) {
                  youtubeDataObj["videos"] = convertTransitionArrayToObject(filteredData);
                  youtubeDataObj["youtubeSubscriberCountTransition"] = convertTransitionArrayToObject(transitionListObj[membar_channel_id]);
                  // console.log(' == youtubeDataObj videos-> ',youtubeDataObj["videos"]);
                }
              }
            }
            // console.log('allYoutubeData:',allYoutubeData);
            // weeklyLiveViewRankingを最新のliveVideosをもとに更新
            for (const newData of liveVideos) {
              // concurrent_viewers が空、null、または undefined の場合はスキップ
              if (!newData.concurrent_viewers || isNaN(parseInt(newData.concurrent_viewers))) {
                continue; // 次のループへ
              }
              let found = false;
              for (let video of weeklyLiveViewRanking) {
                if (video.videoID === newData.videoID) {
                  found = true;
                  if (parseInt(newData.concurrent_viewers) > parseInt(video.concurrent_viewers)) {
                    video.office = newData.office;
                    video.officeKey = newData.officeKey;
                    video.channelTitle = newData.channelTitle;
                    video.channelId = newData.channelId;
                    video.channelThumbnail = newData.channelThumbnail;
                    video.title = newData.title;
                    video.thumbnail = newData.thumbnail;
                    video.viewCount = newData.viewCount;
                    video.comparisonDay = newData.comparisonDay;
                    video.publishedAt = newData.publishedAt;
                    video.duration = newData.duration;
                    video.scheduledStartTime = newData.scheduledStartTime;
                    video.actualStartTime = newData.actualStartTime;
                    video.actualEndTime = newData.actualEndTime;
                    video.concurrent_viewers = newData.concurrent_viewers;
                  }
                  break;
                }
              }
              if (!found) {
                weeklyLiveViewRanking.push(newData);
              }
            }
            // 1週間前の日時を取得
            const oneWeekAgo = new Date();
            oneWeekAgo.setDate(oneWeekAgo.getDate() - 6);

            // 1週間前以上の動画を削除し、concurrent_viewersが空文字列ではないものだけを残す
            weeklyLiveViewRanking = weeklyLiveViewRanking.filter(video => {
              return new Date(video.publishedAt) > oneWeekAgo && video.concurrent_viewers !== "";
            });

            // 同時視聴者数順にソート
            weeklyLiveViewRanking.sort((a, b) => parseInt(b.concurrent_viewers) - parseInt(a.concurrent_viewers));

            //console.log("weeklyLiveViewRanking:",weeklyLiveViewRanking);

            // rankingYoutubeRegiData を youtubeSubscriberCount の多い順に並べ替える
            rankingYoutubeRegiData.sort((a, b) => {
              return b.youtubeSubscriberCount - a.youtubeSubscriberCount;
            });
            // rankingVideoCountData を videoCount の多い順に並べ替える
            rankingVideoCountData.sort((a, b) => {
              return b.videoCount - a.videoCount;
            });

            // officeDataList作成
            // console.log("    == officeDataList作成");
            for (const channelData of allYoutubeDataObj) {
              // office名が空文字やnullの場合は'other'に置き換え
              let officeKey = await mapOfficeStringSafeAsync(channelData["office"]);
              if (!officeKey || officeKey.trim() === "") {
                officeKey = "other";
                channelData["office"] = "other";
              }
              if (officeDataList[officeKey]) {
                officeDataList[officeKey].push(channelData);
              } else {
                officeDataList[officeKey] = [channelData];
              }
            }
            const customSort = (a, b) => {
              // officeFlg が true のものを先頭に
              if (a.officeFlg && !b.officeFlg) {
                return -1;
              } else if (!a.officeFlg && b.officeFlg) {
                return 1;
              }
              // それ以外は createdAt 順にソート
              return new Date(a.createdAt) - new Date(b.createdAt);
            };
            // オブジェクト内の各配列をソート
            for (const office in officeDataList) {
              officeDataList[office].sort(customSort);
              //===========================
              // chatの作成
              //===========================
              const querySnapshot = await threadRef.where('name', '==', office).get();

              if (querySnapshot.empty) {
                // スレッドが存在しない場合、新規作成
                const newThread = {
                  name: await mapOfficeStringSafeAsync(office),
                  office: office,
                  createdAt: admin.firestore.FieldValue.serverTimestamp(),
                };
                const docRef = await threadRef.add(newThread);
                console.log(`New thread created with ID: ${docRef.id}`);
              }
            }
            // 各 office ごとに youtubeSubscriberCountTransition の合計を計算
            const officeTotals = {};
            for (const office in officeDataList) {
              const total = officeDataList[office].reduce((sum, vtuber) => sum + vtuber.viewCount, 0);
              officeTotals[office] = total;
            }
            // officeTotals を降順にソート
            const sortedOffices = Object.keys(officeTotals).sort((a, b) => {
              if (a === "個人") return 1;
              if (b === "個人") return -1;
              return officeTotals[b] - officeTotals[a];
            });

            // ソートされた順に officeList を再構築
            const sortedOfficeList = {};
            for (const office of sortedOffices) {
              sortedOfficeList[office] = officeDataList[office];
            }

            // console.log("    == sortedOfficeList:",sortedOfficeList);

            // console.log("    ========================================");
            // console.log("    == 全てのデータ成形が終わったので、データをアップロード");
            // console.log("    ========================================");

            // console.log("ファイルアップロード START");
            // ===========================
            // allYoutubeDataのファイルアップデート・allVtuberのファイルアップデート
            // ===========================
            //const BATCH_SIZE = 1000;  // 一度に処理するデータの数を設定
            const appendToFile = async (data, bucket, baseFileName) => {
              const fileName = `${baseFileName}.json`;
              // console.log("    == " + baseFileName+"ファイルアップロード");
              const file = bucket.file(fileName);
              const fileStream = file.createWriteStream({
                metadata: {
                  contentType: 'application/json'
                },
                resumable: false,  // 追記するために必要
                timeout: 540000,  // タイムアウトを調整（ミリ秒単位）
              });

              fileStream.on('finish', () => {
                // console.log(`${fileName}: データの追記が完了しました:`,data.length);
              });

              fileStream.on('error', (error) => {
                // console.error(`${fileName}: データの追記中にエラーが発生しました:`, error);
                throw error;  // エラー発生時に終了
              });

              // データ全体を一つのJSON配列にまとめる
              const jsonArray = JSON.stringify(data, null, 2);
              // 配列全体を書き込む
              fileStream.write(jsonArray);
              fileStream.end();

              await new Promise((resolve, reject) => {
                fileStream.on('finish', resolve);
                fileStream.on('error', reject);
              });
            };

            try {
              //　liveVideoListのファイルアップロード
              await appendToFile(liveVideos, bucket, 'livevideoList');
              // console.log('    == liveVideoListのデータの追記が完了しました');
            } catch (error) {
              console.error('    == liveVideoListのデータの追記中にエラーが発生しました:', error);
            }

            try {
              // allYoutubeDataのファイルアップロード
              await appendToFile(allYoutubeData, bucket, 'allYoutubeData');
              // console.log('    == allYoutubeDataのデータの追記が完了しました');
            } catch (error) {
              console.error('    == allYoutubeDataのデータの追記中にエラーが発生しました:', error);
            }

            try {
              // allVtuberDataのファイルアップロード
              vtuberVideoDataObj.sort((a, b) => {
                const dateA = new Date(a.comparisonDay);
                const dateB = new Date(b.comparisonDay);

                // 日付の新しい順にソート
                return dateB - dateA;
              });
              const thirtyDaysAgo = new Date();
              thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
              const allvideos = vtuberVideoDataObj.filter(video => new Date(video.comparisonDay) > thirtyDaysAgo);

              // allVtuberDataのファイルアップロード
              allvideos.sort((a, b) => {
                const dateA = new Date(a.comparisonDay);
                const dateB = new Date(b.comparisonDay);

                // 日付の新しい順にソート
                return dateB - dateA;
              });
              // 30日前より新しいデータだけを抽出
              await appendToFile(allvideos, bucket, 'allvideos');
              // console.log('    == allvideosのデータの追記が完了しました');
            } catch (error) {
              console.error('    == allvideosのデータの追記中にエラーが発生しました:', error);
            }

            try {
              await appendToFile(youtubeSubscriberCountTransitionList, bucket, 'youtubeSubscriberCountTransitionList');
              // console.log('    == youtubeSubscriberCountTransitionListのデータの追記が完了しました');
            } catch (error) {
              console.error('    == youtubeSubscriberCountTransitionListのデータの追記中にエラーが発生しました:', error);
            }

            try {
              //　weeklyLiveViewRankingのファイルアップロード
              await appendToFile(weeklyLiveViewRanking, bucket, 'weeklyLiveViewRanking');
              // console.log('    == weeklyLiveViewRankingデータの追記が完了しました');
            } catch (error) {
              console.error('    == weeklyLiveViewRankingのデータの追記中にエラーが発生しました:', error);
            }

            try {
              //　rankingYoutubeRegiDataのファイルアップロード
              await appendToFile(rankingYoutubeRegiData, bucket, 'rankingYoutubeRegiData');
              // console.log('    == rankingYoutubeRegiDataのデータの追記が完了しました');
            } catch (error) {
              console.error('    == rankingYoutubeRegiDataのデータの追記中にエラーが発生しました:', error);
            }

            try {
              //　rankingVideoCountDataのファイルアップロード
              await appendToFile(rankingVideoCountData, bucket, 'rankingVideoCountData');
              // console.log('    == rankingVideoCountDataのデータの追記が完了しました');
            } catch (error) {
              console.error('    == rankingVideoCountDataのデータの追記中にエラーが発生しました:', error);
            }

            try {
              let eventArray = [];
              eventArray.push(eventList);
              await appendToFile(eventArray, bucket, 'eventList');
              // console.log('    == eventListのデータの追記が完了しました');
            } catch (error) {
              console.error('    == eventListのデータの追記中にエラーが発生しました:', error);
            }

            try {
              // officeDataListのファイルアップロード
              // 常にoffice名ごとのオブジェクト形式で保存
              await appendToFile(sortedOfficeList, bucket, 'officedataList');
              // console.log('    == officeDataListのデータの追記が完了しました');
            } catch (error) {
              console.error('    == officeDataListのデータの追記中にエラーが発生しました:', error);
            }
            // console.log("ファイルアップロード END");
          }
        };
      }
    }
  }
  );

// 事務所追加API
exports.addOffice = functions.https.onRequest(async (req, res) => {
  // CORSヘッダーを常にセット
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');
  res.set('Access-Control-Max-Age', '3600');
  if (req.method === 'OPTIONS') {
    // プリフライトリクエストにはヘッダーのみ返す
    return res.status(204).send('');
  }
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }
  try {
    const { officeKey, officeName } = req.body;
    if (!officeKey || !officeName) {
      return res.status(400).json({ error: 'officeKey and officeName are required' });
    }
    // office.json（配列）に追加
    const officeRef = db.ref('office');
    const snapshot = await officeRef.once('value');
    let arr = [];
    if (Array.isArray(snapshot.val())) {
      arr = snapshot.val();
    } else if (typeof snapshot.val() === 'object' && snapshot.val() !== null) {
      arr = Object.values(snapshot.val()).filter(v => typeof v === 'string');
    }
    if (!arr.includes(officeKey)) {
      arr.push(officeKey);
      await officeRef.set(arr);
    }
    // officeMapping.json（object）に追加
    const mappingRef = db.ref('officeMapping');
    await mappingRef.update({ [officeKey]: officeName });
    res.status(200).json({ success: true });
  } catch (err) {
    console.error('addOffice error:', err);
    res.status(500).json({ error: 'Failed to add office' });
  }
});
// ================================================  
//  RSSからNewsデータ作成
//  scheduled every 1 hours
//  memory: '256MB'
//  timeoutSeconds: 540
// ================================================
// RSSフィードのURLを配列で指定


// // 定期的なニュース取得
// exports.scheduledNewsUpdate = functions.pubsub
//   .schedule('every 1 hours') // 1時間ごとに実行
//   .timeZone('Asia/Tokyo') // タイムゾーンを設定
//   .onRun(async (context) => {
//     console.log('[scheduledNewsUpdate] start');
//     const rssFeeds = [
//       'https://news.google.com/rss/search?q=VTuber+OR+%E3%83%9B%E3%83%AD%E3%83%A9%E3%82%A4%E3%83%96+OR+%E3%81%AB%E3%81%98%E3%81%95%E3%82%93%E3%81%98&hl=ja&gl=JP&ceid=JP:ja'
//     ];
//     let allArticles = [];
//     try {
//       console.log('[scheduledNewsUpdate] fetchFeed start', rssFeeds);
//       const fetchFeedPromises = rssFeeds.map(feedUrl => fetchFeed(feedUrl, allArticles));
//       await Promise.all(fetchFeedPromises);
//       console.log('[scheduledNewsUpdate] fetchFeed done, articles:', allArticles.length);
//       allArticles.forEach((a, i) => {
//         if (i < 3) console.log(`[scheduledNewsUpdate] sample article[${i}]:`, a.title, a.publishedAt);
//       });
//       allArticles.sort((a, b) => new Date(b.publishedAt) - new Date(a.publishedAt));

//       // ★★ ここから videoUrlMap.json 参照による videoUrl 付与処理 ★★
//       let videoUrlMap = {};
//       try {
//         const videoUrlMapFile = storage.bucket('vtuber-335811.appspot.com').file('videoUrlMap.json');
//         const [contents] = await videoUrlMapFile.download();
//         videoUrlMap = JSON.parse(contents.toString());
//         console.log('[scheduledNewsUpdate] videoUrlMap.json loaded:', Object.keys(videoUrlMap).length);
//       } catch (err) {
//         console.log('[scheduledNewsUpdate] videoUrlMap.json not found or empty, skip merge');
//         videoUrlMap = {};
//       }

//       // 記事URLが一致するものにvideoUrlを付与
//       allArticles.forEach(article => {
//         if (videoUrlMap[article.url]) {
//           article.videoUrl = videoUrlMap[article.url];
//         }
//       });
//       // ★★ ここまで videoUrlMap.json 参照による videoUrl 付与処理 ★★

//       // ファイルデータをメモリ内に書き込む
//       const bucket = storage.bucket('vtuber-335811.appspot.com');
//       const fileName = 'news.json';
//       const file = bucket.file(fileName);
//       const fileStream = file.createWriteStream({
//         metadata: {
//           contentType: 'application/json'
//         },
//         timeout: 5400000,
//       });
//       await new Promise((resolve, reject) => {
//         const fileContents = JSON.stringify(allArticles);
//         fileStream.on('finish', () => {
//           console.log('[scheduledNewsUpdate] news.json upload finish');
//           resolve();
//         });
//         fileStream.on('error', (err) => {
//           console.error('[scheduledNewsUpdate][upload ERROR]', err);
//           reject(err);
//         });
//         fileStream.end(fileContents);
//       });
//     } catch (error) {
//       console.error('[scheduledNewsUpdate][ERROR]', error);
//     }
//     console.log('[scheduledNewsUpdate] end');
//   });
const openai = new OpenAI({ apiKey: functions.config().openai.key });
exports.scheduledNewsUpdate = functions
  .runWith({ timeoutSeconds: 300, memory: '1GB' })
  .pubsub
  .schedule('30 6,8,11,12,14,17,20,23 * * *') // ← 指定時刻で毎日実行
  .timeZone('Asia/Tokyo')
  .onRun(async (context) => {
    console.log('[scheduledNewsUpdate][SerpApi] start');
    const serpApiUrl = 'https://serpapi.com/search.json?engine=google_news&q=Vtuber+OR+ホロライブ+OR+にじさんじ&hl=ja&gl=jp&api_key=a3a91148d53c22e83d8fdf3023684b952c802d9a669b40e4b44f4c2885824865';
    let allArticles = [];
    try {
      // SerpApiからニュース取得
      const serpRes = await axios.get(serpApiUrl);
      const newsResults = serpRes.data.news_results || [];
      console.log(`[scheduledNewsUpdate][SerpApi] news_results: ${newsResults.length}`);
      allArticles = newsResults.map(item => ({
        channel: (item.source && typeof item.source === 'object' ? item.source.name : item.source) || '',
        title: item.title,
        publishedAt: formatDateSerpApi(item.date || item.date_published || ''),
        description: item.snippet || '',
        url: item.link,
        creator: item.author || '',
        urlToImage: item.thumbnail_small || '',
        sourceName: '',
        // sourceName: item.source || '',
        sourceUrl: item.link || '',
      }));
      allArticles.forEach((a, i) => {
        if (i < 3) console.log(`[scheduledNewsUpdate][SerpApi] sample article[${i}]:`, a.title, a.publishedAt);
      });
      allArticles.sort((a, b) => new Date(b.publishedAt) - new Date(a.publishedAt));

      // ★★ videoUrlMap.json 参照による videoUrl 付与処理 ★★
      let videoUrlMap = {};
      try {
        const videoUrlMapFile = storage.bucket('vtuber-335811.appspot.com').file('videoUrlMap.json');
        const [contents] = await videoUrlMapFile.download();
        videoUrlMap = JSON.parse(contents.toString());
        console.log('[scheduledNewsUpdate][SerpApi] videoUrlMap.json loaded:', Object.keys(videoUrlMap).length);
      } catch (err) {
        console.log('[scheduledNewsUpdate][SerpApi] videoUrlMap.json not found or empty, skip merge');
        videoUrlMap = {};
      }
      allArticles.forEach(article => {
        if (videoUrlMap[article.url]) {
          article.videoUrl = videoUrlMap[article.url];
        }
      });
      // ★★ ここまで videoUrlMap.json 参照による videoUrl 付与処理 ★★

      // === タイトル重複除去（videoUrl優先） ===
      // 1. タイトル完全一致でグループ化
      console.log('[scheduledNewsUpdate][SerpApi] タイトル完全一致でグループ化');
      const grouped = {};
      for (const article of allArticles) {
        const key = article.title.trim();
        if (!grouped[key]) grouped[key] = [];
        grouped[key].push(article);
      }
      // 2. videoUrl付き優先で1件だけ残す
      console.log('[scheduledNewsUpdate][SerpApi] videoUrl付き優先で1件だけ残す');
      let dedupedArticles = [];
      for (const key in grouped) {
        const group = grouped[key];
        const withVideo = group.filter(a => a.videoUrl);
        if (withVideo.length > 0) {
          dedupedArticles.push(withVideo[0]);
        } else {
          dedupedArticles.push(group[0]);
        }
      }

      // === タイトルが微妙に違うもの同士の重複をOpenAIで判定 ===
      // 3. AIで「同じニュースか？」を判定し、同じなら1つだけ残す
      console.log('[scheduledNewsUpdate][SerpApi] AIで「同じニュースか？」を判定し、同じなら1つだけ残す');
      async function isSameNews(titleA, titleB) {
        if (titleA === titleB) return true;
        const prompt = `次の2つのニュースタイトルは内容的に同じニュースですか？違う場合は「NO」、同じ場合は「YES」とだけ返答してください。\n\nA: ${titleA}\nB: ${titleB}`;
        const completion = await openai.chat.completions.create({
          model: 'gpt-3.5-turbo',
          messages: [{ role: 'user', content: prompt }],
          max_tokens: 3,
          temperature: 0,
        });
        return completion.choices[0].message.content.trim().toUpperCase() === 'YES';
      }

      // 4. 2重ループで比較し、同じと判定されたものは1つだけ残す
      const finalArticles = [];
      console.log('[scheduledNewsUpdate][SerpApi] 2重ループで比較し、同じと判定されたものは1つだけ残す');
      for (let i = 0; i < dedupedArticles.length; i++) {
        if (i % 10 === 0) console.log(`[scheduledNewsUpdate][SerpApi] dedup loop i=${i}/${dedupedArticles.length}`);
        // if (dedupedArticles.length > 20) break;
        let isDuplicate = false;
        for (let j = 0; j < finalArticles.length; j++) {
          // OpenAI APIコスト削減のため、タイトル長が短い・記号だけ違う場合はスキップ
          if (dedupedArticles[i].title === finalArticles[j].title) {
            isDuplicate = true;
            break;
          }
          // // 類似判定（必要な場合のみ呼ぶ）
          // if (await isSameNews(dedupedArticles[i].title, finalArticles[j].title)) {
          //   isDuplicate = true;
          //   break;
          // }
        }
        if (!isDuplicate) finalArticles.push(dedupedArticles[i]);
      }

      console.log('[scheduledNewsUpdate][SerpApi] finalArticles', finalArticles.length);
      // === ファイル書き込み ===
      console.log('[scheduledNewsUpdate][SerpApi] ファイル書き込み');
      const bucket = storage.bucket('vtuber-335811.appspot.com');
      const fileName = 'news.json';
      const file = bucket.file(fileName);
      const fileStream = file.createWriteStream({
        metadata: {
          contentType: 'application/json'
        },
        timeout: 5400000,
      });
      await new Promise((resolve, reject) => {
        const fileContents = JSON.stringify(finalArticles);
        fileStream.on('finish', () => {
          console.log('[scheduledNewsUpdate][SerpApi] news.json upload finish');
          resolve();
        });
        fileStream.on('error', (err) => {
          console.error('[scheduledNewsUpdate][SerpApi][upload ERROR]', err);
          reject(err);
        });
        fileStream.end(fileContents);
      });
    } catch (error) {
      console.error('[scheduledNewsUpdate][SerpApi][ERROR]', error);
    }
    console.log('[scheduledNewsUpdate][SerpApi] end');
  });
// ================================================  
// All Video List取得処理の定義
// ================================================
exports.getAllVideoData = functions.https.onRequest(async (request, response) => {
  response.set('Access-Control-Allow-Origin', '*');
  if (request.method === 'OPTIONS') {
    response.set('Access-Control-Allow-Methods', 'GET');
    response.set('Access-Control-Allow-Headers', 'Content-Type');
    response.set('Access-Control-Max-Age', '3600');
    response.status(204).send('');
    return;
  }
  // ...existing code for getAllVideoData...
});

// ================================================  
// Twitter Ranking Data取得処理の定義
// ================================================
exports.getTwitterData = functions.https.onRequest(async (request, response) => {
  response.set('Access-Control-Allow-Origin', '*');

  if (request.method === 'OPTIONS') {
    // Send response to OPTIONS requests
    response.set('Access-Control-Allow-Methods', 'GET');
    response.set('Access-Control-Allow-Headers', 'Content-Type');
    response.set('Access-Control-Max-Age', '3600');
    response.status(204).send('');
  } else {
    //response.send('Hello World!');
  }
  try {
    // Realtime Databaseからデータを取得
    const bucket = admin.storage().bucket();
    const rankingTwitterDataFile = bucket.file('rankingTwitterData.json'); // ダウンロードするJSONファイルのパスに置き換え
    rankingTwitterDataFile.download((err, contents) => {
      if (!err) {
        const jsonStr = contents.toString();
        const jsonData = JSON.parse(jsonStr);

        // ダウンロードとパースが完了したJSONデータを利用できます
        // console.log("jsonData:",jsonData);
        response.status(200).json({ jsonData });
      } else {
        // console.error('ファイルのダウンロード中にエラーが発生しました:', err);
      }
    });
  } catch (error) {
    // console.error('Error:', error);
    response.status(500).json({ error: 'Something went wrong [rankingTwitterData]' });
  }
});
function formatDateSerpApi(dateStr) {
  if (!dateStr) return '';
  // 例: "08/21/2025, 06:52 AM, +0000 UTC"
  const d = new Date(dateStr.replace(/, \\+\\d+ UTC$/, '')); // UTC部分を除去してDate化
  const pad = n => n.toString().padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`;
}
// ================================================  
// Youtube 登録者数 取得処理の定義
// ================================================
exports.getYoutubeRegiData = functions.https.onRequest(async (request, response) => {
  response.set('Access-Control-Allow-Origin', '*');

  if (request.method === 'OPTIONS') {
    // Send response to OPTIONS requests
    response.set('Access-Control-Allow-Methods', 'GET');
    response.set('Access-Control-Allow-Headers', 'Content-Type');
    response.set('Access-Control-Max-Age', '3600');
    response.status(204).send('');
  } else {
    //response.send('Hello World!');
  }
  try {
    // Realtime Databaseからデータを取得
    const bucket = admin.storage().bucket();
    const rankingYoutubeRegiDataFile = bucket.file('rankingYoutubeRegiData.json'); // ダウンロードするJSONファイルのパスに置き換え
    rankingYoutubeRegiDataFile.download((err, contents) => {
      if (!err) {
        const jsonStr = contents.toString();
        const jsonData = JSON.parse(jsonStr);

        // ダウンロードとパースが完了したJSONデータを利用できます
        // console.log("jsonData:",jsonData);
        response.status(200).json({ jsonData });
      } else {
        // console.error('ファイルのダウンロード中にエラーが発生しました:', err);
      }
    });
  } catch (error) {
    // console.error('Error:', error);
    response.status(500).json({ error: 'Something went wrong [rankingYoutubeRegiData]' });
  }
});

// ================================================  
// event List 取得処理の定義
// ================================================
exports.getEventListData = functions.https.onRequest(async (request, response) => {
  response.set('Access-Control-Allow-Origin', '*');

  if (request.method === 'OPTIONS') {
    // Send response to OPTIONS requests
    response.set('Access-Control-Allow-Methods', 'GET');
    response.set('Access-Control-Allow-Headers', 'Content-Type');
    response.set('Access-Control-Max-Age', '3600');
    response.status(204).send('');
  } else {
    //response.send('Hello World!');
  }
  try {
    // Realtime Databaseからデータを取得
    const bucket = admin.storage().bucket();
    const eventListDataFile = bucket.file('eventList.json'); // ダウンロードするJSONファイルのパスに置き換え
    eventListDataFile.download((err, contents) => {
      if (!err) {
        const jsonStr = contents.toString();
        const jsonData = JSON.parse(jsonStr);

        // ダウンロードとパースが完了したJSONデータを利用できます
        // console.log("jsonData:",jsonData);
        response.status(200).json({ jsonData });
      } else {
        // console.error('ファイルのダウンロード中にエラーが発生しました:', err);
      }
    });
  } catch (error) {
    // console.error('Error:', error);
    response.status(500).json({ error: 'Something went wrong [eventList]' });
  }
});

// ================================================  
// LiveVideo のデータ取得
// ================================================
exports.getLiveVideoData = functions.https.onRequest(async (request, response) => {
  response.set('Access-Control-Allow-Origin', '*');

  if (request.method === 'OPTIONS') {
    // Send response to OPTIONS requests
    response.set('Access-Control-Allow-Methods', 'GET');
    response.set('Access-Control-Allow-Headers', 'Content-Type');
    response.set('Access-Control-Max-Age', '3600');
    response.status(204).send('');
  } else {
    //response.send('Hello World!');
  }
  try {
    // HTTPリクエストから引数を取得
    const bucket = admin.storage().bucket();
    const liveVideoDataFile = bucket.file('livevideoList.json'); // ダウンロードするJSONファイルのパスに置き換え
    liveVideoDataFile.download((err, contents) => {
      if (!err) {
        const jsonStr = contents.toString();
        const jsonData = JSON.parse(jsonStr);

        // ダウンロードとパースが完了したJSONデータを利用できます
        // console.log("liveVideoDataFile:",jsonData);
        response.status(200).json({ jsonData });
      } else {
        // console.error('ファイルのダウンロード中にエラーが発生しました:', err);
      }
    });
  } catch (error) {
    // console.error('Error:', error);
    response.status(500).json({ error: 'Something went wrong [liveVideoData]' });
  }
});
// ================================================  
// Vtuber のデータ取得
// ================================================
exports.getVtuberData = functions.https.onRequest(async (request, response) => {
  response.set('Access-Control-Allow-Origin', '*');

  if (request.method === 'OPTIONS') {
    // Send response to OPTIONS requests
    response.set('Access-Control-Allow-Methods', 'GET');
    response.set('Access-Control-Allow-Headers', 'Content-Type');
    response.set('Access-Control-Max-Age', '3600');
    response.status(204).send('');
  } else {
    //response.send('Hello World!');
  }
  try {
    // HTTPリクエストから引数を取得
    const id = request.query.id;
    const bucket = admin.storage().bucket();
    const vtuberDataFile = bucket.file(id + '.json'); // ダウンロードするJSONファイルのパスに置き換え
    vtuberDataFile.download((err, contents) => {
      if (!err) {
        const jsonStr = contents.toString();
        const jsonData = JSON.parse(jsonStr);

        // ダウンロードとパースが完了したJSONデータを利用できます
        // console.log("vtuberDataFile:",jsonData);
        response.status(200).json({ jsonData });
      } else {
        // console.error('ファイルのダウンロード中にエラーが発生しました:', err);
      }
    });
  } catch (error) {
    // console.error('Error:', error);
    response.status(500).json({ error: 'Something went wrong [vtuberData]' });
  }
});

// ================================================  
// OfficeListData のデータ取得
// ================================================
exports.getOfficeListData = functions.https.onRequest(async (request, response) => {
  response.set('Access-Control-Allow-Origin', '*');

  if (request.method === 'OPTIONS') {
    // Send response to OPTIONS requests
    response.set('Access-Control-Allow-Methods', 'GET');
    response.set('Access-Control-Allow-Headers', 'Content-Type');
    response.set('Access-Control-Max-Age', '3600');
    response.status(204).send('');
  } else {
    //response.send('Hello World!');
  }
  try {
    // HTTPリクエストから引数を取得
    const id = request.query.id;
    const bucket = admin.storage().bucket();
    const officedataListDataFile = bucket.file("officedataList.json"); // ダウンロードするJSONファイルのパスに置き換え
    officedataListDataFile.download((err, contents) => {
      if (!err) {
        const jsonStr = contents.toString();
        const jsonData = JSON.parse(jsonStr);

        // ダウンロードとパースが完了したJSONデータを利用できます
        // console.log("getOfficeListData:",jsonData);
        response.status(200).json({ jsonData });
      } else {
        // console.error('ファイルのダウンロード中にエラーが発生しました:', err);
      }
    });
  } catch (error) {
    // console.error('Error:', error);
    response.status(500).json({ error: 'Something went wrong [officedataListDataFile]' });
  }
});

const nodemailer = require('nodemailer');

// GmailのSMTP設定
const transporter = nodemailer.createTransport({
  service: 'Gmail',
  auth: {
    user: 'kurieitajojojo@gmail.com',
    pass: 'arolsmzekygsoefo'
  }
});

exports.sendMail = functions.https.onRequest(async (request, response) => {
  response.set('Access-Control-Allow-Origin', '*');

  if (request.method === 'OPTIONS') {
    // Send response to OPTIONS requests
    response.set('Access-Control-Allow-Methods', 'GET');
    response.set('Access-Control-Allow-Headers', 'Content-Type');
    response.set('Access-Control-Max-Age', '3600');
    response.status(204).send('');
  } else {
    //response.send('Hello World!');
  }
  // console.log("sendMail:Start");
  const from = request.query.from;
  const subject = request.query.subject;
  const text = request.query.text;
  const mailOptions = {
    from: "kurieitajojojo@gmail.com",//from, // 送信元のメールアドレス（引数から取得）
    to: "kurieitajojojo@gmail.com", // 送信先のメールアドレス
    subject: "subject", // メールの件名（引数から取得）
    text: "text" // メールの本文（引数から取得）
  };

  // ダウンロードとパースが完了したJSONデータを利用できます
  // console.log("mailOptions:",mailOptions);
  // メール送信
  try {
    await transporter.sendMail(mailOptions);
    // console.log("sendMail:success");
    return { success: true };
  } catch (error) {
    // console.log("sendMail:error");
    // console.error(error);
    return { success: false, error: error.message };
  }
});

// ==============================================================================  
// 動画生成の定義
// ==============================================================================
const { v4: uuidv4 } = require("uuid");
//const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
// const openai = new OpenAI({
//   apiKey: functions.config().openai.api_key, // Firebase環境変数からAPIキーを取得
// });
// 🔥 ここで GCS バケットの初期化（関数の外！）
const { exec } = require('child_process');
const util = require('util');
const execAsync = util.promisify(exec);
// const storage_ = new Storage();
const bucketName = 'vtuber-335811.appspot.com';
const bucket_ = storage.bucket(bucketName);
// const path = require('path');
// const TEMP_DIR = '/temp';
// const TMP_OUTPUT_DIR = path.join(TEMP_DIR, 'output');
const VOICEVOX_ENGINE_URL = "https://voicevox-engine-23130474318.asia-northeast1.run.app";
// const VOICEVOX_ENGINE_URL = 'https://voicevox-engine-44ispcgxza-an.a.run.app';
let speedScale = 1.4;
let finalURL = "";
const SPEAKER_ID = 1; // ずんだもん等（適宜変更）
const { youtubeUpload } = require('./youtubeUpload');
const https = require('https');
const fs = require('fs');

//exports.generateBlogVideoFromLatestNews = async (req, res) => {
exports.generateBlogVideoFromLatestNews = functions
  .runWith({ memory: '2GB', timeoutSeconds: 540 })
  .https.onRequest(async (req, res) => {
    // CORS対応
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }

    const uuid = uuidv4();
    let blogText = "";
    let videoTitle = "";
    let videoTags = [];
    let articleLink = "";
    let articleText = "";
    let thumbnail = "";
    let videoId = "";
    let resultMessage = "";

    try {
      const { _videoTitle, _blogText, _videoTags } = req.body || {};
      blogText = _blogText;
      videoTitle = _videoTitle;
      videoTags = _videoTags;
    } catch (err) {
      console.error('_blogTextがからのため自動生成モードで実行');
    }

    try {
      if (!blogText) {
        // 自動実行モード
        let publishedAt = "";
        let description = "";
        // フォールバック
        console.log("[自動モード]news.jsonから記事取得");
        const fallback = await getFallbackNewsData();
        if (fallback) {
          console.log("[自動モード]fallback", fallback.title);
          console.log("[自動モード]fallback", fallback.url);
          videoTitle = fallback.title;
          thumbnail = fallback.thumbnail_small || '';
          console.log('[getFinalUrlWithPuppeteer] Start:', fallback.url);
          articleLink = fallback.url; //await getFinalUrlWithPuppeteer(fallback.url);
          console.log("[自動モード]getFinalUrlWithPuppeteer", articleLink);
          publishedAt = fallback.publishedAt;
        } else {
          throw new Error('[自動モード]Feed Err: No news data available');
        }
        const isAlreadyProcessed = await alreadyProcessed(articleLink);
        if (isAlreadyProcessed) {
          res.status(200).send(`スキップ：すでに生成済み - > ${articleLink}`);
          return;
        }
        finalURL = articleLink;
        articleText = await getArticleContent(articleLink);
        console.log("[自動モード]articleText:", articleText);
        let prompt = "";
        if (articleText) {
          prompt = `Vtuberに関連する記事内容を解説する、ニュース動画を作成します。
          この動画はショート動画でyoutubeにアップします。
          以下の記事内容を適宜要約するなどして、口頭で解説するため自然な文脈にして台本を作成してください。
          youtubeにアップした際、再生数が取れそうな内容にしたいです。
          また、元記事へのリンクは概要欄に貼るので、リンクなどの読み上げは不要です。あくまでも内容にフォーカスしてください。
          必要であればSNSでの反響なども踏まえつつ、台本のボリュームは全体で500文字以内で、改行せず、台本の本文のみを出力してください（そのまま機械的に読み上げるので【ニュース記事】などのタイトルは不要）。
          \n記事: ${articleText}`;
        } else {
          prompt = `以下の記事タイトルに基づいて、youtubeにアップするニュース記事の台本を600文字以内で、Vtuberに関連するニュースのみを改行せず台本の本文のみを出力してください（そのまま機械的に読み上げるので【ニュース記事】などのタイトルは不要）。\nタイトル: ${videoTitle}`;
        }
        const completion = await openai.chat.completions.create({
          model: 'gpt-4o',
          messages: [
            {
              role: "system",
              content: "あなたはYouTubeショート動画用の台本ライターです。Vtuber関連ニュースを自然でわかりやすく解説し、再生数が伸びるようにまとめてください。"
            },
            {
              role: "user",
              content: prompt
            }
          ],
          temperature: 0.7,
        });
        blogText = completion.choices[0].message.content;
        console.log("[自動モード]GGenerated blog text:", blogText);
      } else {
        // 手動モード
        console.log("[手動モード]Generated blog text:", blogText);
      }

      if (!videoTitle) {
        // Title自動モード
        const title_prompt = `以下の台本の内容を読み上げる形でyoutube動画にしようとしています。その際の動画タイトルを、再生数が取れそうな引きのある文言で20文字程度までの長さで作成してください。台本：${blogText}`;
        const title_completion = await openai.chat.completions.create({
          model: 'gpt-3.5-turbo',
          messages: [
            {
              role: "system",
              content: "あなたはYouTubeショート動画用の台本ライターです。Vtuber関連ニュースに対し、再生数が伸びるようなタイトルを付けてください。なお、youtube動画のタイトル文字数制限は100文字です"
            },
            { role: 'user', content: title_prompt }
          ],
          temperature: 0.7,
        });
        videoTitle = title_completion.choices[0].message.content;
        console.log("[自動モード]GGenerated Title:", videoTitle);
      } else {
        // Title手動モード
        console.log("[手動モード]Generated Title:", videoTitle);
      }

      // タイトルとブログ結合
      blogText = `${videoTitle}\n${blogText}\n以上のニュース詳細は概要欄にて。\nいいねと思ったら、チャンネル登録と高評価をお願いします。`;
      console.log("Generated blog text+Title:", blogText);

      const description_prompt = `以下の台本をyoutube動画にする際の動画のdescriptionを、300文字程度までで日本語で作成してください。先ほどの台本：${blogText}`;
      const description_completion = await openai.chat.completions.create({
        model: 'gpt-3.5-turbo',
        messages: [
          {
            role: "system",
            content: "あなたはYouTubeショート動画用の台本ライターです。Vtuber関連ニュースを自然でわかりやすく解説し、再生数が伸びるようにまとめてください。"
          },
          { role: 'user', content: description_prompt }
        ],
        temperature: 0.7,
      });
      let videoDescription = description_completion.choices[0].message.content;

      videoDescription = `${videoDescription}\n\nニュース詳細:${finalURL}\n`;
      console.log("Generated blog videoDescription:", videoDescription);

      const furigana_prompt = `以下の文章に含まれる英単語・アルファベット表記（例: Vtuber, YouTube, SNS, AIなど）・固有名詞を、適切な日本語の読み（カタカナ）に変換してください。文章の構造はそのままにし、不要な改行や説明文は入れず、変換後の文章のみを出力してください。\n\n文章：${blogText}`
      const furigana_completion = await openai.chat.completions.create({
        model: 'gpt-4o',
        messages: [
          {
            role: "system",
            content: "あなたは日本語の音声合成用にテキストを整形するアシスタントです。VOICEVOXで正しく自然に読めるように調整してください。"
          },
          {
            role: "user",
            content: furigana_prompt
          }
        ],
        temperature: 0.3,
      });
      const furiganaText = furigana_completion.choices[0].message.content;
      console.log("Generated Furigana text:", furiganaText);

      if (!Array.isArray(videoTags)) {
        // Tag自動モード
        const tags_prompt = `以下の台本をyouTube動画にする際の動画のTagを、検索にヒットしやすいものから20個、日本語で出力してください。
          - 「vtuber」は必ず含めてください。
          - 絵文字は含めないでください。
          - 出力は JSON 配列形式のみ、余計な説明はしないでください。
          - 例: ["vtuber", "ニュース", "コラボ", "配信", "ゲーム"]
          台本：${blogText}`;

        const tags_completion = await openai.chat.completions.create({
          model: 'gpt-3.5-turbo',
          messages: [
            {
              role: "system",
              content: "あなたはYouTubeショート動画用の台本ライターです。Vtuber関連ニュースを自然でわかりやすく解説し、再生数が伸びるようにまとめてください。"
            },
            { role: 'user', content: tags_prompt }
          ],
          temperature: 0.7,
        });
        const rawText = tags_completion.choices[0].message.content.trim();

        // 最初の JSON 配列っぽい部分を正規表現で抽出
        const match = rawText.match(/\[[\s\S]*?\]/);
        videoTags = ['vtuber', '毎日投稿', 'ニュース']; // フォールバック

        if (match) {
          try {
            videoTags = JSON.parse(match[0]);
          } catch (err) {
            console.error('❌ タグのJSONパース失敗:', err.message);
          }
        } else {
          console.warn('⚠️ タグの配列形式が見つかりませんでした');
        }
        console.log("[手動モード]Generated Tag:", videoTags);
      } else {
        // Tag手動モード
        console.log("[手動モード]Generated Tag:", videoTags);
      }

      // 1. VOICEVOX: 音声合成　2. 字幕生成
      await generateVoiceAndSRT(furiganaText, blogText, uuid);

      // 🎞️ 動画合成リクエスト
      const videoMergerUrl = 'https://video-merger-23130474318.asia-northeast1.run.app/merge';
      const videoGcsUri = await getRandomBackgroundGcsUri(bucketName);
      const outputFilePath = `merged-output/output-${uuid}.mp4`;
      const outputPath = `gs://${bucketName}/${outputFilePath}`;
      const audioGcsUri = `gs://${bucketName}/output/output-${uuid}.wav`;
      const subtitleGcsUri = `gs://${bucketName}/output/output-${uuid}.srt`;

      const mergeRes = await axios.post(videoMergerUrl, {
        videoUri: videoGcsUri,
        audioUri: audioGcsUri,
        outputUri: outputPath,
        subtitleSrtUri: subtitleGcsUri,
      }, {
        headers: { 'Content-Type': 'application/json' },
        timeout: 540000,
        maxContentLength: Infinity,
        maxBodyLength: Infinity,
      });

      console.log("Merge result:", mergeRes.data);
      // ==============================================================================  
      // ✅ 後始末（音声・字幕ファイルを削除）
      // ==============================================================================

      await deleteGcsFile(bucketName, `output/output-${uuid}.wav`);
      await deleteGcsFile(bucketName, `output/output-${uuid}.srt`);

  // ==============================================================================  
  // 動画アップロード実行
  // ==============================================================================
  // アップロード先チャンネルを固定（指定のチャンネル用トークンファイルを使用）
  // トークンファイルは functions/ 配下に置いてください。
  // 例ファイル名: functions/youtube_token_UC5Ci1AAAYsIWnnHmcUTxlnQ.json
  // この行を編集すれば別チャンネルへ切り替え可能です。
  process.env.YOUTUBE_TOKEN_FILE = 'youtube_token_UC5Ci1AAAYsIWnnHmcUTxlnQ.json';

  videoId = await youtubeUpload(bucketName, outputFilePath, videoTitle, videoDescription, videoTags, thumbnail);
      await deleteGcsFile(bucketName, outputFilePath);

      resultMessage = `動画を生成してYouTubeにアップロードしました: https://youtu.be/${videoId}`;

      // ==============================================================================  
      // videoUrlMap.json へのマージ処理 ★★
      // ==============================================================================
      try {
        const videoUrlMapFile = bucket_.file('videoUrlMap.json');
        let videoUrlMap = {};
        try {
          const [contents] = await videoUrlMapFile.download();
          videoUrlMap = JSON.parse(contents.toString());
        } catch (err) {
          console.log('videoUrlMap.jsonが存在しないため新規作成');
          videoUrlMap = {};
        }
        if (articleLink && videoId) {
          videoUrlMap[articleLink] = `https://youtu.be/${videoId}`;
        }
        await videoUrlMapFile.save(JSON.stringify(videoUrlMap, null, 2), { contentType: 'application/json' });
        console.log('videoUrlMap.json updated:', articleLink, videoId);
      } catch (err) {
        console.error('videoUrlMap.json update error:', err);
      }
      // ==============================================================================  
      // news.json への反映（1件のみ追記 or 更新）
      // ==============================================================================
      try {
        const newsFile = bucket_.file('news.json');
        let newsList = [];
        try {
          const [contents] = await newsFile.download();
          newsList = JSON.parse(contents.toString());
        } catch (err) {
          newsList = [];
        }
        // 既存記事のurl一致で上書き、なければ追加
        let found = false;
        for (let i = 0; i < newsList.length; i++) {
          if (newsList[i].url === articleLink) {
            newsList[i].videoUrl = `https://youtu.be/${videoId}`;
            found = true;
            break;
          }
        }
        // if (!found) {
        //   // 必要なフィールドをnews.json形式で追加
        //   newsList.unshift({
        //     channel: '',
        //     title: videoTitle,
        //     publishedAt: publishedAt || new Date().toISOString(),
        //     description: blogText,
        //     url: articleLink,
        //     creator: '',
        //     urlToImage: thumbnail,
        //     sourceName: '',
        //     sourceUrl: articleLink,
        //     videoUrl: `https://youtu.be/${videoId}`
        //   });

        await newsFile.save(JSON.stringify(newsList, null, 2), { contentType: 'application/json' });
        console.log('news.json updated:', articleLink, videoId);
      } catch (err) {
        console.error('news.json update error:', err);
      }
      // ==============================================================================  
      // newVtuberCandidates.json へ、新規Vtuber登録処理 ★★
      // ==============================================================================
      await collectNewVtuberCandidates(articleText, articleLink);
    } catch (error) {
      console.error('Error generating blog or merging video:', error?.response?.data || error);
      res.status(500).send('Error generating blog or merging video.');
      return;
    }

    // 必ず1回だけレスポンスを返す
    res.status(200).send(resultMessage);
  }
  );

async function getFallbackNewsData() {
  try {
    const res = await axios.get('https://storage.googleapis.com/vtuber-335811.appspot.com/news.json');
    const newsList = res.data;
    // videoUrlが無いものだけ抽出
    const noVideo = newsList.filter(article => !article.videoUrl);
    // publishedAt降順でソート
    noVideo.sort((a, b) => new Date(b.publishedAt) - new Date(a.publishedAt));
    if (noVideo.length > 0) {
      return noVideo[0];
    }
  } catch (e) {
    console.error('Fallback news.json fetch error:', e);
  }
  return null;
}

const puppeteer = require('puppeteer-core');
const chromium = require('@sparticuz/chromium'); // Cloud Functions用

/**
 * 記事本文から新規VTuber候補を抽出し、可能な限り情報を埋めてJson保存
 * @param {string} articleText - 記事本文
 * @param {string} articleUrl - 記事URL（出典用）
 */
async function collectNewVtuberCandidates(articleText, articleUrl) {
  // 1. 記事本文からVTuber候補をAIで抽出
  const extractPrompt = `
以下のニュース記事本文に登場するVTuberの名前・YouTubeチャンネルID（@から始まるものがあればそれも）・Twitter名（@から始まるものがあれば）・事務所名（分かれば）・誕生日やデビュー日（分かれば）をできるだけ多く抽出してください。
分かる範囲で下記のJSON形式で1人ずつ出力してください。分からない項目は空文字でOKです。

{
  "name": "",
  "channeID": "",
  "twitterName": "",
  "office": "",
  "birthday": "",
  "debut": ""
}

本文:
${articleText}
`;

  const completion = await openai.chat.completions.create({
    model: 'gpt-3.5-turbo',
    messages: [{ role: 'user', content: extractPrompt }],
    max_tokens: 2048,
    temperature: 0.2,
  });

  // 2. AIの出力からJSON配列を抽出
  let vtuberCandidates = [];
  try {
    // 複数JSONオブジェクトが並ぶ場合も考慮
    const matches = completion.choices[0].message.content.match(/\{[\s\S]*?\}/g);
    if (matches) {
      vtuberCandidates = matches.map(str => {
        try {
          return JSON.parse(str);
        } catch {
          return null;
        }
      }).filter(Boolean);
    }
  } catch (e) {
    console.error('AI出力のパースに失敗:', e);
  }

  if (vtuberCandidates.length === 0) {
    console.log('新規VTuber候補は見つかりませんでした');
    return;
  }

  // 3. 既存VTuberリストを取得
  const snapshot = await db.ref('vtuber').once('value');
  const vtuberDict = snapshot.val() || {};
  const existingNames = Object.values(vtuberDict).map(v => v.name);

  // 4. 未登録のみ抽出し、情報を整形
  const now = new Date().toISOString();
  const newVtuberObjs = vtuberCandidates
    .filter(v => v.name && !existingNames.includes(v.name))
    .map(v => ({
      name: v.name,
      channeID: v.channeID || '',
      twitterName: v.twitterName || '',
      office: v.office || 'personal',
      officeFlg: v.office ? v.office !== 'personal' : false,
      birthday: v.birthday || '',
      debut: v.debut || '',
      description: '',
      createdAt: now,
      updateTime: now,
      sourceUrl: articleUrl,
    }));

  if (newVtuberObjs.length === 0) {
    console.log('未登録の新規VTuber候補はありません');
    return;
  }

  // 5. 既存ファイルを読み込んで追記＋重複除去
  const bucket = storage.bucket('vtuber-335811.appspot.com');
  const file = bucket.file('newVtuberCandidates.json');
  let existing = [];
  try {
    const [contents] = await file.download();
    existing = JSON.parse(contents.toString());
  } catch (e) {
    // ファイルがなければ空配列でOK
    existing = [];
  }

  // 既存候補と新規候補をマージし、重複を除去
  const all = existing.concat(newVtuberObjs);

  // name, channeID, twitterName のいずれかが一致すれば重複とみなす
  const unique = [];
  const seen = new Set();
  for (const v of all) {
    const key = [v.name, v.channeID, v.twitterName].join('|');
    if (!seen.has(key)) {
      unique.push(v);
      seen.add(key);
    }
  }

  await file.save(JSON.stringify(unique, null, 2), { contentType: 'application/json' });

  console.log('新規VTuber候補を追記（重複除去済み）:', newVtuberObjs);
}

// ==============================================================================
// 🎬 動画生成のUtil関数
// ==============================================================================
const express = require('express');
const app = express();
app.use(express.json());
const crypto = require('crypto');
const kuromoji = require('kuromoji');
const ffmpeg = require("fluent-ffmpeg");
// app.post('/', async (req, res) => {
//   try {
//     await generateBlogVideoFromLatestNews(req, res);
//   } catch (err) {
//     console.error(err);
//     res.status(500).send('Internal Server Error');
//   }
// });
// app.get('/', async (req, res) => {
//   await generateBlogVideoFromLatestNews(req, res);
// });
// exports.generateBlogVideoFromLatestNews = app;

// ランダム動画選択
async function getRandomBackgroundGcsUri(bucketName) {
  const prefix = 'background_';
  const [files] = await storage.bucket(bucketName).getFiles({ prefix });

  // background_0_ 〜 background_10_ に一致するファイルを抽出
  const candidates = files.filter(file => /^background_\d+_.*\.mp4$/.test(file.name));
  if (candidates.length === 0) throw new Error("背景動画が見つかりません");

  const randomIndex = Math.floor(Math.random() * candidates.length);
  return `gs://${bucketName}/${candidates[randomIndex].name}`;
}

// ハッシュ + 短縮名で安全なファイル名を作成
function getSafeFileNameFromUrl(url) {
  const hash = crypto.createHash('sha256').update(url).digest('hex').slice(0, 16);
  const shortId = url.split('/').pop()?.slice(0, 20).replace(/[^a-zA-Z0-9-_]/g, '') || 'article';
  return `${shortId}_${hash}`;
}

// 記事内容を取得する関数
async function getArticleContent(url) {
  if (typeof url !== 'string' || !url.startsWith('http')) {
    console.error('getArticleContent: invalid url', url);
    return null;
  }
  const browser = await puppeteer.launch({
    args: ['--no-sandbox', '--disable-setuid-sandbox'],
    executablePath: await chromium.executablePath(),
    headless: chromium.headless,
  });

  const page = await browser.newPage();

  try {
    await page.setUserAgent(
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36'
    );
    await page.setExtraHTTPHeaders({
      'Accept-Charset': 'utf-8'
    });

    await page.goto(url, {
      waitUntil: ['domcontentloaded', 'networkidle2'],
      timeout: 450_000,
    });

    try {
      await page.waitForSelector('article, div.main-article, div.article-body, section', { timeout: 60000 });
    } catch (e) {
      console.log("page.gotoでWarning: 指定されたセレクタが見つかりませんでした（通常のケースもあります）");
    }

    finalURL = page.url();
    console.log('最終URL:', finalURL);

    const paragraphSelectors = [
      'div.entry-body p',
      'div.main-article p',
      'div.article-body p',
      'section p',
      'article p',
      'body p',
    ];

    async function extractParagraphs(context) {
      for (const selector of paragraphSelectors) {
        const paragraphs = await context.$$eval(selector, nodes =>
          nodes.map(p => p.textContent.trim()).filter(Boolean)
        );
        if (paragraphs.length > 0) {
          return paragraphs.join('\n\n');
        }
      }
      // どのセレクタにも該当しなければ全pタグ
      const allP = await context.$$eval('p', nodes =>
        nodes.map(p => p.textContent.trim()).filter(Boolean)
      );
      if (allP.length > 0) {
        return allP.join('\n\n');
      }
      // それでも空ならbody全体
      const bodyText = await context.$eval('body', node => node.innerText.trim());
      return bodyText || '';
    }

    let articleText = await extractParagraphs(page);

    if (!articleText) {
      const frames = page.frames();
      for (const frame of frames) {
        articleText = await extractParagraphs(frame).catch(() => '');
        if (articleText) break;
      }
    }

    if (!articleText) {
      await page.evaluate(() => window.scrollBy(0, window.innerHeight));
      await page.waitForFunction(() => {
        return (
          document.querySelectorAll('div.entry-body p').length > 0 ||
          document.querySelectorAll('div.main-article p').length > 0 ||
          document.querySelectorAll('div.article-body p').length > 0 ||
          document.querySelectorAll('section p').length > 0 ||
          document.querySelectorAll('article p').length > 0 ||
          document.querySelectorAll('p').length > 0
        );
      }, { timeout: 30000 });

      articleText = await extractParagraphs(page);
    }

    await browser.close();

    // URL を先頭に追加
    const mainText = await extractMainContentWithAI(articleText, finalURL);
    return `【出典】${finalURL}\n\n${mainText}`;
  } catch (error) {
    console.error('Error fetching article:', error);
    await browser.close();
    return null;
  }
}

async function extractMainContentWithAI(rawText, url) {
  const prompt = `
以下はWeb記事の全文テキストです。広告や関連記事、ナビゲーションなど記事本文以外の要素が含まれている場合は無視し、記事本文だけを日本語で抽出してください。本文以外は一切出力しないでください。

【記事URL】${url}
【記事テキスト】
${rawText}
`;
  const completion = await openai.chat.completions.create({
    model: 'gpt-3.5-turbo',
    messages: [{ role: 'user', content: prompt }],
    max_tokens: 2048,
    temperature: 0.2,
  });
  return completion.choices[0].message.content.trim();
}

// 🔧 ファイル削除ユーティリティ
async function deleteGcsFile(bucketName, filePath) {
  try {
    await storage.bucket(bucketName).file(filePath).delete();
    console.log(`🧹 Deleted: gs://${bucketName}/${filePath}`);
  } catch (err) {
    console.warn(`⚠️ Failed to delete: gs://${bucketName}/${filePath}`, err.message);
  }
}

// 🔧 ファイルアップロード共通
async function uploadToGCS(localPath, remotePath) {
  console.log(`☁️ Upload ${localPath} to gs://${bucketName}/${remotePath}`);
  await storage.bucket(bucketName).upload(localPath, {
    destination: remotePath,
  });
  console.log(`☁️ Uploaded ${localPath} to gs://${bucketName}/${remotePath}`);

}

// 音声生成
async function synthesizeSentence(text, index, uuid) {
  const queryResp = await axios.post(`${VOICEVOX_ENGINE_URL}/audio_query`, null, {
    params: { text, speaker: SPEAKER_ID },
  });
  queryResp.data.speedScale = 1.4;           // 話速
  queryResp.data.volumeScale = 1.3;          // 音量（1.0→1.3など）
  queryResp.data.intonationScale = 1.3;      // 抑揚（1.0→1.3など）
  const synthesisResp = await axios.post(
    `${VOICEVOX_ENGINE_URL}/synthesis?speaker=${SPEAKER_ID}`,
    queryResp.data,
    { responseType: 'arraybuffer' }
  );

  const filePath = `/tmp/sentence_-${uuid}${index}.wav`;
  await fs.promises.writeFile(filePath, synthesisResp.data);
  await uploadToGCS(filePath, `temp/sentence_-${uuid}${index}.wav`);
  return filePath;
}

// 途中ファイル削除
async function deleteTempFilesByUUID(uuid) {
  const [files] = await storage.bucket(bucketName).getFiles({
    prefix: `temp/sentence_-${uuid}`,
  });

  if (files.length === 0) {
    console.log(`🧹 No files found with uuid: ${uuid}`);
    return;
  }

  console.log(`🧹 Deleting ${files.length} files with uuid: ${uuid}`);
  await Promise.all(
    files.map(file => {
      console.log(`🗑️ Deleting gs://${bucketName}/${file.name}`);
      return file.delete().catch(err => {
        console.warn(`⚠️ Failed to delete ${file.name}: ${err.message}`);
      });
    })
  );
  console.log('✅ All temp files deleted for uuid:', uuid);
}

// 音声ファイルと字幕ファイルの作成
async function generateVoiceAndSRT(text, srttext, uuid) {
  // 音声・字幕用の文節ごとに分割
  const sentences = customSplit(text);
  console.log('✅ 音声sentences:', sentences);
  const srtsentences = customSplit(srttext);
  console.log('✅ 字幕sentences:', srtsentences);

  const audioFiles = [];
  const durations = [];
  let srtContent = '';
  let currentTime = 0;

  for (let i = 0; i < Math.max(sentences.length, srtsentences.length); i++) {
    const sentence = sentences[i] || "";       // 音声用
    const srtsentence = srtsentences[i] || ""; // 字幕用

    // 音声生成
    console.log(`🔊 音声生成中: ${sentence}`);
    const filePath = await synthesizeSentence(sentence, audioFiles.length, uuid);
    audioFiles.push(filePath);

    let duration = await getAudioDuration(filePath);
    if (isNaN(duration)) {
      console.log(`❌ duration が NaN: filePath=${filePath}`);
      duration = 0;
    }
    durations.push(duration);

    const start = formatSrtTime(currentTime);
    const end = formatSrtTime(currentTime + duration);

    // 字幕行の改行（必要ならwrapWithKuromojiの代わりにwrapText等を使う）
    //let wrapped = srtsentence; // 必要に応じてラップ処理
    let wrapped = await wrapWithKuromoji(srtsentence, 16);

    wrapped = cleanUpWrappedText(wrapped);
    console.log(`📝 字幕生成中: ${wrapped}`);
    srtContent += `${audioFiles.length}\n${start} --> ${end}\n${wrapped}\n\n`;
    currentTime += duration;
  }

  const srtPath = `/tmp/output-${uuid}.srt`;
  await fs.promises.writeFile(srtPath, srtContent);
  await uploadToGCS(srtPath, `output/output-${uuid}.srt`);

  const listFile = `/tmp/-${uuid}concat_list.txt`;
  const concatContent = audioFiles.map(f => `file '${f}'`).join('\n');
  await fs.promises.writeFile(listFile, concatContent);

  const outputWavPath = `/tmp/output-${uuid}.wav`;
  await execAsync(`ffmpeg -f concat -safe 0 -i ${listFile} -c copy ${outputWavPath}`);
  await uploadToGCS(outputWavPath, `output/output-${uuid}.wav`);

  //ファイル削除
  for (const file of audioFiles) {
    try {
      await fs.promises.unlink(file);
      console.log(`🗑️ 削除完了: ${file}`);
    } catch (err) {
      console.error(`⚠️ 削除失敗: ${file}`, err);
    }
  }
  deleteTempFilesByUUID(uuid).catch(err => {
    console.warn(`⚠️ Failed to delete temp files for uuid ${uuid}: ${err.message}`);
  });
  console.log(`✅ 音声とSRT生成完了: ${outputWavPath}, ${srtPath}`);
}

// 時間フォーマット
function formatSrtTime(seconds) {
  if (typeof seconds !== 'number' || isNaN(seconds) || seconds < 0) {
    throw new Error(`Invalid time value passed to formatSrtTime: ${seconds}`);
  }

  const ms = Math.floor(seconds * 1000);
  const date = new Date(ms);
  const iso = date.toISOString(); // "1970-01-01T00:00:12.345Z"
  return iso.substr(11, 12).replace('.', ',');
}

// ffprobe で音声長取得
async function getAudioDuration(filePath) {
  return new Promise((resolve, reject) => {
    ffmpeg.ffprobe(filePath, (err, metadata) => {
      if (err) reject(err);
      else resolve(metadata.format.duration);
    });
  });
}

// 句読点の整理
function cleanUpWrappedText(text) {
  return text
    .split('\n')
    .map(line => line.replace(/^[、。]/, '').replace(/[、。]$/, '')) // 改行行の先頭・末尾の句読点を削除
    .join('\n');
}

// 📌 インラインで定義：改行処理（形態素解析）
function wrapWithKuromoji(text, maxLength = 16) {
  return new Promise((resolve, reject) => {
    kuromoji.builder({ dicPath: 'node_modules/kuromoji/dict' }).build((err, tokenizer) => {
      if (err) return reject(err);

      const tokens = tokenizer.tokenize(text);
      const lines = [];
      let buffer = '';

      for (const token of tokens) {
        const word = token.surface_form;
        const next = buffer + word;

        if (countVisibleCharacters(next) > maxLength) {
          lines.push(buffer);
          buffer = word;
        } else {
          buffer = next;
        }
      }

      if (buffer) lines.push(buffer);

      resolve(lines.join('\\N'));
    });
  });
}

function splitLongSentenceWithKuromoji(tokenizer, sentence, maxLength = 32) {
  const tokens = tokenizer.tokenize(sentence);
  const result = [];
  let buffer = '';

  for (const token of tokens) {
    const word = token.surface_form;
    const next = buffer + word;

    if (countVisibleCharacters(next) > maxLength) {
      if (buffer) result.push(buffer);
      buffer = word;
    } else {
      buffer = next;
    }
  }

  if (buffer) result.push(buffer);

  return result;
}

function countVisibleCharacters(str) {
  return [...str].length;
}


// 字幕と音声の区切りを実施
function customSplit(text) {
  // 「！」「？」の連続を最後の1文字に正規化（例: "？！？」 -> "？"）
  text = text.replace(/(?:[！？]){2,}/g, (m) => m[m.length - 1]);

  // 区切り位置（句点・読点・句末記号・閉じ括弧の直後、開き括弧の直前）
  // 「、」「。」「！」「？」の直後で分割、また「」や『』の開きの直前で分割する
  const pattern = /(?<=、|。|！|？|」|』)|(?=「|『)/g;

  return text
    .split(pattern)
    .map(s => s.trim())
    .filter(Boolean);
}

// // SRT 時間形式に変換
// function formatTime(seconds) {
//   const ms = Math.floor((seconds % 1) * 1000);
//   const s = Math.floor(seconds % 60);
//   const m = Math.floor((seconds / 60) % 60);
//   const h = Math.floor(seconds / 3600);
//   return `${pad(h)}:${pad(m)}:${pad(s)},${pad(ms, 3)}`;
// }

function pad(n, z = 2) {
  return n.toString().padStart(z, "0");
}

// ffmpegで無音開始時間を検出する関数
const { spawn } = require('child_process');
async function detectSilenceStart(audioPath) {
  return new Promise((resolve, reject) => {
    const ffmpegPath = 'ffmpeg'; // インストールされている前提
    const args = [
      '-i', audioPath,
      '-af', 'silencedetect=noise=-30dB:d=0.1',
      '-f', 'null', '-'
    ];

    const ffmpeg = spawn(ffmpegPath, args);
    let stderr = '';

    ffmpeg.stderr.on('data', data => {
      stderr += data.toString();
    });

    ffmpeg.on('close', () => {
      const match = stderr.match(/silence_start: ([\d\.]+)/);
      if (match) {
        resolve(parseFloat(match[1])); // 秒数を返す
      } else {
        resolve(0); // 無音検出できなかったら0
      }
    });

    ffmpeg.on('error', reject);
  });
}

// async function detectInitialSilence(audioPath) {
//   const cmd = `ffmpeg -i ${audioPath} -af silencedetect=noise=-40dB:d=0.1 -f null -`;
//   const { stdout, stderr } = await exec(cmd);

//   // stderrが文字列じゃなかったら、無理やり中身読む
//   let stderrString;
//   if (typeof stderr === 'string') {
//     stderrString = stderr;
//   } else if (Buffer.isBuffer(stderr)) {
//     stderrString = stderr.toString('utf-8');
//   } else if (typeof stderr?.read === 'function') {
//     // ストリームっぽかったら、中身を全部読む
//     stderrString = await streamToString(stderr);
//   } else {
//     console.error('stderrが想定外の型です:', stderr);
//     stderrString = '';
//   }

//   console.log('🔍 ffmpeg無音検出ログ:', stderrString);

//   const silenceStartMatch = stderrString.match(/silence_start: (\d+(\.\d+)?)/);
//   const silenceEndMatch = stderrString.match(/silence_end: (\d+(\.\d+)?)/);

//   if (silenceStartMatch && silenceEndMatch) {
//     const silenceEnd = parseFloat(silenceEndMatch[1]);
//     console.log(`🔍 無音検出: ${silenceEnd}秒`);
//     return silenceEnd;
//   } else {
//     console.log(`🔍 無音なし検出`);
//     return 0;
//   }
// }
// function streamToString(stream) {
//   const chunks = [];
//   return new Promise((resolve, reject) => {
//     stream.on('data', (chunk) => {
//       if (typeof chunk === 'string') {
//         chunks.push(Buffer.from(chunk));
//       } else {
//         chunks.push(chunk);
//       }
//     });
//     stream.on('error', reject);
//     stream.on('end', () => resolve(Buffer.concat(chunks).toString('utf-8')));
//   });
// }

// すでに記事を動画化しているか判定
async function alreadyProcessed(articleLink) {
  const encodedURL = encodeURIComponent(articleLink);

  const okPath = `temp/OK_${encodedURL}.txt`;
  const ngPath = `temp/NG_${encodedURL}.txt`;

  const bucket = storage.bucket(bucketName);

  // OKまたはNGファイルどちらかあれば「処理済み」とみなす
  const [okExists] = await bucket.file(okPath).exists();
  const [ngExists] = await bucket.file(ngPath).exists();

  return okExists || ngExists;
}


// VTuberデータ入稿機能
exports.addVtuberData = functions.https.onRequest(async (request, response) => {
  // CORS設定
  response.set('Access-Control-Allow-Origin', '*');
  response.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  response.set('Access-Control-Allow-Headers', 'Content-Type');

  if (request.method === 'OPTIONS') {
    response.status(200).send('');
    return;
  }

  if (request.method !== 'POST') {
    response.status(405).json({
      success: false,
      error: 'Method not allowed. Use POST.'
    });
    return;
  }

  try {
    const newVtuberData = request.body;
    console.log('受信データ:', newVtuberData);

    // 必須フィールドの検証
    const requiredFields = ['name', 'channeID', 'office'];
    const missingFields = requiredFields.filter(field => !newVtuberData[field]);
    if (missingFields.length > 0) {
      response.status(400).json({
        success: false,
        error: `Missing required fields: ${missingFields.join(', ')}`
      });
      return;
    }

    // データベース参照を取得
    const vtuberRef = admin.database().ref('vtuber');
    const snapshot = await vtuberRef.once('value');
    const existingData = snapshot.val() || {};

    // 重複チェック
    const duplicateChecks = [];

    // チャンネルID重複チェック
    for (const [key, data] of Object.entries(existingData)) {
      if (data.channeID === newVtuberData.channeID) {
        duplicateChecks.push({
          type: 'channeID',
          existingKey: key,
          existingName: data.name,
          value: newVtuberData.channeID
        });
      }

      // Twitterネーム重複チェック（両方に値がある場合のみ）
      if (newVtuberData.twitterName && data.twitterName &&
        data.twitterName === newVtuberData.twitterName) {
        duplicateChecks.push({
          type: 'twitterName',
          existingKey: key,
          existingName: data.name,
          value: newVtuberData.twitterName
        });
      }
    }

    if (duplicateChecks.length > 0) {
      response.status(400).json({
        success: false,
        error: 'Duplicate data found',
        duplicates: duplicateChecks
      });
      return;
    }

    // 新しいキーを生成（既存の最大数値キー + 1）
    const numericKeys = Object.keys(existingData)
      .map(key => parseInt(key))
      .filter(num => !isNaN(num));

    const nextKey = numericKeys.length > 0 ? Math.max(...numericKeys) + 1 : 1;

    // データにタイムスタンプを追加
    const dataToAdd = {
      ...newVtuberData,
      createdAt: new Date().toISOString(),
      updateTime: new Date().toISOString()
    };

    // データベースに追加
    await vtuberRef.child(nextKey.toString()).set(dataToAdd);

    response.json({
      success: true,
      message: 'VTuber data added successfully',
      addedKey: nextKey.toString(),
      addedData: dataToAdd
    });

  } catch (error) {
    console.error('Add VTuber data error:', error);
    response.status(500).json({
      success: false,
      error: error.message
    });
  }
});