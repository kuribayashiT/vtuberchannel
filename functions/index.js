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
const functions = require('firebase-functions/v1');
const fs = require('fs');
const { Storage } = require('@google-cloud/storage');
const axios = require('axios');
const { google } = require('googleapis');
const API_KEY = 'AIzaSyDEJ47ME_oxje2r5XX6hHtMf-F8W2zINSE'; 

// The Firebase Admin SDK to access Firestore.
const admin = require("firebase-admin");
const cors = require("cors")({ origin: true });

const OpenAI = require('openai');
const Parser = require('rss-parser');
const parser = new Parser();
// admin.initializeApp();
admin.initializeApp({
  databaseURL: "https://vtuber-335811-default-rtdb.firebaseio.com", // ← ここに自分のURLを記載
  storageBucket: "vtuber-335811.appspot.com"
});
const db = admin.database();
const storage = admin.storage();
const bucket = storage.bucket();
const firestoreDB = admin.firestore();
let officeDataList = {};
let youtubeDataList = {};
let vtuberDataList = {};
let twitterDataList = {};

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
    //★★★★★★★★★★★★★★★
    // Realtime Databaseからデータを取得
    const snapshot = await db.ref('office').once('value');
    officeDataList = snapshot.val();
    //★★★★★★★★★★★★★★★
    // データをJSON形式でクライアントに返す
    response.status(200).json({ officeDataList });
  } catch (error) {
    console.error('Error:', error);
    response.status(500).json({ error: 'Something went wrong [officeDataList]' });
  }
});


exports.getFirebaseYoutubeData = functions.https.onRequest(async (request, response) => {
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
    //★★★★★★★★★★★★★★★
    const snapshot = await db.ref('youtube').once('value');
    youtubeDataList = snapshot.val();
    //★★★★★★★★★★★★★★★
    // データをJSON形式でクライアントに返す
    response.status(200).json({ youtubeDataList });
  } catch (error) {
    console.error('Error:', error);
    response.status(500).json({ error: 'Something went wrong [youtubeDataList]' });
  }
});

exports.getFirebaseVtuberData = functions.https.onRequest(async (request, response) => {
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
    const refVtuber = await db.ref('vtuber').once('value');;
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

      }catch (error) {
        console.error("エラー発生", error);
      }
      if(membar_channel_id_List_str_List.length - 1 == i){
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
          allvideos =[];
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
          weeklyLiveViewRanking =[];
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
      if (channel.kind === "youtube#channel") { 
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
      if(allChannelYoutubeApiInfo.length - 1 == mapIndex){
        // console.log("  == officeNameList:",officeNameList);
        // console.log("  == allChannelYoutubeApiInfo -> channelMap:",channelMap);

        let memberName = "";
        let ENTRY_LIST = [];

        // channel情報をアップデート
        for (const [index, channel_result] of allChannelYoutubeApiInfo.entries()) {
          let membar_channel_id = "";
          if (channel_result.kind === "youtube#channel") {  
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
              [todayStr]:todaysSubscriberCount
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
              feed = await parser.parseURL(RSS_URL);
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
                    }else{
                      // allvideosにあるが、終了していなかったVideoであれば追加。
                      let ongoingVideoExists = ongoingVideos.some(video => video.videoID === entry['yt:videoId']);
                      if (ongoingVideoExists){
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
                    for (const [videoindex, entry] of ENTRY_LIST.entries())  {
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
                        [entry['yt:videoId']]:{
                          office:mapOfficeString(channelOfficeKey),
                          officeKey:channelOfficeKey,
                          videoID:entry['yt:videoId'],
                          channelTitle:channelName, 
                          channelId:entry['yt:channelId'],
                          channelThumbnail: channelThumbnail, 
                          title: entry.title,
                          thumbnail: media_thumbnail,
                          viewCount: views,
                          goodCount: goodCount,
                          comparisonDay:comparisonDay,
                          publishedAt: entry["pubDate"],
                          duration: duration,
                          scheduledStartTime: scheduledStartTime,
                          actualStartTime: actualStartTime,
                          actualEndTime: actualEndTime,
                          concurrent_viewers: concurrentViewers,
                        }
                      });
                      const vtuberVideobjOValueAdd = Object.assign({}, {
                          office:mapOfficeString(channelOfficeKey),
                          officeKey:channelOfficeKey,
                          videoID:entry['yt:videoId'],
                          channelTitle:channelName,
                          channelId:entry['yt:channelId'],
                          channelThumbnail: channelThumbnail,
                          title: entry.title,
                          thumbnail: media_thumbnail,
                          viewCount: views,
                          goodCount: goodCount,
                          comparisonDay:comparisonDay,
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
                channeID:membar_channel_id,
                name:channel_result.snippet.title,
                office:channelMap[membar_channel_id].officeKey,
                officeFlg:channelMap[membar_channel_id].officeFlg,
                birthday:channelMap[membar_channel_id].birthday,
                debut:channelMap[membar_channel_id].debut,
                officeName:mapOfficeString(channelMap[membar_channel_id].officeKey),
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
                twitterSubscriberCountTransition:{},
                youtubeSubscriberCountTransition:{},
                videos:{},
                twitterName: memberName,
              }
            });
            const _youtubeValueAdd = Object.assign({}, {
              channeID:membar_channel_id,
              name:channel_result.snippet.title,
              office:channelMap[membar_channel_id].officeKey,
              officeFlg:channelMap[membar_channel_id].officeFlg,
              officeName:mapOfficeString(channelMap[membar_channel_id].officeKey),
              birthday:channelMap[membar_channel_id].birthday,
              debut:channelMap[membar_channel_id].debut,
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
              twitterSubscriberCountTransition:{},
              youtubeSubscriberCountTransition:{},
              videos:{},
              twitterName: memberName,
            });
            allYoutubeDataObj.push(_youtubeValueAdd);
            allYoutubeData.push(youtubeValueAdd);            

            // rankingYoutubeRegiDataに格納
            const rankingYoutubeRegi  = Object.assign({}, {
              channelId:membar_channel_id,
              channelThumbnail:channel_result.snippet.thumbnails.high.url,
              name:channel_result.snippet.title,
              office:mapOfficeString(channelMap[membar_channel_id].officeKey),
              youtubeSubscriberCount:channel_result.statistics.subscriberCount

            });
            rankingYoutubeRegiData.push(rankingYoutubeRegi);
            // rankingVideoCountDataに格納
            const rankingVideoCount  = Object.assign({}, {
              channelId:membar_channel_id,
              channelThumbnail:channel_result.snippet.thumbnails.high.url,
              name:channel_result.snippet.title,
              office:mapOfficeString(channelMap[membar_channel_id].officeKey),
              videoCount:channel_result.statistics.videoCount

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
            const _eventList  = Object.assign({}, {
              eventType:"createAt",
              channelId:membar_channel_id,
              channelThumbnail:channel_result.snippet.thumbnails.high.url,
              name:channel_result.snippet.title,
              office:mapOfficeString(channelMap[membar_channel_id].officeKey),
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
            const _eventBList  = Object.assign({}, {
              eventType:"birthday",
              channelId:membar_channel_id,
              channelThumbnail:channel_result.snippet.thumbnails.high.url,
              name:channel_result.snippet.title,
              office:mapOfficeString(channelMap[membar_channel_id].officeKey),
              birthday:channelMap[membar_channel_id].birthday,
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
          if(allChannelYoutubeApiInfo.length - 1 == index){
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
              if (!videoExists){
                // console.log('== videoExists、古いVideoData追加');
                vtuberVideoDataObj.push(oldVideoData)
                // console.log('== videoExists、古いVideoData追加 -> ',oldVideoData['videoID']);
                const _vtuberVideoValueAdd = Object.assign({}, {
                  [oldVideoData['videoID']]:{
                    office:oldVideoData['office'],
                    officeKey:oldVideoData['officeKey'],
                    videoID:oldVideoData['videoID'],
                    channelTitle:oldVideoData['channelTitle'], 
                    channelId:oldVideoData['channelId'],
                    channelThumbnail: oldVideoData['channelThumbnail'], 
                    title:oldVideoData['title'],
                    thumbnail:oldVideoData['thumbnail'],
                    viewCount:oldVideoData['viewCount'],
                    comparisonDay:oldVideoData['comparisonDay'],
                    publishedAt:oldVideoData['publishedAt'],
                    duration:oldVideoData['duration'],
                    scheduledStartTime:oldVideoData['scheduledStartTime'],
                    actualStartTime:oldVideoData['actualStartTime'],
                    actualEndTime:oldVideoData['actualEndTime'],
                    concurrent_viewers:oldVideoData['concurrent_viewers'],
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
                if (youtubeDataObj["channeID"] == membar_channel_id){
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
              
              // console.log("    == officeDataList作成 : mapOfficeString(channelData[officeKey])",mapOfficeString(channelData["office"]));
              if (officeDataList[mapOfficeString(channelData["office"])]) {
                officeDataList[mapOfficeString(channelData["office"])].push(channelData);

              } else {
                officeDataList[mapOfficeString(channelData["office"])] = [channelData];
              }
            }
            const customSort = (a, b) => {
              // pfficeFlg が true のものを先頭に
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
                  name: office,
                  office: mapOfficeString(office),
                  createdAt: admin.firestore.FieldValue.serverTimestamp(),
                };
                const docRef = await threadRef.add(newThread);
                // console.log(`New thread created with ID: ${docRef.id}`);
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
              //　officeDataListのファイルアップロード
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

// ================================================  
//  RSSからNewsデータ作成
//  scheduled every 1 hours
//  memory: '256MB'
//  timeoutSeconds: 540
// ================================================
// RSSフィードのURLを配列で指定
const rssFeeds = [
  // 'http://vtubernews.jp/index.rdf',
  // 'https://vtuber-matomeruyon.blog.jp/index.rdf',
  // 'https://www.moguravr.com/feed',
  // 'https://holosoku.com/feed',
  // 'https://moti-soku.com/feed',
  'https://news.google.com/rss/search?q=VTuber+OR+%E3%83%9B%E3%83%AD%E3%83%A9%E3%82%A4%E3%83%96+OR+%E3%81%AB%E3%81%98%E3%81%95%E3%82%93%E3%81%98&hl=ja&gl=JP&ceid=JP:ja'
  // 他のRSSフィードも追加可能
];
// 記事データを格納する配列
let allArticles = [];

// 定期的なニュース取得
exports.scheduledNewsUpdate = functions.pubsub
  .schedule('every 1 hours') // 1時間ごとに実行
  .timeZone('Asia/Tokyo') // タイムゾーンを設定
  .onRun( async (context)  => {
    try {
      const fetchFeedPromises = rssFeeds.map(fetchFeed);
      await Promise.all(fetchFeedPromises);
      // 日付順にソート
      allArticles.sort((a, b) => new Date(b.publishedAt) - new Date(a.publishedAt));
    
      // 一覧表示
      allArticles.forEach(article => {
        // console.log(`${article.title} - ${article.publishedAt}`);
      });
      // console.log(allArticles);

      // ファイルデータをメモリ内に書き込む
      const bucket = storage.bucket('vtuber-335811.appspot.com'); // ご自身のバケット名に置き換え
      const fileName = 'news.json';
      const file = bucket.file(fileName);
      const fileStream = file.createWriteStream({
        metadata: {
          contentType: 'application/json'
        },
        timeout: 5400000, // タイムアウトを調整（ミリ秒単位）
      });

      await new Promise((resolve, reject) => {
        const fileContents = JSON.stringify(allArticles);
        fileStream.end(fileContents);

        fileStream.on('finish', () => {
          // console.log('ニュースデータのアップロードが完了しました');
          resolve();
        });

        fileStream.on('error', (error) => {
          // console.error('アップロード中にエラーが発生しました:', error);
          reject(error);
        });
      });

    } catch (error) {
      // console.error('データの取得中にエラーが発生しました:', error);
    }
});


// ================================================  
// All Video List取得処理の定義
// ================================================
exports.getAllVideoData = functions.https.onRequest(async (request, response) => {
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
    const allvideosFile = bucket.file('allvideos.json'); // ダウンロードするJSONファイルのパスに置き換え
    allvideosFile.download((err, contents) => {
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
    response.status(500).json({ error: 'Something went wrong [allvideosFile]' });
  }
});


// ================================================  
// ニュース取得処理の定義
// ================================================
exports.getNewsData = functions.https.onRequest(async (request, response) => {
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
    const newsFile = bucket.file('news.json'); // ダウンロードするJSONファイルのパスに置き換え
    newsFile.download((err, contents) => {
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
    response.status(500).json({ error: 'Something went wrong [news]' });
  }
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
// 共通関数の定義
// ==============================================================================
// 単一のRSSフィードの取得
async function fetchFeed(feedUrl) {
  try {
    const feed = await parser.parseURL(feedUrl);
    // 画像取得を試みる
    let _imageUrl = ""
    try {
      _imageUrl = ""//feed.image.url
    } catch (error) {
      console.error(`Error fetching or parsing feed ${feedUrl}: ${error.message}`);
    }

    feed.items.forEach(item => {
      let date = new Date()
      if ( item.hasOwnProperty('date') ){
        date = formatDate(item.date)
      }else if  ( item.hasOwnProperty('pubDate') ){
        date = formatDate(item.pubDate)
      }
      let imageUrl = _imageUrl;
      let articleContentEncoded = "";
      try {
        articleContentEncoded = item['content:encoded'];
        if (articleContentEncoded) {
          const imageUrlRegex = /https?:\/\/[^\s]+?\.(jpg|png)/g; // jpg または webp を含むURLを正規表現で検索
          const matches = articleContentEncoded.match(imageUrlRegex);
  
          if (matches && matches.length >= 2) {
            imageUrl = matches[1];
            // console.log(`Image URL: ${imageUrl}`);
          } else {
            // console.log(`Image URL: No image URL found.`);
          }
        } else {
          // console.log(` No content:encoded section found. Skipping.`);
        }
      } catch (error) {
        articleContentEncoded = item.contentEncoded;
      }

      const article = {
        channel: feed.title,
        title: item.title,
        publishedAt: date,
        description: item.description,
        url: item.link,
        creator: item.creator,
        urlToImage: imageUrl
        // 他の記事データも必要に応じて追加
      };
      allArticles.push(article);
    });
  } catch (error) {
    console.error(`Error fetching or parsing feed ${feedUrl}: ${error.message}`);
  }
};

function getLastValue (transition) {
    let lastDate = null;
    if (!transition || Object.keys(transition).length === 0) {
      return null;
    }

    if (!lastDate) {
      // lastDate がまだ初期化されていない場合、最後の日付を計算
      lastDate = Object.keys(transition).reduce((latest, date) => {
        return date > latest ? date : latest;
      });
    }
    return transition[lastDate];
}

// 文字列マッピング関数
function mapOfficeString(input) {
    var mapping = {
        "hololive": "ホロライブ",
        "holoEN": "ホロライブEnglish",
        "holoID": "ホロライブインドネシア",
        "personal": "個人",
        "KizunaAI": "Kizuna AI",
        "holostars": "ホロスターズ",
        ".LIVE": ".LIVE",
        "Vshojo": "VShojo",
        "noripuro": "のりプロ",
        "nijisannji": "にじさんじ",
        "nanashiinc": "ななしいんく",
        "aogirigakuen": "あおぎり高校",
        "vsupo":"ぶいすぽっ",
        // 他のマッピングも追加できます
    };
    if (mapping.hasOwnProperty(input)) {
        return mapping[input];
    }
    return input; // マッピングが見つからない場合はそのままの文字列を返す
}
// 日付文字列のフォーマットを統一する関数
function formatDate(dateString) {
  // "Sun, 24 Mar 2024 01:00:40 +0000" 形式を "2024-03-24T10:30:20+09:00" 形式に変換する例
  const date = new Date(dateString);
  const isoDateString = date.toISOString();
  return isoDateString;
}


// ==============================================================================  
// 共通関数の定義
// ==============================================================================
// const openai = new OpenAI({
//   apiKey: functions.config().openai.api_key, // Firebase環境変数からAPIキーを取得
// });
// // メイン関数（Cloud Function）
// exports.generateBlogFromLatestNews = async (req, res) => {
//   try {
//     const feed = await parser.parseURL('https://vtuber-matomeruyon.blog.jp/index.rdf');
//     const latestItem = feed.items[0];

//     const prompt = `以下のタイトルに基づいて、ブログ記事を800文字程度で生成してください。\n\nタイトル: ${latestItem.title}`;
//     const completion = await openai.chat.completions.create({
//       model: 'gpt-3.5-turbo',
//       messages: [{ role: 'user', content: prompt }],
//       temperature: 0.7,
//     });

//     const blogText = completion.choices[0].message.content;
//     res.status(200).send(blogText);
//   } catch (error) {
//     console.error('Error:', error);
//     res.status(500).send('Error generating blog.');
//   }
// };
// メイン関数（Cloud Function）
// import { generateSRTFromVoicevoxTiming } from './video-merger/utils/generateSRTFromVoicevoxTiming.js';
// exports.generateBlogFromLatestNews = async (req, res) => {
//   try {
//     const feed = await parser.parseURL('https://vtuber-matomeruyon.blog.jp/index.rdf');
//     const latestItem = feed.items[0];
//     const title = latestItem.title;

//     const prompt = `以下のタイトルに基づいて、ブログ記事を600文字程度で、SNSなどの反応も交えて生成してください。\n\nタイトル: ${title}`;
//     const completion = await openai.chat.completions.create({
//       model: 'gpt-3.5-turbo',
//       messages: [{ role: 'user', content: prompt }],
//       temperature: 0.7,
//     });

//     const blogText = completion.choices[0].message.content;
//     const VOICEVOX_ENGINE_URL = 'https://voicevox-engine-xxxx.a.run.app';
//     const speakerId = 1;

//     const queryRes = await axios.post(
//       `${VOICEVOX_ENGINE_URL}/audio_query?text=${encodeURIComponent(blogText)}&speaker=${speakerId}`,
//       null,
//       { headers: { 'Accept': 'application/json' } }
//     );

//     let audioQuery = queryRes.data;
//     audioQuery.speedScale = 1.2;
//     audioQuery.postPhonemeLength = 0.1;

//     const synthRes = await axios.post(
//       `${VOICEVOX_ENGINE_URL}/synthesis?speaker=${speakerId}`,
//       audioQuery,
//       {
//         headers: { 'Content-Type': 'application/json' },
//         responseType: 'arraybuffer',
//         timeout: 600000,
//       }
//     );

//     const audioBuffer = Buffer.from(synthRes.data);
//     const audioFileName = `audio-${Date.now()}.wav`;
//     const audioTempPath = `/tmp/${audioFileName}`;
//     fs.writeFile(audioTempPath, audioBuffer);
//     console.log(`✅ 音声生成完了: ${tempAudioPath}`);


//     const gcsAudioUri = `generated/audio/${audioFileName}`;
//     await storage.bucket(bucketName).upload(audioTempPath, {
//       destination: gcsAudioUri,
//     });

//     // 🔤 字幕を生成（VOICEVOXの音素タイミングを元に）
//     const totalDuration = audioQuery.outputSamplingRate > 0 ? audioBuffer.length / (audioQuery.outputSamplingRate * 2) : 30;
//     const srtPath = `/tmp/subtitle-${Date.now()}.srt`;
//     await generateSRTFromVoicevoxTiming(audioQuery, blogText, srtPath, totalDuration);
//     console.log(`✅ 字幕生成完了: ${srtPath}`);


//     const gcsSrtUri = `generated/subtitles/${Date.now()}.srt`;
//     await storage.bucket(bucketName).upload(srtPath, {
//       destination: gcsSrtUri,
//     });

//     // ✅ 動画合成サービスを呼び出し（Cloud Run）
//     const mergeResponse = await axios.post('https://video-merger-xxxx.a.run.app/merge', {
//       videoUri: 'gs://your-bucket/input/background.mp4',
//       audioUri: `gs://${bucketName}/${gcsAudioUri}`,
//       subtitleSrtUri: `gs://${bucketName}/${gcsSrtUri}`,
//       outputUri: `generated/output/output-${Date.now()}.mp4`,
//     });

//     res.json({
//       message: '🎉 動画生成成功',
//       outputVideoUri: mergeResponse.data.outputUri,
//     });

//   } catch (error) {
//     console.error('🔥 処理失敗:', error?.response?.data || error);
//     res.status(500).send('動画生成に失敗しました。');
//   }
// };


// // メイン関数（Cloud Function）
// exports.generateBlogVideoFromLatestNews = async (req, res) => {
//   try {
//     // RSSフィードを解析して最新ニュースを取得
//     const feed = await parser.parseURL('https://vtuber-matomeruyon.blog.jp/index.rdf');
//     const latestItem = feed.items[0];
//     const title = latestItem.title;

//     // ChatGPTでブログ生成
//     const prompt = `以下のタイトルに基づいて、ブログ記事を600文字程度で、SNSなどの反応も交えて生成してください。\n\nタイトル: ${title}`;
//     const completion = await openai.chat.completions.create({
//       model: 'gpt-3.5-turbo',
//       messages: [{ role: 'user', content: prompt }],
//       temperature: 0.7,
//     });

//     // OpenAIレスポンスの中身をログ出力
//     console.log("OpenAI Completion Response:", JSON.stringify(completion, null, 2));
//     const blogText = completion.choices[0].message.content; // 完成したブログ内容
//     console.log("Generated blog text:", blogText);

//     // VOICEVOX ENGINE の URL（Cloud Run）
//     const VOICEVOX_ENGINE_URL = 'https://voicevox-engine-44ispcgxza-an.a.run.app';
//     const speakerId = 1;
    
//     // Step1: audio_query を取得（GET + URLエンコード）
//     const queryRes = await axios.post(
//       `${VOICEVOX_ENGINE_URL}/audio_query?text=${encodeURIComponent(blogText)}&speaker=${speakerId}`,
//       null,
//       {
//         headers: { 'Accept': 'application/json' },
//       }
//     );
//     let audioQuery = queryRes.data;

//     // 🎵 再生速度を上げる（デフォルト: 1.0）
//     audioQuery.speedScale = 1.2;
//     audioQuery.postPhonemeLength = 0.1;
    
//     console.log("Modified Audio Query with speedScale:", audioQuery);
    
//     // Step2: synthesis で音声生成
//     const synthRes = await axios.post(
//       `${VOICEVOX_ENGINE_URL}/synthesis?speaker=${speakerId}`,
//       audioQuery,
//       {
//         headers: { 'Content-Type': 'application/json' },
//         responseType: 'arraybuffer',
//         timeout: 600000,
//       }
//     );
//     console.log("Synthesis Response: Audio Data received");

//     // 音声を返却
//     const buffer = Buffer.from(synthRes.data);
//     res.set('Content-Type', 'audio/wav');
//     res.set('Content-Length', buffer.length);
//     res.set('Accept-Ranges', 'bytes');  // ブラウザのシーク対応
//     res.send(buffer);
//         // res.send(synthRes.data);

//   } catch (error) {
//     console.error('Error generating blog or synthesizing voice:', error?.response?.data || error);
//     res.status(500).send('Error generating blog or synthesizing voice.');
//   }
// };

const { v4: uuidv4 } = require("uuid");
const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
// const openai = new OpenAI({
//   apiKey: functions.config().openai.api_key, // Firebase環境変数からAPIキーを取得
// });
// 🔥 ここで GCS バケットの初期化（関数の外！）
const { exec } = require('child_process');
const util = require('util');
const execAsync = util.promisify(exec);
const storage_ = new Storage();
const bucketName = 'vtuber-335811.appspot.com';
const bucket_ = storage_.bucket(bucketName);
// const path = require('path');
// const TEMP_DIR = '/temp';
// const TMP_OUTPUT_DIR = path.join(TEMP_DIR, 'output');
const VOICEVOX_ENGINE_URL = "https://voicevox-engine-23130474318.asia-northeast1.run.app";
// const VOICEVOX_ENGINE_URL = 'https://voicevox-engine-44ispcgxza-an.a.run.app';
let speedScale = 1.4;
let finalURL = "";
const SPEAKER_ID = 1; // ずんだもん等（適宜変更）
const { youtubeUpload } = require('./youtubeUpload');


//exports.generateBlogVideoFromLatestNews = async (req, res) => {
exports.generateBlogVideoFromLatestNews = functions.https.onRequest(async (req, res) => {
  // CORS対応
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST');
  res.set('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }
  // if (req.method !== 'POST') {
  //   res.status(405).send('Method Not Allowed');
  //   return;
  // }
  const uuid = uuidv4();
  let blogText = "";
  let videoTitle = "";
  let videoTags = [];
  try {
      // POSTで受け取ったデータ（UIから来た場合）
      const { _videoTitle, _blogText, _videoTags } = req.body || {};
      blogText = _blogText;
      videoTitle = _videoTitle;
      videoTags = _videoTags;
  }catch (err) {
    console.error('_blogTextがからのため自動生成モードで実行');
  }

  try {
    if (!blogText) {
      // 自動実行モード
      const feed = await parser.parseURL('https://news.google.com/rss/search?q=VTuber+OR+%E3%83%9B%E3%83%AD%E3%83%A9%E3%82%A4%E3%83%96+OR+%E3%81%AB%E3%81%98%E3%81%95%E3%82%93%E3%81%98&hl=ja&gl=JP&ceid=JP:ja');
      //const feed = await parser.parseURL('https://news.google.com/rss/search?q=VTuber&hl=ja&gl=JP&ceid=JP:ja');

        // pubDateでソート
      const sortedItems = feed.items.sort((a, b) => {
        return new Date(b.pubDate) - new Date(a.pubDate); // 新しい順
      });
      const latestItem = sortedItems[0];
      console.log(latestItem.title);
      console.log(latestItem.link);
      const title = latestItem.title;
      const articleLink = latestItem.link;

      const isAlreadyProcessed = await alreadyProcessed(articleLink);
      if (isAlreadyProcessed) {
        console.log(`スキップ：すでに生成済み - > ${articleLink}`);

        res.status(200).send(`スキップ：すでに生成済み - > ${articleLink}`);
        return; // 処理終了
      }else{
        console.log(`スタート：動画を生成します - > ${articleLink}`);
      }
      finalURL = articleLink;
      const articleText = await getArticleContent(articleLink);
      let prompt = "";
      console.log("記事:", articleText);
      
      // const status = articleText ? 'OK' : 'NG';
      // const safeFileName = getSafeFileNameFromUrl(articleLink);
      
      // // 既存の文字列テンプレートの形を維持
      // const filePath = `temp/${status}_${safeFileName}.txt`;
      // const tempFilePath = `/tmp/${status}_${safeFileName}.txt`; 
      
      // // 一時ファイルとして保存
      // await fs.promises.writeFile(tempFilePath, articleText || '', { encoding: 'utf8' });
      
      // // Cloud Storageにアップロード
      // await storage.bucket(bucketName).upload(tempFilePath, {
      //   destination: filePath,
      // });

      // console.log(`記事を ${filePath} に保存しました`);
      
      if (articleText) {
        // スクレイピングした記事内容を元に台本を生成
        // await generateScript(articleText);
        prompt = `以下のVtuberに関連する記事を要約し、youtubeにアップするためのニュース動画の台本を作成してください。youtubeにアップした際再生数が取れそうな内容にしたいです。必要であればSNSでの反響なども踏まえつつ、台本のボリュームは全体で400文字以内で、改行せず、台本の本文のみを出力してください（そのまま機械的に読み上げるので【ニュース記事】などのタイトルは不要）。\n記事: ${articleText}`;
      } else {
        console.log('記事の取得に失敗しました。タイトルで生成します。');
        prompt = `以下の記事タイトルに基づいて、youtubeにアップするニュース記事の台本を400文字以内で、Vtuberに関連するニュースのみを改行せず台本の本文のみを出力してください（そのまま機械的に読み上げるので【ニュース記事】などのタイトルは不要）。\nタイトル: ${title}`;
      }

      const completion = await openai.chat.completions.create({
        model: 'gpt-3.5-turbo',
        messages: [{ role: 'user', content: prompt }],
        temperature: 0.7,
      });
      blogText = completion.choices[0].message.content;
      console.log("[自動モード]GGenerated blog text:", blogText);
    }else{
      // 手動モード
      console.log("[手動モード]Generated blog text:", blogText);
    }


    if (!videoTitle) {
      // Title自動モード
      const title_prompt = `以下の台本の内容を見上げる形でyoutube動画にしようとしています。その際の動画タイトルを、再生数が取れそうな引きのある文言で20文字程度までの長さで作成してください。台本：${blogText}`;
      const title_completion = await openai.chat.completions.create({
        model: 'gpt-3.5-turbo',
        messages: [{ role: 'user', content: title_prompt }],
        temperature: 0.7,
      });
      videoTitle = title_completion.choices[0].message.content;
      console.log("[自動モード]GGenerated Title:", videoTitle);
    }else{
      // Title手動モード
      console.log("[手動モード]Generated Title:", videoTitle);
    }


    // タイトルとブログ結合
    blogText = `${videoTitle}\n${blogText}\n以上のニュース詳細は概要欄にて。このチャンネルでは、\nこのようなVtuber関連ニュースの\n解説を最速で投稿しています。\nよろしければ、\nチャンネル登録と高評価をお願いします。`;
    console.log("Generated blog text+Title:", blogText);

    const description_prompt = `以下の台本をyoutube動画にする際の動画のdescriptionを、300文字程度までで日本語で作成してください。先ほどの台本：${blogText}`;
    const description_completion = await openai.chat.completions.create({
      model: 'gpt-3.5-turbo',
      messages: [{ role: 'user', content: description_prompt }],
      temperature: 0.7,
    });
    let videoDescription = description_completion.choices[0].message.content;

    videoDescription = `${videoDescription}\n\nニュース詳細:${finalURL}\n`;
    console.log("Generated blog videoDescription:", videoDescription);

    const furigana_prompt = `以下の文章全てをVOICEVOXに正しく読ませるために、「Vtuber」を「ブイチューバー」など、英単語やアルファベットで書かれている名詞や英単語をすべて日本語の読み仮名（カタカナ）に変換してください。\n文章：${blogText}`;
    const furigana_completion = await openai.chat.completions.create({
      model: 'gpt-3.5-turbo',
      messages: [{ role: 'user', content: furigana_prompt }],
      temperature: 0.7,
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
        messages: [{ role: 'user', content: tags_prompt }],
        temperature: 0.7,
      });
      const rawText = tags_completion.choices[0].message.content.trim();

      // 最初の JSON 配列っぽい部分を正規表現で抽出
      const match = rawText.match(/\[[\s\S]*?\]/);
      videoTags = ['vtuber','毎日投稿','ニュース']; // フォールバック

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
    }else{
      // Tag手動モード
      console.log("[手動モード]Generated Tag:", videoTags);

    }


    // 1. VOICEVOX: 音声合成　2. 字幕生成
     await generateVoiceAndSRT(furiganaText,blogText,uuid);

    // 🎞️ 動画合成リクエスト
    const videoMergerUrl = 'https://video-merger-23130474318.asia-northeast1.run.app/merge';
    const videoGcsUri = await getRandomBackgroundGcsUri(bucketName);//'gs://vtuber-335811.appspot.com/background.mp4';
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
    // ✅ 後始末（音声・字幕ファイルを削除）
    await deleteGcsFile(bucketName, `output/output-${uuid}.wav`);
    await deleteGcsFile(bucketName, `output/output-${uuid}.srt`);

    // ~~~~~~~~~~~~~~~~~~~~
    // // ② アップロード実行（バケット名と動画ファイル名を指定）
    const videoId = await youtubeUpload(bucketName, outputFilePath,videoTitle,videoDescription,videoTags);
    await deleteGcsFile(bucketName, outputFilePath);

    res.status(200).send(`動画を生成してYouTubeにアップロードしました: https://youtu.be/${videoId}`);
    // // ~~~~~~~~~~~~~~~~~~~~

  } catch (error) {
    console.error('Error generating blog or merging video:', error?.response?.data || error);
    res.status(500).send('Error generating blog or merging video.');
  }
});
const express = require('express');
const app = express();
app.use(express.json());
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
// ===============================
// 🎬 Util
// ===============================

const crypto = require('crypto');

// ハッシュ + 短縮名で安全なファイル名を作成
function getSafeFileNameFromUrl(url) {
  const hash = crypto.createHash('sha256').update(url).digest('hex').slice(0, 16);
  const shortId = url.split('/').pop()?.slice(0, 20).replace(/[^a-zA-Z0-9-_]/g, '') || 'article';
  return `${shortId}_${hash}`;
}

const puppeteer = require('puppeteer-core');
const chromium = require('@sparticuz/chromium');
// 記事内容を取得する関数
async function getArticleContent(url) {
  const browser = await puppeteer.launch({
    args: ['--no-sandbox', '--disable-setuid-sandbox'],
    executablePath: await chromium.executablePath(),
    headless: chromium.headless,
  });

  const page = await browser.newPage();

  try {
    await page.setUserAgent(
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3'
    );

    // 文字化け対策として UTF-8 を優先
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
      return '';
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
          document.querySelectorAll('article p').length > 0
        );
      }, { timeout: 30000 });

      articleText = await extractParagraphs(page);
    }

    await browser.close();

    // URL を先頭に追加
    return `【出典】${finalURL}\n\n${articleText}`;
  } catch (error) {
    console.error('Error fetching article:', error);
    await browser.close();
    return null;
  }
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

// ファイルアップロード共通
async function uploadToGCS(localPath,remotePath) {
  console.log(`☁️ Upload ${localPath} to gs://${bucketName}/${remotePath}`);
  await storage.bucket(bucketName).upload(localPath, {
    destination: remotePath,
  });
  console.log(`☁️ Uploaded ${localPath} to gs://${bucketName}/${remotePath}`);

}

// 音声生成
async function synthesizeSentence(text, index,uuid) {
  const queryResp = await axios.post(`${VOICEVOX_ENGINE_URL}/audio_query`, null, {
    params: { text, speaker: SPEAKER_ID },
  });
  queryResp.data.speedScale = 1.4;
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

async function generateVoiceAndSRT(text, srttext,uuid) {
  const sentences = text
    .split(/(?<=[。！？])/)
    .map(s => s.trim())
    .filter(Boolean);

  const srtsentences = srttext
    .split(/(?<=[。！？])/)
    .map(s => s.trim())
    .filter(Boolean);

  const audioFiles = [];
  const durations = [];
  let srtContent = '';
  let currentTime = 0;

  const tokenizer = await new Promise((resolve, reject) => {
    kuromoji.builder({ dicPath: 'node_modules/kuromoji/dict' }).build((err, tokenizer) => {
      if (err) return reject(err);
      resolve(tokenizer);
    });
  });
  for (let i = 0; i < sentences.length; i++) {
    const sentence = sentences[i];
    const srtsentence = srtsentences[i];

    // kuromoji で長文センテンスを分割（音声と字幕タイミング）
    const fragments = splitLongSentenceWithKuromoji(tokenizer, srtsentence, 32);

    for (let frag of fragments) {
      console.log(`🔊 音声生成中: ${frag}`);
      const filePath = await synthesizeSentence(frag, audioFiles.length,uuid);
      audioFiles.push(filePath);

      let duration = await getAudioDuration(filePath);
      if (isNaN(duration)) {
        console.log(`❌ duration が NaN: filePath=${filePath}`);
        duration = 0;
      }
      durations.push(duration);

      const start = formatSrtTime(currentTime);
      const end = formatSrtTime(currentTime + duration);

      let wrapped = await wrapWithKuromoji(frag); // 字幕行の改行（16文字など）
      wrapped = cleanUpWrappedText(wrapped);
      console.log(`📝 字幕生成中: ${wrapped}`);
      srtContent += `${audioFiles.length}\n${start} --> ${end}\n${wrapped}\n\n`;

      currentTime += duration;
    }
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


function formatSrtTime(seconds) {
  if (typeof seconds !== 'number' || isNaN(seconds) || seconds < 0) {
    throw new Error(`Invalid time value passed to formatSrtTime: ${seconds}`);
  }

  const ms = Math.floor(seconds * 1000);
  const date = new Date(ms);
  const iso = date.toISOString(); // "1970-01-01T00:00:12.345Z"
  return iso.substr(11, 12).replace('.', ',');
}
const ffmpeg = require("fluent-ffmpeg");

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

const kuromoji = require('kuromoji'); 
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

// async function wrapSubtitleText(text, maxLength = 16) {
//   if (typeof text !== 'string' || !text.trim()) return '';

//   const prompt =  `
// 以下の文章を、字幕として読みやすいように、1行${maxLength}文字以内で改行してください。
// 改行には必ず "\\N" を使ってください。
// 可能な限り文章全体の意味が伝わるよう自然なところで改行してください。

// ただし、「、」「。」などの句読点の直前や後であっても、1行の文字数制限(${maxLength}文字以内)を最優先してください。

// 文章:
// ${text}
// `;

//   try {
//     const response = await openai.chat.completions.create({
//       model: 'gpt-3.5-turbo',
//       messages: [{ role: 'user', content: prompt }],
//       temperature: 0.7,
//     });

//     let output = response.choices[0].message.content;
//     output = output.replace(/\r?\n/g, ''); // 改行除去
//     console.log('📤 ChatGPTからの生出力:', output);
//     const lines = output.split('\\N');

//     // ✅ 全角長チェックに修正
//     const allLinesValid = lines.every(line => countVisibleCharacters(line.trim()) <= maxLength);

//     if (!allLinesValid) {
//       console.warn('⚠ ChatGPT output exceeded max full-width length. Falling back to JS logic.');
//       return fallbackLineWrap(text, maxLength);
//     }

//     return lines.map(line => line.trim()).join('\\N');

//   } catch (err) {
//     console.error('❌ ChatGPT API エラー:', err.message);
//     console.log(`エラーになったので、JSロジックにて改行処理を実施`);
//     return fallbackLineWrap(text, maxLength);
//   }
// }

// // ✅ JS側のフェイルセーフ改行処理
// function fallbackLineWrap(text, maxLength) {
//   if (typeof text !== 'string') return '';

//   const avoidBreakingWords = ['EN', 'Official', 'Store', 'NIJISANJI'];
//   const result = [];
//   let buffer = '';

//   // 一旦、「、」「。」の後で仮の分割を入れてから処理
//   const preSplit = text
//     .replace(/(、|。)/g, '$1|') // 「、」「。」の直後に仮の区切り記号（|）を挿入
//     .split('|')                 // その記号で分割
//     .map(s => s.trim())         // 前後の空白削除
//     .filter(Boolean);           // 空文字除去

//   for (let fragment of preSplit) {
//     const newBuffer = (buffer + fragment).trim();

//     if (
//       avoidBreakingWords.some(w => fragment.includes(w)) ||
//       countVisibleCharacters(newBuffer) > maxLength
//     ) {
//       if (buffer) result.push(buffer.trim());
//       buffer = fragment;
//     } else {
//       buffer = newBuffer;
//     }
//   }

//   if (buffer) result.push(buffer.trim());

//   return result.join('\\N');
// }

// countVisibleCharacters は全角＝2, 半角＝1でカウント
// function countVisibleCharacters(text) {
//   let count = 0;
//   for (const char of text) {
//     count += /[ -~]/.test(char) ? 1 : 2; // 半角なら1, 全角なら2
//   }
//   return count;
// }




// SRT 時間形式に変換
function formatTime(seconds) {
  const ms = Math.floor((seconds % 1) * 1000);
  const s = Math.floor(seconds % 60);
  const m = Math.floor((seconds / 60) % 60);
  const h = Math.floor(seconds / 3600);
  return `${pad(h)}:${pad(m)}:${pad(s)},${pad(ms, 3)}`;
}

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

async function detectInitialSilence(audioPath) {
  const cmd = `ffmpeg -i ${audioPath} -af silencedetect=noise=-40dB:d=0.1 -f null -`;
  const { stdout, stderr } = await exec(cmd);

  // stderrが文字列じゃなかったら、無理やり中身読む
  let stderrString;
  if (typeof stderr === 'string') {
    stderrString = stderr;
  } else if (Buffer.isBuffer(stderr)) {
    stderrString = stderr.toString('utf-8');
  } else if (typeof stderr?.read === 'function') {
    // ストリームっぽかったら、中身を全部読む
    stderrString = await streamToString(stderr);
  } else {
    console.error('stderrが想定外の型です:', stderr);
    stderrString = '';
  }
  
  console.log('🔍 ffmpeg無音検出ログ:', stderrString);

  const silenceStartMatch = stderrString.match(/silence_start: (\d+(\.\d+)?)/);
  const silenceEndMatch = stderrString.match(/silence_end: (\d+(\.\d+)?)/);

  if (silenceStartMatch && silenceEndMatch) {
    const silenceEnd = parseFloat(silenceEndMatch[1]);
    console.log(`🔍 無音検出: ${silenceEnd}秒`);
    return silenceEnd;
  } else {
    console.log(`🔍 無音なし検出`);
    return 0;
  }
}
function streamToString(stream) {
  const chunks = [];
  return new Promise((resolve, reject) => {
    stream.on('data', (chunk) => {
      if (typeof chunk === 'string') {
        chunks.push(Buffer.from(chunk));
      } else {
        chunks.push(chunk);
      }
    });
    stream.on('error', reject);
    stream.on('end', () => resolve(Buffer.concat(chunks).toString('utf-8')));
  });
}
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


// // 長文を最大3行・12文字ずつに改行（句読点優先）
// function wrapSubtitleText(text, maxLineLength = 20, maxLines = 15) {
//   const lines = [];

//   // 句読点や助詞、スペースなどで切れる位置を優先
//   //const breakChars = ['。', '、', '！', '？', '・', ' ', '　'];
//   const breakChars = ['。', '、', '！', '？', '・', '\N', '】', '」'];
//   //const breakChars = ['。', '、', '！', '？', '・'];
//   //const breakChars = ['。'];

//   let remaining = text;

//   for (let i = 0; i < maxLines && remaining.length > 0; i++) {
//     // まず最大長の部分を取り出す
//     let sliceEnd = Math.min(maxLineLength, remaining.length);
//     let candidate = remaining.slice(0, sliceEnd);

//     // 最後の breakChar の位置で改行する
//     let bestBreak = -1;
//     for (let j = candidate.length - 1; j >= 0; j--) {
//       if (breakChars.includes(candidate[j])) {
//         bestBreak = j + 1;
//         break;
//       }
//     }

//     // breakCharが見つからない → 強制的に13文字
//     if (bestBreak === -1) bestBreak = sliceEnd;

//     const line = remaining.slice(0, bestBreak).trim();
//     lines.push(line);
//     remaining = remaining.slice(bestBreak).trim();
//   }

//   return lines.join("\\N");
// }


// async function generateSRTFromVoicevoxTiming(text, srtPath, speakerId = 1,synthesisRes,query) {


//   const tmpAudioPath = "/tmp/voice.wav";
//   await fs.promises.writeFile(tmpAudioPath, Buffer.from(synthesisRes.data));

//   // 3. 無音時間を検出
//   const silenceStart = await detectSilenceStart(tmpAudioPath);
//   console.log('⏱️ silenceStart:', silenceStart, '秒');

//   // 4. 実際の音声の長さを取得
//   const realAudioDuration = await getAudioDuration(tmpAudioPath);
//   console.log('⏱️ realAudioDuration:', realAudioDuration, '秒');

//   // 5. モーラ＋pause分長さを集計
//   const rawLengths = [];
//   for (const phrase of query.accent_phrases) {
//     for (const mora of phrase.moras) {
//       rawLengths.push((mora.consonant_length || 0) + (mora.vowel_length || 0));
//     }
//     if (phrase.pause_mora) {
//       rawLengths.push(phrase.pause_mora.vowel_length || 0.3);
//     }
//   }

//   const estimatedDuration = rawLengths.reduce((a, b) => a + b, 0);
//   const scale = realAudioDuration / estimatedDuration;
//   const adjustedScale = scale * (query.speedScale || 1);//scale ;//* (query.speedScale || 1);

//   const scaledLengths = rawLengths.map(l => l * adjustedScale);
//   const cumTimes = [0];
//   for (let i = 0; i < scaledLengths.length; i++) {
//     cumTimes.push(cumTimes[i] + scaledLengths[i]);
//   }

//   // 6. 文単位に分ける
//   // const sentences = text.split(/(?<=[。！？])/).map(s => s.trim()).filter(Boolean);
//   const sentences = text
//   .split(/(?<=[。！？、・…‥\n])|(?=そして|しかし|つまり|そのため|なお|ただし)/)
//   .map(s => s.trim())
//   .filter(Boolean);
//   const moraCountPerSentence = [];
//   let moraIdx = 0;
//   for (const sentence of sentences) {
//     let count = 0;
//     while (count < sentence.length && moraIdx < rawLengths.length) {
//       count++;
//       moraIdx++;
//     }
//     moraCountPerSentence.push(count);
//   }

//   // 無音検出
//   const initialSilence = await detectInitialSilence(tmpAudioPath);

//   // 7. SRTファイル作成
//   const OFFSET = silenceStart > 0 ? -silenceStart-3 : -3;
//   // const OFFSET = -silenceStart;
//   let startMora = 0;
//   const srtLines = [];
//   srtLines.push(''); 
//   const totalAudioDuration = realAudioDuration + silenceStart; // 音声と無音を合わせた合計時間
//   let adjustedTimeScale = realAudioDuration / totalAudioDuration; // 全体の時間スケール調整

//   for (let i = 0; i < sentences.length; i++) {
//     const count = moraCountPerSentence[i];
//     const endMora = startMora + count;

//     // 無音時間と全体スケールに基づいて時間を調整
//     const startTime = Math.max(cumTimes[startMora] - initialSilence + OFFSET, 0);
//     const endTime   = Math.max(cumTimes[endMora] + initialSilence - OFFSET, 0);
//     // const startTime = Math.max(cumTimes[startMora] + OFFSET, 0);
//     // const endTime   = Math.max(cumTimes[endMora] + OFFSET, 0);

//     // ここで調整後のタイムスケールを適
//     const adjustedStart = startTime * adjustedTimeScale;
//     const adjustedEnd = endTime * adjustedTimeScale;

//     const start = formatTime(adjustedStart);
//     const end = formatTime(adjustedEnd);
//     const wrapped = wrapSubtitleText(sentences[i]);

//     srtLines.push(`${i+1}\n${start} --> ${end}\n  ${wrapped}\n`);
//     startMora = endMora;
//   }

//   await fs.promises.writeFile(srtPath, srtLines.join("\n\n"), "utf-8");
//   console.log('✅ 字幕書き出し完了:', srtPath);
// }

// // 時間を "00:00:00,000" 形式にする
// function formatTime(seconds) {
//   const date = new Date(seconds * 1000);
//   const hh = String(date.getUTCHours()).padStart(2, '0');
//   const mm = String(date.getUTCMinutes()).padStart(2, '0');
//   const ss = String(date.getUTCSeconds()).padStart(2, '0');
//   const ms = String(date.getUTCMilliseconds()).padStart(3, '0');
//   return `${hh}:${mm}:${ss},${ms}`;
// }

// function pad(n, z = 2) {
//   return n.toString().padStart(z, "0");
// }

// exports.generateBlogVideoFromLatestNews = async (req, res) => {
//   // if (req.method !== 'POST') {
//   //   res.status(405).send('Method Not Allowed');
//   //   return;
//   // }
//   const uuid = uuidv4();
//   try {
//     const feed = await parser.parseURL('https://news.google.com/rss/search?q=VTuber+OR+%E3%83%9B%E3%83%AD%E3%83%A9%E3%82%A4%E3%83%96+OR+%E3%81%AB%E3%81%98%E3%81%95%E3%82%93%E3%81%98&hl=ja&gl=JP&ceid=JP:ja');
//     //const feed = await parser.parseURL('https://news.google.com/rss/search?q=VTuber&hl=ja&gl=JP&ceid=JP:ja');

//       // pubDateでソート
//     const sortedItems = feed.items.sort((a, b) => {
//       return new Date(b.pubDate) - new Date(a.pubDate); // 新しい順
//     });
  
//     const latestItem = sortedItems[0];
//     console.log(latestItem.title);
//     console.log(latestItem.link);
//     const title = latestItem.title;
//     const articleLink = latestItem.link;

//     const isAlreadyProcessed = await alreadyProcessed(articleLink);
//     if (isAlreadyProcessed) {
//       console.log(`スキップ：すでに生成済み - > ${articleLink}`);

//       res.status(200).send(`スキップ：すでに生成済み - > ${articleLink}`);
//       return; // 処理終了
//     }else{
//       console.log(`スタート：動画を生成します - > ${articleLink}`);
//     }
//     finalURL = articleLink;
//     const articleText = await getArticleContent(articleLink);
//     let prompt = "";
//     console.log("記事:", articleText);
    
//     const status = articleText ? 'OK' : 'NG';
//     const safeFileName = getSafeFileNameFromUrl(articleLink);
    
//     // 既存の文字列テンプレートの形を維持
//     const filePath = `temp/${status}_${safeFileName}.txt`;
//     const tempFilePath = `/tmp/${status}_${safeFileName}.txt`; 
    
//     // 一時ファイルとして保存
//     await fs.promises.writeFile(tempFilePath, articleText || '', { encoding: 'utf8' });
    
//     // Cloud Storageにアップロード
//     await storage.bucket(bucketName).upload(tempFilePath, {
//       destination: filePath,
//     });

//     console.log(`記事を ${filePath} に保存しました`);
//     if (articleText) {
//       // スクレイピングした記事内容を元に台本を生成
//       // await generateScript(articleText);
//       prompt = `以下の記事に基づいて、youtubeにアップするニュース記事の台本を400文字程度で、Vtuberに関連するニュースのみを改行せず台本の本文のみを出力してください（そのまま機械的に読み上げるので【ニュース記事】などのタイトルは不要）。\n記事: ${articleText}`;
//     } else {
//       console.log('記事の取得に失敗しました。タイトルで生成します。');
//       prompt = `以下の記事タイトルに基づいて、youtubeにアップするニュース記事の台本を400文字程度で、Vtuberに関連するニュースのみを改行せず台本の本文のみを出力してください（そのまま機械的に読み上げるので【ニュース記事】などのタイトルは不要）。\nタイトル: ${title}`;
//     }

//     const completion = await openai.chat.completions.create({
//       model: 'gpt-3.5-turbo',
//       messages: [{ role: 'user', content: prompt }],
//       temperature: 0.7,
//     });
//     let blogText = completion.choices[0].message.content;
//     console.log("Generated blog text:", blogText);


//     const title_prompt = `先ほど生成した台本をYoutube動画にする際の動画タイトルを、再生数が取れそうな引きのある文言で15文字程度で作成してください。先ほどの台本：${blogText}`;
//     const title_completion = await openai.chat.completions.create({
//       model: 'gpt-3.5-turbo',
//       messages: [{ role: 'user', content: title_prompt }],
//       temperature: 0.7,
//     });
//     const videoTitle = title_completion.choices[0].message.content;


//     // タイトルとブログ結合
//     blogText = `${videoTitle}\n${blogText}\n以上のニュース詳細は概要欄にて。このチャンネルでは、このようなVtuber関連ニュースの解説を最速で投稿しています。よろしければ、チャンネル登録と高評価をお願いします。`;
//     console.log("Generated blog text+Title:", blogText);

//     const description_prompt = `先ほど生成した台本をYoutube動画にする際の動画のdescriptionを、200文字程度日本語で作成してください。先ほどの台本：${blogText}`;
//     const description_completion = await openai.chat.completions.create({
//       model: 'gpt-3.5-turbo',
//       messages: [{ role: 'user', content: description_prompt }],
//       temperature: 0.7,
//     });
//     let videoDescription = description_completion.choices[0].message.content;

//     videoDescription = `${videoDescription}\n\nニュース詳細:${finalURL}\n`;
//     console.log("Generated blog videoDescription:", videoDescription);

//     const furigana_prompt = `以下の文章全てをVOICEVOXに正しく読ませるために、「Vtuber」を「ブイチューバー」など、英単語やアルファベットで書かれている名詞や英単語をすべて日本語の読み仮名（カタカナ）に変換してください。\n文章：${blogText}`;
//     const furigana_completion = await openai.chat.completions.create({
//       model: 'gpt-3.5-turbo',
//       messages: [{ role: 'user', content: furigana_prompt }],
//       temperature: 0.7,
//     });
//     const furiganaText = furigana_completion.choices[0].message.content;
//     console.log("Generated Furigana text:", furiganaText);


//     const tags_prompt = `先ほど生成した台本をYoutube動画にする際の動画のTagを、より検索にヒットしそうなもので、かつ絵文字を含まないで5つ程度リスト形式（['vtuber', 'ニュース']のような形）で作成してください。先ほどの台本：${blogText}`;
//     const tags_completion = await openai.chat.completions.create({
//       model: 'gpt-3.5-turbo',
//       messages: [{ role: 'user', content: tags_prompt }],
//       temperature: 0.7,
//     });
//     const videoTags = tags_completion.choices[0].message.content;

//     // 1. VOICEVOX: 音声合成
//     const speakerId = 1;

//     const queryRes = await axios.post(
//       `${VOICEVOX_ENGINE_URL}/audio_query?text=${encodeURIComponent(furiganaText)}&speaker=${speakerId}`,
//       // `${VOICEVOX_ENGINE_URL}/audio_query?text=${encodeURIComponent("テスト文言")}&speaker=${speakerId}`,
//       null,
//       {
//         headers: { 'Accept': 'application/json' },
//         timeout: 600000 // 10秒など、妥当な値を設定
//       }
//     );
//     let audioQuery = queryRes.data;
//     audioQuery.speedScale = 1.2;
//     audioQuery.volumeScale = 1.0; // ⭐️ 音量を固定
//     // audioQuery.intonationScale = 0.9; // ⭐️ 抑揚を軽めに
//     speedScale = audioQuery.speedScale;
//     audioQuery.postPhonemeLength = 0.1;

//     const synthRes = await axios.post(
//       `${VOICEVOX_ENGINE_URL}/synthesis?speaker=${speakerId}`,
//       audioQuery,
//       {
//         headers: { 'Content-Type': 'application/json' },
//         responseType: 'arraybuffer',
//         timeout: 600000,
//       }
//     );

//     // 🎙️ 1. 一度ローカルに保存（/tmp）
//     const audioFileName = `temp/audio-${uuid}.wav`;
//     const tempAudioPath = `/tmp/audio-${uuid}.wav`; 
//     await fs.promises.writeFile(tempAudioPath, synthRes.data);

//     // ☁️ 2. それを GCS にアップロード
//     await storage.bucket(bucketName).upload(tempAudioPath, {
//       destination: audioFileName,
//     });
//     console.log('✅ 音声アップロード完了', audioFileName);

//     // 3. 字幕生成
//     // const totalDuration = audioQuery.outputSamplingRate > 0 ? synthRes.data.length / (audioQuery.outputSamplingRate * 2) : 30;
//     const srtPathFileName = `temp/subtitle-${Date.now()}.srt`;
//     const tempSrtPath = `/tmp/subtitle-${Date.now()}.srt`;
//     await generateSRTFromVoicevoxTiming(blogText, tempSrtPath, 1,synthRes,audioQuery);
//     console.log(`✅ 字幕生成完了: ${tempSrtPath}`);
//     await storage.bucket(bucketName).upload(tempSrtPath, {
//       destination: srtPathFileName,
//     });
//     console.log(`✅ 字幕アップロード完了: ${srtPathFileName}`);

//     // 🎯 字幕用の .srt を GCS に保存（UTF-8エンコードで書き出し）
//     const subtitleGcsUri = `gs://${bucketName}/${srtPathFileName}`;

//     // 🎞️ 動画合成リクエスト
//     const videoMergerUrl = 'https://video-merger-23130474318.asia-northeast1.run.app/merge';
//     const videoGcsUri = 'gs://vtuber-335811.appspot.com/background.mp4';
//     const outputFilePath = `merged-output/output-${uuid}.mp4`;
//     const outputPath = `gs://${bucketName}/${outputFilePath}`;

//     const mergeRes = await axios.post(videoMergerUrl, {
//       videoUri: videoGcsUri,
//       audioUri: `gs://${bucketName}/${audioFileName}`,
//       outputUri: outputPath,
//       subtitleSrtUri: subtitleGcsUri,
//     }, {
//       headers: { 'Content-Type': 'application/json' },
//       timeout: 540000,
//       maxContentLength: Infinity,
//       maxBodyLength: Infinity,
//     });

//     console.log("Merge result:", mergeRes.data);
//     // ✅ 後始末（音声・字幕ファイルを削除）
//     await deleteGcsFile(bucketName, audioFileName);
//     await deleteGcsFile(bucketName, srtPathFileName);


//     // ~~~~~~~~~~~~~~~~~~~~
//     // // ② アップロード実行（バケット名と動画ファイル名を指定）
//     const videoId = await youtubeUpload(bucketName, outputFilePath,videoTitle,videoDescription,videoTags);
//     await deleteGcsFile(bucketName, outputFilePath);

//     res.status(200).send(`動画を生成してYouTubeにアップロードしました: https://youtu.be/${videoId}`);
//     // // ~~~~~~~~~~~~~~~~~~~~

//     // // 完了メッセージを返す
//     // res.json({ message: '動画の生成が完了しました', videoUrl: mergeRes.data.url });

//   } catch (error) {
//     console.error('Error generating blog or merging video:', error?.response?.data || error);
//     res.status(500).send('Error generating blog or merging video.');
//   }
// };