---
name: youtube-transcript
description: Extract and analyze YouTube video transcripts. Use this skill whenever the user wants to get a transcript from a YouTube video, whether they provide a full URL (e.g., `https://www.youtube.com/watch?v=xyz`) or just a video ID. Triggers for phrases like "get transcript", "YouTube transcript", "transcript for this video", "what's this video about", "YouTube summary", "key highlights from", or any request involving a YouTube link or video ID. This skill fetches the transcript using the youtube-transcript npm package and can analyze it to extract highlights, main themes, or notable quotes.
---

# YouTube Transcript Skill

Extracts transcripts from YouTube videos and offers analysis options. Uses a **subagent for fetching** to minimize token context.

## Two-Phase Architecture

```
Main Session          Subagent (fetch)
     │                      │
     │──── spawn ──────────►│
     │                      │── fetch transcript
     │◄── return ──────────┤
     │                      │
     ├── present options     │
     ├── user picks         │
     └── analyze            │
```

---

## Phase 1: Choose Format + Fetch

When the user provides a YouTube URL/ID, ask which format they want:

```
**Video:** <title>

Choose transcript format:

A. **Plain** - Just the text
B. **Timestamped** - [MM:SS] timestamps for each segment
```

Wait for the user to pick A or B, then spawn the subagent.

### Fetch Script (Subagent)

**First**: Check if `youtube-transcript` is installed globally, if not install it:
```bash
npm list -g youtube-transcript 2>/dev/null | grep -q youtube-transcript || npm install -g youtube-transcript
```

```bash
cd /tmp && node -e "
const { YoutubeTranscript } = require('youtube-transcript');
(async () => {
  const videoId = '<VIDEO_ID>';
  const lang = 'en';
  const transcript = await YoutubeTranscript.fetchTranscript(videoId, { lang }).catch(async () => {
    // Fallback: try common languages
    for (const l of ['ro','es','de','fr','pt']) {
      try {
        return await YoutubeTranscript.fetchTranscript(videoId, {lang:l});
      } catch {}
    }
    throw new Error('NO_TRANSCRIPT');
  });
  const fmt = (ms) => {
    const s = Math.floor(ms/1000), h = Math.floor(s/3600), m = Math.floor((s%3600)/60), sec = s%60;
    return h > 0 ? \`\${h}:\${m.toString().padStart(2,'0')}:\${sec.toString().padStart(2,'0')}\` : \`\${m}:\${sec.toString().padStart(2,'0')}\`;
  };
  const TIMESTAMPED = <USER_CHOICE>; // true or false
  const text = TIMESTAMPED
    ? transcript.map(i => \`[\${fmt(i.offset)}] \${i.text}\`).join('\n')
    : transcript.map(i => i.text).join(' ');
  console.log(text);
})().catch(e => console.error(e.message));
"

# Also get title
curl -s "https://www.youtube.com/watch?v=<VIDEO_ID>" | grep -o '<title>[^<]*</title>' | sed 's/<title>//;s/<\/title>//' | sed 's/ - YouTube$//'
```

### Return Format

Subagent returns:
```
TITLE: <video title>
LANG: <language code if not English>
TRANSCRIPT:
<transcript text>
```

---

## Phase 2: Present Analysis Options

After subagent returns, present:

```
**Video:** <title>
**Format:** Plain / Timestamped
**Language:** English / Romanian / etc.

What would you like me to do with it?

1. **Key highlights** - Extract the most important points
2. **Main focus** - What is this video primarily about (1-2 sentence summary)
3. **Notable quotes** - Extract the most memorable/quotable lines
4. **Save transcript** - Save to ~/Downloads/<kebab-name>_transcript.txt
5. **Translate to English** - Translate the transcript (for non-English videos)
6. **Download audio** - Extract MP3 audio from the video (uses yt-dlp)
7. **Download video** - Download full video in 1080p (uses yt-dlp)
```

Note: Option 3 "Full transcript" was removed — if they want it, just display the transcript we already have from Phase 1.

---

## Phase 3: Process User Choice

### Option 1: Key Highlights
Analyze the transcript and extract key points. Format as:
```
## Key Highlights

1. [Highlight point]
2. [Highlight point]
...
```

### Option 2: Main Focus
Provide a 1-2 sentence summary of the video's main topic/thesis.

### Option 3: Notable Quotes
Extract memorable/quotable lines from the transcript.

### Option 4: Save to File

1. **Convert title to kebab-case**:
   ```
   "Billionaire's WARNING: I'm SELLING" → billionaires-warning-i-m-selling
   ```
   - Remove special characters, keep only alphanumeric + spaces
   - Convert spaces to hyphens, all lowercase

2. **Filename reflects format and language**:
   - Plain English: `<kebab-name>_transcript.txt`
   - Plain non-English: `<kebab-name>_transcript_[lang].txt`
   - Timestamped: `<kebab-name>_transcript_timestamped.txt`
   - Translated: `<kebab-name>_transcript_translated.txt`

3. **Save to**: `~/Downloads/<kebab-name>_transcript[.ext]`

### Option 5: Translate to English

1. Translate the transcript text to English — preserve tone/style
2. Return the translated text
3. Save: `~/Downloads/<kebab-name>_transcript_translated.txt`

**Note**: Always mention original language (e.g., "Translated from Romanian")

### Option 6: Download Audio (MP3)

Use `yt-dlp` to extract audio:

```bash
yt-dlp -x --audio-format mp3 --audio-quality 0 -o "~/Downloads/<kebab-name>_audio.%(ext)s" "https://www.youtube.com/watch?v=<VIDEO_ID>"
```

- `-x` = extract audio
- `--audio-format mp3` = MP3 format
- `--audio-quality 0` = best quality
- Saves to: `~/Downloads/<kebab-name>_audio.mp3`

**Note**: yt-dlp is already installed globally. No need to install.

### Option 7: Download Video

Use `yt-dlp` to download video:

```bash
yt-dlp -f "bestvideo[height<=1080]+bestaudio/best" --merge-output-format mp4 -o "<kebab-name>_video.%(ext)s" "https://www.youtube.com/watch?v=<VIDEO_ID>"
```

- Downloads best quality video up to 1080p (merged video+audio into MP4)
- Saves to: `~/Downloads/<kebab-name>_video.mp4`

**Note**: yt-dlp is already installed globally. No need to install.

## Error Handling

| Error | Response |
|-------|----------|
| Invalid URL/ID | "I couldn't extract a video ID from that. Please provide a YouTube URL like `https://www.youtube.com/watch?v=...` or just the video ID." |
| No transcript available | "No transcript is available for this video. The uploader may have disabled captions." |
| Transcript in non-English | Proceed normally, note the language in Phase 2 options |

---

## Example Flow

**Input**: "get transcript for https://www.youtube.com/watch?v=32u5T6lO8qk"

**Step 1**: Main session extracts ID, shows video title, asks: Plain or Timestamped?

**Step 2**: User picks "Timestamped" → spawn subagent → subagent returns with timestamps

**Step 3**: Main session presents options 1-5

**Step 4**: User picks "key highlights" → main session analyzes and returns highlights
