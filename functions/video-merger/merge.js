import { exec } from 'child_process';
import { promisify } from 'util';
import fs from 'fs/promises';
import path from 'path';
import { convertSrtToAss } from './utils/convertSrtToAss.js';
import { existsSync } from 'fs';

const execAsync = promisify(exec);

/**
 * 動画・音声・字幕を合成する
 */
export async function mergeVideoAndAudio({
  videoPath,
  audioPath,
  outputPath,
  subtitleSrtPath = null,
}) {
  const hasSubtitle = Boolean(subtitleSrtPath);
  const assPath = hasSubtitle
    ? subtitleSrtPath.replace(/\.srt$/, '.ass')
    : null;

  console.log('🛠️ Merging with subtitle path:', subtitleSrtPath);
  // const { execAsync } = require('child_process');
  try {
    const { stdout, stderr } = await execAsync(
      // `ffmpeg -y -i "${videoPath}" -i "${audioPath}" -filter_complex "[0:a][1:a]amix=inputs=2:duration=shortest" -c:a aac /tmp/mixed-audio.aac`);
      `ffmpeg -y -i "${videoPath}" -i "${audioPath}" -filter_complex "[0:a]volume=0.1[a0];[1:a]volume=2.0[a1];[a0][a1]amix=inputs=2:duration=shortest" -c:a aac /tmp/mixed-audio.aac`
    );
    console.log('🌀 Audio mix stdout:', stdout);
    console.log('⚠️ Audio mix stderr:', stderr);

    if (!existsSync('/tmp/mixed-audio.aac')) {
      throw new Error('❌ /tmp/mixed-audio.aac が作成されていません。音声合成に失敗しています。');
    }
  } catch (e) {
    console.error('❌ Audio mix failed:', e.message);
    throw e;
  }
  if (hasSubtitle) {
    // SRT → ASS 変換（字幕位置とフォント設定）
    console.log('🧪 Converting SRT to ASS:', subtitleSrtPath, '→', assPath);
    // await convertSrtToAss(subtitleSrtPath, assPath, {
    //   videoWidth: 720,
    //   videoHeight: 1280,
    //   subtitleBox: {
    //     x: 60,          // 左余白（中央寄り）
    //     y: 900,         // 字幕の上辺（下から300pxぐらい）
    //     width: 600,     // 幅を赤枠に収める（全体から余白差し引いた）
    //     height: 200     // 高さはそのままOK
    //   },
    //   fontSize: 72,
    //   fontName: 'Noto Sans CJK JP', // 'sans-serif' だと環境によって再現されない可能性あり
    //   audioPath:'/tmp/mixed-audio.aac', // 音声ファイルのパス
    // });
    await convertSrtToAss(subtitleSrtPath, assPath, {
      videoWidth: 720,
      videoHeight: 1280,
      subtitleBox: {
        x: 80,          // 左余白（中央寄り）
        y: 500,         // 字幕の上辺（下から300pxぐらい）
        width: 560,     // 幅を赤枠に収める（全体から余白差し引いた）
        height: 300     // 高さはそのままOK
      },
      fontSize: 52,
      fontName: 'Noto Sans CJK JP', // 'sans-serif' だと環境によって再現されない可能性あり
      audioPath: '/tmp/mixed-audio.aac', // 音声ファイルのパス
    });
  }

  // 🔍 ここで .ass ファイルの中身をログ出力
  const assDebug = await fs.readFile(assPath, 'utf8');
  console.log('📄 ASS file content:\n', assDebug);

  // FFmpegコマンド構築（空白・パス対策）
  const ffmpegArgs = [
    '-y',
    '-i', videoPath,
    '-i', '/tmp/mixed-audio.aac',
    '-map', '0:v:0',
    '-map', '1:a:0',
    '-c:v', 'libx264',
    '-preset', 'slow',
    '-crf', '18',
    '-c:a', 'aac',
    '-b:a', '192k',
    '-ar', '44100',
    '-ac', '2',
    '-af', 'volume=10dB',
    ...(hasSubtitle ? ['-vf', `subtitles=${assPath}:fontsdir=/usr/share/fonts`] : []),
    '-shortest',
    outputPath,
  ];

  const cmd = ['ffmpeg', ...ffmpegArgs.map(arg => `"${arg}"`)].join(' ');

  console.log('🔥 FFmpegコマンド:', cmd);

  try {
    await execAsync(cmd);
    return { message: '✅ Video merge complete!' };
  } catch (error) {
    console.error('❌ FFmpeg merge failed:', error.stderr || error.message);
    throw error;
  }
}
