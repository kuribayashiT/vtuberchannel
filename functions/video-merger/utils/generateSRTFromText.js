import fs from "fs/promises";
import path from "path";

export async function generateSRTFromText(text, srtPath, totalDuration) {
  const sentences = text.split(/(?<=[。！？\n])/).filter(Boolean);
  const durationPerSentence = totalDuration / sentences.length;

  const srtLines = sentences.map((sentence, i) => {
    const start = i * durationPerSentence;
    const end = start + durationPerSentence;

    const formatTime = (sec) => {
      const date = new Date(sec * 1000).toISOString().substr(11, 12).replace('.', ',');
      return date;
    };

    const softWrap = (str, maxLen = 12) => {
      let result = '';
      let count = 0;
      for (let i = 0; i < str.length; i++) {
        result += str[i];
        count++;

        const isPunctuation = /[。！？\n]/.test(str[i]);
        if (isPunctuation) {
          count = 0; // リセット
        }

        if (count >= maxLen) {
          // 次の文字が句読点でないなら改行
          const nextChar = str[i + 1];
          if (!/[。！？\n]/.test(nextChar)) {
            result += '\\N';
            count = 0;
          }
        }
      }
      return result;
    };

    const safeText = softWrap(sentence.trim());

    return `${i + 1}
${formatTime(start)} --> ${formatTime(end)}
${safeText}
`;
  });

  await fs.writeFile(srtPath, srtLines.join("\n"), "utf-8");
}