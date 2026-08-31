// AI layer: Claude API when a key is configured, local heuristics otherwise.
//
// This is a buildless static app, so Claude is called over raw HTTP from the
// browser (the official JS SDK needs a bundler). The
// `anthropic-dangerous-direct-browser-access` header opts into CORS with a
// user-supplied key that never leaves this browser except to api.anthropic.com.

import { getApiKey } from './store.js';

const API_URL = 'https://api.anthropic.com/v1/messages';
const MODEL = 'claude-opus-5';

export function hasApiKey() {
  return !!getApiKey();
}

async function callClaude(content, { maxTokens = 3000, system } = {}) {
  const key = getApiKey();
  if (!key) throw new Error('no-key');
  const body = {
    model: MODEL,
    max_tokens: maxTokens,
    messages: [{ role: 'user', content }],
  };
  if (system) body.system = system;

  const res = await fetch(API_URL, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'x-api-key': key,
      'anthropic-version': '2023-06-01',
      'anthropic-dangerous-direct-browser-access': 'true',
    },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    const detail = (await res.text().catch(() => '')).slice(0, 300);
    throw new Error(`Claude API error ${res.status}: ${detail}`);
  }
  const data = await res.json();
  if (data.stop_reason === 'refusal') {
    throw new Error('Claude declined to process this content.');
  }
  return (data.content || [])
    .filter(b => b.type === 'text')
    .map(b => b.text)
    .join('');
}

// Pull the first JSON object/array out of a model reply that may have prose
// or a ```json fence around it.
function extractJson(text) {
  const fenced = text.match(/```(?:json)?\s*([\s\S]*?)```/);
  const candidate = fenced ? fenced[1] : text;
  const start = candidate.search(/[[{]/);
  if (start === -1) throw new Error('No JSON in model reply');
  for (let end = candidate.length; end > start; end--) {
    const slice = candidate.slice(start, end).trim();
    if (!slice) continue;
    try { return JSON.parse(slice); } catch { /* keep shrinking */ }
  }
  throw new Error('Unparsable JSON in model reply');
}

function imageBlockFromDataUrl(dataUrl) {
  const m = dataUrl.match(/^data:(image\/[a-z+.-]+);base64,(.+)$/s);
  if (!m) throw new Error('Unsupported image format');
  return {
    type: 'image',
    source: { type: 'base64', media_type: m[1], data: m[2] },
  };
}

const ANALYZE_SYSTEM = `You turn a user's screenshot and/or raw text into a short-form "note short" for a TikTok-style personal notes app. Respond with ONLY a JSON object, no prose, with exactly these fields:
{
  "title": "punchy title, max 8 words",
  "summary": "1-2 vivid sentences capturing the essence",
  "keyPoints": ["3-5 short takeaways, each under 12 words"],
  "extractedText": "the important text you can read in the screenshot, or the cleaned input text",
  "suggestedTags": ["4-6 lowercase single-word-or-hyphenated tags"],
  "category": "one broad category like Ideas, Work, Reading, Code, Finance, Health, Travel, Recipes, Learning",
  "theme": {
    "gradient": ["#hex1", "#hex2", "#hex3"],
    "emoji": "one emoji that captures the vibe",
    "particles": ["2-3 emoji for floating background particles"]
  }
}
Make the theme gradient vivid and saturated, matched to the content's mood (e.g. finance = deep greens/golds, recipes = warm oranges). Colors must read well behind white text.`;

// ---- screenshot / text -> note fields ----
export async function analyzeCapture({ imageDataUrl, text }) {
  if (hasApiKey()) {
    const content = [];
    if (imageDataUrl) content.push(imageBlockFromDataUrl(imageDataUrl));
    content.push({
      type: 'text',
      text: text
        ? `Here is my note text${imageDataUrl ? ' to go with the screenshot' : ''}:\n\n${text}`
        : 'Analyze this screenshot and turn it into a note short.',
    });
    const reply = await callClaude(content, { system: ANALYZE_SYSTEM, maxTokens: 2500 });
    const parsed = extractJson(reply);
    return normalizeAnalysis(parsed, text);
  }
  return analyzeLocally({ text });
}

function normalizeAnalysis(a, fallbackText) {
  const theme = a.theme || {};
  return {
    title: String(a.title || 'Untitled note').slice(0, 90),
    summary: String(a.summary || '').slice(0, 400),
    keyPoints: (Array.isArray(a.keyPoints) ? a.keyPoints : []).slice(0, 5).map(String),
    text: String(a.extractedText || fallbackText || ''),
    suggestedTags: (Array.isArray(a.suggestedTags) ? a.suggestedTags : [])
      .slice(0, 8).map(t => String(t).toLowerCase().replace(/^#/, '').trim()).filter(Boolean),
    category: String(a.category || 'General').slice(0, 30),
    theme: {
      gradient: Array.isArray(theme.gradient) && theme.gradient.length >= 2
        ? theme.gradient.slice(0, 3).map(String)
        : randomGradient(),
      emoji: String(theme.emoji || '📝').slice(0, 8),
      particles: (Array.isArray(theme.particles) ? theme.particles : ['✨']).slice(0, 3).map(String),
    },
  };
}

// ---- all notes -> mind-map links ----
const LINK_SYSTEM = `You find meaningful connections between a user's personal notes for a mind map. Given a list of notes, respond with ONLY a JSON array of links:
[{ "a": "<note id>", "b": "<note id>", "reason": "why they connect, under 8 words" }]
Only link notes with a real thematic, topical or causal connection. Prefer quality over quantity: at most ${'${MAX}'} links, none for unrelated notes. Never link a note to itself; never repeat a pair.`;

export async function suggestLinks(notes) {
  if (notes.length < 2) return [];
  if (hasApiKey()) {
    const digest = notes.map(n => ({
      id: n.id,
      title: n.title,
      summary: n.summary,
      tags: n.tags,
      category: n.category,
    }));
    const maxLinks = Math.min(notes.length * 2, 30);
    const reply = await callClaude(
      [{ type: 'text', text: 'My notes:\n' + JSON.stringify(digest, null, 1) }],
      { system: LINK_SYSTEM.replace('${MAX}', String(maxLinks)), maxTokens: 2000 },
    );
    const parsed = extractJson(reply);
    const ids = new Set(notes.map(n => n.id));
    const seen = new Set();
    const links = [];
    for (const l of Array.isArray(parsed) ? parsed : []) {
      if (!ids.has(l.a) || !ids.has(l.b) || l.a === l.b) continue;
      const pair = [l.a, l.b].sort().join('|');
      if (seen.has(pair)) continue;
      seen.add(pair);
      links.push({ a: l.a, b: l.b, reason: String(l.reason || 'related').slice(0, 60) });
    }
    return links;
  }
  return linkLocally(notes);
}

// ============================================================
// Local fallbacks (no API key): simple but serviceable.
// ============================================================

const STOPWORDS = new Set(('the a an and or but of to in on for with at by from is are was were be been ' +
  'this that these those it its as if then than so not no yes you your i my me we our they them he she ' +
  'his her do does did have has had will would can could should about into over under out up down just ' +
  'very really more most some any all there here what when where which who how why also').split(' '));

function keywords(text, n) {
  const freq = new Map();
  for (const raw of (text.toLowerCase().match(/[a-z][a-z0-9'-]{2,}/g) || [])) {
    const w = raw.replace(/'s$/, '');
    if (STOPWORDS.has(w)) continue;
    freq.set(w, (freq.get(w) || 0) + 1);
  }
  return [...freq.entries()].sort((x, y) => y[1] - x[1]).slice(0, n).map(e => e[0]);
}

const PALETTES = [
  ['#fe2c55', '#7b2ff7', '#25f4ee'],
  ['#ff9a3d', '#ff2e63', '#6a2ff7'],
  ['#0ba360', '#3cba92', '#0f2027'],
  ['#12c2e9', '#c471ed', '#f64f59'],
  ['#f7971e', '#ffd200', '#c0392b'],
  ['#4776e6', '#8e54e9', '#1a2980'],
  ['#11998e', '#38ef7d', '#0f3443'],
  ['#e100ff', '#7f00ff', '#00c9ff'],
];
function randomGradient() {
  return PALETTES[Math.floor(Math.random() * PALETTES.length)];
}

function analyzeLocally({ text }) {
  const body = (text || '').trim();
  const lines = body.split(/\n+/).map(l => l.trim()).filter(Boolean);
  const firstLine = lines[0] || 'Screenshot note';
  const title = firstLine.length > 60 ? firstLine.slice(0, 57) + '…' : firstLine;
  const sentences = body.replace(/\n+/g, ' ').match(/[^.!?]+[.!?]?/g) || [];
  return {
    title,
    summary: sentences.slice(0, 2).join(' ').trim().slice(0, 240) || 'A captured moment worth keeping.',
    keyPoints: lines.slice(1, 5).map(l => l.slice(0, 80)),
    text: body,
    suggestedTags: keywords(body, 5),
    category: 'General',
    theme: {
      gradient: randomGradient(),
      emoji: '📝',
      particles: ['✨', '💫'],
    },
  };
}

function linkLocally(notes) {
  const links = [];
  for (let i = 0; i < notes.length; i++) {
    for (let j = i + 1; j < notes.length; j++) {
      const a = notes[i], b = notes[j];
      const shared = (a.tags || []).filter(t => (b.tags || []).includes(t));
      if (shared.length) {
        links.push({ a: a.id, b: b.id, reason: '#' + shared[0] });
      } else if (a.category && a.category === b.category) {
        links.push({ a: a.id, b: b.id, reason: a.category });
      }
    }
  }
  return links.slice(0, 40);
}
