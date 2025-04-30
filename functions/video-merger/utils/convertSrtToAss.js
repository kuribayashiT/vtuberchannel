import fs from 'fs/promises';
import path from 'path';
import ffmpeg from 'fluent-ffmpeg';
import { getAudioDuration } from './getAudioDuration.js'; 


// SRT終了時刻 → 秒数に変換
function srtTimestampToSeconds(timestamp) {
  const match = timestamp.match(/(\d+):(\d+):(\d+),(\d+)/);
  if (!match) return 0;
  const [, h, m, s, ms] = match.map(Number);
  return h * 3600 + m * 60 + s + ms / 1000;
}

// テキストを改行して、clipも付ける
function breakTextIntoLines(text, maxCharsPerLine = 20, maxLines = 3) {
  const words = text.split(/(?<=。|、|\s)/);
  let lines = [''];
  for (const word of words) {
    const currentLine = lines[lines.length - 1];
    if ((currentLine + word).length > maxCharsPerLine) {
      if (lines.length < maxLines) {
        lines.push(word);
      } else {
        lines[maxLines - 1] += word;
      }
    } else {
      lines[lines.length - 1] += word;
    }
  }
  return lines.join('\\N');
}

// メイン関数（すべて統合済み）
export async function convertSrtToAss(srtPath, assPath, {
  videoWidth,
  videoHeight,
  subtitleBox,
  fontSize,
  fontName,
  audioPath,
}) {
  const srtContent = await fs.readFile(srtPath, 'utf8');
  const srtBlocks = srtContent.trim().split(/\n\n+/);

  // SRT最終行の終了時間を取得
  const lastBlock = srtBlocks[srtBlocks.length - 1];
  const lastTimestamp = lastBlock.split('\n')[1]?.split(' --> ')[1] ?? '00:00:00,000';
  const srtDurationSec = srtTimestampToSeconds(lastTimestamp);

  // 音声ファイルの長さを取得し、scaleFactorを算出
  const audioDurationSec = await getAudioDuration(audioPath);
  const scaleFactor = audioDurationSec / srtDurationSec;
  console.log('⏱️ audioDurationSec:', audioDurationSec);
  console.log('🧮 srtDurationSec:', srtDurationSec);
  console.log('📐 scaleFactor:', scaleFactor.toFixed(4));

  const style = `
[Script Info]
ScriptType: v4.00+
PlayResX: ${videoWidth}
PlayResY: ${videoHeight}

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, BackColour, OutlineColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Default,${fontName},${fontSize},&H00FFFFFF,&H64000000,&H00000000,1,0,0,0,100,100,0,0,1,1,0,7,30,60,40,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
`;

  const assEvents = srtBlocks.map((block) => {
    const lines = block.trim().split('\n');
    if (lines.length < 3) return null;
    const [, timeRange, ...textLines] = lines;
    const [startRaw, endRaw] = timeRange.split(' --> ');
    const text = breakTextIntoLines(textLines.join('')).replace(/\n/g, '\\N');

    // scaleFactorを使わないバージョン（音ズレ防止）
    const scaleTime = (t) => {
      const sec = srtTimestampToSeconds(t);
      const h = String(Math.floor(sec / 3600)).padStart(2, '0');
      const m = String(Math.floor((sec % 3600) / 60)).padStart(2, '0');
      const s = String(Math.floor(sec % 60)).padStart(2, '0');
      const cs = String(Math.floor((sec % 1) * 100)).padStart(2, '0');
      return `${h}:${m}:${s}.${cs}`;
    };

    const start = scaleTime(startRaw);
    const end = scaleTime(endRaw);
    // const clipTag = `{\\clip(${subtitleBox.x},${subtitleBox.y},${subtitleBox.x + subtitleBox.width},${subtitleBox.y + subtitleBox.height})}`;

    const centerX = subtitleBox.x + subtitleBox.width / 2;
    const halfWidth = subtitleBox.width / 2;
    //const clipTag = `{\\clip(${0},${0},${centerX + halfWidth},${subtitleBox.y + subtitleBox.height})}`;
    


    // return `Dialogue: 0,${start},${end},Default,,0,0,0,,${clipTag}${text}`;
    //return `Dialogue: 0,${start},${end},Default,,0,0,0,,${clipTag}${text}`;
    return `Dialogue: 0,${start},${end},Default,,0,0,0,,${text}`;
  }).filter(Boolean).join('\n');

  await fs.writeFile(assPath, style + assEvents, 'utf8');
  console.log('✅ ASSファイル作成完了:', assPath);
}
