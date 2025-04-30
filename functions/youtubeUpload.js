const fs = require('fs');
const path = require('path');
const { google } = require('googleapis');

/**
 * Cloud Storageから/tmpにダウンロードし、YouTubeにアップロード
 * @param {string} bucketName - Cloud Storageバケット名
 * @param {string} fileName - アップロードしたい動画ファイル名 (例: output.mp4)
 */
async function youtubeUpload(bucketName, fileName,videoTitle,videoDescription,videoTags) {
  const localPath = path.join('/tmp', path.basename(fileName)); // ✅ tmpに保存
  //const localPath = fileName;

  // GCS からローカルへダウンロード
  const { Storage } = require('@google-cloud/storage');
  const storage = new Storage();
  await storage.bucket(bucketName).file(fileName).download({ destination: localPath });
  console.log(`Downloaded ${fileName} to ${localPath}`);

  // 認証情報の読み込み
  const credentials = JSON.parse(fs.readFileSync(path.join(__dirname, 'client_secret.json')));
  const token = JSON.parse(fs.readFileSync(path.join(__dirname, 'youtube_token.json')));

  const { client_secret, client_id, redirect_uris } = credentials.installed;
  const oAuth2Client = new google.auth.OAuth2(client_id, client_secret, redirect_uris[0]);
  oAuth2Client.setCredentials(token);

  const youtube = google.youtube({ version: 'v3', auth: oAuth2Client });

  // アップロードリクエスト
  console.log('videoTitle:', videoTitle);
  console.log('videoTags:', videoTags);
  const res = await youtube.videos.insert({
    part: 'snippet,status',
    requestBody: {
      snippet: {
        title: videoTitle,
        description: videoDescription,
        tags: videoTags,
      },
      status: {
        privacyStatus: 'public', // or 'public'
      },
    },
    media: {
      body: fs.createReadStream(localPath),
    },
  });

  console.log('YouTube upload successful:', res.data.id);
  return res.data.id;
}

module.exports = { youtubeUpload };
