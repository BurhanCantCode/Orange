Orange: macOS Voice-to-Action AI Agent (HeyLemon.ai Clone)
Context
The goal is to build a product that mimics heylemon.ai — a macOS-native AI productivity tool that turns voice commands into executed actions across any Mac app. Users press a hotkey, speak a command like "Reply to Sarah's email saying I'll be there at 3pm", and the app captures screen context, plans actions via an LLM, and executes them (clicking, typing, navigating) — all without the user touching the keyboard. The project directory (/Users/burhankhatri/Documents/Orange/) is currently empty; this is a greenfield build.

Tech Stack
Layer	Technology	Rationale
macOS App	Swift 6, SwiftUI + AppKit	Native access to Accessibility API, ScreenCaptureKit, AVFAudio, CGEvent taps — all essential
Build System	Xcode + Swift Package Manager	Standard macOS app toolchain
AI / LLM	OpenAI GPT-4o (vision + planning), Whisper API (STT)	Best vision model for screen understanding; structured JSON output
Local STT	Apple SFSpeechRecognizer (default), whisper.cpp (offline option)	Zero-latency on-device transcription
Marketing Site	Next.js 15 + Tailwind CSS + Framer Motion	Modern landing page matching Lemon's Framer aesthetic
Backend	Supabase (Auth + Postgres) + Stripe	Lightweight; handles auth, subscriptions, usage tracking
Deployment	Vercel (website), DMG + Sparkle (app updates)	Standard distribution
Why Swift over Electron/Tauri: The app requires deep macOS integration (Accessibility API, ScreenCaptureKit, CGEvent taps, NSAppleScript, NSPanel floating windows). Every core feature is a first-class Swift API. Electron would require constant native bridging, add 200MB+ to app size, and produce worse UX.

Project Structure

Orange/
├── Orange/                           # Xcode project (Swift macOS app)
│   ├── Orange/
│   │   ├── App/
│   │   │   ├── OrangeApp.swift              # @main entry, app lifecycle
│   │   │   ├── AppDelegate.swift            # Menu bar, permissions, lifecycle
│   │   │   └── AppState.swift               # Observable global state
│   │   ├── Core/
│   │   │   ├── HotkeyManager.swift          # CGEvent tap for hotkey (Cmd+Shift+O default)
│   │   │   ├── PermissionsManager.swift     # Accessibility, mic, screen recording perms
│   │   │   └── SessionManager.swift         # Orchestrates one voice→action session
│   │   ├── Voice/
│   │   │   ├── AudioCaptureService.swift    # AVAudioEngine mic recording
│   │   │   ├── SpeechToTextService.swift    # Protocol for STT
│   │   │   ├── AppleSpeechRecognizer.swift  # On-device Apple Speech
│   │   │   ├── WhisperAPIClient.swift       # OpenAI Whisper API
│   │   │   └── WhisperLocalEngine.swift     # whisper.cpp offline (optional)
│   │   ├── Context/
│   │   │   ├── ScreenCaptureService.swift   # ScreenCaptureKit screenshots
│   │   │   ├── AccessibilityReader.swift    # AX API to read UI tree
│   │   │   ├── ContextAssembler.swift       # Combines screenshot + AX tree + app info
│   │   │   └── AppDetector.swift            # NSWorkspace frontmost app metadata
│   │   ├── Agent/
│   │   │   ├── AgentOrchestrator.swift      # ReAct loop: plan → act → verify
│   │   │   ├── LLMClient.swift             # Protocol for LLM calls
│   │   │   ├── OpenAIClient.swift           # GPT-4o implementation
│   │   │   ├── ActionPlanner.swift          # Parse LLM JSON → Action array
│   │   │   ├── PromptTemplates.swift        # System prompts, few-shot examples
│   │   │   └── ConversationMemory.swift     # Multi-step task context
│   │   ├── Execution/
│   │   │   ├── ActionExecutor.swift         # Dispatcher: routes to correct executor
│   │   │   ├── AppleScriptExecutor.swift    # NSAppleScript runner
│   │   │   ├── AccessibilityExecutor.swift  # AX API: click, type, scroll
│   │   │   ├── KeyboardMouseController.swift # CGEvent posting
│   │   │   ├── ActionVerifier.swift         # Post-action screenshot verification
│   │   │   └── SafetyGuard.swift            # Confirm before destructive actions
│   │   ├── UI/
│   │   │   ├── OverlayWindow.swift          # NSPanel floating overlay
│   │   │   ├── OverlayView.swift            # SwiftUI overlay content
│   │   │   ├── RecordingIndicator.swift     # Pulsing mic animation
│   │   │   ├── ActionFeedbackView.swift     # Step-by-step progress
│   │   │   ├── StatusBarController.swift    # Menu bar icon + dropdown
│   │   │   ├── SettingsView.swift           # Preferences window
│   │   │   └── OnboardingView.swift         # First-run permission setup
│   │   ├── Models/
│   │   │   ├── Action.swift                 # Enum: click, type, keyCombo, openApp, etc.
│   │   │   ├── ScreenContext.swift          # Screenshot + AX tree + app info
│   │   │   ├── VoiceSession.swift           # One voice command session
│   │   │   └── UserPreferences.swift        # @AppStorage-backed settings
│   │   ├── Utilities/
│   │   │   ├── Logger.swift                 # OSLog wrapper
│   │   │   ├── Keychain.swift               # API key storage
│   │   │   ├── ImageEncoder.swift           # CGImage → base64 for vision API
│   │   │   └── RetryHelper.swift            # Exponential backoff
│   │   └── Resources/
│   │       ├── Assets.xcassets
│   │       ├── Info.plist
│   │       └── Orange.entitlements
│   └── OrangeTests/
├── website/                          # Next.js marketing site
│   ├── src/app/
│   │   ├── page.tsx                  # Landing page
│   │   ├── pricing/page.tsx
│   │   └── api/stripe/webhook/route.ts
│   └── src/components/
│       ├── Hero.tsx, DemoVideo.tsx, FeatureGrid.tsx, Pricing.tsx, Footer.tsx
└── scripts/
    ├── build.sh, notarize.sh, release.sh
End-to-End Data Flow

User presses Cmd+Shift+O (hotkey)
       ↓
[HotkeyManager] → AppState.isRecording = true → Overlay shows "Listening..."
       ↓
[AudioCaptureService] starts recording via AVAudioEngine
       ↓
User speaks: "Reply to Sarah's email saying I'll be there at 3pm"
       ↓
1.5s silence detected → recording stops → audio buffer ready
       ↓
[SpeechToTextService] → transcribed text
       ↓
Overlay shows transcription + "Thinking..."
       ↓
[ScreenCaptureService] captures screenshot (parallel)
[AccessibilityReader] reads AX tree of frontmost app (parallel)
[AppDetector] identifies app + window title (parallel)
       ↓
[ContextAssembler] → ScreenContext { screenshot, axTree, app, windowTitle }
       ↓
[AgentOrchestrator] sends to LLM:
  - System prompt + screenshot (base64) + AX tree + user command
       ↓
LLM responds with JSON action plan:
  [click "Sarah's email"], [click "Reply"], [type "Hi Sarah..."], [cmd+Enter]
       ↓
[SafetyGuard] shows preview for send action → user confirms
       ↓
[ActionExecutor] executes step-by-step:
  AppleScriptExecutor → AccessibilityExecutor → KeyboardMouseController
       ↓
[ActionVerifier] takes new screenshot → LLM confirms success
       ↓
Overlay shows "Done! Email sent." → fades out after 2s
Core Module Details
1. Global Hotkey (HotkeyManager.swift)
CGEvent.tapCreate on .cgSessionEventTap to intercept key events
Default: Cmd+Shift+O (configurable in settings)
Optional: double-tap Fn key (advanced, can conflict with macOS Globe key)
Runs on a dedicated CFRunLoop background thread
Requires Accessibility permission
2. Voice Capture (Voice/)
AVAudioEngine taps input node at 16kHz mono
Voice Activity Detection: RMS-based silence detection (1.5s threshold)
Tiered STT: Apple SFSpeechRecognizer (default, on-device, free) → Whisper API (high accuracy) → whisper.cpp (offline)
Protocol-based: SpeechToTextService with streaming partial results
3. Screen Context (Context/)
Screenshot: SCScreenshotManager via ScreenCaptureKit, downscaled to 1280x720
AX Tree: Recursive traversal of AXUIElement tree (depth-limited to 5 levels), collecting role/title/value/frame/state. Serialized to ~2000 tokens
App Detection: NSWorkspace.shared.frontmostApplication + window title via AX API + active URL for browsers via AppleScript
4. LLM Agent (Agent/)
ReAct loop: Reason → Act → Observe → repeat (max 5 iterations)
GPT-4o with vision: sends screenshot as base64 image_url + AX tree as text
response_format: { type: "json_object" } for structured action plans
Smart model routing: simple commands → GPT-4o-mini; complex → GPT-4o
System prompt includes: available actions, AX tree format, safety rules, few-shot examples per app
5. Action Execution (Execution/)
Execution priority: AppleScript first (most semantic) → AX API (UI interaction) → CGEvent (raw input)
Action types: click, type, keyCombo, scroll, openApp, runAppleScript, selectMenuItem, wait
SafetyGuard: Confirmation overlay before sending messages, deleting files, or making purchases
ActionVerifier: Post-action screenshot → LLM verifies success → corrective actions if needed
6. Overlay UI (UI/)
NSPanel with .nonactivatingPanel, .floating level, transparent background + NSVisualEffectView vibrancy
Compact pill shape (~300x80px), expandable for multi-step feedback
States: Idle (hidden) → Listening (pulsing mic) → Processing ("Thinking...") → Executing (step list) → Done (success/fade)
Position: top-center, user-configurable
macOS Permissions (requested during onboarding)
Accessibility — AXIsProcessTrusted() — read UI elements, simulate clicks/keystrokes
Microphone — NSMicrophoneUsageDescription — voice capture
Screen Recording — CGPreflightScreenCaptureAccess() — screenshots via ScreenCaptureKit
Automation — per-app AppleScript consent (prompted on first use per app)
Backend & Website
Backend (Supabase + Stripe)
Auth: Supabase Auth (email + Google OAuth)
Database: users, subscriptions, usage_logs tables
API Proxy: Next.js API route proxying LLM calls for Pro users (injects managed API key)
Stripe: Webhook-driven subscription management
Pricing Model
Free: 10 commands/day, bring your own OpenAI key
Pro ($12/mo): Unlimited commands, managed API key, priority models
Team ($20/mo/seat): Admin dashboard, shared settings
Marketing Website (Next.js)
Hero section with demo video showing voice → action flow
Feature grid: Email, Slack, Browser, Docs, Calendar, Custom
Stats bar: "5x faster | 12x faster email replies | 2+ hours saved daily"
Pricing cards, download CTA, testimonials
Built with Tailwind CSS + Framer Motion for Lemon-like polish
Implementation Phases
Phase 1: Foundation (Weeks 1-2)
Xcode project setup with SPM dependencies
HotkeyManager — global Cmd+Shift+O detection
AudioCaptureService — record mic to buffer
AppleSpeechRecognizer — on-device STT (no API key needed)
Basic OverlayWindow — listening/processing/done states
StatusBarController — menu bar icon
Milestone: Press hotkey → speak → see transcription in overlay
Phase 2: Screen Context (Weeks 3-4)
ScreenCaptureService, AccessibilityReader, AppDetector, ContextAssembler
PermissionsManager with guided onboarding flow
Milestone: Capture and display screen context alongside transcription
Phase 3: LLM Agent (Weeks 5-7)
OpenAIClient with vision support
PromptTemplates with system prompt + few-shot examples
AgentOrchestrator — single-turn planning
ActionPlanner — JSON → Action parsing
Settings view for API key input
Milestone: Speak command → see LLM-generated action plan in overlay
Phase 4: Action Execution (Weeks 8-10)
AppleScriptExecutor, AccessibilityExecutor, KeyboardMouseController
ActionExecutor dispatcher + SafetyGuard
Milestone: Full pipeline — "open Safari and go to google.com" → it happens
Phase 5: Verification & Reliability (Weeks 11-12)
ActionVerifier with post-action screenshots
Multi-step ReAct loop (up to 5 iterations)
Error recovery, ConversationMemory
Whisper API as alternate STT
Milestone: Reliable multi-step task execution
Phase 6: Polish (Weeks 13-15)
App-specific prompt templates (Gmail, Slack, Finder, VS Code)
Refined overlay animations
Onboarding flow, launch-at-login, auto-updater (Sparkle)
Milestone: Beta-ready app
Phase 7: Website & Backend (Weeks 14-16, parallel)
Next.js marketing site + Supabase + Stripe
Milestone: Product website live with subscription flow
Phase 8: Distribution (Weeks 17-18)
Code signing, notarization, DMG packaging
Launch on Product Hunt
Milestone: v1.0 public release
Verification Plan
Unit tests: Each service module (STT, AX reader, executors) with mocked dependencies
Integration tests: Full session flow with a test app target
Manual testing matrix: Test across Mail, Chrome/Gmail, Slack, Finder, VS Code, Calendar — verify click/type/navigate actions
Safety testing: Verify SafetyGuard blocks destructive actions, verify LLM doesn't hallucinate dangerous scripts
Performance: Measure end-to-end latency (target: <4s from speech end to first action)
Website: Lighthouse audit, mobile responsiveness, Stripe webhook testing
Here are the most relevant open-source repos to build on:

| Repo | Why It's Perfect |
|------|-----------------|
| **[browser-use/macOS-use](https://github.com/browser-use/macOS-use)** | ⭐ Best match — AI agent using Accessibility API across ALL Mac apps, Python-based, actively maintained |
| **[chidiwilliams/GPT-Automator](https://github.com/chidiwilliams/GPT-Automator)** | Voice → Whisper → LangChain → AppleScript pipeline, exact Lemon flow |
| **[steipete/macos-automator-mcp](https://github.com/steipete/macos-automator-mcp)** | 200+ pre-built AppleScript recipes + full Accessibility API wrapper, MCP server |
| **[realrasengan/blind.sh](https://github.com/realrasengan/blind.sh)** | Tiny bash script showing Whisper → ChatGPT → AppleScript in ~50 lines |

`macOS-use` is your core engine. It's from the **browser-use** team (the people who built the best browser agent), and it's essentially Lemon's backend already built. Here's the full plan:

---

# 🍋 Orange — Lemon.ai Clone: Implementation Plan

## Tech Stack Decision: Swift vs Python+Electron

**Recommendation: Python backend + Swift/SwiftUI frontend (hybrid approach)**

Don't pick one or the other. The open-source agent ecosystem (macOS-use, LangChain, Whisper) is entirely Python. Swift is necessary for native macOS UI, global hotkeys, and App Store distribution. The right architecture bridges both.

```
SwiftUI App (Menu Bar + Overlay UI)
        ↕ XPC / Local HTTP
Python Agent Process (macOS-use engine)
        ↕ subprocess / osascript
macOS Accessibility API + AppleScript
```

---

## Project Structure

```
/Users/burhankhatri/Documents/Orange/
├── apps/
│   ├── desktop/                    # Swift/SwiftUI native app
│   │   ├── Orange.xcodeproj
│   │   ├── Sources/
│   │   │   ├── App/
│   │   │   │   ├── OrangeApp.swift          # @main entry, menu bar setup
│   │   │   │   └── AppDelegate.swift
│   │   │   ├── UI/
│   │   │   │   ├── OverlayWindow.swift       # Floating HUD
│   │   │   │   ├── OverlayViewModel.swift
│   │   │   │   ├── RecordingIndicator.swift  # Pulsing mic animation
│   │   │   │   ├── ActionFeedback.swift      # "Composing email..." toast
│   │   │   │   └── SettingsView.swift
│   │   │   ├── HotkeyManager.swift           # Fn key global shortcut
│   │   │   ├── AudioRecorder.swift           # AVFoundation mic capture
│   │   │   ├── AgentBridge.swift             # Talks to Python process
│   │   │   └── PermissionsManager.swift      # Mic + Accessibility perms
│   │   └── Info.plist
│   │
│   └── web/                        # Next.js marketing site
│       ├── app/
│       │   ├── page.tsx             # Landing page
│       │   ├── pricing/page.tsx
│       │   └── docs/page.tsx
│       ├── components/
│       │   ├── Hero.tsx
│       │   ├── DemoVideo.tsx
│       │   └── PricingTable.tsx
│       └── package.json
│
├── agent/                          # Python agent engine (core)
│   ├── main.py                     # FastAPI server, IPC entry point
│   ├── core/
│   │   ├── voice_pipeline.py       # Audio → Whisper → text
│   │   ├── screen_context.py       # Screenshot + accessibility tree
│   │   ├── intent_agent.py         # LLM agent (macOS-use based)
│   │   ├── action_executor.py      # AppleScript + AX API execution
│   │   └── feedback_loop.py        # Verify action, retry logic
│   ├── actions/
│   │   ├── email.py                # Gmail, Apple Mail, Outlook
│   │   ├── browser.py              # Chrome, Safari automation
│   │   ├── slack.py                # Slack message composition
│   │   ├── docs.py                 # Word, Pages, Notion
│   │   ├── system.py               # Files, apps, settings
│   │   └── calendar.py
│   ├── scripts/                    # AppleScript templates
│   │   ├── mail_compose.applescript
│   │   ├── chrome_navigate.applescript
│   │   └── slack_message.applescript
│   ├── models/
│   │   └── schemas.py              # Pydantic models
│   └── requirements.txt
│
├── backend/                        # Cloud backend (auth + billing)
│   ├── api/
│   │   ├── auth.py                 # Clerk/Supabase auth
│   │   ├── usage.py                # Track commands/month
│   │   └── webhooks.py             # Stripe webhooks
│   └── supabase/
│       └── schema.sql
│
├── scripts/
│   ├── setup.sh                    # Install Python deps, agent
│   └── build.sh                   # Build Swift app + bundle agent
│
└── README.md
```

---

## Core Modules — Deep Dive

### 1. Global Hotkey (Fn Key Capture) — Swift

```swift
// HotkeyManager.swift
import Carbon

class HotkeyManager {
    private var eventHandler: EventHandlerRef?
    
    // Fn key = kVK_Function, but easier with CGEvent tap
    func registerFnKey(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) {
        // Use CGEventTap for system-level Fn key interception
        let eventMask = (1 << CGEventType.flagsChanged.rawValue)
        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { proxy, type, event, refcon in
                let flags = event.flags
                if flags.contains(.maskSecondaryFn) {
                    // Fn held down
                }
                return Unmanaged.passRetained(event)
            },
            userInfo: nil
        )
        // Alternative: Use HotKey library (sindresorhus/KeyboardShortcuts)
    }
}
```

> **Easier path**: Use [sindresorhus/KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) — a Swift package that handles global shortcuts with 3 lines of code. Map to `⌘Space` or a custom combo as fallback since Fn requires special entitlements.

---

### 2. Audio Recording + Whisper Pipeline — Python

```python
# agent/core/voice_pipeline.py
import sounddevice as sd
import numpy as np
import whisper
import tempfile, scipy.io.wavfile

class VoicePipeline:
    def __init__(self):
        self.model = whisper.load_model("base.en")  # ~150MB, fast
        self.sample_rate = 16000
        self.recording = False
        self.frames = []
    
    def start_recording(self):
        self.frames = []
        self.recording = True
        self.stream = sd.InputStream(
            samplerate=self.sample_rate,
            channels=1,
            dtype='float32',
            callback=self._audio_callback
        )
        self.stream.start()
    
    def stop_and_transcribe(self) -> str:
        self.stream.stop()
        audio = np.concatenate(self.frames)
        
        with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as f:
            scipy.io.wavfile.write(f.name, self.sample_rate, audio)
            result = self.model.transcribe(f.name)
        
        return result["text"].strip()
    
    # Optional: Use OpenAI Whisper API instead of local model
    # for faster cold start and better accuracy
    async def transcribe_via_api(self, audio_bytes: bytes) -> str:
        import openai
        return openai.Audio.transcribe("whisper-1", audio_bytes)
```

---

### 3. Screen Context Capture — Python (from macOS-use)

```python
# agent/core/screen_context.py
import subprocess
import base64
from PIL import Image
import io

class ScreenContext:
    def capture_screenshot(self) -> str:
        """Returns base64 screenshot for vision model"""
        result = subprocess.run(
            ['screencapture', '-x', '-t', 'png', '/tmp/orange_screen.png'],
            capture_output=True
        )
        with open('/tmp/orange_screen.png', 'rb') as f:
            return base64.b64encode(f.read()).decode()
    
    def get_active_app(self) -> dict:
        """Get frontmost app info via AppleScript"""
        script = '''
        tell application "System Events"
            set frontApp to first application process whose frontmost is true
            return {name of frontApp, bundle identifier of frontApp}
        end tell
        '''
        result = subprocess.run(['osascript', '-e', script], capture_output=True, text=True)
        return {"name": result.stdout.strip()}
    
    def get_accessibility_tree(self, app_name: str) -> dict:
        """Use macOS-use's AX API wrapper — this is the KEY differentiator"""
        # Borrow directly from browser-use/macOS-use
        from macos_use import get_accessibility_tree
        return get_accessibility_tree(app_name)
```

---

### 4. LLM Intent Agent — Python (macOS-use + LangChain)

```python
# agent/core/intent_agent.py
from langchain.agents import AgentExecutor, create_openai_functions_agent
from langchain_openai import ChatOpenAI
from langchain.tools import tool
from .action_executor import ActionExecutor
from .screen_context import ScreenContext

class IntentAgent:
    def __init__(self):
        self.llm = ChatOpenAI(model="gpt-4o", temperature=0)
        self.executor = ActionExecutor()
        self.screen = ScreenContext()
    
    async def execute(self, transcribed_text: str) -> str:
        screenshot = self.screen.capture_screenshot()
        active_app = self.screen.get_active_app()
        ax_tree = self.screen.get_accessibility_tree(active_app["name"])
        
        system_prompt = f"""You are Orange, a macOS AI agent. 
        Current app: {active_app["name"]}
        UI elements available: {ax_tree}
        User said: "{transcribed_text}"
        
        Choose the right action and execute it precisely."""
        
        # Use macOS-use's agent loop directly:
        from macos_use import MacOSAgent
        agent = MacOSAgent(
            llm=self.llm,
            screenshot=screenshot,
            ax_tree=ax_tree
        )
        return await agent.run(transcribed_text)
```

---

### 5. Action Executor — Python

```python
# agent/core/action_executor.py
import subprocess

class ActionExecutor:
    def run_applescript(self, script: str) -> str:
        result = subprocess.run(
            ['osascript', '-e', script],
            capture_output=True, text=True, timeout=30
        )
        if result.returncode != 0:
            raise Exception(f"AppleScript error: {result.stderr}")
        return result.stdout.strip()
    
    def click_element(self, ax_element) -> None:
        """Use macOS Accessibility API to click UI element"""
        # Borrowed from macOS-use's element interaction
        from ApplicationServices import AXUIElementPerformAction, kAXPressAction
        AXUIElementPerformAction(ax_element, kAXPressAction)
    
    def type_text(self, text: str) -> None:
        script = f'''
        tell application "System Events"
            keystroke "{text}"
        end tell
        '''
        self.run_applescript(script)
    
    # Pre-built action templates (from steipete/macos-automator-mcp)
    def compose_email(self, to: str, subject: str, body: str) -> None:
        script = f'''
        tell application "Mail"
            activate
            set newMsg to make new outgoing message with properties {{
                subject:"{subject}", content:"{body}", visible:true
            }}
            tell newMsg to make new to recipient with properties {{address:"{to}"}}
        end tell
        '''
        self.run_applescript(script)
    
    def reply_slack_message(self, message: str) -> None:
        # Use AX API to find message field and type
        ...
```

---

### 6. Overlay UI — SwiftUI

```swift
// OverlayWindow.swift
import SwiftUI
import AppKit

class OverlayWindowController: NSWindowController {
    static let shared = OverlayWindowController()
    
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 120),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .floating          // Always on top
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.ignoresMouseEvents = false
        
        // Center bottom of screen
        let screen = NSScreen.main!.frame
        window.setFrameOrigin(NSPoint(
            x: (screen.width - 400) / 2,
            y: screen.height * 0.15
        ))
        
        super.init(window: window)
        window.contentView = NSHostingView(rootView: OverlayView())
    }
}

struct OverlayView: View {
    @StateObject var vm = OverlayViewModel()
    
    var body: some View {
        HStack(spacing: 16) {
            // Pulsing mic orb
            Circle()
                .fill(vm.state == .recording ? Color.red : Color.orange)
                .frame(width: 40, height: 40)
                .scaleEffect(vm.pulseScale)
                .animation(.easeInOut(duration: 0.6).repeatForever(), value: vm.pulseScale)
            
            VStack(alignment: .leading) {
                Text(vm.statusText)           // "Listening...", "Thinking...", "Composing email..."
                    .font(.system(size: 15, weight: .medium))
                if !vm.transcription.isEmpty {
                    Text(vm.transcription)    // Shows what was heard
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

enum AgentState { case idle, recording, transcribing, thinking, executing, done }
```

---

### 7. IPC Bridge (Swift ↔ Python) — AgentBridge.swift

```swift
// AgentBridge.swift — Swift talks to Python FastAPI server
class AgentBridge {
    private let baseURL = "http://127.0.0.1:7789"
    
    func startRecording() async {
        await post("/recording/start")
    }
    
    func stopAndExecute() async -> AgentResponse {
        return await post("/recording/stop")
    }
    
    // Stream status updates via SSE
    func streamStatus(onUpdate: @escaping (String) -> Void) {
        // EventSource SSE connection to /status/stream
    }
}
```

```python
# agent/main.py — FastAPI server
from fastapi import FastAPI
from fastapi.responses import StreamingResponse
from core.voice_pipeline import VoicePipeline
from core.intent_agent import IntentAgent

app = FastAPI()
pipeline = VoicePipeline()
agent = IntentAgent()

@app.post("/recording/start")
async def start_recording():
    pipeline.start_recording()
    return {"status": "recording"}

@app.post("/recording/stop")
async def stop_recording():
    text = pipeline.stop_and_transcribe()
    result = await agent.execute(text)
    return {"transcription": text, "result": result}

@app.get("/status/stream")  # Server-sent events for live UI updates
async def status_stream():
    async def generate():
        async for update in agent.status_updates():
            yield f"data: {update}\n\n"
    return StreamingResponse(generate(), media_type="text/event-stream")
```

---

## Data Flow — End to End

```
1. USER presses Fn (hold)
        ↓
2. HotkeyManager.swift detects keyDown
        ↓
3. OverlayWindow shows ("Listening..." + red pulse)
   AudioRecorder.swift starts AVAudioEngine capture
   AgentBridge.POST /recording/start → Python starts sounddevice stream
        ↓
4. USER speaks command: "Reply to the last Slack message saying I'll be there"
        ↓
5. USER releases Fn
        ↓
6. AudioRecorder stops → sends WAV bytes to Python
   VoicePipeline.transcribe() → Whisper → "Reply to the last Slack message saying I'll be there"
   Overlay shows: "Heard: Reply to the last Slack message..."
        ↓
7. ScreenContext captures:
   - screenshot() → base64 PNG
   - get_active_app() → "Slack"
   - get_accessibility_tree("Slack") → list of AX elements, message threads
        ↓
8. IntentAgent receives: {text, screenshot, ax_tree, active_app}
   → GPT-4o with vision plans: [find_last_message, click_reply, type_text]
   → Streams thinking steps to UI
        ↓
9. ActionExecutor runs:
   a. AXUIElementPerformAction → click reply button
   b. type_text("I'll be there")
   c. run_applescript → press Enter / Send
        ↓
10. FeedbackLoop takes new screenshot → verifies message sent
    Overlay shows: "✓ Replied to #general" (2 sec) → fades out
```

---

## API & Models

| Component | Model/Service | Why |
|-----------|---------------|-----|
| Transcription | `whisper-1` (OpenAI API) or local `base.en` | Fast, accurate, offline option |
| Intent + Planning | `gpt-4o` | Vision + reasoning, best for AX tree understanding |
| Fallback | `claude-3-5-sonnet` | Better at long-context AX trees |
| Screen Understanding | `gpt-4o` vision | Sees screenshots, understands UI |
| Local option | `mlx-vlm` on Apple Silicon | macOS-use's goal — zero cost, private |

**Cost optimization**: Use `gpt-4o-mini` for simple commands (open app, type text), `gpt-4o` only for complex multi-step tasks.

---

## Backend Services

```
Supabase (PostgreSQL + Auth)
├── users table (id, email, plan, created_at)
├── usage table (user_id, commands_used, period)
└── sessions table (for JWT refresh)

Stripe
├── Free tier: 50 commands/month
├── Pro ($12/mo): Unlimited commands
└── Team ($29/mo): Shared team commands

Clerk (recommended over raw Supabase auth)
└── Handles SSO, magic links, Apple Sign-In

Backend: FastAPI (extend agent/main.py)
├── POST /auth/token
├── GET /usage/current
└── POST /stripe/webhook
```

---

## Landing Page (Next.js)

```bash
cd apps/web
npx create-next-app@latest . --typescript --tailwind --app
```

Key sections to build:
- **Hero**: Screen recording of Lemon-style demo (record yourself using the app)
- **How it works**: 3-step animation (speak → think → done)
- **Use cases**: Email, Slack, docs with GIF demos per app
- **Pricing**: Free / Pro / Team with Stripe Checkout
- **Social proof**: "2 hours saved per day" stat cards

Stack: Next.js 15 + Tailwind + Framer Motion + Stripe + Clerk

---

## Implementation Phases

### Phase 1 — Working Prototype (2 weeks)
**Goal**: Voice → action in one app, no UI

1. Clone `macOS-use` and `GPT-Automator` into `/agent/vendor/`
2. Build `voice_pipeline.py` using local Whisper (offline, no API key needed)
3. Wire to macOS-use's agent loop
4. Test with hardcoded commands in Gmail
5. Simple Python CLI: `python agent/main.py "compose email to mom"`

**Milestone**: You can say a command in terminal and see it execute on screen.

---

### Phase 2 — Mac App Shell (1 week)
**Goal**: Proper Mac app with overlay

1. Create SwiftUI project, add menu bar icon (NSStatusItem)
2. Build OverlayWindow with recording state UI
3. Implement HotkeyManager (use `KeyboardShortcuts` package, map to `⌥Space` initially)
4. Connect AudioRecorder.swift → save WAV → pass to Python via AgentBridge
5. Spin up FastAPI server as embedded Python process on app launch

**Milestone**: Press hotkey → speak → see overlay → action executes.

---

### Phase 3 — Multi-App Coverage (2 weeks)
**Goal**: Works across Mail, Slack, Chrome, Finder, Calendar

1. Build `actions/` module with app-specific AppleScript templates
2. Add app detection logic — route to right action handler
3. Implement FeedbackLoop with screenshot verification
4. Add retry logic for failed actions
5. Test with 20+ real-world commands

**Milestone**: Demo video covering 5+ apps.

---

### Phase 4 — Polish + Onboarding (1 week)
**Goal**: Feels like a real product

1. Permissions flow (Mic, Accessibility, Screen Recording) with guided UI
2. Settings window: model selection, hotkey config, API key input
3. Command history (local SQLite)
4. Error states ("I couldn't find that element, try again")
5. Smooth animations in overlay

---

### Phase 5 — Backend + Web (1 week)
**Goal**: Users can sign up and pay

1. Deploy Next.js landing page (Vercel)
2. Set up Supabase + Clerk auth
3. Add usage tracking in Python agent
4. Stripe integration (Checkout + webhooks)
5. Build usage dashboard in Settings

---

### Phase 6 — Distribution (1 week)
**Goal**: People can install it

1. Code sign with Apple Developer account ($99/yr)
2. Bundle Python agent inside `.app` via PyInstaller
3. Notarize with Apple Notary Service
4. Build Sparkle auto-updater
5. Submit to Mac App Store OR distribute via direct DMG

---

## Quick Start Commands

```bash
# Clone the key repos as references
git clone https://github.com/browser-use/macOS-use agent/vendor/macos-use
git clone https://github.com/chidiwilliams/GPT-Automator agent/vendor/gpt-automator

# Set up Python agent
cd agent
python -m venv .venv && source .venv/bin/activate
pip install openai-whisper sounddevice fastapi uvicorn langchain langchain-openai pillow pyobjc-framework-ApplicationServices

# Install macOS-use
cd vendor/macos-use && pip install -e . && cd ../..

# Run agent server
uvicorn main:app --host 127.0.0.1 --port 7789

# Set up web
cd ../apps/web
npm install && npm run dev
```

---

The absolute fastest path: take `macOS-use` as your agent core verbatim, wrap it in a FastAPI server, build the SwiftUI overlay for the Mac-native feel, and you'll have a working Lemon clone in under 2 weeks. The Apple polish (animations, permissions flow, hotkey feel) is what makes it feel like a $12/mo product instead of a hackathon demo.
use this repo clone it and use its code https://github.com/browser-use/macOS-use

