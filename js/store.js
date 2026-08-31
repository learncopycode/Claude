// IndexedDB-backed note store.
//
// Note shape:
// {
//   id, createdAt, title, summary, keyPoints: [string],
//   text,                    // raw text (typed or OCR'd from the screenshot)
//   image,                   // dataURL of the pasted screenshot, or null
//   tags: [string],          // user-confirmed tags
//   suggestedTags: [string], // what the AI proposed (kept for reference)
//   category,                // single category string
//   theme: { gradient: [c1, c2, c3], emoji, particles: [emoji] },
//   liked: bool,
//   links: [{ to: noteId, reason }]   // mind-map edges owned by this note
// }

const DB_NAME = 'notetok';
const DB_VERSION = 1;
const STORE = 'notes';

let dbPromise = null;

function openDb() {
  if (dbPromise) return dbPromise;
  dbPromise = new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, DB_VERSION);
    req.onupgradeneeded = () => {
      const db = req.result;
      if (!db.objectStoreNames.contains(STORE)) {
        db.createObjectStore(STORE, { keyPath: 'id' });
      }
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
  return dbPromise;
}

function tx(mode, fn) {
  return openDb().then(db => new Promise((resolve, reject) => {
    const t = db.transaction(STORE, mode);
    const result = fn(t.objectStore(STORE));
    t.oncomplete = () => resolve(result && 'result' in result ? result.result : undefined);
    t.onerror = () => reject(t.error);
  }));
}

export async function getAllNotes() {
  const db = await openDb();
  return new Promise((resolve, reject) => {
    const req = db.transaction(STORE, 'readonly').objectStore(STORE).getAll();
    req.onsuccess = () => {
      const notes = req.result || [];
      notes.sort((a, b) => b.createdAt - a.createdAt);
      resolve(notes);
    };
    req.onerror = () => reject(req.error);
  });
}

export function saveNote(note) {
  return tx('readwrite', store => store.put(note));
}

export function deleteNote(id) {
  return tx('readwrite', store => store.delete(id));
}

export function clearAllNotes() {
  return tx('readwrite', store => store.clear());
}

export function newId() {
  return 'n_' + Date.now().toString(36) + '_' + Math.random().toString(36).slice(2, 8);
}

// ---- settings (small, localStorage is fine) ----
const KEY_API = 'notetok.apiKey';
const KEY_SEEDED = 'notetok.seeded';

export function getApiKey() {
  try { return localStorage.getItem(KEY_API) || ''; } catch { return ''; }
}
export function setApiKey(k) {
  try { localStorage.setItem(KEY_API, k || ''); } catch { /* private mode */ }
}
export function wasSeeded() {
  try { return localStorage.getItem(KEY_SEEDED) === '1'; } catch { return true; }
}
export function markSeeded() {
  try { localStorage.setItem(KEY_SEEDED, '1'); } catch { /* private mode */ }
}
