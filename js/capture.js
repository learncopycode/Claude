// Capture flow: paste/drop/pick a screenshot (and/or type text),
// let the AI analyze it, review + confirm tags, save.

import { analyzeCapture, hasApiKey } from './ai.js';
import { saveNote, newId } from './store.js';

const modal = document.getElementById('modal-capture');
const stepInput = document.getElementById('capture-step-input');
const stepReview = document.getElementById('capture-step-review');
const loadingEl = document.getElementById('capture-loading');
const loadingMsg = document.getElementById('capture-loading-msg');
const modalTitle = document.getElementById('capture-title');

const dropZone = document.getElementById('drop-zone');
const dropEmpty = dropZone.querySelector('.drop-zone-empty');
const previewImg = document.getElementById('capture-preview');
const clearImgBtn = document.getElementById('btn-clear-image');
const fileInput = document.getElementById('file-input');
const textInput = document.getElementById('capture-text');
const hintEl = document.getElementById('capture-hint');

const themePreview = document.getElementById('review-theme-preview');
const emojiEl = document.getElementById('review-emoji');
const titleEl = document.getElementById('review-title');
const summaryEl = document.getElementById('review-summary');
const pointsEl = document.getElementById('review-points');
const categoryEl = document.getElementById('review-category');
const tagsEl = document.getElementById('review-tags');
const tagInput = document.getElementById('review-tag-input');

let state = null; // { image, analysis, confirmedTags:Set, editingNote|null }
let onSaved = null;

export function initCapture({ onSaved: cb, showToast }) {
  onSaved = cb;

  // Global paste: from anywhere in the app, an image paste opens the composer.
  document.addEventListener('paste', ev => {
    if (ev.target.closest?.('input, textarea') && modal.classList.contains('hidden') === false) return;
    const item = [...(ev.clipboardData?.items || [])].find(i => i.type.startsWith('image/'));
    if (!item) return;
    ev.preventDefault();
    const file = item.getAsFile();
    if (!file) return;
    openCapture();
    loadImageFile(file);
    showToast('Screenshot pasted 📸');
  });

  document.getElementById('btn-pick-file').addEventListener('click', () => fileInput.click());
  fileInput.addEventListener('change', () => {
    if (fileInput.files[0]) loadImageFile(fileInput.files[0]);
    fileInput.value = '';
  });
  clearImgBtn.addEventListener('click', () => setImage(null));

  dropZone.addEventListener('dragover', ev => { ev.preventDefault(); dropZone.classList.add('dragover'); });
  dropZone.addEventListener('dragleave', () => dropZone.classList.remove('dragover'));
  dropZone.addEventListener('drop', ev => {
    ev.preventDefault();
    dropZone.classList.remove('dragover');
    const file = [...(ev.dataTransfer?.files || [])].find(f => f.type.startsWith('image/'));
    if (file) loadImageFile(file);
  });

  document.getElementById('btn-analyze').addEventListener('click', analyze);
  document.getElementById('btn-back-capture').addEventListener('click', () => showStep('input'));
  document.getElementById('btn-save-note').addEventListener('click', save);

  document.getElementById('btn-add-tag').addEventListener('click', addOwnTag);
  tagInput.addEventListener('keydown', ev => { if (ev.key === 'Enter') addOwnTag(); });
}

export function openCapture(editNote = null) {
  state = {
    image: editNote?.image || null,
    analysis: null,
    confirmedTags: new Set(editNote?.tags || []),
    editingNote: editNote,
  };
  modalTitle.textContent = editNote ? 'Edit note' : 'New note';
  textInput.value = editNote?.text || '';
  setImage(state.image);
  hintEl.textContent = hasApiKey()
    ? 'Claude will read the screenshot, write the short, pick a vibe and suggest tags.'
    : 'No API key set (see Setup) — using the built-in analyzer. Add a key for the full Claude magic.';
  modal.classList.remove('hidden');

  if (editNote) {
    // Jump straight to review with the existing fields.
    state.analysis = {
      title: editNote.title,
      summary: editNote.summary,
      keyPoints: editNote.keyPoints || [],
      text: editNote.text || '',
      suggestedTags: [...new Set([...(editNote.suggestedTags || []), ...(editNote.tags || [])])],
      category: editNote.category || 'General',
      theme: editNote.theme,
    };
    fillReview();
    showStep('review');
  } else {
    showStep('input');
  }
}

export function closeCapture() {
  modal.classList.add('hidden');
  state = null;
}

function showStep(which) {
  stepInput.classList.toggle('hidden', which !== 'input');
  stepReview.classList.toggle('hidden', which !== 'review');
  loadingEl.classList.toggle('hidden', which !== 'loading');
}

function loadImageFile(file) {
  const reader = new FileReader();
  reader.onload = () => {
    // Downscale large screenshots so IndexedDB and the API stay happy.
    const img = new Image();
    img.onload = () => {
      const MAX = 1400;
      let { width, height } = img;
      if (Math.max(width, height) > MAX) {
        const s = MAX / Math.max(width, height);
        width = Math.round(width * s);
        height = Math.round(height * s);
      }
      const c = document.createElement('canvas');
      c.width = width; c.height = height;
      c.getContext('2d').drawImage(img, 0, 0, width, height);
      setImage(c.toDataURL('image/jpeg', 0.85));
    };
    img.src = reader.result;
  };
  reader.readAsDataURL(file);
}

function setImage(dataUrl) {
  if (state) state.image = dataUrl;
  previewImg.src = dataUrl || '';
  previewImg.classList.toggle('hidden', !dataUrl);
  clearImgBtn.classList.toggle('hidden', !dataUrl);
  dropEmpty.classList.toggle('hidden', !!dataUrl);
}

async function analyze() {
  const text = textInput.value.trim();
  if (!state.image && !text) {
    hintEl.textContent = 'Paste a screenshot or type some text first ✋';
    return;
  }
  showStep('loading');
  loadingMsg.textContent = hasApiKey()
    ? (state.image ? 'Claude is reading your screenshot…' : 'Claude is shaping your note…')
    : 'Analyzing locally…';
  try {
    state.analysis = await analyzeCapture({ imageDataUrl: state.image, text });
    state.confirmedTags = new Set(state.editingNote?.tags || []);
    fillReview();
    showStep('review');
  } catch (err) {
    console.error(err);
    showStep('input');
    hintEl.textContent = '⚠️ ' + (err.message || 'Analysis failed — try again.');
  }
}

function fillReview() {
  const a = state.analysis;
  const [c1, c2, c3] = a.theme?.gradient || ['#fe2c55', '#7b2ff7', '#25f4ee'];
  themePreview.style.backgroundImage = `linear-gradient(120deg, ${c1}, ${c2}, ${c3})`;
  emojiEl.textContent = a.theme?.emoji || '📝';
  titleEl.value = a.title || '';
  summaryEl.value = a.summary || '';
  pointsEl.value = (a.keyPoints || []).join('\n');
  categoryEl.value = a.category || 'General';
  renderTagChips();
}

function renderTagChips() {
  const all = [...new Set([...(state.analysis.suggestedTags || []), ...state.confirmedTags])];
  tagsEl.innerHTML = '';
  for (const tag of all) {
    const chip = document.createElement('button');
    chip.type = 'button';
    chip.className = 'tag-chip' + (state.confirmedTags.has(tag) ? ' on' : '');
    chip.textContent = '#' + tag;
    chip.addEventListener('click', () => {
      state.confirmedTags.has(tag) ? state.confirmedTags.delete(tag) : state.confirmedTags.add(tag);
      chip.classList.toggle('on');
    });
    tagsEl.appendChild(chip);
  }
  if (!all.length) {
    tagsEl.innerHTML = '<span class="muted small-text">No suggestions — add your own below.</span>';
  }
}

function addOwnTag() {
  const tag = tagInput.value.trim().toLowerCase().replace(/^#/, '').replace(/\s+/g, '-');
  if (!tag) return;
  state.confirmedTags.add(tag);
  if (!state.analysis.suggestedTags.includes(tag)) state.analysis.suggestedTags.push(tag);
  tagInput.value = '';
  renderTagChips();
}

async function save() {
  const a = state.analysis;
  const base = state.editingNote;
  const note = {
    id: base?.id || newId(),
    createdAt: base?.createdAt || Date.now(),
    title: titleEl.value.trim() || 'Untitled note',
    summary: summaryEl.value.trim(),
    keyPoints: pointsEl.value.split('\n').map(s => s.trim()).filter(Boolean).slice(0, 6),
    text: a.text || textInput.value.trim(),
    image: state.image,
    tags: [...state.confirmedTags],
    suggestedTags: a.suggestedTags || [],
    category: categoryEl.value.trim() || 'General',
    theme: a.theme,
    liked: base?.liked || false,
    links: base?.links || [],
  };
  await saveNote(note);
  closeCapture();
  onSaved?.(note);
}
