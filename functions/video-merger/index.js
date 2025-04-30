import express from 'express';
import { mergeVideoAndAudio } from './merge.js';
import { Storage } from '@google-cloud/storage';
import path from 'path';
import { v4 as uuidv4 } from 'uuid';
import fs from 'fs/promises';
import os from 'os';

const PORT = process.env.PORT || 8080;
const app = express();
const storage = new Storage();

app.use(express.json());

app.get('/', (req, res) => {
  res.send('✅ Video merger service is running!');
});

app.post('/merge', async (req, res) => {
  try {
    const { videoUri, audioUri, outputUri, subtitleSrtUri } = req.body;

    const tempDir = path.join(os.tmpdir(), uuidv4());
    await fs.mkdir(tempDir, { recursive: true });

    const videoPath = path.join(tempDir, 'video.mp4');
    const audioPath = path.join(tempDir, 'audio.wav');
    const outputPath = path.join(tempDir, 'output.mp4');
    const subtitlePath = subtitleSrtUri ? path.join(tempDir, 'subtitle.srt') : null;

    console.log('📦 subtitleSrtUri:', subtitleSrtUri);

    await Promise.all([
      downloadFromGcs(videoUri, videoPath),
      downloadFromGcs(audioUri, audioPath),
      subtitleSrtUri ? downloadFromGcs(subtitleSrtUri, subtitlePath) : null,
    ]);

    const mergeOptions = {
      videoPath,
      audioPath,
      outputPath,
    };

    if (subtitlePath) {
      mergeOptions.subtitleSrtPath = subtitlePath;
    }

    console.log('🛠️ Passing to mergeVideoAndAudio:', mergeOptions);

    await mergeVideoAndAudio(mergeOptions);

    await uploadToGCS(outputPath, outputUri);

    res.json({ message: 'Video merge complete!', outputUri });

    await fs.rm(tempDir, { recursive: true, force: true });
  } catch (err) {
    console.error('🔥 Merge error:', err);
    res.status(500).json({ error: 'Internal Server Error', details: err.message });
  }
});


async function downloadFromGcs(gcsUri, destinationPath) {
  const match = gcsUri.match(/^gs:\/\/([^\/]+)\/(.+)$/);
  if (!match) throw new Error("Invalid GCS URI");

  const bucketName = match[1];
  const filePath = match[2];

  const bucket = storage.bucket(bucketName);
  const file = bucket.file(filePath);

  // ✅ ダウンロードを実行
  await file.download({ destination: destinationPath });

  // ✅ ダウンロード後にファイルの存在確認＆サイズログ（ffprobe前の安全対策）
  const stat = await fs.stat(destinationPath);
  console.log(`✅ GCSからダウンロード完了: ${destinationPath}, サイズ: ${stat.size} バイト`);

  return destinationPath;
}

async function uploadToGCS(localPath, gsUri) {
  const match = gsUri.match(/^gs:\/\/([^\/]+)\/(.+)$/);
  if (!match) throw new Error(`Invalid GCS URI: ${gsUri}`);
  const [, bucketName, filePath] = match;

  await storage.bucket(bucketName).upload(localPath, {
    destination: filePath,
    resumable: false,
    metadata: {
      cacheControl: 'no-cache',
    },
  });
}

app.listen(PORT, () => {
  console.log(`🚀 Video merger server listening on port ${PORT}`);
});
