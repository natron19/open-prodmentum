# Prodmentum Demo

> Walk your product idea through a structured discovery process. AI guides you at every step.

## Description

Prodmentum Demo is an open source Rails 8 app that pairs a five-step product discovery workflow with Google Gemini. At each step of the discovery process — from framing the opportunity to assessing risk — the app collects your inputs and returns targeted, structured AI output designed to help you think more clearly, not think for you.

The workflow is based on Marty Cagan's continuous discovery framework as described in INSPIRED and EMPOWERED. It covers the four questions every product team should answer before engineering begins: does the customer want it, can they use it, can we build it, and does it work commercially?

## Why I Built This

I built this as a demo of one feature from Prodmentum, a multi-tenant AI-powered product management platform I am building for product teams. The full version connects discovery to execution — from strategic themes through OKRs down to tasks and retrospectives.

Most of the PMs I have talked to skip structured discovery because it feels heavyweight. They write a brief, add it to Jira, and start building. Cagan's framework is the right antidote, but it is hard to do alone. This demo shows what it looks like when AI plays the role of the experienced colleague who asks the questions you should have asked yourself.

This demo is open source under the MIT license. Clone it, run it, tune the prompts to your framework of choice.

## Quick Start

1. Clone this repo
2. Run `bin/setup`
3. Add your Gemini API key to `.env` (see below)
4. `bin/rails server`
5. Visit http://localhost:3000 and sign in with `demo@example.com` / `password123`

The seed data includes a complete pre-filled product example (QuickFeedback) so you can see what the output looks like before entering your own inputs. No API key required to explore the demo.

## Editing the AI Prompts

Every prompt in this app is stored as an editable template, not hardcoded. After running `bin/setup`, sign in as `demo@example.com` (password: `password123`) and navigate to `/admin/ai_templates`. You can edit any of the five discovery prompts and test them live from the admin UI without restarting the server. Prompt iteration notes are stored in the `notes` field on each template.

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `APP_NAME` | `"Open Demo Starter"` | Displayed in the navbar and title |
| `APP_TAGLINE` | — | Shown in the footer and landing page |
| `APP_DESCRIPTION` | — | Shown on the landing page |
| `GEMINI_API_KEY` | (required for live AI) | Your Google Gemini API key — get one free at https://aistudio.google.com/app/apikey |
| `AI_CALLS_PER_USER_PER_DAY` | `50` | Daily AI call budget per user |
| `AI_GLOBAL_TIMEOUT_SECONDS` | `15` | Gemini request timeout in seconds |

## Stack

| Layer | Choice |
|---|---|
| Framework | Rails 8.1 |
| Database | PostgreSQL with UUID primary keys |
| Auth | Rails native (`has_secure_password`, sessions) |
| CSS | Bootstrap 5 dark mode (CDN) |
| JavaScript | Stimulus + Turbo via importmap |
| AI | Google Gemini via Faraday (REST) |
| Queue / Cache / Cable | Solid Stack (no Redis) |
| Testing | RSpec |

## AI Safety Posture

**What this app enforces:**
- Per-user daily call cap (default: 50/day, set via `AI_CALLS_PER_USER_PER_DAY`)
- Pre-flight gatekeeper: input length limit, prompt injection patterns, profanity filter
- Hard output token cap per template
- Configurable request timeout (default: 15s)
- Rate limit on discovery step generation (10 requests per minute)
- Full request log with status, tokens, duration, and cost estimate
- Fail-soft UI: errors render an inline alert, never crash the page
- AI disclaimer in the footer on every page
- Step 5 inline disclaimer near the iterate/pivot/proceed recommendation

## License

MIT — see [LICENSE](LICENSE)
