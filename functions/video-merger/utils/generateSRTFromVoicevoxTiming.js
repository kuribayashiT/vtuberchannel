import axios from "axios";
import fs from "fs/promises";
import { exec } from "child_process";
import { promisify } from "util";
import { getAudioDuration } from './getAudioDuration.js';

const execAsync = promisify(exec);
const VOICEVOX_ENGINE_URL = "https://voicevox-engine-23130474318.asia-northeast1.run.app";

export async function generateSRTFromVoicevoxTiming(text, srtPath, speakerId = 1) {
  const queryRes = await axios.post(`${VOICEVOX_ENGINE_URL}/audio_query`, null, {
    params: { text, speaker: speakerId },
  });
  const query = queryRes.data;

  const synthesisRes = await axios.post(`${VOICEVOX_ENGINE_URL}/synthesis`, query, {
    params: { speaker: speakerId },
    responseType: "arraybuffer",
  });

  const tmpAudioPath = "/tmp/voice.wav";
  await fs.writeFile(tmpAudioPath, Buffer.from(synthesisRes.data));
  const realAudioDuration = await getAudioDuration(tmpAudioPath);
  console.log('⏱️ realAudioDuration:', realAudioDuration);

  const timingList = [];
  for (const phrase of query.accent_phrases) {
    for (const mora of phrase.moras) {
      const length = (mora.consonant_length || 0) + (mora.vowel_length || 0);
      timingList.push(length);
    }
    if (phrase.pause_mora) {
      timingList.push(phrase.pause_mora.vowel_length || 0.3);
    }
  }

  const estimatedDuration = timingList.reduce((a, b) => a + b, 0);
  const scale = realAudioDuration / estimatedDuration;

  const sentences = text.split(/(?<=[。！？])/).map((s) => s.trim()).filter(Boolean);
  const moraCountPerSentence = sentences.map(s => s.length);
  const totalMora = moraCountPerSentence.reduce((a, b) => a + b, 0);

  const srtLines = [];
  let moraIndex = 0;
  let currentTime = 0;
  const OFFSET = -0.2;

  for (let i = 0; i < sentences.length; i++) {
    const sentence = sentences[i];
    const moraCount = moraCountPerSentence[i];

    const segmentTimings = timingList.slice(moraIndex, moraIndex + moraCount);
    const duration = segmentTimings.reduce((a, b) => a + b, 0) * scale;

    const start = formatTime(Math.max(currentTime + OFFSET, 0));
    currentTime += duration;
    const end = formatTime(Math.max(currentTime + OFFSET, 0));

    const wrapped = wrapSubtitleText(sentence);
    srtLines.push(`${i + 1}\n${start} --> ${end}\n${wrapped}\n`);

    moraIndex += moraCount;
  }

  await fs.writeFile(srtPath, srtLines.join("\n"), "utf-8");
}

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

function wrapSubtitleText(text, maxLineLength = 20) {
  if (text.length <= maxLineLength) return text;

  const breakChars = /[、。,.]/g;
  let breakIndex = -1;
  let match;
  while ((match = breakChars.exec(text)) !== null) {
    if (match.index >= maxLineLength / 2) {
      breakIndex = match.index + 1;
      break;
    }
  }
  if (breakIndex === -1) breakIndex = maxLineLength;

  return text.slice(0, breakIndex).trim() + "\n" + text.slice(breakIndex).trim();
}
