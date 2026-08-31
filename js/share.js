// Render a note short into a 1080x1920 story-format PNG and share/download it.

function loadImage(src) {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = reject;
    img.src = src;
  });
}

// Draw wrapped text; returns the y after the last line drawn.
function wrapText(ctx, text, x, y, maxWidth, lineHeight, maxLines = Infinity) {
  const words = String(text || '').split(/\s+/).filter(Boolean);
  let line = '';
  let lines = 0;
  for (let i = 0; i < words.length; i++) {
    const test = line ? line + ' ' + words[i] : words[i];
    if (ctx.measureText(test).width > maxWidth && line) {
      if (lines + 1 >= maxLines) {
        while (line && ctx.measureText(line + '…').width > maxWidth) {
          line = line.slice(0, -1);
        }
        ctx.fillText(line + '…', x, y);
        return y + lineHeight;
      }
      ctx.fillText(line, x, y);
      y += lineHeight;
      lines++;
      line = words[i];
    } else {
      line = test;
    }
  }
  if (line) {
    ctx.fillText(line, x, y);
    y += lineHeight;
  }
  return y;
}

export async function shareNoteAsImage(note) {
  const W = 1080, H = 1920, PAD = 84;
  const canvas = document.createElement('canvas');
  canvas.width = W;
  canvas.height = H;
  const ctx = canvas.getContext('2d');

  // background gradient
  const [c1, c2, c3] = note.theme?.gradient || ['#fe2c55', '#7b2ff7', '#25f4ee'];
  const bg = ctx.createLinearGradient(0, 0, W, H);
  bg.addColorStop(0, c1);
  bg.addColorStop(0.5, c2);
  bg.addColorStop(1, c3);
  ctx.fillStyle = bg;
  ctx.fillRect(0, 0, W, H);

  // bottom vignette for text legibility
  const v = ctx.createLinearGradient(0, H * 0.4, 0, H);
  v.addColorStop(0, 'rgba(0,0,0,0)');
  v.addColorStop(1, 'rgba(0,0,0,0.72)');
  ctx.fillStyle = v;
  ctx.fillRect(0, 0, W, H);

  // screenshot, contained with rounded corners
  let textTop = 640;
  if (note.image) {
    try {
      const img = await loadImage(note.image);
      const boxW = W - PAD * 2, boxH = 780;
      const scale = Math.min(boxW / img.width, boxH / img.height);
      const dw = img.width * scale, dh = img.height * scale;
      const dx = (W - dw) / 2, dy = 190 + (boxH - dh) / 2;
      ctx.save();
      ctx.shadowColor = 'rgba(0,0,0,0.55)';
      ctx.shadowBlur = 60;
      ctx.shadowOffsetY = 24;
      ctx.beginPath();
      ctx.roundRect(dx, dy, dw, dh, 28);
      ctx.fillStyle = '#000';
      ctx.fill();
      ctx.restore();
      ctx.save();
      ctx.beginPath();
      ctx.roundRect(dx, dy, dw, dh, 28);
      ctx.clip();
      ctx.drawImage(img, dx, dy, dw, dh);
      ctx.restore();
      textTop = 190 + boxH + 110;
    } catch { /* corrupt image: text-only layout */ }
  }

  ctx.textBaseline = 'alphabetic';
  ctx.shadowColor = 'rgba(0,0,0,0.6)';
  ctx.shadowBlur = 24;

  // category
  ctx.fillStyle = '#25f4ee';
  ctx.font = '800 34px sans-serif';
  ctx.fillText(
    `${note.theme?.emoji || '📝'}  ${(note.category || 'GENERAL').toUpperCase()}`,
    PAD, textTop
  );
  let y = textTop + 88;

  // title
  ctx.fillStyle = '#ffffff';
  ctx.font = '800 76px sans-serif';
  y = wrapText(ctx, note.title, PAD, y, W - PAD * 2, 88, 3) + 22;

  // summary
  ctx.fillStyle = 'rgba(255,255,255,0.92)';
  ctx.font = '400 40px sans-serif';
  y = wrapText(ctx, note.summary, PAD, y, W - PAD * 2, 54, 3) + 30;

  // key points
  ctx.font = '600 36px sans-serif';
  for (const point of (note.keyPoints || []).slice(0, 4)) {
    if (y > H - 260) break;
    ctx.fillStyle = '#ffd200';
    ctx.fillText('⚡', PAD, y);
    ctx.fillStyle = '#ffffff';
    y = wrapText(ctx, point, PAD + 52, y, W - PAD * 2 - 52, 46, 2) + 12;
  }

  // tags
  y = Math.min(Math.max(y + 18, H - 210), H - 170);
  ctx.fillStyle = '#25f4ee';
  ctx.font = '800 34px sans-serif';
  wrapText(ctx, (note.tags || []).map(t => '#' + t).join('  '), PAD, y, W - PAD * 2, 44, 2);

  // watermark
  ctx.shadowBlur = 0;
  ctx.fillStyle = 'rgba(255,255,255,0.6)';
  ctx.font = '700 28px sans-serif';
  ctx.fillText('made with NoteTok ⚡', PAD, H - 64);

  const blob = await new Promise(resolve => canvas.toBlob(resolve, 'image/png'));
  const name = (note.title || 'note').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 40) || 'note';
  const file = new File([blob], `notetok-${name}.png`, { type: 'image/png' });

  if (navigator.canShare?.({ files: [file] })) {
    await navigator.share({ files: [file], title: note.title });
    return 'shared';
  }
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = file.name;
  a.click();
  setTimeout(() => URL.revokeObjectURL(a.href), 5000);
  return 'downloaded';
}
