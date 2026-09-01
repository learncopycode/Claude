// TikTok-style vertical feed of "note shorts".

import { saveNote, deleteNote } from './store.js';
import { shareNoteAsImage } from './share.js';
import { confirmDialog } from './ui.js';

const feedEl = document.getElementById('view-feed');

let observer = null;
let callbacks = {}; // { onEdit(note), onDelete(note), onOpenMap(note), onChanged() }

export function initFeed(cbs) {
  callbacks = cbs;
  observer = new IntersectionObserver(entries => {
    for (const e of entries) {
      e.target.classList.toggle('is-active', e.isIntersecting && e.intersectionRatio > 0.6);
    }
  }, { root: feedEl, threshold: [0, 0.6, 1] });
}

export function renderFeed(notes, { category = 'For You' } = {}) {
  const filtered = category === 'For You'
    ? notes
    : notes.filter(n => (n.category || 'General') === category);

  feedEl.innerHTML = '';
  observer.disconnect();

  if (!filtered.length) {
    feedEl.appendChild(emptyState(notes.length === 0));
    return;
  }
  for (const note of filtered) {
    const el = renderShort(note);
    feedEl.appendChild(el);
    observer.observe(el);
  }
  // Activate the first card immediately (observer fires async).
  feedEl.firstElementChild?.classList.add('is-active');
}

export function scrollFeedToNote(id) {
  const el = feedEl.querySelector(`[data-id="${CSS.escape(id)}"]`);
  el?.scrollIntoView({ behavior: 'instant', block: 'start' });
}

function emptyState(noNotesAtAll) {
  const div = document.createElement('div');
  div.className = 'feed-empty';
  div.innerHTML = `
    <div>
      <div class="big">${noNotesAtAll ? '⚡' : '🔍'}</div>
      <h2>${noNotesAtAll ? 'Your feed is empty' : 'Nothing in this category yet'}</h2>
      <p>${noNotesAtAll
        ? 'Paste a screenshot anywhere (Ctrl/Cmd+V) or hit the ＋ button, and Claude will turn it into a scrollable note short.'
        : 'Pick another category up top, or add a note to this one.'}</p>
      <button class="cta-btn" data-action="add">＋ Make your first short</button>
    </div>`;
  div.querySelector('[data-action="add"]').addEventListener('click', () => callbacks.onAdd?.());
  return div;
}

function esc(s) {
  return String(s ?? '').replace(/[&<>"']/g, c =>
    ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

function renderShort(note) {
  const el = document.createElement('article');
  el.className = 'short';
  el.dataset.id = note.id;

  const [c1, c2, c3] = note.theme?.gradient || ['#fe2c55', '#7b2ff7', '#25f4ee'];
  const particles = (note.theme?.particles?.length ? note.theme.particles : ['✨'])
    .flatMap(p => [p, p, p])
    .map((p, i) => {
      const left = (i * 37 + 11) % 100;
      const dur = 9 + ((i * 13) % 8);
      const delay = (i * 1.7) % 9;
      return `<span class="particle" style="left:${left}%;animation-duration:${dur}s;animation-delay:${delay}s">${esc(p)}</span>`;
    }).join('');

  let d = 0;
  const delay = () => `style="--d:${(d += 0.09).toFixed(2)}s"`;
  const points = (note.keyPoints || []).map(p => `<li ${delay()}>${esc(p)}</li>`).join('');
  const tags = (note.tags || []).map(t => `<span class="tag" ${delay()}>#${esc(t)}</span>`).join('');
  const date = new Date(note.createdAt).toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' });

  el.innerHTML = `
    <div class="short-bg" style="background-image:linear-gradient(135deg, ${esc(c1)}, ${esc(c2)}, ${esc(c3)})"></div>
    <div class="short-particles">${particles}</div>
    ${note.image ? `<div class="short-media"><img src="${note.image}" alt="${esc(note.title)}"></div>` : ''}
    <div class="short-vignette"></div>
    <div class="short-content ${note.image ? '' : 'center-stage'}">
      <div class="short-cat" style="--d:0s">${esc(note.theme?.emoji || '📝')} ${esc(note.category || 'General')}</div>
      <h2 class="short-title" style="--d:0.08s">${esc(note.title)}</h2>
      <p class="short-summary" style="--d:0.16s">${esc(note.summary)}</p>
      ${points ? `<ul class="short-points">${points}</ul>` : ''}
      ${tags ? `<div class="short-tags">${tags}</div>` : ''}
      <div class="short-date" ${delay()}>${date}</div>
    </div>
    <div class="short-rail">
      <button class="rail-btn ${note.liked ? 'liked' : ''}" data-action="like">
        <span class="rail-ico">${note.liked ? '❤️' : '🤍'}</span><span class="lbl">${note.liked ? 'Liked' : 'Like'}</span>
      </button>
      <button class="rail-btn" data-action="edit"><span class="rail-ico">✏️</span><span class="lbl">Edit</span></button>
      <button class="rail-btn" data-action="map"><span class="rail-ico">🕸️</span><span class="lbl">Map</span></button>
      <button class="rail-btn" data-action="share"><span class="rail-ico">📤</span><span class="lbl">Share</span></button>
      <button class="rail-btn" data-action="delete"><span class="rail-ico">🗑️</span><span class="lbl">Delete</span></button>
    </div>
    <div class="short-progress"><i></i></div>`;

  el.querySelector('[data-action="like"]').addEventListener('click', () => toggleLike(note, el));
  el.querySelector('[data-action="edit"]').addEventListener('click', () => callbacks.onEdit?.(note));
  el.querySelector('[data-action="map"]').addEventListener('click', () => callbacks.onOpenMap?.(note));
  el.querySelector('[data-action="share"]').addEventListener('click', async () => {
    try {
      const how = await shareNoteAsImage(note);
      if (how === 'downloaded') callbacks.showToast?.('Short saved as an image 📤');
    } catch (err) {
      if (err?.name !== 'AbortError') {
        console.error(err);
        callbacks.showToast?.('⚠️ Could not share this short');
      }
    }
  });
  el.querySelector('[data-action="delete"]').addEventListener('click', async () => {
    if (!await confirmDialog(`Delete "${note.title}"?`)) return;
    await deleteNote(note.id);
    callbacks.onChanged?.();
  });

  // Double-tap (or double-click) to like, with a heart burst.
  let lastTap = 0;
  el.addEventListener('pointerup', ev => {
    if (ev.target.closest('.short-rail')) return;
    const now = Date.now();
    if (now - lastTap < 320) {
      burstHeart(el, ev.clientX, ev.clientY);
      if (!note.liked) toggleLike(note, el);
    }
    lastTap = now;
  });

  return el;
}

async function toggleLike(note, el) {
  note.liked = !note.liked;
  await saveNote(note);
  const btn = el.querySelector('[data-action="like"]');
  btn.classList.toggle('liked', note.liked);
  btn.querySelector('.rail-ico').textContent = note.liked ? '❤️' : '🤍';
  btn.querySelector('.lbl').textContent = note.liked ? 'Liked' : 'Like';
}

function burstHeart(el, x, y) {
  const rect = el.getBoundingClientRect();
  const heart = document.createElement('div');
  heart.className = 'heart-burst';
  heart.textContent = '❤️';
  heart.style.left = (x - rect.left) + 'px';
  heart.style.top = (y - rect.top) + 'px';
  el.appendChild(heart);
  heart.addEventListener('animationend', () => heart.remove());
}
