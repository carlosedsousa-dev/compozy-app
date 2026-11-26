# CompozyOS Mobile Design Reference Guide

This guide is the canonical visual specification for the **designer** agent when refactoring `compozy-app` interfaces. All screens must faithfully mirror the official CompozyOS screenshots located in `docs/design/reference-images/`.

---

## 1. Reference Image Mapping

| File | CompozyOS Surface | Usage in Mobile App |
|---|---|---|
| `hero.jpg` | Main Session / Agent Chat screen | Chat layout, session header, "While you were away" card, prompt input bar with pill buttons, and status pills. |
| `board.jpg` | Board / Active and recent Sessions list | Session card styling, agent avatars, status badges ("Needs you", "Working", "Waiting", "Done"), relative timestamps, and tags. |
| `always-on.jpg` | Agents overview and status | Circular avatars with activity status badges (pulsing green dot for running, amber dot for waiting), subtitle typography, and metrics. |
| `handoff.jpg` | Subagent hierarchy and transcript | Clean subtask tree rendering, collapsible tool execution pills, compact cards, and visual hierarchy. |
| `loops.jpg` | Loops catalog and editor | Loop cards with subtle thin borders, category tags (`Engineering`, `Marketing`, etc.), minimalist icons, and execution badges. |
| `automations.jpg` | Scheduled runs and history | Automation details, past run history, status pill, and parameter cards. |
| `lockup-dark.png` | CompozyOS visual identity | Typography, logo, and official branding proportions in dark mode. |

---

## 2. Design Tokens and Visual Philosophy

### Surface Colors (Chroma-Free Neutrals)
* **Canvas / General Background**: `#0A0A0A` (ultra-dark, with no blue or purple tints).
* **Secondary Surface / Desk**: `#101010` (for navigation areas and groupings).
* **Cards & Containers**: `#161616` to `#1A1A1A` with an extremely subtle border (`#262626`, 1px solid).
* **Elevated Surfaces / Hover**: `#232323`.

### Action and Interactivity
* **Primary Action (Primary Button)**: **Inverted Monochrome** (`#F5F5F5` with `#0A0A0A` text/icon in dark mode). **NEVER use orange or brand colors for primary buttons**.
* **Pills and Secondary Buttons**: `#232323` surface, `#2B2B2B` border, `#ECECEC` text.

### Semantic Signals (Accent Budget)
* **Orange / Accent (`#E8572A`)**: Reserved exclusively for **attention and urgency** (e.g., "Needs you" badge or dot, unread counters). Never used on general borders or primary buttons.
* **Green / Mint (`#34D399`)**: "Working" / "Online" / Success status.
* **Amber / Warning (`#F5B14C`)**: "Waiting" / Warning status.
* **Red / Danger (`#F87171`)**: Errors and failures.
* **Muted Foreground (`#989898`)**: Secondary text, metadata, timestamps, and categories.

---

## 3. Screen-by-Screen Guidelines

### A. Sessions List (`sessions_list_screen.dart`)
* Mirrors `board.jpg` and `hero.jpg`.
* Each session card includes:
  * Avatar identifying the agent or a subtle icon.
  * Prominent session title (`#FFFFFF`, weight 600, 15px).
  * Status line with colored dot (Orange for *Needs You*, Green for *Working*, Gray for *Done*).
  * Agent badge (e.g., `fixer`, `dispatcher`, `designer`) in a compact neutral pill.
  * Discreet relative timestamp (`#989898`).
* Top Bar: Compozy logo or clean title, accompanied by the compact daemon connection status pill (green `Online` / red `Offline`).

### B. Chat & Interaction Screen (`session_chat_screen.dart`)
* Mirrors `hero.jpg` and `handoff.jpg`.
* Messages:
  * User messages: right-aligned, subtle background (`#232323`), subtle border (`#2B2B2B`), rounded corners (16px, with a sharper bottom-right corner).
  * Agent messages: left-aligned, flat/transparent background over the canvas, agent avatar on the left or top, clean typography with support for code blocks using a `#161616` background.
  * Tool calls / Subagents: thin collapsible pills with a chevron to expand and inspect details (e.g., `Run manage_task` or `File ...`).
* Prompt Bar:
  * `#161616` background with subtle `#262626` border.
  * Send button shaped as a circle or rounded pill in `#FFFFFF` with a `#0A0A0A` dark icon.

### C. Loops Catalog (`loops_catalog_screen.dart`)
* Mirrors `loops.jpg` and `automations.jpg`.
* Loop cards with rounded corners (12px), `#161616` background, `#262626` border.
* Refined category chips (`All`, `Engineering`, `Marketing`, etc.) with high-contrast monochrome selection.
* Bottom sheet or detail modal displaying the contract, inputs, and status of previous runs.

### D. Mobile Navigation (`app_shell.dart`)
* Discreet Bottom Navigation Bar, 64dp height, `#0A0A0A` background, 1px `#202020` top border.
* Clean geometric-style icons; selected item in `#FFFFFF`, unselected in `#707070`.
