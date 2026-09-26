// ============================================================================
// WebUI.swift — Production-Grade Embedded Web Chat, Vision & Audio Interface
// Part of dev — Apple Intelligence from the command line
// ============================================================================

import Foundation

public enum WebUIContent {
    public static let html: String = ##"""
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>SayItDev — On-Device Intelligence</title>
  <style>
    :root {
      --bg: #0d0d11;
      --sidebar: #13131a;
      --card: #1c1c24;
      --border: #2c2c38;
      --accent: #3b82f6;
      --accent-hover: #2563eb;
      --text: #f3f4f6;
      --text-muted: #9ca3af;
      --user-msg: #2563eb;
      --bot-msg: #1a1a23;
      --code-bg: #121218;
      --radius: 12px;
      --shadow: 0 4px 20px -2px rgba(0, 0, 0, 0.5);
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro Text", "Segoe UI", Roboto, sans-serif;
      background: var(--bg);
      color: var(--text);
      display: flex;
      height: 100vh;
      overflow: hidden;
      -webkit-font-smoothing: antialiased;
    }
    /* Sidebar */
    #sidebar {
      width: 270px;
      background: var(--sidebar);
      border-right: 1px solid var(--border);
      display: flex;
      flex-direction: column;
      flex-shrink: 0;
      transition: all 0.25s ease;
    }
    .side-header {
      padding: 18px 16px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      border-bottom: 1px solid var(--border);
    }
    .brand {
      display: flex;
      align-items: center;
      gap: 10px;
      font-weight: 700;
      font-size: 1.05rem;
      letter-spacing: -0.3px;
    }
    .brand-icon {
      width: 28px;
      height: 28px;
      background: linear-gradient(135deg, #3b82f6, #8b5cf6);
      border-radius: 8px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 1rem;
      color: white;
    }
    .new-chat-btn {
      margin: 14px 16px 8px;
      background: rgba(59, 130, 246, 0.12);
      border: 1px solid rgba(59, 130, 246, 0.3);
      color: var(--accent);
      padding: 10px 14px;
      border-radius: 10px;
      font-weight: 600;
      font-size: 0.9rem;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
      transition: all 0.2s;
    }
    .new-chat-btn:hover {
      background: var(--accent);
      color: white;
    }
    .chat-list {
      flex: 1;
      overflow-y: auto;
      padding: 8px 12px;
      display: flex;
      flex-direction: column;
      gap: 4px;
    }
    .chat-item {
      padding: 10px 12px;
      border-radius: 8px;
      font-size: 0.88rem;
      color: var(--text-muted);
      cursor: pointer;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
      display: flex;
      align-items: center;
      gap: 8px;
      transition: all 0.15s;
    }
    .chat-item:hover, .chat-item.active {
      background: var(--card);
      color: var(--text);
    }
    .side-footer {
      padding: 14px 16px;
      border-top: 1px solid var(--border);
      font-size: 0.78rem;
      color: var(--text-muted);
      display: flex;
      flex-direction: column;
      gap: 6px;
    }
    .status-pill {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      padding: 4px 8px;
      border-radius: 99px;
      background: rgba(16, 185, 129, 0.12);
      color: #10b981;
      font-weight: 500;
    }
    .status-pill.offline {
      background: rgba(239, 68, 68, 0.12);
      color: #ef4444;
    }
    .dot {
      width: 7px;
      height: 7px;
      border-radius: 50%;
      background: currentColor;
    }

    /* Main Area */
    #main-content {
      flex: 1;
      display: flex;
      flex-direction: column;
      height: 100vh;
      position: relative;
    }
    /* Top Bar */
    header {
      height: 56px;
      border-bottom: 1px solid var(--border);
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 0 24px;
      background: rgba(19, 19, 26, 0.7);
      backdrop-filter: blur(12px);
      z-index: 10;
    }
    .top-left {
      display: flex;
      align-items: center;
      gap: 12px;
    }
    .model-tag {
      font-size: 0.8rem;
      padding: 4px 10px;
      border-radius: 6px;
      background: var(--card);
      border: 1px solid var(--border);
      color: var(--text-muted);
      font-family: ui-monospace, monospace;
    }
    .top-right {
      display: flex;
      align-items: center;
      gap: 10px;
    }

    /* Chat Messages */
    #chat-scroll {
      flex: 1;
      overflow-y: auto;
      padding: 24px 20px;
      display: flex;
      flex-direction: column;
      align-items: center;
      scroll-behavior: smooth;
    }
    #chat-container {
      width: 100%;
      max-width: 820px;
      display: flex;
      flex-direction: column;
      gap: 20px;
      padding-bottom: 30px;
    }
    .welcome-hero {
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      margin: 80px auto 30px;
      text-align: center;
      max-width: 540px;
      animation: fadeIn 0.4s ease;
    }
    .welcome-icon {
      font-size: 3rem;
      margin-bottom: 16px;
    }
    .welcome-title {
      font-size: 1.8rem;
      font-weight: 700;
      letter-spacing: -0.5px;
      margin-bottom: 8px;
    }
    .welcome-sub {
      color: var(--text-muted);
      font-size: 0.95rem;
      line-height: 1.5;
      margin-bottom: 24px;
    }
    .suggestions {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 10px;
      width: 100%;
    }
    .sugg-card {
      background: var(--card);
      border: 1px solid var(--border);
      padding: 14px 16px;
      border-radius: 12px;
      cursor: pointer;
      font-size: 0.88rem;
      text-align: left;
      transition: all 0.2s;
    }
    .sugg-card:hover {
      border-color: var(--accent);
      transform: translateY(-1px);
    }
    .sugg-title {
      font-weight: 600;
      color: var(--text);
      margin-bottom: 4px;
    }
    .sugg-desc {
      color: var(--text-muted);
      font-size: 0.8rem;
    }

    /* Message Bubbles */
    .msg-row {
      display: flex;
      width: 100%;
      animation: fadeIn 0.25s ease;
    }
    .msg-row.user { justify-content: flex-end; }
    .msg-row.assistant { justify-content: flex-start; }
    .bubble-wrapper {
      max-width: 85%;
      display: flex;
      flex-direction: column;
      gap: 6px;
    }
    .msg-row.user .bubble-wrapper { align-items: flex-end; }
    .msg-bubble {
      padding: 14px 18px;
      border-radius: 14px;
      font-size: 0.95rem;
      line-height: 1.6;
      word-break: break-word;
    }
    .msg-row.user .msg-bubble {
      background: var(--user-msg);
      color: white;
      border-bottom-right-radius: 3px;
    }
    .msg-row.assistant .msg-bubble {
      background: var(--bot-msg);
      border: 1px solid var(--border);
      border-bottom-left-radius: 3px;
    }
    .msg-img {
      max-width: 320px;
      max-height: 260px;
      border-radius: 10px;
      object-fit: cover;
      border: 1px solid var(--border);
      margin-bottom: 8px;
      display: block;
    }
    .msg-footer {
      display: flex;
      align-items: center;
      gap: 10px;
      font-size: 0.72rem;
      color: var(--text-muted);
      padding: 0 4px;
    }
    .audio-play-btn {
      background: none;
      border: none;
      color: var(--text-muted);
      cursor: pointer;
      font-size: 0.85rem;
      display: inline-flex;
      align-items: center;
      gap: 4px;
      transition: color 0.15s;
    }
    .audio-play-btn:hover { color: var(--accent); }

    /* Code Block */
    pre {
      background: var(--code-bg);
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 12px 14px;
      overflow-x: auto;
      margin: 10px 0;
      position: relative;
      font-family: ui-monospace, Menlo, Monaco, Consolas, monospace;
      font-size: 0.88rem;
    }
    code {
      font-family: ui-monospace, Menlo, Monaco, Consolas, monospace;
      font-size: 0.9em;
    }
    .copy-btn {
      position: absolute;
      top: 8px;
      right: 8px;
      background: rgba(255, 255, 255, 0.08);
      border: 1px solid rgba(255, 255, 255, 0.12);
      color: var(--text-muted);
      border-radius: 5px;
      padding: 4px 8px;
      font-size: 0.72rem;
      cursor: pointer;
    }
    .copy-btn:hover { color: var(--text); background: rgba(255, 255, 255, 0.15); }

    /* Bottom Input Area */
    #input-dock {
      width: 100%;
      max-width: 820px;
      margin: 0 auto;
      padding: 0 20px 24px;
      position: relative;
    }
    .input-box {
      background: var(--card);
      border: 1px solid var(--border);
      border-radius: 16px;
      padding: 12px 16px 10px;
      display: flex;
      flex-direction: column;
      gap: 8px;
      box-shadow: var(--shadow);
      transition: border-color 0.2s, box-shadow 0.2s;
    }
    .input-box:focus-within {
      border-color: var(--accent);
      box-shadow: 0 0 0 1px var(--accent), var(--shadow);
    }
    .input-box.drag-over {
      border-color: #8b5cf6;
      background: rgba(139, 92, 246, 0.08);
    }
    .preview-pill {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      background: var(--bg);
      border: 1px solid var(--border);
      padding: 4px 10px 4px 6px;
      border-radius: 8px;
      align-self: flex-start;
      font-size: 0.8rem;
    }
    .preview-pill img {
      width: 32px;
      height: 32px;
      border-radius: 6px;
      object-fit: cover;
    }
    .remove-pill {
      background: none;
      border: none;
      color: var(--text-muted);
      cursor: pointer;
      font-size: 1rem;
      line-height: 1;
    }
    .remove-pill:hover { color: #ef4444; }
    #user-prompt {
      background: transparent;
      border: none;
      outline: none;
      color: var(--text);
      font-family: inherit;
      font-size: 0.96rem;
      line-height: 1.45;
      resize: none;
      max-height: 180px;
      min-height: 24px;
      width: 100%;
    }
    .input-actions {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding-top: 4px;
    }
    .action-group {
      display: flex;
      align-items: center;
      gap: 6px;
    }
    .tool-btn {
      background: none;
      border: none;
      color: var(--text-muted);
      cursor: pointer;
      padding: 6px 8px;
      border-radius: 8px;
      font-size: 1.1rem;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      transition: all 0.15s;
    }
    .tool-btn:hover {
      background: rgba(255, 255, 255, 0.08);
      color: var(--text);
    }
    .tool-btn.recording {
      color: #ef4444;
      animation: pulse 1s infinite;
    }
    .send-btn {
      background: var(--accent);
      border: none;
      color: white;
      width: 36px;
      height: 36px;
      border-radius: 50%;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      transition: all 0.2s;
    }
    .send-btn:hover { background: var(--accent-hover); transform: scale(1.05); }
    .send-btn:disabled { opacity: 0.35; cursor: not-allowed; transform: none; }
    .stop-btn {
      background: #ef4444;
      border: none;
      color: white;
      width: 36px;
      height: 36px;
      border-radius: 50%;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
    }

    @keyframes fadeIn { from { opacity: 0; transform: translateY(6px); } to { opacity: 1; transform: translateY(0); } }
    @keyframes pulse { 0% { transform: scale(1); } 50% { transform: scale(1.15); } 100% { transform: scale(1); } }
  </style>
</head>
<body>

  <!-- Left Sidebar -->
  <aside id="sidebar">
    <div class="side-header">
      <div class="brand">
        <div class="brand-icon">🍏</div>
        <span>SayItDev</span>
      </div>
    </div>
    <button class="new-chat-btn" id="new-chat-btn">
      <span>+</span> New Conversation
    </button>
    <div class="chat-list" id="chat-history-list"></div>
    <div class="side-footer">
      <div class="status-pill" id="health-pill">
        <span class="dot"></span>
        <span id="health-label">Checking...</span>
      </div>
      <div>100% On-Device &bull; FoundationModels</div>
    </div>
  </aside>

  <!-- Main Content -->
  <div id="main-content">
    <header>
      <div class="top-left">
        <span id="current-title" style="font-weight: 600; font-size: 0.95rem;">New Conversation</span>
        <span class="model-tag" id="model-tag">sayitdev-on-device</span>
      </div>
      <div class="top-right">
        <input type="text" id="server-url" value="" style="background:var(--card);border:1px solid var(--border);color:var(--text-muted);padding:4px 8px;border-radius:6px;font-size:0.75rem;width:170px;" />
        <button class="tool-btn" id="refresh-btn" title="Refresh Server Connection">🔄</button>
      </div>
    </header>

    <div id="chat-scroll">
      <div id="chat-container">
        <div class="welcome-hero" id="welcome-hero">
          <div class="welcome-icon">⚡️</div>
          <div class="welcome-title">Apple Intelligence On-Device</div>
          <div class="welcome-sub">Ask questions, attach images for vision analysis, stream code, or use voice transcription. Everything stays on your Mac.</div>
          <div class="suggestions">
            <div class="sugg-card" onclick="setPrompt('Describe this image in detail and transcribe any text you find.')">
              <div class="sugg-title">📷 Vision & OCR</div>
              <div class="sugg-desc">Attach an image and ask for extraction</div>
            </div>
            <div class="sugg-card" onclick="setPrompt('Write a Swift function that fetches JSON concurrently with async/await.')">
              <div class="sugg-title">💻 Swift Code</div>
              <div class="sugg-desc">Async/await, strict concurrency</div>
            </div>
            <div class="sugg-card" onclick="setPrompt('Explain how Apple FoundationModels on-device inference works.')">
              <div class="sugg-title">🧠 Architecture</div>
              <div class="sugg-desc">Learn about macOS on-device LLMs</div>
            </div>
            <div class="sugg-card" onclick="setPrompt('Summarize the top advantages of 100% local AI processing.')">
              <div class="sugg-title">🔒 Privacy First</div>
              <div class="sugg-desc">Zero cloud calls, zero data leaks</div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Bottom Dock -->
    <div id="input-dock">
      <div class="input-box" id="input-box">
        <div class="preview-pill" id="img-preview" style="display:none;">
          <img id="preview-thumb" src="" alt="preview" />
          <span id="preview-filename" style="max-width:180px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">image.png</span>
          <button class="remove-pill" id="remove-img-btn">&times;</button>
        </div>
        <textarea id="user-prompt" rows="1" placeholder="Type a message or drag/paste an image... (Enter to send, Shift+Enter for newline)"></textarea>
        <div class="input-actions">
          <div class="action-group">
            <input type="file" id="file-picker" accept="image/*" style="display:none;" />
            <button class="tool-btn" id="attach-img-btn" title="Attach Image (Vision)">📷</button>
            <button class="tool-btn" id="voice-btn" title="Voice Input (STT)">🎙️</button>
          </div>
          <button class="send-btn" id="send-btn" title="Send (Enter)">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><line x1="22" y1="2" x2="11" y2="13"></line><polygon points="22 2 15 22 11 13 2 9 22 2"></polygon></svg>
          </button>
          <button class="stop-btn" id="stop-btn" title="Stop Generation" style="display:none;">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><rect x="4" y="4" width="16" height="16" rx="2"></rect></svg>
          </button>
        </div>
      </div>
    </div>
  </div>

  <script>
    const serverInput = document.getElementById('server-url');
    if (!serverInput.value) {
      serverInput.value = window.location.origin && window.location.origin !== 'null' ? window.location.origin : 'http://127.0.0.1:11434';
    }

    const healthPill = document.getElementById('health-pill');
    const healthLabel = document.getElementById('health-label');
    const chatContainer = document.getElementById('chat-container');
    const chatScroll = document.getElementById('chat-scroll');
    const welcomeHero = document.getElementById('welcome-hero');
    const promptInput = document.getElementById('user-prompt');
    const sendBtn = document.getElementById('send-btn');
    const stopBtn = document.getElementById('stop-btn');
    const attachBtn = document.getElementById('attach-img-btn');
    const filePicker = document.getElementById('file-picker');
    const imgPreview = document.getElementById('img-preview');
    const previewThumb = document.getElementById('preview-thumb');
    const previewFilename = document.getElementById('preview-filename');
    const removeImgBtn = document.getElementById('remove-img-btn');
    const inputBox = document.getElementById('input-box');
    const voiceBtn = document.getElementById('voice-btn');
    const newChatBtn = document.getElementById('new-chat-btn');
    const chatList = document.getElementById('chat-history-list');

    let currentImageData = null;
    let abortController = null;
    let conversations = JSON.parse(localStorage.getItem('sayitdev_convos') || '[]');
    let activeConvoId = null;

    function saveConversations() {
      localStorage.setItem('sayitdev_convos', JSON.stringify(conversations));
      renderChatList();
    }

    function renderChatList() {
      chatList.innerHTML = '';
      conversations.forEach(c => {
        const item = document.createElement('div');
        item.className = 'chat-item' + (c.id === activeConvoId ? ' active' : '');
        item.textContent = c.title || 'Untitled Chat';
        item.onclick = () => loadConversation(c.id);
        chatList.appendChild(item);
      });
    }

    function createNewConversation() {
      activeConvoId = 'conv_' + Date.now();
      const newConv = { id: activeConvoId, title: 'New Conversation', messages: [] };
      conversations.unshift(newConv);
      saveConversations();
      loadConversation(activeConvoId);
    }

    function loadConversation(id) {
      activeConvoId = id;
      const conv = conversations.find(c => c.id === id);
      if (!conv) return;
      document.getElementById('current-title').textContent = conv.title || 'Conversation';
      chatContainer.innerHTML = '';
      if (conv.messages.length === 0) {
        chatContainer.appendChild(welcomeHero);
      } else {
        conv.messages.forEach(m => {
          appendMessageUI(m.role, m.content, m.image, false);
        });
      }
      renderChatList();
    }

    newChatBtn.onclick = createNewConversation;

    async function checkHealth() {
      const base = serverInput.value.replace(/\/+$/, '');
      try {
        const res = await fetch(`${base}/health`);
        if (res.ok) {
          const data = await res.json();
          healthPill.className = 'status-pill';
          healthLabel.textContent = `Online (${data.model || 'on-device'})`;
          document.getElementById('model-tag').textContent = data.model || 'sayitdev-on-device';
        } else {
          healthPill.className = 'status-pill offline';
          healthLabel.textContent = `Error ${res.status}`;
        }
      } catch (e) {
        healthPill.className = 'status-pill offline';
        healthLabel.textContent = 'Server Offline';
      }
    }
    checkHealth();
    document.getElementById('refresh-btn').onclick = checkHealth;
    serverInput.onchange = checkHealth;

    // Auto-grow textarea
    promptInput.addEventListener('input', () => {
      promptInput.style.height = 'auto';
      promptInput.style.height = Math.min(promptInput.scrollHeight, 180) + 'px';
    });

    // File attachments
    attachBtn.onclick = () => filePicker.click();
    filePicker.onchange = (e) => {
      const file = e.target.files[0];
      if (file) handleImage(file);
    };

    // Drag and drop & paste
    ['dragenter', 'dragover'].forEach(name => {
      inputBox.addEventListener(name, (e) => { e.preventDefault(); inputBox.classList.add('drag-over'); });
    });
    ['dragleave', 'drop'].forEach(name => {
      inputBox.addEventListener(name, (e) => { e.preventDefault(); inputBox.classList.remove('drag-over'); });
    });
    inputBox.addEventListener('drop', (e) => {
      const file = e.dataTransfer.files[0];
      if (file && file.type.startsWith('image/')) handleImage(file);
    });
    window.addEventListener('paste', (e) => {
      const items = (e.clipboardData || e.originalEvent.clipboardData).items;
      for (const item of items) {
        if (item.type.indexOf('image') === 0) {
          handleImage(item.getAsFile());
          break;
        }
      }
    });

    function handleImage(file) {
      const reader = new FileReader();
      reader.onload = (e) => {
        currentImageData = e.target.result;
        previewThumb.src = currentImageData;
        previewFilename.textContent = file.name || 'Image Attachment';
        imgPreview.style.display = 'inline-flex';
      };
      reader.readAsDataURL(file);
    }

    removeImgBtn.onclick = () => {
      currentImageData = null;
      filePicker.value = '';
      imgPreview.style.display = 'none';
    };

    function setPrompt(text) {
      promptInput.value = text;
      promptInput.dispatchEvent(new Event('input'));
      promptInput.focus();
    }

    promptInput.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault();
        sendMessage();
      }
    });
    sendBtn.onclick = sendMessage;

    async function sendMessage() {
      const text = promptInput.value.trim();
      if (!text && !currentImageData) return;

      if (!activeConvoId) createNewConversation();
      const conv = conversations.find(c => c.id === activeConvoId);

      if (welcomeHero.parentNode) welcomeHero.remove();

      const userContent = [];
      if (text) userContent.push({ type: 'text', text });
      if (currentImageData) {
        userContent.push({ type: 'image_url', image_url: { url: currentImageData } });
      }

      appendMessageUI('user', text, currentImageData, true);
      conv.messages.push({ role: 'user', content: text, image: currentImageData });
      if (conv.messages.length === 1 && text) {
        conv.title = text.slice(0, 32) + (text.length > 32 ? '...' : '');
        document.getElementById('current-title').textContent = conv.title;
      }
      saveConversations();

      const sentImage = currentImageData;
      currentImageData = null;
      imgPreview.style.display = 'none';
      promptInput.value = '';
      promptInput.style.height = 'auto';

      sendBtn.style.display = 'none';
      stopBtn.style.display = 'flex';

      const assistantRow = appendMessageUI('assistant', '', null, true);
      const bubble = assistantRow.querySelector('.msg-bubble');

      abortController = new AbortController();
      const base = serverInput.value.replace(/\/+$/, '');

      try {
        const payloadMessages = conv.messages.map(m => {
          if (m.image) {
            return {
              role: m.role,
              content: [
                { type: 'text', text: m.content || '' },
                { type: 'image_url', image_url: { url: m.image } }
              ]
            };
          }
          return { role: m.role, content: m.content };
        });

        const startTime = Date.now();
        const res = await fetch(`${base}/v1/chat/completions`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            model: 'sayitdev-on-device',
            stream: true,
            messages: payloadMessages
          }),
          signal: abortController.signal
        });

        if (!res.ok) {
          const err = await res.json().catch(() => ({}));
          bubble.textContent = `Error (${res.status}): ${err.error?.message || res.statusText}`;
          return;
        }

        const reader = res.body.getReader();
        const decoder = new TextDecoder();
        let fullText = '';
        let buffer = '';

        while (true) {
          const { done, value } = await reader.read();
          if (done) break;

          buffer += decoder.decode(value, { stream: true });
          const lines = buffer.split('\n');
          buffer = lines.pop();

          for (const line of lines) {
            const trimmed = line.trim();
            if (trimmed.startsWith('data: ') && trimmed !== 'data: [DONE]') {
              try {
                const json = JSON.parse(trimmed.slice(6));
                const delta = json.choices[0]?.delta?.content || '';
                fullText += delta;
                renderMarkdown(bubble, fullText);
                chatScroll.scrollTop = chatScroll.scrollHeight;
              } catch (_) {}
            }
          }
        }

        const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
        conv.messages.push({ role: 'assistant', content: fullText });
        saveConversations();

        // Add TTS speak button
        const footer = assistantRow.querySelector('.msg-footer');
        const speakBtn = document.createElement('button');
        speakBtn.className = 'audio-play-btn';
        speakBtn.innerHTML = '🔊 Speak';
        speakBtn.onclick = () => playSpeech(fullText);
        footer.appendChild(speakBtn);

      } catch (err) {
        if (err.name !== 'AbortError') {
          bubble.textContent = `Network error: ${err.message}`;
        }
      } finally {
        sendBtn.style.display = 'flex';
        stopBtn.style.display = 'none';
        abortController = null;
      }
    }

    stopBtn.onclick = () => {
      if (abortController) abortController.abort();
    };

    function appendMessageUI(role, text, imageSrc, scroll) {
      const row = document.createElement('div');
      row.className = `msg-row ${role}`;

      const wrapper = document.createElement('div');
      wrapper.className = 'bubble-wrapper';

      if (imageSrc) {
        const img = document.createElement('img');
        img.src = imageSrc;
        img.className = 'msg-img';
        wrapper.appendChild(img);
      }

      const bubble = document.createElement('div');
      bubble.className = 'msg-bubble';
      renderMarkdown(bubble, text);
      wrapper.appendChild(bubble);

      const footer = document.createElement('div');
      footer.className = 'msg-footer';
      footer.textContent = `${role === 'user' ? 'You' : 'SayItDev'} • ${new Date().toLocaleTimeString([], {hour:'2-digit', minute:'2-digit'})}`;
      wrapper.appendChild(footer);

      row.appendChild(wrapper);
      chatContainer.appendChild(row);
      if (scroll) chatScroll.scrollTop = chatScroll.scrollHeight;
      return row;
    }

    function renderMarkdown(el, md) {
      if (!md) { el.textContent = ''; return; }
      // Format code blocks
      let html = md.replace(/```([a-zA-Z0-9]*)\n([\s\S]*?)```/g, (match, lang, code) => {
        return `<pre><button class="copy-btn" onclick="navigator.clipboard.writeText(this.nextElementSibling.innerText);this.innerText='Copied!';setTimeout(()=>this.innerText='Copy',1500)">Copy</button><code>${escapeHtml(code.trim())}</code></pre>`;
      });
      // Bold
      html = html.replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>');
      // Inline code
      html = html.replace(/`([^`]+)`/g, '<code style="background:var(--code-bg);padding:2px 6px;border-radius:4px;border:1px solid var(--border);">$1</code>');
      // Line breaks
      html = html.replace(/\n/g, '<br>');
      el.innerHTML = html;
    }

    function escapeHtml(str) {
      return (str || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    }

    async function playSpeech(text) {
      const base = serverInput.value.replace(/\/+$/, '');
      try {
        const res = await fetch(`${base}/v1/audio/speech`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ input: text, voice: 'personal' })
        });
        if (res.ok) {
          const blob = await res.blob();
          const audio = new Audio(URL.createObjectURL(blob));
          audio.play();
        }
      } catch (e) {
        console.error('Speech playback failed', e);
      }
    }

    // Voice recording (STT)
    let mediaRecorder = null;
    let audioChunks = [];
    voiceBtn.onclick = async () => {
      if (mediaRecorder && mediaRecorder.state === 'recording') {
        mediaRecorder.stop();
        voiceBtn.classList.remove('recording');
        return;
      }
      try {
        const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
        mediaRecorder = new MediaRecorder(stream);
        audioChunks = [];
        mediaRecorder.ondataavailable = e => audioChunks.push(e.data);
        mediaRecorder.onstop = async () => {
          const audioBlob = new Blob(audioChunks, { type: 'audio/wav' });
          const formData = new FormData();
          formData.append('file', audioBlob, 'recording.wav');
          formData.append('model', 'whisper-1');
          const base = serverInput.value.replace(/\/+$/, '');
          const res = await fetch(`${base}/v1/audio/transcriptions`, { method: 'POST', body: formData });
          if (res.ok) {
            const data = await res.json();
            if (data.text) {
              promptInput.value = (promptInput.value ? promptInput.value + ' ' : '') + data.text;
              promptInput.dispatchEvent(new Event('input'));
            }
          }
        };
        mediaRecorder.start();
        voiceBtn.classList.add('recording');
      } catch (err) {
        alert('Microphone permission denied or not available');
      }
    };

    if (conversations.length === 0) {
      createNewConversation();
    } else {
      loadConversation(conversations[0].id);
    }
  </script>
</body>
</html>
"""##
}
