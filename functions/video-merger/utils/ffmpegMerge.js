// import { Storage } from "@google-cloud/storage";
// import ffmpeg from "fluent-ffmpeg";
// import { v4 as uuidv4 } from "uuid";
// import path from "path";
// import fs from "fs/promises";
// import { getAudioDuration } from './getAudioDuration.js'; 


// const storage = new Storage();

// export async function mergeVideoAndAudio({ audioGcsUri, videoGcsUri, outputFileName, bucketName, subtitleText }) {
//   const tempId = uuidv4();
//   const tmpDir = `/tmp/${tempId}`;
//   await fs.mkdir(tmpDir, { recursive: true });

//   console.log('🛠️ mergeVideoAndAudio():', subtitleText);

//   const audioPath = path.join(tmpDir, "audio.wav");
//   const videoPath = path.join(tmpDir, "background.mp4");
//   const outputPath = path.join(tmpDir, "output.mp4");
//   let srtPath = path.join(tmpDir, "subtitles.srt"); // ✅ let に修正

//   const parseGcsUri = (gcsUri) => {
//     const match = gcsUri.match(/^gs:\/\/([^\/]+)\/(.+)$/);
//     if (!match) throw new Error(`Invalid GCS URI: ${gcsUri}`);
//     return { bucket: match[1], filePath: match[2] };
//   };

//   const downloadFromGcs = async (uri, destination) => {
//     const { bucket, filePath } = parseGcsUri(uri);
//     await storage.bucket(bucket).file(filePath).download({ destination });
//   };

//   await Promise.all([
//     downloadFromGcs(audioGcsUri, audioPath),
//     downloadFromGcs(videoGcsUri, videoPath),
//   ]);

//   const audioDuration = await getAudioDuration(audioPath);

//   // // ✅ SRTを生成
//   // await generateSRTFromVoicevoxTiming(subtitleText, srtPath, 1); // ← こちらを使う

//   const assPath = srtPath.replace(/\.srt$/, ".ass");

//   // ✅ SRT → ASS 変換
//   await new Promise((resolve, reject) => {
//     ffmpeg(srtPath)
//       .output(assPath)
//       .on("end", resolve)
//       .on("error", reject)
//       .run();
//   });

//   // ✅ ASS字幕をつけて動画合成
//   await new Promise((resolve, reject) => {
//     ffmpeg()
//       .input(videoPath)
//       // .inputOptions(["-stream_loop", "4"]) // ❗必要なければ削除か、durationと比較して条件分岐
//       .input(audioPath)
//       .outputOptions([
//         "-t", `${audioDuration + 1}`,
//         "-map 0:v:0",
//         "-map 1:a:0",
//         "-c:v libx264",
//         "-c:a aac",
//         "-ar 44100",
//         "-ac 2",
//         "-af volume=20dB",
//         "-vf", `ass='${assPath.replace(/:/g, '\\:').replace(/ /g, '\\ ')}'`,
//         "-shortest"
//       ])
//       .on("start", (cmd) => console.log("FFmpegコマンド:", cmd))
//       .on("end", resolve)
//       .on("error", (err, stdout, stderr) => {
//         console.error("FFmpeg エラー:", err);
//         console.error("FFmpeg stderr:", stderr);
//         reject(err);
//       })
//       .save(outputPath);
//   });

//   // ✅ GCSアップロード
//   await storage.bucket(bucketName).upload(outputPath, {
//     destination: outputFileName,
//   });

//   await fs.rm(tmpDir, { recursive: true });

//   return `gs://${bucketName}/${outputFileName}`;
// }
