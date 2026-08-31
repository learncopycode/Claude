// Classic notes view: a calm grid, the anti-TikTok toggle.

const gridEl = document.getElementById('notes-grid');

function esc(s) {
  return String(s ?? '').replace(/[&<>"']/g, c =>
    ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

export function renderNotesGrid(notes, { category = 'For You', onOpen } = {}) {
  const filtered = category === 'For You'
    ? notes
    : notes.filter(n => (n.category || 'General') === category);

  gridEl.innerHTML = '';
  if (!filtered.length) {
    gridEl.innerHTML = `<p class="muted" style="grid-column:1/-1;text-align:center;padding:40px 0">
      No notes here yet — hit ＋ to add one.</p>`;
    return;
  }

  for (const note of filtered) {
    const [c1, c2, c3] = note.theme?.gradient || ['#fe2c55', '#7b2ff7', '#25f4ee'];
    const card = document.createElement('article');
    card.className = 'note-card';
    card.innerHTML = `
      <div class="note-card-banner" style="background:linear-gradient(90deg, ${esc(c1)}, ${esc(c2)}, ${esc(c3)})"></div>
      ${note.image ? `<img class="note-card-img" src="${note.image}" alt="" loading="lazy">` : ''}
      <div class="note-card-body">
        <div class="note-card-title">${esc(note.theme?.emoji || '📝')} ${esc(note.title)}</div>
        <div class="note-card-summary">${esc(note.summary || note.text || '')}</div>
        <div class="note-card-meta">
          <span class="cat">${esc(note.category || 'General')}</span>
          ${(note.tags || []).slice(0, 4).map(t => `<span class="tag">#${esc(t)}</span>`).join('')}
        </div>
      </div>`;
    card.addEventListener('click', () => onOpen?.(note));
    gridEl.appendChild(card);
  }
}
