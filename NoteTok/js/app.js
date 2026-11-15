// NoteTok — main glue: navigation, categories, search, settings, seeding.

import { getAllNotes, saveNote, clearAllNotes, getApiKey, setApiKey, wasSeeded, markSeeded, newId } from './store.js';
import { suggestLinks, aiMode } from './ai.js';
import { initFeed, renderFeed, scrollFeedToNote } from './feed.js';
import { renderNotesGrid } from './notes.js';
import { initMindmap, setGraph, startMindmap, stopMindmap } from './mindmap.js';
import { initCapture, openCapture } from './capture.js';
import { confirmDialog } from './ui.js';

let notes = [];
let activeCategory = 'For You';
let activeView = 'feed';        // 'feed' | 'notes' | 'mindmap'
let lastFeedView = 'feed';      // for the top-right toggle
let mindmapLinks = [];
let mindmapFresh = false;

const toastEl = document.getElementById('toast');
let toastTimer = null;
function showToast(msg) {
  toastEl.textContent = msg;
  toastEl.classList.remove('hidden');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => toastEl.classList.add('hidden'), 2600);
}

// ---------- view switching ----------
function switchView(name) {
  activeView = name;
  if (name !== 'mindmap') stopMindmap();
  for (const v of document.querySelectorAll('.view')) {
    v.classList.toggle('active', v.id === 'view-' + name);
  }
  for (const b of document.querySelectorAll('.nav-btn[data-nav]')) {
    b.classList.toggle('active', b.dataset.nav === name);
  }
  if (name === 'feed' || name === 'notes') lastFeedView = name;
  if (name === 'mindmap') {
    refreshMindmap();
    startMindmap();
  }
  render();
}

function render() {
  if (activeView === 'feed') renderFeed(notes, { category: activeCategory });
  if (activeView === 'notes') renderNotesGrid(notes, { category: activeCategory, onOpen: openInFeed });
  renderCategories();
}

function openInFeed(note) {
  switchView('feed');
  requestAnimationFrame(() => scrollFeedToNote(note.id));
}

async function reload({ keepScroll = false } = {}) {
  notes = await getAllNotes();
  mindmapFresh = false;
  render();
  if (activeView === 'mindmap') refreshMindmap();
  return keepScroll;
}

// ---------- categories ----------
function renderCategories() {
  const bar = document.getElementById('category-bar');
  const cats = ['For You', ...new Set(notes.map(n => n.category || 'General'))];
  if (!cats.includes(activeCategory)) activeCategory = 'For You';
  bar.innerHTML = '';
  for (const cat of cats) {
    const chip = document.createElement('button');
    chip.className = 'cat-chip' + (cat === activeCategory ? ' active' : '');
    chip.textContent = cat;
    chip.setAttribute('role', 'tab');
    chip.addEventListener('click', () => {
      activeCategory = cat;
      render();
    });
    bar.appendChild(chip);
  }
}

// ---------- mind map ----------
function refreshMindmap() {
  if (!mindmapFresh) {
    // Instant local pass (shared tags / categories) so the map is never empty;
    // the ✨ button upgrades it with Claude.
    mindmapLinks = localLinksFromNotes();
    mindmapFresh = true;
  }
  setGraph(notes, mindmapLinks);
}

function localLinksFromNotes() {
  const links = [];
  const stored = new Set();
  for (const n of notes) {
    for (const l of n.links || []) {
      const pair = [n.id, l.to].sort().join('|');
      if (stored.has(pair)) continue;
      stored.add(pair);
      links.push({ a: n.id, b: l.to, reason: l.reason });
    }
  }
  if (links.length) return links;
  for (let i = 0; i < notes.length; i++) {
    for (let j = i + 1; j < notes.length; j++) {
      const a = notes[i], b = notes[j];
      const shared = (a.tags || []).filter(t => (b.tags || []).includes(t));
      if (shared.length) links.push({ a: a.id, b: b.id, reason: '#' + shared[0] });
      else if (a.category && a.category === b.category) links.push({ a: a.id, b: b.id, reason: a.category });
    }
  }
  return links.slice(0, 40);
}

async function aiRelink() {
  const btn = document.getElementById('btn-relink');
  const status = document.getElementById('mindmap-status');
  if (notes.length < 2) { showToast('Add at least two notes first'); return; }
  btn.disabled = true;
  status.textContent = (await aiMode()) !== 'local' ? 'Claude is connecting the dots…' : 'Linking by shared tags…';
  try {
    mindmapLinks = await suggestLinks(notes);
    mindmapFresh = true;
    setGraph(notes, mindmapLinks);
    // Persist links on the notes so they survive reloads.
    const byId = new Map(notes.map(n => [n.id, n]));
    for (const n of notes) n.links = [];
    for (const l of mindmapLinks) {
      byId.get(l.a)?.links.push({ to: l.b, reason: l.reason });
    }
    await Promise.all(notes.map(saveNote));
    status.textContent = `${mindmapLinks.length} link${mindmapLinks.length === 1 ? '' : 's'} found`;
  } catch (err) {
    console.error(err);
    status.textContent = '';
    showToast('⚠️ ' + (err.message || 'Linking failed'));
  } finally {
    btn.disabled = false;
  }
}

// ---------- search ----------
function esc(s) {
  return String(s ?? '').replace(/[&<>"']/g, c =>
    ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

function runSearch(query) {
  const resultsEl = document.getElementById('search-results');
  const q = query.trim().toLowerCase();
  if (!q) { resultsEl.innerHTML = '<div class="search-empty">Type to search your shorts — try a word or a #tag.</div>'; return; }

  const tagQuery = q.startsWith('#') ? q.slice(1) : null;
  const hits = notes.filter(n => {
    if (tagQuery !== null) return (n.tags || []).some(t => t.includes(tagQuery));
    const hay = [n.title, n.summary, n.text, n.category, ...(n.tags || []).map(t => '#' + t), ...(n.keyPoints || [])]
      .join(' ').toLowerCase();
    return q.split(/\s+/).every(word => hay.includes(word));
  });

  if (!hits.length) { resultsEl.innerHTML = '<div class="search-empty">No notes match — maybe it\'s time to make one? ✨</div>'; return; }

  const mark = text => {
    const t = esc(text || '');
    if (tagQuery !== null) return t;
    let out = t;
    for (const word of q.split(/\s+/).filter(Boolean)) {
      out = out.replace(new RegExp('(' + word.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + ')', 'ig'), '<mark>$1</mark>');
    }
    return out;
  };

  resultsEl.innerHTML = '';
  for (const n of hits.slice(0, 30)) {
    const el = document.createElement('button');
    el.className = 'search-hit';
    const [c1, c2] = n.theme?.gradient || ['#fe2c55', '#25f4ee'];
    el.innerHTML = `
      <div class="hit-thumb" style="background:linear-gradient(135deg, ${esc(c1)}, ${esc(c2)})">
        ${n.image ? `<img src="${n.image}" alt="">` : esc(n.theme?.emoji || '📝')}
      </div>
      <div>
        <div class="hit-title">${mark(n.title)}</div>
        <div class="hit-sub">${esc(n.category || 'General')} · ${(n.tags || []).slice(0, 3).map(t => '#' + esc(t)).join(' ')}</div>
      </div>`;
    el.addEventListener('click', () => {
      closeModal('modal-search');
      activeCategory = 'For You';
      openInFeed(n);
    });
    resultsEl.appendChild(el);
  }
}

// ---------- modals ----------
function openModal(id) { document.getElementById(id).classList.remove('hidden'); }
function closeModal(id) { document.getElementById(id).classList.add('hidden'); }
function anyModalOpen() {
  return [...document.querySelectorAll('.modal')].some(m => !m.classList.contains('hidden'));
}

// ---------- feed navigation & autoplay ----------
function feedStep(dir) {
  const el = document.getElementById('view-feed');
  const atEnd = dir > 0 && el.scrollTop + el.clientHeight * 1.5 >= el.scrollHeight;
  if (atEnd) el.scrollTo({ top: 0, behavior: 'smooth' });        // loop like TikTok
  else el.scrollBy({ top: dir * el.clientHeight, behavior: 'smooth' });
}

let autoplayTimer = null;
function setAutoplay(on) {
  clearInterval(autoplayTimer);
  autoplayTimer = null;
  const btn = document.getElementById('btn-autoplay');
  btn.classList.toggle('on', on);
  btn.textContent = on ? '⏸' : '▶';
  btn.setAttribute('aria-pressed', String(on));
  if (on) {
    autoplayTimer = setInterval(() => {
      if (activeView !== 'feed' || anyModalOpen() || document.hidden) return;
      feedStep(1);
    }, 8000);
  }
}

// ---------- seed notes (first run) ----------
async function seedIfNeeded() {
  if (wasSeeded()) return;
  markSeeded();
  const now = Date.now();
  const seeds = [
    {
      title: 'Welcome to NoteTok ⚡',
      summary: 'Your notes, but they scroll like TikTok. Swipe up to see how it works.',
      keyPoints: ['Paste any screenshot with Ctrl/Cmd+V', 'Claude turns it into a vivid short', 'Confirm the tags it suggests', 'Swipe categories up top to filter'],
      text: 'Welcome note explaining the app.',
      tags: ['welcome', 'howto'], suggestedTags: ['welcome', 'howto', 'notes'],
      category: 'Learning',
      theme: { gradient: ['#fe2c55', '#7b2ff7', '#25f4ee'], emoji: '⚡', particles: ['⚡', '✨'] },
    },
    {
      title: 'The Mind Map connects everything',
      summary: 'Hit the Map tab and let AI link your notes to each other — your second brain, visualized.',
      keyPoints: ['Tap 🕸️ Map in the bottom bar', 'Press "✨ AI: link my notes"', 'Drag nodes, scroll to zoom, tap to open'],
      text: 'Mind map explainer.',
      tags: ['mindmap', 'howto'], suggestedTags: ['mindmap', 'howto', 'ai'],
      category: 'Learning',
      theme: { gradient: ['#12c2e9', '#c471ed', '#f64f59'], emoji: '🕸️', particles: ['🕸️', '💫'] },
    },
    {
      title: 'Two moods, one brain',
      summary: 'Feeling calm? Toggle the grid icon (top right) for a classic notes view. Feeling ✨scrolly✨? Come back to the feed.',
      keyPoints: ['Grid icon = classic notes view', 'Search 🔍 finds text and #tags', 'Double-tap any short to like it'],
      text: 'View toggle explainer.',
      tags: ['howto', 'views'], suggestedTags: ['howto', 'views', 'search'],
      category: 'Learning',
      theme: { gradient: ['#0ba360', '#3cba92', '#0f2027'], emoji: '🌗', particles: ['🌗', '✨'] },
    },
  ];
  for (let i = 0; i < seeds.length; i++) {
    await saveNote({
      id: newId(), createdAt: now - i, image: null, liked: false, links: [], ...seeds[i],
    });
  }
}

// ---------- boot ----------
async function boot() {
  initFeed({
    onEdit: note => openCapture(note),
    onOpenMap: () => switchView('mindmap'),
    onChanged: () => reload().then(() => showToast('Note deleted')),
    onAdd: () => openCapture(),
    showToast,
  });
  initMindmap({ onOpen: openInFeed });
  initCapture({
    onSaved: async note => {
      await reload();
      showToast('Short saved 🚀');
      if (activeView === 'notes') return;
      switchView('feed');
      activeCategory = 'For You';
      render();
      requestAnimationFrame(() => scrollFeedToNote(note.id));
    },
    showToast,
  });

  // nav
  for (const b of document.querySelectorAll('.nav-btn[data-nav]')) {
    b.addEventListener('click', () => switchView(b.dataset.nav));
  }
  document.getElementById('btn-add').addEventListener('click', () => openCapture());
  document.getElementById('btn-view-toggle').addEventListener('click', () => {
    switchView(activeView === 'notes' ? 'feed' : 'notes');
  });

  // search
  document.getElementById('btn-search').addEventListener('click', () => {
    openModal('modal-search');
    const input = document.getElementById('search-input');
    input.value = '';
    runSearch('');
    input.focus();
  });
  document.getElementById('search-input').addEventListener('input', ev => runSearch(ev.target.value));

  // settings
  document.getElementById('btn-settings').addEventListener('click', () => {
    document.getElementById('settings-api-key').value = getApiKey();
    aiMode().then(mode => {
      document.getElementById('settings-ai-note').classList.toggle('hidden', mode !== 'claude');
    });
    openModal('modal-settings');
  });
  document.getElementById('btn-save-settings').addEventListener('click', () => {
    setApiKey(document.getElementById('settings-api-key').value.trim());
    closeModal('modal-settings');
    showToast(getApiKey() ? 'API key saved — Claude is on ✨' : 'Key cleared — using local analyzer');
  });
  document.getElementById('btn-clear-all').addEventListener('click', async () => {
    if (!await confirmDialog('Delete ALL notes? This cannot be undone.', { confirmLabel: 'Delete all' })) return;
    await clearAllNotes();
    await reload();
    closeModal('modal-settings');
    showToast('All notes deleted');
  });

  // mind map relink
  document.getElementById('btn-relink').addEventListener('click', aiRelink);

  // generic modal close (✕ buttons + backdrop click)
  for (const btn of document.querySelectorAll('.modal-close')) {
    btn.addEventListener('click', () => closeModal(btn.dataset.close));
  }
  for (const m of document.querySelectorAll('.modal')) {
    m.addEventListener('pointerdown', ev => { if (ev.target === m) m.classList.add('hidden'); });
  }
  // autoplay toggle
  document.getElementById('btn-autoplay').addEventListener('click', () => {
    const turningOn = !autoplayTimer;
    if (turningOn && activeView !== 'feed') switchView('feed');
    setAutoplay(turningOn);
    showToast(turningOn ? 'Auto-scroll on — sit back 🍿' : 'Auto-scroll off');
  });

  document.addEventListener('keydown', ev => {
    if (ev.key === 'Escape') {
      for (const m of document.querySelectorAll('.modal:not(.hidden)')) {
        if (m.id === 'modal-confirm') document.getElementById('btn-confirm-cancel').click();
        else m.classList.add('hidden');
      }
      return;
    }
    if (anyModalOpen() || ev.target.closest?.('input, textarea')) return;
    if (activeView !== 'feed') return;
    if (ev.key === 'ArrowDown' || ev.key === 'PageDown' || ev.key === 'j') {
      ev.preventDefault();
      feedStep(1);
    } else if (ev.key === 'ArrowUp' || ev.key === 'PageUp' || ev.key === 'k') {
      ev.preventDefault();
      feedStep(-1);
    }
  });

  // installable PWA + offline shell
  if ('serviceWorker' in navigator && /^https?:$/.test(location.protocol)) {
    navigator.serviceWorker.register('sw.js').catch(() => { /* e.g. sandboxed context */ });
  }

  await seedIfNeeded();
  await reload();
  switchView('feed');
}

boot();
