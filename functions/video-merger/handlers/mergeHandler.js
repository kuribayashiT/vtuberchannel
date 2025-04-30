// import { mergeVideoAndAudio } from "../utils/ffmpegMerge.js";

// const bucketName = "vtuber-335811.appspot.com"; // Cloud Storage のバケット名

// export const mergeVideoAndAudioHandler = async (req, res) => {
//   const { audioGcsUri, videoGcsUri, outputFileName } = req.body;

//   try {
//     const resultUrl = await mergeVideoAndAudio({
//       audioGcsUri,
//       videoGcsUri,
//       outputFileName,
//       bucketName, // 👈 必ずここで渡す
//     });
//     res.json({ message: "Success", resultUrl });
//   } catch (err) {
//     console.error("Merge failed:", err);
//     res.status(500).json({ error: "Merge failed", details: err.message });
//   }
// };
