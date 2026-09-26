// ============================================================================
// WebUI.swift — Production-Grade Embedded Web Chat, Vision & Audio Interface
// Part of dev — Apple Intelligence from the command line
// ============================================================================

import Foundation

public enum WebUIContent {
    public static let html: String = ##"""
<!DOCTYPE html>
<html lang="en" data-theme="dark">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">
  <title>SayItDev — On-Device Apple Intelligence</title>
  <style>
    /* ═══════════════════════════════════════════════════════════════
       Design Tokens — Fanout.sh / System Design System
       ═══════════════════════════════════════════════════════════════ */
    :root {
      --font-sans: "Inter", -apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro Text", "Segoe UI", system-ui, sans-serif;
      --font-mono: "JetBrains Mono", "SF Mono", ui-monospace, Menlo, Consolas, monospace;
      --font-heading: var(--font-sans);

      --r-sm: 4px;
      --r-md: 6px;
      --r-lg: 8px;
      --r-xl: 12px;
      --r-2xl: 16px;
      --r-full: 999px;

      --dur-fast: 120ms;
      --dur-normal: 200ms;
      --dur-slow: 350ms;
      --ease-out: cubic-bezier(0, 0, 0.2, 1);

      --topbar-h: 54px;
      --sidebar-w: 270px;
    }

    /* ── Dark Theme (Default) ──────────────────────────────────── */
    [data-theme="dark"], :root {
      --bg: #111213;
      --bg-alt: #0d0e0f;
      --surface: #191a1c;
      --surface-hover: #242527;
      --surface-active: #2c2d30;
      --sidebar-bg: #151617;
      --topbar-bg: rgba(17, 18, 19, 0.88);
      --panel-glass: rgba(25, 26, 28, 0.94);

      --border: #2a2b2e;
      --border-strong: #36373b;
      --border-focus: #4c4e54;
      --divider: #202123;

      --fg: #f2f4f7;
      --fg-prose: #d0d6de;
      --fg-muted: #a9b0ba;
      --fg-faint: #747d89;
      --fg-inv: #111315;

      --accent: #3e7bfa;
      --accent-hover: #2b6bf2;
      --accent-muted: rgba(62, 123, 250, 0.12);
      --accent-border: rgba(62, 123, 250, 0.32);

      --success: #4ed08a;
      --success-muted: rgba(78, 208, 138, 0.12);
      --warning: #f0a45b;
      --warning-muted: rgba(240, 164, 91, 0.12);
      --error: #f87171;
      --error-muted: rgba(248, 113, 113, 0.12);

      --chip-bg: #202123;
      --chip-border: #2e3034;
      --chip-fg: #a9b0ba;

      --code-bg: #141517;
      --code-border: #26272b;
      --code-fg: #e6edf3;

      --shadow-sm: 0 1px 2px rgba(0, 0, 0, 0.35), 0 0 0 1px rgba(255, 255, 255, 0.03);
      --shadow-md: 0 2px 6px rgba(0, 0, 0, 0.45), 0 0 0 1px rgba(255, 255, 255, 0.04);
      --shadow-lg: 0 8px 24px rgba(0, 0, 0, 0.55), 0 0 0 1px rgba(255, 255, 255, 0.06);
      --shadow-card: 0 1px 2px rgba(0, 0, 0, 0.35), 0 0 0 1px rgba(255, 255, 255, 0.03);
      --shadow-card-hover: 0 4px 16px rgba(0, 0, 0, 0.5), 0 0 0 1px rgba(255, 255, 255, 0.06);

      color-scheme: dark;
    }

    /* ── Light Theme ───────────────────────────────────────────── */
    [data-theme="light"] {
      --bg: #fbfbfb;
      --bg-alt: #f4f5f6;
      --surface: #ffffff;
      --surface-hover: #f1f3f5;
      --surface-active: #e9ecef;
      --sidebar-bg: #f8f9fa;
      --topbar-bg: rgba(251, 251, 251, 0.92);
      --panel-glass: rgba(255, 255, 255, 0.96);

      --border: #e2e4e8;
      --border-strong: #cbd0d6;
      --border-focus: #9ca3af;
      --divider: #e9ebef;

      --fg: #111827;
      --fg-prose: #374151;
      --fg-muted: #4b5563;
      --fg-faint: #6b7280;
      --fg-inv: #ffffff;

      --accent: #2563eb;
      --accent-hover: #1d4ed8;
      --accent-muted: rgba(37, 99, 235, 0.1);
      --accent-border: rgba(37, 99, 235, 0.28);

      --success: #059669;
      --success-muted: rgba(5, 150, 105, 0.1);
      --warning: #d97706;
      --warning-muted: rgba(217, 119, 6, 0.1);
      --error: #dc2626;
      --error-muted: rgba(220, 38, 38, 0.1);

      --chip-bg: #f3f4f6;
      --chip-border: #e5e7eb;
      --chip-fg: #374151;

      --code-bg: #f6f8fa;
      --code-border: #d0d7de;
      --code-fg: #1f2328;

      --shadow-sm: 0 1px 2px rgba(0, 0, 0, 0.05);
      --shadow-md: 0 4px 12px rgba(0, 0, 0, 0.07);
      --shadow-lg: 0 8px 24px rgba(0, 0, 0, 0.09);
      --shadow-card: 0 1px 3px rgba(0, 0, 0, 0.06), 0 1px 2px rgba(0, 0, 0, 0.04);
      --shadow-card-hover: 0 4px 14px rgba(0, 0, 0, 0.08), 0 2px 4px rgba(0, 0, 0, 0.04);

      color-scheme: light;
    }

    * { box-sizing: border-box; margin: 0; padding: 0; }
    html, body {
      height: 100%;
      font-family: var(--font-sans);
      background: var(--bg);
      color: var(--fg);
      overflow: hidden;
      -webkit-font-smoothing: antialiased;
      -moz-osx-font-smoothing: grayscale;
    }

    /* ── Layout ────────────────────────────────────────────────── */
    #app {
      display: flex;
      height: 100vh;
      width: 100vw;
      position: relative;
    }

    /* ── Sidebar ───────────────────────────────────────────────── */
    #sidebar {
      width: var(--sidebar-w);
      background: var(--sidebar-bg);
      border-right: 1px solid var(--border);
      display: flex;
      flex-direction: column;
      flex-shrink: 0;
      transition: transform var(--dur-normal) var(--ease-out), width var(--dur-normal) var(--ease-out);
      z-index: 30;
      height: 100%;
    }

    .sidebar-header {
      padding: 14px 16px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      border-bottom: 1px solid var(--divider);
      height: var(--topbar-h);
    }

    .brand {
      display: flex;
      align-items: center;
      gap: 10px;
      text-decoration: none;
      color: var(--fg);
    }

    .brand-icon {
      width: 26px;
      height: 26px;
      border-radius: var(--r-md);
      background: var(--surface);
      border: 1px solid var(--border-strong);
      display: flex;
      align-items: center;
      justify-content: center;
      font-weight: 700;
      font-size: 13px;
      color: var(--accent);
      box-shadow: var(--shadow-sm);
    }

    .brand-text {
      font-weight: 700;
      font-size: 15px;
      letter-spacing: -0.02em;
    }

    .brand-badge {
      font-size: 10px;
      font-family: var(--font-mono);
      font-weight: 600;
      padding: 1px 6px;
      border-radius: var(--r-sm);
      background: var(--accent-muted);
      color: var(--accent);
      border: 1px solid var(--accent-border);
      letter-spacing: 0.03em;
      text-transform: uppercase;
    }

    .new-chat-wrap {
      padding: 12px 14px 8px;
    }

    .btn {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 6px;
      font-family: var(--font-sans);
      font-size: 13px;
      font-weight: 500;
      border-radius: var(--r-md);
      border: 1px solid transparent;
      cursor: pointer;
      transition: all var(--dur-fast) var(--ease-out);
      white-space: nowrap;
      text-decoration: none;
    }

    .btn--primary {
      background: var(--accent);
      color: #ffffff;
      padding: 8px 14px;
      width: 100%;
      box-shadow: var(--shadow-sm);
    }
    .btn--primary:hover {
      background: var(--accent-hover);
    }

    .btn--secondary {
      background: var(--surface);
      color: var(--fg);
      border-color: var(--border);
      padding: 6px 12px;
    }
    .btn--secondary:hover {
      background: var(--surface-hover);
      border-color: var(--border-strong);
    }

    .btn--icon {
      width: 32px;
      height: 32px;
      padding: 0;
      border-radius: var(--r-md);
      background: transparent;
      border: 1px solid transparent;
      color: var(--fg-muted);
    }
    .btn--icon:hover {
      background: var(--surface-hover);
      border-color: var(--border);
      color: var(--fg);
    }

    .kbd-chip {
      font-family: var(--font-mono);
      font-size: 11px;
      padding: 1px 5px;
      border-radius: var(--r-sm);
      background: rgba(255, 255, 255, 0.1);
      margin-left: auto;
    }

    .chat-history {
      flex: 1;
      overflow-y: auto;
      padding: 8px 10px;
      display: flex;
      flex-direction: column;
      gap: 3px;
    }

    .history-section-title {
      font-size: 11px;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.04em;
      color: var(--fg-faint);
      padding: 10px 8px 4px;
    }

    .chat-item {
      display: flex;
      align-items: center;
      gap: 10px;
      padding: 8px 10px;
      border-radius: var(--r-md);
      color: var(--fg-muted);
      cursor: pointer;
      font-size: 13px;
      transition: all var(--dur-fast);
      position: relative;
      user-select: none;
    }

    .chat-item:hover {
      background: var(--surface-hover);
      color: var(--fg);
    }

    .chat-item.active {
      background: var(--surface);
      color: var(--fg);
      border: 1px solid var(--border);
      box-shadow: var(--shadow-sm);
    }

    .chat-item.active::before {
      content: "";
      position: absolute;
      left: -10px;
      top: 6px;
      bottom: 6px;
      width: 3px;
      border-radius: 0 var(--r-sm) var(--r-sm) 0;
      background: var(--accent);
    }

    .chat-item-icon {
      font-size: 14px;
      opacity: 0.7;
      flex-shrink: 0;
    }

    .chat-item-title {
      flex: 1;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }

    .chat-item-del {
      opacity: 0;
      background: none;
      border: none;
      color: var(--fg-faint);
      cursor: pointer;
      padding: 2px 4px;
      border-radius: var(--r-sm);
      transition: all var(--dur-fast);
    }
    .chat-item:hover .chat-item-del {
      opacity: 1;
    }
    .chat-item-del:hover {
      color: var(--error);
      background: var(--error-muted);
    }

    /* Sidebar Footer */
    .sidebar-footer {
      padding: 12px 14px;
      border-top: 1px solid var(--divider);
      background: var(--bg-alt);
      display: flex;
      flex-direction: column;
      gap: 8px;
    }

    .system-status-card {
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: var(--r-md);
      padding: 8px 10px;
      display: flex;
      flex-direction: column;
      gap: 6px;
      font-size: 11px;
    }

    .status-row {
      display: flex;
      align-items: center;
      justify-content: space-between;
    }

    .status-dot {
      width: 7px;
      height: 7px;
      border-radius: 50%;
      background: var(--success);
      box-shadow: 0 0 6px var(--success);
      display: inline-block;
      flex-shrink: 0;
    }
    .status-dot.offline {
      background: var(--error);
      box-shadow: 0 0 6px var(--error);
    }

    .engine-badge {
      display: flex;
      align-items: center;
      gap: 6px;
      font-weight: 500;
      color: var(--fg);
    }

    /* ── Main Area ─────────────────────────────────────────────── */
    #main {
      flex: 1;
      display: flex;
      flex-direction: column;
      height: 100vh;
      overflow: hidden;
      background: var(--bg);
      position: relative;
    }

    /* ── Top Bar ───────────────────────────────────────────────── */
    .topbar {
      height: var(--topbar-h);
      border-bottom: 1px solid var(--border);
      background: var(--topbar-bg);
      backdrop-filter: blur(12px);
      -webkit-backdrop-filter: blur(12px);
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 0 18px;
      z-index: 20;
      flex-shrink: 0;
    }

    .topbar-left {
      display: flex;
      align-items: center;
      gap: 12px;
    }

    .topbar-title {
      font-size: 14px;
      font-weight: 600;
      letter-spacing: -0.01em;
      color: var(--fg);
      max-width: 320px;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }

    .badge {
      display: inline-flex;
      align-items: center;
      gap: 5px;
      padding: 2px 8px;
      font-size: 11px;
      font-weight: 500;
      border-radius: var(--r-sm);
      line-height: 1.4;
      font-family: var(--font-mono);
    }

    .badge--accent {
      background: var(--accent-muted);
      color: var(--accent);
      border: 1px solid var(--accent-border);
    }

    .badge--success {
      background: var(--success-muted);
      color: var(--success);
    }

    .topbar-right {
      display: flex;
      align-items: center;
      gap: 8px;
    }

    .endpoint-input-wrap {
      display: flex;
      align-items: center;
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: var(--r-md);
      padding: 2px 6px;
    }

    .endpoint-input {
      background: transparent;
      border: none;
      outline: none;
      font-family: var(--font-mono);
      font-size: 11px;
      color: var(--fg-muted);
      width: 145px;
    }

    /* ── Chat Messages Scroll Area ─────────────────────────────── */
    .chat-scroll {
      flex: 1;
      overflow-y: auto;
      padding: 24px 20px;
      display: flex;
      flex-direction: column;
      align-items: center;
      scroll-behavior: smooth;
    }

    .chat-messages {
      width: 100%;
      max-width: 780px;
      display: flex;
      flex-direction: column;
      gap: 24px;
      padding-bottom: 20px;
    }

    /* ── Hero / Empty State ────────────────────────────────────── */
    .hero-container {
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      margin: 40px auto 20px;
      max-width: 680px;
      text-align: center;
      animation: fadeIn var(--dur-normal) var(--ease-out);
    }

    .hero-icon-ring {
      width: 56px;
      height: 56px;
      border-radius: var(--r-xl);
      background: var(--surface);
      border: 1px solid var(--border-strong);
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 26px;
      margin-bottom: 18px;
      box-shadow: var(--shadow-md);
    }

    .hero-title {
      font-size: 24px;
      font-weight: 700;
      letter-spacing: -0.03em;
      color: var(--fg);
      margin-bottom: 8px;
    }

    .hero-sub {
      font-size: 14px;
      color: var(--fg-muted);
      line-height: 1.6;
      max-width: 520px;
      margin-bottom: 28px;
    }

    .cards-grid {
      display: grid;
      grid-template-columns: repeat(2, 1fr);
      gap: 12px;
      width: 100%;
      text-align: left;
    }

    .prompt-card {
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: var(--r-lg);
      padding: 14px 16px;
      cursor: pointer;
      transition: all var(--dur-fast) var(--ease-out);
      box-shadow: var(--shadow-card);
      display: flex;
      flex-direction: column;
      gap: 4px;
    }

    .prompt-card:hover {
      background: var(--surface-hover);
      border-color: var(--border-strong);
      transform: translateY(-1px);
      box-shadow: var(--shadow-card-hover);
    }

    .card-header {
      display: flex;
      align-items: center;
      gap: 8px;
      font-size: 13px;
      font-weight: 600;
      color: var(--fg);
    }

    .card-desc {
      font-size: 12px;
      color: var(--fg-muted);
      line-height: 1.5;
    }

    /* ── Messages ──────────────────────────────────────────────── */
    .msg-group {
      display: flex;
      gap: 14px;
      width: 100%;
      animation: fadeIn var(--dur-normal) var(--ease-out);
    }

    .msg-group.user {
      flex-direction: row-reverse;
    }

    .avatar {
      width: 32px;
      height: 32px;
      border-radius: var(--r-md);
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 14px;
      font-weight: 600;
      flex-shrink: 0;
      box-shadow: var(--shadow-sm);
    }

    .avatar.assistant {
      background: var(--surface);
      border: 1px solid var(--border-strong);
      color: var(--accent);
    }

    .avatar.user {
      background: var(--accent);
      color: white;
    }

    .msg-body {
      display: flex;
      flex-direction: column;
      max-width: 85%;
      gap: 6px;
    }

    .msg-group.user .msg-body {
      align-items: flex-end;
    }

    .msg-bubble {
      padding: 12px 16px;
      border-radius: var(--r-xl);
      font-size: 14px;
      line-height: 1.65;
      word-break: break-word;
      position: relative;
    }

    .msg-group.user .msg-bubble {
      background: var(--surface);
      border: 1px solid var(--border-strong);
      color: var(--fg);
      border-top-right-radius: var(--r-sm);
      box-shadow: var(--shadow-sm);
    }

    .msg-group.assistant .msg-bubble {
      background: var(--surface);
      border: 1px solid var(--border);
      color: var(--fg);
      border-top-left-radius: var(--r-sm);
      box-shadow: var(--shadow-card);
      width: 100%;
    }

    .msg-image-thumb {
      max-width: 320px;
      max-height: 240px;
      border-radius: var(--r-md);
      border: 1px solid var(--border);
      object-fit: cover;
      margin-bottom: 6px;
      cursor: zoom-in;
      display: block;
      transition: transform var(--dur-fast);
    }
    .msg-image-thumb:hover {
      transform: scale(1.01);
    }

    .msg-meta {
      display: flex;
      align-items: center;
      gap: 10px;
      font-size: 11px;
      color: var(--fg-faint);
      padding: 0 4px;
    }

    .msg-action-btn {
      background: transparent;
      border: none;
      color: var(--fg-muted);
      cursor: pointer;
      font-size: 12px;
      display: inline-flex;
      align-items: center;
      gap: 4px;
      padding: 2px 6px;
      border-radius: var(--r-sm);
      transition: all var(--dur-fast);
    }
    .msg-action-btn:hover {
      background: var(--surface-hover);
      color: var(--fg);
    }

    /* ── Prose & Code in Markdown ──────────────────────────────── */
    .prose {
      font-size: 14px;
      line-height: 1.7;
      color: var(--fg-prose);
    }
    .prose > * + * { margin-top: 10px; }
    .prose h1, .prose h2, .prose h3, .prose h4 {
      color: var(--fg);
      font-weight: 600;
      letter-spacing: -0.015em;
      margin-top: 14px;
      margin-bottom: 6px;
    }
    .prose h1 { font-size: 1.25rem; }
    .prose h2 { font-size: 1.15rem; }
    .prose h3 { font-size: 1.05rem; }
    .prose p { margin: 0 0 8px 0; }
    .prose p:last-child { margin-bottom: 0; }
    .prose ul, .prose ol { padding-left: 20px; margin: 8px 0; }
    .prose li { margin-bottom: 4px; }
    .prose blockquote {
      border-left: 2px solid var(--accent);
      background: var(--accent-muted);
      padding: 8px 14px;
      border-radius: 0 var(--r-md) var(--r-md) 0;
      margin: 10px 0;
      color: var(--fg);
    }
    .prose code.inline-code {
      font-family: var(--font-mono);
      font-size: 12.5px;
      background: var(--code-bg);
      border: 1px solid var(--code-border);
      color: var(--code-fg);
      padding: 1px 5px;
      border-radius: var(--r-sm);
    }
    .code-block {
      background: var(--code-bg);
      border: 1px solid var(--code-border);
      border-radius: var(--r-md);
      margin: 12px 0;
      overflow: hidden;
      box-shadow: var(--shadow-sm);
    }
    .code-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 6px 12px;
      background: rgba(0, 0, 0, 0.2);
      border-bottom: 1px solid var(--code-border);
      font-family: var(--font-mono);
      font-size: 11px;
      color: var(--fg-muted);
    }
    .code-copy-btn {
      background: transparent;
      border: 1px solid var(--border);
      color: var(--fg-muted);
      border-radius: var(--r-sm);
      padding: 2px 7px;
      font-size: 11px;
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      gap: 4px;
      transition: all var(--dur-fast);
    }
    .code-copy-btn:hover {
      background: var(--surface-hover);
      color: var(--fg);
    }
    .code-content {
      padding: 12px 14px;
      overflow-x: auto;
      font-family: var(--font-mono);
      font-size: 12.5px;
      line-height: 1.6;
      color: var(--code-fg);
    }

    .cursor {
      display: inline-block;
      width: 7px;
      height: 15px;
      background: var(--accent);
      vertical-align: text-bottom;
      margin-left: 2px;
      animation: blink 0.8s infinite;
    }

    /* ── Floating Input Dock ───────────────────────────────────── */
    .input-dock {
      width: 100%;
      max-width: 820px;
      margin: 0 auto;
      padding: 0 20px 20px;
      position: relative;
      flex-shrink: 0;
    }

    .input-box {
      background: var(--surface);
      border: 1px solid var(--border-strong);
      border-radius: var(--r-xl);
      padding: 12px 14px 10px;
      display: flex;
      flex-direction: column;
      gap: 8px;
      box-shadow: var(--shadow-lg);
      transition: border-color var(--dur-fast), box-shadow var(--dur-fast);
      position: relative;
    }

    .input-box:focus-within {
      border-color: var(--accent);
      box-shadow: 0 0 0 1px var(--accent-border), var(--shadow-lg);
    }

    .input-box.drag-active {
      border-color: var(--accent);
      background: var(--accent-muted);
    }

    .attachment-bar {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
    }

    .attachment-chip {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      background: var(--bg);
      border: 1px solid var(--border);
      border-radius: var(--r-md);
      padding: 4px 8px;
      font-size: 12px;
    }

    .attachment-thumb {
      width: 26px;
      height: 26px;
      border-radius: var(--r-sm);
      object-fit: cover;
    }

    .attachment-close {
      background: none;
      border: none;
      color: var(--fg-faint);
      cursor: pointer;
      font-size: 14px;
      line-height: 1;
      padding: 0 2px;
    }
    .attachment-close:hover { color: var(--error); }

    .prompt-textarea {
      background: transparent;
      border: none;
      outline: none;
      color: var(--fg);
      font-family: var(--font-sans);
      font-size: 14px;
      line-height: 1.5;
      resize: none;
      min-height: 26px;
      max-height: 200px;
      width: 100%;
    }

    .dock-actions {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding-top: 4px;
      border-top: 1px solid var(--divider);
    }

    .dock-left-actions {
      display: flex;
      align-items: center;
      gap: 6px;
    }

    .action-icon-btn {
      background: transparent;
      border: 1px solid transparent;
      color: var(--fg-muted);
      border-radius: var(--r-md);
      width: 32px;
      height: 32px;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      transition: all var(--dur-fast);
      font-size: 15px;
    }

    .action-icon-btn:hover {
      background: var(--surface-hover);
      color: var(--fg);
      border-color: var(--border);
    }

    .action-icon-btn.recording {
      color: var(--error);
      background: var(--error-muted);
      border-color: var(--error);
      animation: pulse 1s infinite;
    }

    .dock-right-actions {
      display: flex;
      align-items: center;
      gap: 8px;
    }

    .send-action-btn {
      width: 32px;
      height: 32px;
      border-radius: var(--r-md);
      background: var(--accent);
      color: white;
      border: none;
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      transition: all var(--dur-fast);
      box-shadow: var(--shadow-sm);
    }
    .send-action-btn:hover {
      background: var(--accent-hover);
      transform: translateY(-1px);
    }
    .send-action-btn:disabled {
      opacity: 0.35;
      cursor: not-allowed;
      transform: none;
    }

    .stop-action-btn {
      width: 32px;
      height: 32px;
      border-radius: var(--r-md);
      background: var(--error);
      color: white;
      border: none;
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      box-shadow: var(--shadow-sm);
    }

    .dock-footer-hints {
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 11px;
      color: var(--fg-faint);
      margin-top: 8px;
      gap: 12px;
    }

    /* ── Lightbox Modal ────────────────────────────────────────── */
    .lightbox-modal {
      position: fixed;
      inset: 0;
      z-index: 100;
      background: rgba(0, 0, 0, 0.82);
      backdrop-filter: blur(8px);
      display: none;
      align-items: center;
      justify-content: center;
      padding: 20px;
    }
    .lightbox-modal.open {
      display: flex;
    }
    .lightbox-content {
      max-width: 90vw;
      max-height: 90vh;
      border-radius: var(--r-lg);
      border: 1px solid var(--border-strong);
      box-shadow: var(--shadow-lg);
      position: relative;
    }
    .lightbox-close {
      position: absolute;
      top: -38px;
      right: 0;
      background: none;
      border: none;
      color: white;
      font-size: 24px;
      cursor: pointer;
    }

    /* ── Animations ────────────────────────────────────────────── */
    @keyframes fadeIn {
      from { opacity: 0; transform: translateY(4px); }
      to { opacity: 1; transform: translateY(0); }
    }
    @keyframes pulse {
      0% { transform: scale(1); }
      50% { transform: scale(1.08); }
      100% { transform: scale(1); }
    }
    @keyframes blink {
      0%, 100% { opacity: 1; }
      50% { opacity: 0; }
    }

    /* ── Responsive ────────────────────────────────────────────── */
    @media (max-width: 768px) {
      #sidebar {
        position: absolute;
        left: 0;
        top: 0;
        bottom: 0;
        transform: translateX(-100%);
      }
      #sidebar.open {
        transform: translateX(0);
      }
      .cards-grid {
        grid-template-columns: 1fr;
      }
    }
  </style>
</head>
<body>

<div id="app">
  <!-- Left Sidebar -->
  <aside id="sidebar">
    <div class="sidebar-header">
      <a href="/" class="brand">
        <div class="brand-icon">🍏</div>
        <div class="brand-text">dev</div>
        <div class="brand-badge">On-Device</div>
      </a>
      <button class="btn btn--icon" id="sidebar-close-btn" title="Close Sidebar" style="display:none;">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 6L6 18M6 6l12 12"/></svg>
      </button>
    </div>

    <div class="new-chat-wrap">
      <button class="btn btn--primary" id="new-chat-btn">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><line x1="12" y1="5" x2="12" y2="19"></line><line x1="5" y1="12" x2="19" y2="12"></line></svg>
        <span>New Conversation</span>
        <span class="kbd-chip">⌘K</span>
      </button>
    </div>

    <div class="history-section-title">Conversations</div>
    <div class="chat-history" id="chat-history"></div>

    <div class="sidebar-footer">
      <div class="system-status-card">
        <div class="status-row">
          <span class="engine-badge">
            <span class="status-dot" id="server-dot"></span>
            <span>Neural Engine</span>
          </span>
          <span id="server-status-label" style="color:var(--fg-faint); font-family:var(--font-mono);">Online</span>
        </div>
        <div style="color:var(--fg-faint); line-height:1.4;">
          100% On-Device &bull; Zero Network
        </div>
      </div>
    </div>
  </aside>

  <!-- Main Chat Workspace -->
  <main id="main">
    <!-- Topbar -->
    <header class="topbar">
      <div class="topbar-left">
        <button class="btn btn--icon" id="sidebar-toggle-btn" title="Toggle Sidebar">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="3" y1="12" x2="21" y2="12"></line><line x1="3" y1="6" x2="21" y2="6"></line><line x1="3" y1="18" x2="21" y2="18"></line></svg>
        </button>
        <span class="topbar-title" id="chat-title">New Conversation</span>
        <span class="badge badge--accent" id="model-badge">FoundationModels</span>
      </div>

      <div class="topbar-right">
        <div class="endpoint-input-wrap" title="Server URL">
          <span style="font-size:11px; color:var(--fg-faint); margin-right:4px;">API:</span>
          <input type="text" class="endpoint-input" id="endpoint-url" value="" />
        </div>
        <button class="btn btn--icon" id="theme-toggle-btn" title="Toggle Dark/Light Mode">
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="sun-icon"><circle cx="12" cy="12" r="5"></circle><line x1="12" y1="1" x2="12" y2="3"></line><line x1="12" y1="21" x2="12" y2="23"></line><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"></line><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"></line><line x1="1" y1="12" x2="3" y2="12"></line><line x1="21" y1="12" x2="23" y2="12"></line><line x1="4.22" y1="19.78" x2="5.64" y2="18.36"></line><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"></line></svg>
        </button>
        <button class="btn btn--icon" id="clear-chat-btn" title="Clear Conversation">
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="3 6 5 6 21 6"></polyline><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path></svg>
        </button>
      </div>
    </header>

    <!-- Scrollable Messages Area -->
    <div class="chat-scroll" id="chat-scroll">
      <div class="chat-messages" id="chat-messages">
        <!-- Hero screen shown when no messages -->
        <div class="hero-container" id="hero-container">
          <div class="hero-icon-ring">🍏</div>
          <h1 class="hero-title">The Free AI Already On Your Mac</h1>
          <p class="hero-sub">Direct access to Apple's on-device FoundationModels LLM. Fast, private, and 100% local with zero cloud dependencies.</p>
          <div class="cards-grid">
            <div class="prompt-card" onclick="setPrompt('Describe this image in detail and extract all visible code or text.')">
              <div class="card-header"><span>📷</span> Vision & OCR Analysis</div>
              <div class="card-desc">Attach an image or paste from clipboard to extract data</div>
            </div>
            <div class="prompt-card" onclick="setPrompt('Write a clean Swift actor that handles concurrent job queues with TaskGroup.')">
              <div class="card-header"><span>💻</span> Swift Strict Concurrency</div>
              <div class="card-desc">Actors, Sendable types, and modern Swift 6 patterns</div>
            </div>
            <div class="prompt-card" onclick="setPrompt('Explain how Fanout architecture works in distributed event-driven systems.')">
              <div class="card-header"><span>🧠</span> System Design & Fanout</div>
              <div class="card-desc">Event queues, pub-sub scaling, and delivery guarantees</div>
            </div>
            <div class="prompt-card" onclick="setPrompt('Show me 5 useful zsh one-liners for text processing using jq and xargs.')">
              <div class="card-header"><span>⚡️</span> UNIX Shell Pipelines</div>
              <div class="card-desc">Pipe-friendly workflows and terminal automation</div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Floating Input Dock -->
    <div class="input-dock">
      <div class="input-box" id="input-box">
        <div class="attachment-bar" id="attachment-bar" style="display:none;">
          <div class="attachment-chip">
            <img id="attachment-preview" class="attachment-thumb" src="" alt="preview" />
            <span id="attachment-name" style="max-width:200px; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; font-family:var(--font-mono); font-size:11px;">image.png</span>
            <button class="attachment-close" id="attachment-remove-btn" title="Remove">&times;</button>
          </div>
        </div>

        <textarea class="prompt-textarea" id="prompt-input" rows="1" placeholder="Type a message or drag/paste an image... (Enter to send, Shift+Enter for newline)"></textarea>

        <div class="dock-actions">
          <div class="dock-left-actions">
            <input type="file" id="file-input" accept="image/*" style="display:none;" />
            <button class="action-icon-btn" id="attach-btn" title="Attach image (Vision)">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="18" height="18" rx="2" ry="2"></rect><circle cx="8.5" cy="8.5" r="1.5"></circle><polyline points="21 15 16 10 5 21"></polyline></svg>
            </button>
            <button class="action-icon-btn" id="voice-btn" title="Voice Input (STT)">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 1a3 3 0 0 0-3 3v8a3 3 0 0 0 6 0V4a3 3 0 0 0-3-3z"></path><path d="M19 10v2a7 7 0 0 1-14 0v-2"></path><line x1="12" y1="19" x2="12" y2="23"></line><line x1="8" y1="23" x2="16" y2="23"></line></svg>
            </button>
            <span class="badge" style="font-size:10px; opacity:0.7;">4,096 ctx</span>
          </div>

          <div class="dock-right-actions">
            <button class="stop-action-btn" id="stop-btn" title="Stop Generation" style="display:none;">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><rect x="4" y="4" width="16" height="16" rx="2"></rect></svg>
            </button>
            <button class="send-action-btn" id="send-btn" title="Send (Enter)">
              <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><line x1="12" y1="19" x2="12" y2="5"></line><polyline points="5 12 12 5 19 12"></polyline></svg>
            </button>
          </div>
        </div>
      </div>

      <div class="dock-footer-hints">
        <span>Enter to send &bull; Shift+Enter for newline</span>
        <span>&bull;</span>
        <span>Drag or ⌘V to attach images</span>
        <span>&bull;</span>
        <span>100% on-device</span>
      </div>
    </div>
  </main>
</div>

<!-- Image Lightbox Modal -->
<div class="lightbox-modal" id="lightbox-modal">
  <div style="position:relative;">
    <button class="lightbox-close" id="lightbox-close-btn">&times;</button>
    <img id="lightbox-img" class="lightbox-content" src="" alt="expanded image" />
  </div>
</div>

<script>
  // ── Theme Management ─────────────────────────────────────────
  const themeToggleBtn = document.getElementById('theme-toggle-btn');
  function initTheme() {
    const saved = localStorage.getItem('dev_theme') || 'dark';
    document.documentElement.setAttribute('data-theme', saved);
  }
  themeToggleBtn.onclick = () => {
    const current = document.documentElement.getAttribute('data-theme') || 'dark';
    const next = current === 'dark' ? 'light' : 'dark';
    document.documentElement.setAttribute('data-theme', next);
    localStorage.setItem('dev_theme', next);
  };
  initTheme();

  // ── Endpoint & Health Management ─────────────────────────────
  const endpointInput = document.getElementById('endpoint-url');
  const serverDot = document.getElementById('server-dot');
  const serverStatusLabel = document.getElementById('server-status-label');
  const modelBadge = document.getElementById('model-badge');

  const defaultEndpoint = (window.location.origin && window.location.origin !== 'null' && !window.location.origin.startsWith('file:'))
    ? window.location.origin
    : 'http://127.0.0.1:11434';
  endpointInput.value = localStorage.getItem('dev_endpoint') || defaultEndpoint;

  async function checkServerHealth() {
    const base = endpointInput.value.trim().replace(/\/+$/, '');
    localStorage.setItem('dev_endpoint', base);
    try {
      const res = await fetch(`${base}/health`, { signal: AbortSignal.timeout(3000) });
      if (res.ok) {
        const data = await res.json();
        serverDot.className = 'status-dot';
        serverStatusLabel.textContent = 'Online';
        modelBadge.textContent = data.model || 'FoundationModels';
      } else {
        serverDot.className = 'status-dot offline';
        serverStatusLabel.textContent = `HTTP ${res.status}`;
      }
    } catch (_) {
      serverDot.className = 'status-dot offline';
      serverStatusLabel.textContent = 'Offline';
    }
  }
  endpointInput.onchange = checkServerHealth;
  checkServerHealth();
  setInterval(checkServerHealth, 15000);

  // ── Conversation State ───────────────────────────────────────
  let conversations = JSON.parse(localStorage.getItem('dev_convos') || '[]');
  let activeId = null;
  let currentImageBase64 = null;
  let abortCtrl = null;

  const chatHistoryEl = document.getElementById('chat-history');
  const chatMessagesEl = document.getElementById('chat-messages');
  const chatScrollEl = document.getElementById('chat-scroll');
  const heroContainerEl = document.getElementById('hero-container');
  const promptInput = document.getElementById('prompt-input');
  const sendBtn = document.getElementById('send-btn');
  const stopBtn = document.getElementById('stop-btn');
  const chatTitle = document.getElementById('chat-title');
  const clearChatBtn = document.getElementById('clear-chat-btn');
  const newChatBtn = document.getElementById('new-chat-btn');

  // Sidebar toggle for mobile/compact
  const sidebarEl = document.getElementById('sidebar');
  const sidebarToggleBtn = document.getElementById('sidebar-toggle-btn');
  sidebarToggleBtn.onclick = () => {
    sidebarEl.classList.toggle('open');
  };

  function persistConversations() {
    localStorage.setItem('dev_convos', JSON.stringify(conversations));
    renderHistory();
  }

  function renderHistory() {
    chatHistoryEl.innerHTML = '';
    conversations.forEach(c => {
      const item = document.createElement('div');
      item.className = 'chat-item' + (c.id === activeId ? ' active' : '');
      item.innerHTML = `
        <span class="chat-item-icon">💬</span>
        <span class="chat-item-title">${escapeHtml(c.title || 'New Conversation')}</span>
        <button class="chat-item-del" title="Delete conversation">&times;</button>
      `;
      item.querySelector('.chat-item-title').onclick = () => selectConversation(c.id);
      item.querySelector('.chat-item-icon').onclick = () => selectConversation(c.id);
      item.querySelector('.chat-item-del').onclick = (e) => {
        e.stopPropagation();
        deleteConversation(c.id);
      };
      chatHistoryEl.appendChild(item);
    });
  }

  function createNewConversation() {
    activeId = 'c_' + Date.now();
    const conv = { id: activeId, title: 'New Conversation', messages: [] };
    conversations.unshift(conv);
    persistConversations();
    selectConversation(activeId);
  }

  function deleteConversation(id) {
    conversations = conversations.filter(c => c.id !== id);
    if (activeId === id) {
      if (conversations.length > 0) selectConversation(conversations[0].id);
      else createNewConversation();
    } else {
      persistConversations();
    }
  }

  function selectConversation(id) {
    activeId = id;
    const conv = conversations.find(c => c.id === id);
    if (!conv) return;
    chatTitle.textContent = conv.title || 'New Conversation';
    chatMessagesEl.innerHTML = '';

    if (!conv.messages || conv.messages.length === 0) {
      chatMessagesEl.appendChild(heroContainerEl);
    } else {
      conv.messages.forEach(m => {
        renderMessageItem(m.role, m.content, m.image, false);
      });
    }
    renderHistory();
    chatScrollEl.scrollTop = chatScrollEl.scrollHeight;
  }

  newChatBtn.onclick = createNewConversation;
  clearChatBtn.onclick = () => {
    const conv = conversations.find(c => c.id === activeId);
    if (conv) {
      conv.messages = [];
      conv.title = 'New Conversation';
      persistConversations();
      selectConversation(activeId);
    }
  };

  // Keyboard shortcut: ⌘K or Ctrl+K for new chat
  window.addEventListener('keydown', (e) => {
    if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') {
      e.preventDefault();
      createNewConversation();
    }
  });

  // ── Auto-Grow Textarea ───────────────────────────────────────
  promptInput.addEventListener('input', () => {
    promptInput.style.height = 'auto';
    promptInput.style.height = Math.min(promptInput.scrollHeight, 200) + 'px';
  });

  // ── Attachment & Vision ──────────────────────────────────────
  const fileInput = document.getElementById('file-input');
  const attachBtn = document.getElementById('attach-btn');
  const attachmentBar = document.getElementById('attachment-bar');
  const attachmentPreview = document.getElementById('attachment-preview');
  const attachmentName = document.getElementById('attachment-name');
  const attachmentRemoveBtn = document.getElementById('attachment-remove-btn');
  const inputBox = document.getElementById('input-box');

  attachBtn.onclick = () => fileInput.click();
  fileInput.onchange = (e) => {
    const file = e.target.files[0];
    if (file) handleImageFile(file);
  };

  function handleImageFile(file) {
    if (!file || !file.type.startsWith('image/')) return;
    const reader = new FileReader();
    reader.onload = (e) => {
      currentImageBase64 = e.target.result;
      attachmentPreview.src = currentImageBase64;
      attachmentName.textContent = file.name || 'image.png';
      attachmentBar.style.display = 'flex';
    };
    reader.readAsDataURL(file);
  }

  attachmentRemoveBtn.onclick = () => {
    currentImageBase64 = null;
    fileInput.value = '';
    attachmentBar.style.display = 'none';
  };

  // Drag and Drop
  ['dragenter', 'dragover'].forEach(ev => {
    inputBox.addEventListener(ev, (e) => {
      e.preventDefault();
      inputBox.classList.add('drag-active');
    });
  });
  ['dragleave', 'drop'].forEach(ev => {
    inputBox.addEventListener(ev, (e) => {
      e.preventDefault();
      inputBox.classList.remove('drag-active');
    });
  });
  inputBox.addEventListener('drop', (e) => {
    const file = e.dataTransfer.files[0];
    if (file) handleImageFile(file);
  });

  // Clipboard Paste (Cmd+V)
  window.addEventListener('paste', (e) => {
    const items = (e.clipboardData || window.clipboardData).items;
    for (const item of items) {
      if (item.type.indexOf('image') === 0) {
        handleImageFile(item.getAsFile());
        break;
      }
    }
  });

  // Lightbox Modal
  const lightboxModal = document.getElementById('lightbox-modal');
  const lightboxImg = document.getElementById('lightbox-img');
  const lightboxCloseBtn = document.getElementById('lightbox-close-btn');
  function openLightbox(src) {
    lightboxImg.src = src;
    lightboxModal.classList.add('open');
  }
  lightboxCloseBtn.onclick = () => lightboxModal.classList.remove('open');
  lightboxModal.onclick = (e) => {
    if (e.target === lightboxModal) lightboxModal.classList.remove('open');
  };

  // ── Prompt Execution ─────────────────────────────────────────
  window.setPrompt = function(text) {
    promptInput.value = text;
    promptInput.dispatchEvent(new Event('input'));
    promptInput.focus();
  };

  promptInput.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      submitMessage();
    }
  });
  sendBtn.onclick = submitMessage;

  async function submitMessage() {
    const text = promptInput.value.trim();
    if (!text && !currentImageBase64) return;

    if (!activeId) createNewConversation();
    const conv = conversations.find(c => c.id === activeId);

    if (heroContainerEl.parentNode) heroContainerEl.remove();

    const userImg = currentImageBase64;
    renderMessageItem('user', text, userImg, true);

    conv.messages.push({ role: 'user', content: text, image: userImg });
    if (conv.messages.length === 1 && text) {
      conv.title = text.slice(0, 36) + (text.length > 36 ? '...' : '');
      chatTitle.textContent = conv.title;
    }
    persistConversations();

    // Reset input
    currentImageBase64 = null;
    attachmentBar.style.display = 'none';
    promptInput.value = '';
    promptInput.style.height = 'auto';

    sendBtn.style.display = 'none';
    stopBtn.style.display = 'flex';

    // Assistant response container
    const assistantRow = renderMessageItem('assistant', '', null, true);
    const bubbleEl = assistantRow.querySelector('.msg-bubble');
    const proseEl = assistantRow.querySelector('.prose');
    const metaEl = assistantRow.querySelector('.msg-meta');

    // Add streaming cursor
    const cursor = document.createElement('span');
    cursor.className = 'cursor';
    bubbleEl.appendChild(cursor);

    abortCtrl = new AbortController();
    const base = endpointInput.value.trim().replace(/\/+$/, '');
    const startTime = Date.now();

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

      const res = await fetch(`${base}/v1/chat/completions`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          model: 'sayitdev-on-device',
          stream: true,
          messages: payloadMessages
        }),
        signal: abortCtrl.signal
      });

      if (!res.ok) {
        const err = await res.json().catch(() => ({}));
        proseEl.innerHTML = `<span style="color:var(--error);">Error (${res.status}): ${escapeHtml(err.error?.message || res.statusText)}</span>`;
        cursor.remove();
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
              renderMarkdownProse(proseEl, fullText);
              bubbleEl.appendChild(cursor);
              chatScrollEl.scrollTop = chatScrollEl.scrollHeight;
            } catch (_) {}
          }
        }
      }

      cursor.remove();
      const elapsedSec = ((Date.now() - startTime) / 1000).toFixed(1);
      conv.messages.push({ role: 'assistant', content: fullText });
      persistConversations();

      // Update meta row with stats + actions
      metaEl.innerHTML = `
        <span>${elapsedSec}s</span>
        <span>&bull;</span>
        <button class="msg-action-btn" onclick="copyText(decodeURIComponent('${encodeURIComponent(fullText)}'), this)">
          <span>📋</span> Copy
        </button>
        <button class="msg-action-btn" onclick="speakText(decodeURIComponent('${encodeURIComponent(fullText)}'))">
          <span>🔊</span> Listen
        </button>
      `;

    } catch (err) {
      cursor.remove();
      if (err.name !== 'AbortError') {
        proseEl.innerHTML = `<span style="color:var(--error);">Connection error: ${escapeHtml(err.message)}</span>`;
      }
    } finally {
      sendBtn.style.display = 'flex';
      stopBtn.style.display = 'none';
      abortCtrl = null;
    }
  }

  stopBtn.onclick = () => {
    if (abortCtrl) abortCtrl.abort();
  };

  // ── Render Message DOM ───────────────────────────────────────
  function renderMessageItem(role, text, imageSrc, scroll) {
    const group = document.createElement('div');
    group.className = `msg-group ${role}`;

    const avatar = document.createElement('div');
    avatar.className = `avatar ${role}`;
    avatar.textContent = role === 'user' ? 'U' : '🍏';
    group.appendChild(avatar);

    const body = document.createElement('div');
    body.className = 'msg-body';

    if (imageSrc) {
      const img = document.createElement('img');
      img.src = imageSrc;
      img.className = 'msg-image-thumb';
      img.title = 'Click to view full size';
      img.onclick = () => openLightbox(imageSrc);
      body.appendChild(img);
    }

    const bubble = document.createElement('div');
    bubble.className = 'msg-bubble';

    const prose = document.createElement('div');
    prose.className = 'prose';
    renderMarkdownProse(prose, text);
    bubble.appendChild(prose);
    body.appendChild(bubble);

    const meta = document.createElement('div');
    meta.className = 'msg-meta';
    if (role === 'assistant' && text) {
      meta.innerHTML = `
        <button class="msg-action-btn" onclick="copyText(decodeURIComponent('${encodeURIComponent(text)}'), this)">
          <span>📋</span> Copy
        </button>
        <button class="msg-action-btn" onclick="speakText(decodeURIComponent('${encodeURIComponent(text)}'))">
          <span>🔊</span> Listen
        </button>
      `;
    } else {
      meta.textContent = role === 'user' ? 'You' : 'dev';
    }
    body.appendChild(meta);

    group.appendChild(body);
    chatMessagesEl.appendChild(group);
    if (scroll) chatScrollEl.scrollTop = chatScrollEl.scrollHeight;
    return group;
  }

  // ── Markdown Parser ──────────────────────────────────────────
  function renderMarkdownProse(container, md) {
    if (!md) { container.innerHTML = ''; return; }

    // Fenced code blocks
    let html = md.replace(/```([a-zA-Z0-9_-]*)\n([\s\S]*?)```/g, (match, lang, code) => {
      const language = lang || 'text';
      const cleanCode = code.trim();
      return `
        <div class="code-block">
          <div class="code-header">
            <span>${escapeHtml(language)}</span>
            <button class="code-copy-btn" onclick="copyCodeBlock(this)">Copy</button>
          </div>
          <pre class="code-content"><code>${escapeHtml(cleanCode)}</code></pre>
        </div>
      `;
    });

    // Headers
    html = html.replace(/^### (.*$)/gim, '<h3>$1</h3>');
    html = html.replace(/^## (.*$)/gim, '<h2>$1</h2>');
    html = html.replace(/^# (.*$)/gim, '<h1>$1</h1>');

    // Bold & Italics
    html = html.replace(/\*\*\*(.*?)\*\*\*/g, '<strong><em>$1</em></strong>');
    html = html.replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>');
    html = html.replace(/\*(.*?)\*/g, '<em>$1</em>');

    // Blockquotes
    html = html.replace(/^> (.*$)/gim, '<blockquote>$1</blockquote>');

    // Inline code
    html = html.replace(/`([^`]+)`/g, '<code class="inline-code">$1</code>');

    // Lists
    html = html.replace(/^\s*[-*]\s+(.*)$/gim, '<li>$1</li>');
    html = html.replace(/(<li>[\s\S]*?<\/li>)/g, '<ul>$1</ul>');

    // Line breaks
    html = html.replace(/\n\n/g, '<p></p>');
    html = html.replace(/\n/g, '<br>');

    container.innerHTML = html;
  }

  function escapeHtml(str) {
    return (str || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }

  window.copyCodeBlock = function(btn) {
    const code = btn.closest('.code-block').querySelector('code').innerText;
    navigator.clipboard.writeText(code);
    const original = btn.innerText;
    btn.innerText = 'Copied!';
    setTimeout(() => { btn.innerText = original; }, 1500);
  };

  window.copyText = function(text, btn) {
    navigator.clipboard.writeText(text);
    if (btn) {
      const prev = btn.innerHTML;
      btn.innerHTML = '<span>✓</span> Copied!';
      setTimeout(() => { btn.innerHTML = prev; }, 1500);
    }
  };

  // ── Speech Synthesis (TTS) ───────────────────────────────────
  window.speakText = async function(text) {
    if (!text) return;
    const base = endpointInput.value.trim().replace(/\/+$/, '');
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
        return;
      }
    } catch (_) {}

    // Fallback to native Web Speech API
    if ('speechSynthesis' in window) {
      window.speechSynthesis.cancel();
      const utterance = new SpeechSynthesisUtterance(text);
      window.speechSynthesis.speak(utterance);
    }
  };

  // ── Voice Input (STT) ────────────────────────────────────────
  let mediaRecorder = null;
  let audioChunks = [];
  const voiceBtn = document.getElementById('voice-btn');

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
        formData.append('file', audioBlob, 'voice.wav');
        formData.append('model', 'whisper-1');

        const base = endpointInput.value.trim().replace(/\/+$/, '');
        try {
          const res = await fetch(`${base}/v1/audio/transcriptions`, {
            method: 'POST',
            body: formData
          });
          if (res.ok) {
            const data = await res.json();
            if (data.text) {
              promptInput.value = (promptInput.value ? promptInput.value + ' ' : '') + data.text;
              promptInput.dispatchEvent(new Event('input'));
              promptInput.focus();
            }
          }
        } catch (_) {}
      };
      mediaRecorder.start();
      voiceBtn.classList.add('recording');
    } catch (_) {
      alert('Microphone access unavailable or denied.');
    }
  };

  // ── Init ─────────────────────────────────────────────────────
  if (conversations.length === 0) {
    createNewConversation();
  } else {
    selectConversation(conversations[0].id);
  }
</script>
</body>
</html>
"""##
}
