# XuéBàn 学伴 — Chinese Learning Companion

> **Speak. Transcribe. Learn.**
> An iOS app for learning Mandarin Chinese through voice transcription, AI-powered quizzes, stroke-order animation, and spaced flashcard practice.

---

## Features

### Translate Tab — Voice Transcription
Record yourself speaking Chinese (or play audio aloud near your phone). The app:
- Transcribes the audio into Chinese characters
- Breaks down the sentence **word-by-word** with English and Pinyin for each word
- Lets you **Accept & Save** the result, which translates the full sentence and stores the vocabulary for use in Quizzes and Flashcards
- Tap any word to open a **stroke-order animation sheet** showing how each character is drawn

### Quiz Tab — AI Conversation Quiz
Practice your knowledge with an adaptive conversational quiz:
- **Custom topic** — enter any subject (e.g. "food", "travel", "HSK 2 vocabulary")
- **Random** — surprise yourself with a randomly generated topic
- **Recent lessons** — quiz yourself on vocabulary you've recently saved
- Questions are read aloud via text-to-speech so you can practice listening comprehension
- Each answer is scored and you receive immediate feedback with corrections
- At the end of a session you get an **overall score, strengths, and suggested improvements**

### Characters Tab — Character Lookup
Search any Chinese word or phrase to get:
- Pinyin pronunciation with tone marks
- English meaning
- Animated **stroke-order diagrams** rendered from the hanzi-writer dataset, so you can see exactly how to write each character

### Flash Cards Tab — Vocabulary Practice
Test your recall of saved vocabulary:
- A random card is drawn from your saved word list
- Type the **English meaning or Pinyin** (tone marks optional — diacritic-insensitive matching)
- **Correct** → green banner, move to the next card
- **Incorrect** → red banner showing the correct English and Pinyin; retry the card, reveal the answer, or skip to the next card
- **Show Answer** → reveals the answer and resets the input for review

---

## Tech Stack

| Layer | Technology |
|---|---|
| iOS UI | SwiftUI |
| Persistence | SwiftData |
| Stroke animations | hanzi-writer-data (via CDN, rendered in WKWebView) |
| Backend API | Custom REST API (`/transcribe`, `/translate`, `/lookup`, `/quiz/*`, `/flashcard`) |
| Audio recording | AVFoundation |
| Text-to-speech | AVSpeechSynthesizer |

---

## Project Structure

```
ChineseVoiceTranslator/
├── ChineseVoiceTranslatorApp.swift   # App entry point, tab bar, SwiftData container
├── ContentView.swift                 # Translate tab + stroke-order sheet
├── QuizView.swift                    # AI quiz tab
├── CharacterView.swift               # Character lookup tab
├── FlashcardView.swift               # Flashcard practice tab
├── APIClient.swift                   # All network calls and response models
├── AudioRecorder.swift               # AVAudioRecorder wrapper
├── SharedComponents.swift            # Reusable UI components (PulsingRecordButton, etc.)
└── Theme.swift                       # Color palette (red, jade, warmBg)
```

---

## Getting Started

1. Clone the repo and open `ChineseVoiceTranslator/ChineseVoiceTranslator.xcodeproj` in Xcode.
2. Set your backend API base URL in `APIClient.swift`.
3. Build and run on a physical device or simulator (iOS 17+).
4. Grant microphone permission when prompted to use the Translate tab.
