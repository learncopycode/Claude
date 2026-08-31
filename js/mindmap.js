// Mind map: force-directed canvas graph of notes and their links.
// Links come from suggestLinks() (Claude with a key, shared tags without).

const canvas = document.getElementById('mindmap-canvas');
const ctx = canvas.getContext('2d');

let nodes = [];          // { id, note, x, y, vx, vy, r }
let edges = [];          // { a: node, b: node, reason }
let running = false;
let onOpenNote = null;

let cam = { x: 0, y: 0, zoom: 1 };
let drag = null;         // { type: 'pan'|'node', ... }
let hoverNode = null;

export function initMindmap({ onOpen }) {
  onOpenNote = onOpen;
  const resize = () => {
    const dpr = window.devicePixelRatio || 1;
    canvas.width = canvas.clientWidth * dpr;
    canvas.height = canvas.clientHeight * dpr;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  };
  new ResizeObserver(resize).observe(canvas);
  resize();
  bindInput();
}

export function setGraph(notes, links) {
  const prev = new Map(nodes.map(n => [n.id, n]));
  const w = canvas.clientWidth || 360;
  const h = canvas.clientHeight || 640;
  nodes = notes.map((note, i) => {
    const old = prev.get(note.id);
    const angle = (i / Math.max(notes.length, 1)) * Math.PI * 2;
    return old ? Object.assign(old, { note }) : {
      id: note.id,
      note,
      x: w / 2 + Math.cos(angle) * Math.min(w, h) * 0.28,
      y: h / 2 + Math.sin(angle) * Math.min(w, h) * 0.28,
      vx: 0, vy: 0,
      r: 26,
    };
  });
  const byId = new Map(nodes.map(n => [n.id, n]));
  edges = links
    .map(l => ({ a: byId.get(l.a), b: byId.get(l.b), reason: l.reason }))
    .filter(e => e.a && e.b);
}

export function startMindmap() {
  if (running) return;
  running = true;
  requestAnimationFrame(tick);
}
export function stopMindmap() { running = false; }

function tick() {
  if (!running) return;
  simulate();
  draw();
  requestAnimationFrame(tick);
}

function simulate() {
  const w = canvas.clientWidth, h = canvas.clientHeight;
  const cx = w / 2, cy = h / 2;
  for (const n of nodes) {
    // gentle pull to centre
    n.vx += (cx - n.x) * 0.0018;
    n.vy += (cy - n.y) * 0.0018;
  }
  // node repulsion
  for (let i = 0; i < nodes.length; i++) {
    for (let j = i + 1; j < nodes.length; j++) {
      const a = nodes[i], b = nodes[j];
      let dx = b.x - a.x, dy = b.y - a.y;
      let d2 = dx * dx + dy * dy;
      if (d2 < 1) { d2 = 1; dx = 1; }
      const d = Math.sqrt(d2);
      const force = Math.min(2600 / d2, 3);
      const fx = (dx / d) * force, fy = (dy / d) * force;
      a.vx -= fx; a.vy -= fy;
      b.vx += fx; b.vy += fy;
    }
  }
  // edge springs
  for (const e of edges) {
    const dx = e.b.x - e.a.x, dy = e.b.y - e.a.y;
    const d = Math.max(Math.hypot(dx, dy), 1);
    const stretch = (d - 150) * 0.004;
    const fx = (dx / d) * stretch, fy = (dy / d) * stretch;
    e.a.vx += fx; e.a.vy += fy;
    e.b.vx -= fx; e.b.vy -= fy;
  }
  for (const n of nodes) {
    if (drag?.type === 'node' && drag.node === n) continue;
    n.vx *= 0.86; n.vy *= 0.86;
    n.x += n.vx; n.y += n.vy;
  }
}

function draw() {
  const w = canvas.clientWidth, h = canvas.clientHeight;
  ctx.clearRect(0, 0, w, h);
  ctx.save();
  ctx.translate(cam.x, cam.y);
  ctx.scale(cam.zoom, cam.zoom);

  // edges
  ctx.lineWidth = 1.2 / cam.zoom;
  for (const e of edges) {
    const grad = ctx.createLinearGradient(e.a.x, e.a.y, e.b.x, e.b.y);
    const ca = e.a.note.theme?.gradient?.[0] || '#25f4ee';
    const cb = e.b.note.theme?.gradient?.[0] || '#fe2c55';
    grad.addColorStop(0, ca + 'aa');
    grad.addColorStop(1, cb + 'aa');
    ctx.strokeStyle = grad;
    ctx.beginPath();
    ctx.moveTo(e.a.x, e.a.y);
    ctx.lineTo(e.b.x, e.b.y);
    ctx.stroke();
    if (cam.zoom > 0.75 && e.reason) {
      ctx.fillStyle = '#9a9ab0';
      ctx.font = `${10 / cam.zoom}px sans-serif`;
      ctx.textAlign = 'center';
      ctx.fillText(e.reason, (e.a.x + e.b.x) / 2, (e.a.y + e.b.y) / 2 - 4 / cam.zoom);
    }
  }

  // nodes
  for (const n of nodes) {
    const g = n.note.theme?.gradient || ['#fe2c55', '#25f4ee'];
    const grad = ctx.createRadialGradient(n.x, n.y, 2, n.x, n.y, n.r);
    grad.addColorStop(0, g[0]);
    grad.addColorStop(1, g[g.length - 1]);
    ctx.beginPath();
    ctx.arc(n.x, n.y, n.r, 0, Math.PI * 2);
    ctx.fillStyle = grad;
    ctx.shadowColor = g[0];
    ctx.shadowBlur = n === hoverNode ? 26 : 12;
    ctx.fill();
    ctx.shadowBlur = 0;
    ctx.strokeStyle = '#ffffff33';
    ctx.stroke();

    ctx.font = `${18}px sans-serif`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(n.note.theme?.emoji || '📝', n.x, n.y + 1);

    ctx.fillStyle = '#f5f5fa';
    ctx.font = `600 ${11.5}px sans-serif`;
    ctx.textBaseline = 'top';
    const label = n.note.title.length > 26 ? n.note.title.slice(0, 24) + '…' : n.note.title;
    ctx.fillText(label, n.x, n.y + n.r + 6);
  }
  ctx.restore();
}

function toWorld(px, py) {
  return { x: (px - cam.x) / cam.zoom, y: (py - cam.y) / cam.zoom };
}
function nodeAt(px, py) {
  const p = toWorld(px, py);
  for (let i = nodes.length - 1; i >= 0; i--) {
    const n = nodes[i];
    if (Math.hypot(p.x - n.x, p.y - n.y) <= n.r + 6) return n;
  }
  return null;
}

function bindInput() {
  canvas.addEventListener('pointerdown', ev => {
    canvas.setPointerCapture(ev.pointerId);
    const n = nodeAt(ev.offsetX, ev.offsetY);
    drag = n
      ? { type: 'node', node: n, moved: false }
      : { type: 'pan', sx: ev.offsetX, sy: ev.offsetY, ox: cam.x, oy: cam.y, moved: false };
  });
  canvas.addEventListener('pointermove', ev => {
    hoverNode = drag ? hoverNode : nodeAt(ev.offsetX, ev.offsetY);
    canvas.style.cursor = hoverNode ? 'pointer' : 'grab';
    if (!drag) return;
    drag.moved = true;
    if (drag.type === 'node') {
      const p = toWorld(ev.offsetX, ev.offsetY);
      drag.node.x = p.x; drag.node.y = p.y;
      drag.node.vx = drag.node.vy = 0;
    } else {
      cam.x = drag.ox + (ev.offsetX - drag.sx);
      cam.y = drag.oy + (ev.offsetY - drag.sy);
    }
  });
  canvas.addEventListener('pointerup', ev => {
    if (drag && !drag.moved) {
      const n = nodeAt(ev.offsetX, ev.offsetY);
      if (n) onOpenNote?.(n.note);
    }
    drag = null;
  });
  canvas.addEventListener('wheel', ev => {
    ev.preventDefault();
    const factor = ev.deltaY < 0 ? 1.1 : 0.9;
    const next = Math.min(Math.max(cam.zoom * factor, 0.35), 3);
    // zoom towards the cursor
    cam.x = ev.offsetX - (ev.offsetX - cam.x) * (next / cam.zoom);
    cam.y = ev.offsetY - (ev.offsetY - cam.y) * (next / cam.zoom);
    cam.zoom = next;
  }, { passive: false });
}
