/* Animated illustrations for each reflection. Shapes only: people and
   animals are silhouettes without faces. viewBox 400×300. */
let ART_N = 0;
function rng(seed) { return () => { seed |= 0; seed = seed + 0x6D2B79F5 | 0; let t = Math.imul(seed ^ seed >>> 15, 1 | seed); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; }
function palette(c) {
  // The light look paints the same scenes at dusk instead of deep night, with brighter colour.
  if (typeof isLight === "function" && isLight()) return {
    main: hsb(c.h, Math.min(1, c.s * 1.1), Math.min(1, c.b * 1.08)), light: hsb(c.h, c.s * 0.4, 1),
    soft: hsb(c.h, c.s * 0.6, c.b, 0.35), deep: hsb(c.h, Math.min(1, c.s * 0.9), c.b * 0.6),
    night: hsb(c.h, 0.55, 0.36), ivory: "#fff8ec", warm: hsb((c.h + 40) % 360, 0.6, 1),
    sun: "#ffcf6e", honey: "#f5ad3c", wheat: "#f0c879",
  };
  return {
    main: hsb(c.h, c.s, c.b), light: hsb(c.h, c.s * 0.45, Math.min(1, c.b * 1.12)),
    soft: hsb(c.h, c.s * 0.6, c.b, 0.35), deep: hsb(c.h, Math.min(1, c.s * 0.9), c.b * 0.34),
    night: hsb(c.h, 0.5, 0.11), ivory: "#f3ecdd", warm: hsb((c.h + 40) % 360, 0.55, 0.95),
    sun: "#f3c56f", honey: "#eba841", wheat: "#e3bf78",
  };
}
const sky = (id, P, gx = 200, gy = 120) => `<defs>
  <linearGradient id="${id}s" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${P.night}"/><stop offset="1" stop-color="${P.deep}"/></linearGradient>
  <radialGradient id="${id}g" cx="${gx / 400}" cy="${gy / 300}" r=".62"><stop offset="0" stop-color="${P.main}" stop-opacity=".55"/><stop offset="1" stop-color="${P.main}" stop-opacity="0"/></radialGradient>
</defs><rect width="400" height="300" fill="url(#${id}s)"/><rect width="400" height="300" fill="url(#${id}g)"/>`;
function stars(n, seed, P, maxY = 300) {
  const r = rng(seed); let s = "";
  for (let i = 0; i < n; i++) s += `<circle class="a-tw" style="animation-delay:-${(r() * 4).toFixed(2)}s" cx="${(r() * 400).toFixed(1)}" cy="${(r() * maxY).toFixed(1)}" r="${(0.5 + r() * 1.4).toFixed(2)}" fill="${P.ivory}"/>`;
  return s;
}
/* A person as a faceless silhouette: round head, arched body. */
function person(x, ground, h, fill, delay = 0) {
  const hr = h * 0.12, top = ground - h + hr * 2.4, w = h * 0.36;
  return `<g class="a-float" style="animation-delay:-${delay}s"><circle cx="${x}" cy="${ground - h + hr}" r="${hr}" fill="${fill}"/><path d="M${x - w / 2} ${ground}V${top + w * 0.45}Q${x - w / 2} ${top} ${x} ${top}Q${x + w / 2} ${top} ${x + w / 2} ${top + w * 0.45}V${ground}Z" fill="${fill}"/></g>`;
}
const hills = (P, y = 240, op = 1) => `<path d="M0 ${y}Q100 ${y - 26} 200 ${y - 6}T400 ${y - 14}V300H0Z" fill="${P.deep}" opacity="${op}"/><path d="M0 ${y + 22}Q120 ${y + 2} 240 ${y + 18}T400 ${y + 12}V300H0Z" fill="${P.night}" opacity=".85"/>`;

const SCENES = {
  family(id, P) {
    let rise = ""; const r = rng(7);
    for (let i = 0; i < 12; i++) rise += `<circle class="a-rise" style="animation-delay:-${(r() * 6).toFixed(2)}s" cx="${(110 + r() * 180).toFixed(0)}" cy="${(190 + r() * 40).toFixed(0)}" r="${(1 + r() * 2).toFixed(1)}" fill="${P.light}"/>`;
    return sky(id, P, 200, 150) + stars(30, 3, P, 150) +
      `<path d="M105 246V150A95 95 0 0 1 295 150V246" fill="none" stroke="${P.light}" stroke-opacity=".35" stroke-width="2"/>
       <path d="M120 246V158A80 80 0 0 1 280 158V246" fill="${P.main}" fill-opacity=".10"/>` + hills(P, 250) + rise +
      `<path d="M137 214Q150 206 166 212M180 206Q195 198 210 206M222 212Q232 206 242 218" stroke="${P.ivory}" stroke-opacity=".7" stroke-width="3" fill="none" stroke-linecap="round"/>` +
      person(132, 252, 52, P.light, 0.4) + person(168, 252, 112, P.ivory, 1.2) + person(208, 252, 102, P.light, 2) + person(244, 252, 64, P.ivory, 2.8);
  },
  mother(id, P) {
    return sky(id, P, 210, 160) + stars(40, 11, P, 200) +
      `<g class="a-pulse" style="animation-duration:7s"><circle cx="318" cy="64" r="22" fill="${P.ivory}" opacity=".9"/><circle cx="328" cy="58" r="20" fill="${P.night}"/></g>` + hills(P, 252) +
      `<circle class="a-pulse" cx="212" cy="176" r="46" fill="${P.main}" opacity=".25"/>` + person(188, 262, 150, P.light, 0) +
      `<g class="a-float" style="animation-delay:-1s"><ellipse cx="214" cy="182" rx="17" ry="11" fill="${P.ivory}"/><circle cx="226" cy="170" r="9" fill="${P.ivory}"/></g>
       <path d="M180 168Q214 160 236 186" stroke="${P.light}" stroke-width="10" stroke-linecap="round" fill="none"/>`;
  },
  father(id, P) {
    return sky(id, P, 200, 215) +
      `<circle class="a-pulse" style="animation-duration:6s" cx="200" cy="222" r="58" fill="${P.sun}" opacity=".9"/><circle cx="200" cy="222" r="90" fill="${P.sun}" opacity=".14"/>
       <rect y="222" width="400" height="78" fill="${P.deep}"/><path d="M188 222L120 300H280L212 222Z" fill="${P.main}" opacity=".25"/>
       <path d="M190 240Q200 232 214 236" stroke="${P.ivory}" stroke-width="3" fill="none" stroke-linecap="round"/>` +
      person(176, 290, 118, P.night, 0) + person(222, 290, 66, P.night, 1.5);
  },
  milk(id, P) {
    let drops = "";
    for (let i = 0; i < 5; i++) drops += `<ellipse class="a-fall" style="animation-delay:-${(i * 0.5).toFixed(1)}s" cx="${196 + (i % 3) * 4}" cy="120" rx="3" ry="5" fill="${P.ivory}"/>`;
    return sky(id, P, 200, 90) + hills(P, 238) +
      `<path d="M193 0H207V196Q200 206 193 196Z" fill="${P.ivory}" opacity=".88"/>` + drops +
      `<ellipse class="a-ripple" cx="200" cy="214" rx="40" ry="7" fill="none" stroke="${P.ivory}" stroke-opacity=".7"/>
       <ellipse class="a-ripple" style="animation-delay:-2s" cx="200" cy="214" rx="40" ry="7" fill="none" stroke="${P.ivory}" stroke-opacity=".7"/>
       <path d="M140 212H260Q256 262 200 262Q144 262 140 212Z" fill="${P.light}"/><ellipse cx="200" cy="212" rx="60" ry="9" fill="${P.ivory}"/>` +
      [70, 95, 300, 330, 350].map((x, i) => `<path class="a-sway" style="animation-delay:-${i}s" d="M${x} 270Q${x + 4} 250 ${x + 10} 238" stroke="${P.main}" stroke-width="3" fill="none" stroke-linecap="round"/>`).join("");
  },
  stars(id, P) {
    const pts = [[70, 90], [118, 60], [165, 78], [205, 48], [250, 70], [300, 64]];
    return sky(id, P, 300, 64) + stars(110, 21, P, 230) +
      `<polyline points="${pts.map(p => p.join(",")).join(" ")}" fill="none" stroke="${P.light}" stroke-opacity=".45" stroke-dasharray="3 5"/>` +
      pts.map(([x, y]) => `<circle cx="${x}" cy="${y}" r="2.6" fill="${P.ivory}"/>`).join("") +
      `<g class="a-pulse" style="animation-duration:4s"><path d="M300 40L304 60L324 64L304 68L300 88L296 68L276 64L296 60Z" fill="${P.ivory}"/><circle cx="300" cy="64" r="16" fill="${P.light}" opacity=".3"/></g>
       <path d="M0 250Q90 214 190 240T400 228V300H0Z" fill="${P.deep}"/><path d="M0 270Q140 246 260 268T400 262V300H0Z" fill="${P.night}"/>` +
      person(118, 246, 28, P.night, 0);
  },
  bee(id, P) {
    let hex = ""; const R = 22, w = R * Math.sqrt(3);
    for (let row = 0; row < 4; row++) for (let col = 0; col < 6; col++) {
      const x = 170 + col * w + (row % 2) * w / 2, y = 168 + row * R * 1.5;
      const pts = Array.from({ length: 6 }, (_, k) => { const a = Math.PI / 6 + k * Math.PI / 3; return `${(x + R * Math.cos(a)).toFixed(1)},${(y + R * Math.sin(a)).toFixed(1)}`; }).join(" ");
      const filled = (row * 7 + col * 3) % 4 !== 0;
      hex += `<polygon points="${pts}" fill="${filled ? P.honey : "none"}" fill-opacity="${filled ? (0.45 + ((row + col) % 3) * 0.15).toFixed(2) : 0}" stroke="${P.light}" stroke-opacity=".5" ${filled ? `class="a-tw" style="animation-duration:${4 + (col % 3)}s"` : ""}/>`;
    }
    return sky(id, P, 120, 100) + hex +
      `<path class="a-drip" d="M246 196Q252 210 246 216Q240 210 246 196Z" fill="${P.honey}"/>
       <g class="a-orbit" style="transform-origin:120px 110px"><g transform="translate(-60 -50) scale(1.4)">
         <ellipse class="a-flap" cx="150" cy="98" rx="10" ry="6" fill="${P.ivory}" opacity=".75"/><ellipse class="a-flap" cx="164" cy="98" rx="10" ry="6" fill="${P.ivory}" opacity=".6"/>
         <ellipse cx="157" cy="110" rx="15" ry="9" fill="${P.honey}"/><rect x="152" y="101" width="3.5" height="18" fill="${P.night}"/><rect x="159" y="101" width="3.5" height="18" fill="${P.night}"/>
       </g></g>`;
  },
  camel(id, P) {
    return sky(id, P, 286, 120) + `<circle cx="286" cy="126" r="62" fill="${P.sun}" opacity=".6"/>` +
      `<path d="M0 222Q120 196 240 216T400 206V300H0Z" fill="${P.main}" opacity=".35"/>` +
      `<g class="a-walk"><g fill="${P.night}">
        <ellipse cx="168" cy="196" rx="42" ry="18"/><ellipse cx="160" cy="178" rx="22" ry="17"/>
        <path d="M200 192Q220 174 216 150L226 146Q234 174 212 202Z"/><ellipse cx="229" cy="146" rx="13" ry="7"/>
        <path d="M128 198Q118 206 120 218" stroke="${P.night}" stroke-width="3" fill="none"/>
       </g>
       <g stroke="${P.night}" stroke-width="6" stroke-linecap="round"><line class="a-leg" x1="144" y1="206" x2="142" y2="244"/><line class="a-leg b" x1="156" y1="208" x2="158" y2="244"/><line class="a-leg b" x1="184" y1="208" x2="182" y2="244"/><line class="a-leg" x1="196" y1="206" x2="198" y2="244"/></g></g>` +
      `<path d="M0 246Q140 228 270 244T400 240V300H0Z" fill="${P.deep}"/>`;
  },
  rain(id, P) {
    let drops = ""; const r = rng(5);
    for (let i = 0; i < 18; i++) { const x = 70 + r() * 260; drops += `<line class="a-fall" style="animation-delay:-${(r() * 2.4).toFixed(2)}s;animation-duration:${(1.4 + r()).toFixed(2)}s" x1="${x.toFixed(0)}" y1="96" x2="${(x - 4).toFixed(0)}" y2="110" stroke="${P.light}" stroke-width="2" stroke-linecap="round"/>`; }
    const sprout = (x, d) => `<g class="a-grow" style="animation-delay:-${d}s"><path d="M${x} 262V226" stroke="${P.main}" stroke-width="3"/><path d="M${x} 236Q${x - 14} 228 ${x - 16} 216Q${x - 2} 220 ${x} 236Z" fill="${P.main}"/><path d="M${x} 230Q${x + 14} 222 ${x + 16} 210Q${x + 2} 214 ${x} 230Z" fill="${P.light}"/></g>`;
    return sky(id, P, 200, 70) + drops +
      `<g class="a-drift" style="animation-duration:16s" fill="${P.light}" opacity=".9"><circle cx="160" cy="80" r="30"/><circle cx="200" cy="66" r="38"/><circle cx="244" cy="82" r="28"/><rect x="130" y="80" width="140" height="28" rx="14"/></g>` +
      `<path d="M0 262Q200 244 400 262V300H0Z" fill="${P.deep}"/>` + [100, 160, 220, 280, 330].map((x, i) => sprout(x, i * 0.8)).join("");
  },
  birds(id, P) {
    const r = rng(9); let b = "";
    for (let i = 0; i < 7; i++) {
      const y = 60 + r() * 140, s = 0.7 + r() * 0.8;
      b += `<g class="a-fly" style="animation-delay:-${(r() * 18).toFixed(1)}s;animation-duration:${(14 + r() * 8).toFixed(1)}s"><g transform="translate(0 ${y.toFixed(0)}) scale(${s.toFixed(2)})"><path class="a-flap" style="animation-delay:-${r().toFixed(2)}s" d="M-14 0Q-7 -9 0 0Q7 -9 14 0" stroke="${P.ivory}" stroke-width="2.6" fill="none" stroke-linecap="round"/></g></g>`;
    }
    return sky(id, P, 200, 250) + `<circle cx="200" cy="262" r="70" fill="${P.sun}" opacity=".6"/>` +
      `<g class="a-drift" style="animation-duration:20s" fill="${P.light}" opacity=".18"><ellipse cx="90" cy="90" rx="70" ry="10"/><ellipse cx="300" cy="140" rx="80" ry="9"/></g>` + b +
      `<path d="M0 270Q200 250 400 270V300H0Z" fill="${P.night}"/>`;
  },
  countless(id, P) {
    let d = "";
    for (let i = 1; i < 260; i++) {
      const a = i * 2.39996, rr = 8.4 * Math.sqrt(i), x = 200 + rr * Math.cos(a), y = 150 + rr * Math.sin(a);
      if (x < -10 || x > 410 || y < -10 || y > 310) continue;
      d += `<circle cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="${(1 + i / 90).toFixed(2)}" fill="${i % 3 ? P.light : P.warm}" opacity="${(1 - i / 320).toFixed(2)}"/>`;
    }
    return sky(id, P, 200, 150) + `<g class="a-spin" style="transform-origin:200px 150px">${d}</g><circle class="a-pulse" cx="200" cy="150" r="10" fill="${P.ivory}"/>`;
  },
  sunmoon(id, P) {
    return sky(id, P, 200, 150) + stars(60, 13, P) +
      `<circle cx="200" cy="150" r="104" fill="none" stroke="${P.light}" stroke-opacity=".3" stroke-dasharray="2 6"/><circle cx="200" cy="150" r="62" fill="none" stroke="${P.light}" stroke-opacity=".3" stroke-dasharray="2 6"/>
       <g class="a-spin" style="transform-origin:200px 150px;animation-duration:40s"><circle cx="304" cy="150" r="30" fill="${P.sun}" opacity=".25"/><circle cx="304" cy="150" r="18" fill="${P.sun}"/></g>
       <g class="a-spin" style="transform-origin:200px 150px;animation-duration:24s;animation-direction:reverse"><circle cx="200" cy="88" r="12" fill="${P.ivory}"/><circle cx="206" cy="84" r="11" fill="${P.night}"/></g>
       <circle cx="200" cy="150" r="5" fill="${P.light}" opacity=".6"/>`;
  },
  mountains(id, P) {
    return sky(id, P, 260, 90) + stars(40, 17, P, 120) +
      `<polygon points="0,220 70,120 130,190 200,90 270,180 330,110 400,200 400,300 0,300" fill="${P.main}" opacity=".45"/>
       <polyline points="186,108 200,90 214,108" fill="none" stroke="${P.ivory}" stroke-width="4" stroke-linejoin="round"/><polyline points="318,124 330,110 342,124" fill="none" stroke="${P.ivory}" stroke-width="3"/>
       <polygon points="0,250 90,170 160,230 240,150 320,226 400,180 400,300 0,300" fill="${P.deep}"/>
       <g class="a-drift" style="animation-duration:18s" fill="${P.ivory}" opacity=".12"><ellipse cx="120" cy="212" rx="120" ry="10"/><ellipse cx="300" cy="236" rx="140" ry="9"/></g>
       <polygon points="0,280 120,230 220,276 330,240 400,268 400,300 0,300" fill="${P.night}"/>`;
  },
  seas(id, P) {
    const wave = (y, c, o, d) => `<path class="a-wave" style="animation-delay:-${d}s" d="M-100 ${y}${Array.from({ length: 7 }, (_, i) => `q25 -10 50 0t50 0`).join("")}V300H-100Z" fill="${c}" opacity="${o}"/>`;
    return sky(id, P, 200, 90) +
      `<clipPath id="${id}L"><rect width="200" height="300"/></clipPath><clipPath id="${id}R"><rect x="200" width="200" height="300"/></clipPath>
       <g clip-path="url(#${id}L)">${wave(170, P.main, 0.55, 0)}${wave(200, P.main, 0.8, 1.5)}${wave(236, P.deep, 1, 3)}</g>
       <g clip-path="url(#${id}R)">${wave(176, P.light, 0.45, 2)}${wave(206, P.light, 0.7, 0.5)}${wave(240, P.night, 1, 2.5)}</g>
       <rect class="a-tw" x="198" y="150" width="4" height="150" fill="${P.ivory}" opacity=".7"/><rect x="190" y="150" width="20" height="150" fill="${P.ivory}" opacity=".08"/>`;
  },
  water(id, P) {
    return sky(id, P, 200, 190) +
      [0, 1, 2, 3].map(i => `<ellipse class="a-ripple" style="animation-delay:-${i}s" cx="200" cy="210" rx="60" ry="16" fill="none" stroke="${P.light}" stroke-width="2"/>`).join("") +
      `<path class="a-fall" style="animation-duration:4s" d="M200 60Q212 80 200 92Q188 80 200 60Z" fill="${P.ivory}"/>
       <g class="a-float" style="animation-duration:8s"><path d="M262 222Q290 200 318 214Q292 236 262 222Z" fill="${P.main}"/><path d="M262 222L312 215" stroke="${P.light}" stroke-width="1.5"/></g>`;
  },
  food(id, P) {
    const stalk = (x, h, d) => { let g = ""; for (let k = 0; k < 6; k++) g += `<ellipse cx="${x + (k % 2 ? 5 : -5)}" cy="${262 - h + k * 9}" rx="4" ry="7" fill="${P.wheat}" transform="rotate(${k % 2 ? 25 : -25} ${x + (k % 2 ? 5 : -5)} ${262 - h + k * 9})"/>`; return `<g class="a-sway" style="animation-delay:-${d}s"><path d="M${x} 280V${270 - h}" stroke="${P.wheat}" stroke-width="2.5"/>${g}</g>`; };
    return sky(id, P, 290, 80) + `<circle class="a-pulse" style="animation-duration:6s" cx="290" cy="80" r="34" fill="${P.sun}" opacity=".85"/>` +
      `<path d="M0 270Q200 252 400 270V300H0Z" fill="${P.deep}"/>` + [70, 110, 150, 190, 230, 270, 315, 350].map((x, i) => stalk(x, 90 + (i % 3) * 22, i * 0.6)).join("");
  },
  seeds(id, P) {
    return sky(id, P, 200, 140) + stars(30, 31, P, 120) +
      `<rect y="200" width="400" height="100" fill="${P.deep}"/><path d="M0 200Q200 188 400 200" stroke="${P.main}" stroke-opacity=".4" fill="none"/>
       <g class="a-openL"><path d="M200 232Q176 232 178 212Q182 196 200 196Z" fill="${P.wheat}"/></g><g class="a-openR"><path d="M200 232Q224 232 222 212Q218 196 200 196Z" fill="${P.wheat}" opacity=".85"/></g>
       <g class="a-grow" style="animation-duration:5s"><path d="M200 214V120" stroke="${P.light}" stroke-width="4" stroke-linecap="round"/><path d="M200 140Q172 126 166 104Q192 108 200 140Z" fill="${P.light}"/><path d="M200 128Q228 114 234 92Q208 96 200 128Z" fill="${P.main}"/></g>`;
  },
  sleep(id, P) {
    const house = (x, w, h) => `<rect x="${x}" y="${270 - h}" width="${w}" height="${h}" fill="${P.night}"/><path d="M${x - 4} ${270 - h}L${x + w / 2} ${250 - h}L${x + w + 4} ${270 - h}Z" fill="${P.night}"/><rect class="a-tw" style="animation-duration:6s" x="${x + w / 2 - 4}" y="${276 - h + 6}" width="8" height="9" fill="${P.warm}" opacity=".85"/>`;
    return sky(id, P, 270, 100) + stars(70, 41, P, 200) +
      `<g class="a-pulse" style="animation-duration:9s"><circle cx="270" cy="100" r="58" fill="${P.light}" opacity=".12"/><circle cx="270" cy="100" r="34" fill="${P.ivory}"/><circle cx="286" cy="90" r="32" fill="${P.night}"/></g>` +
      `<path d="M0 262Q200 236 400 258V300H0Z" fill="${P.deep}"/>` + house(70, 34, 30) + house(118, 26, 22) + house(300, 30, 28);
  },
  wind(id, P) {
    const cloud = (x, y, s, d, dur) => `<g class="a-drift" style="animation-delay:-${d}s;animation-duration:${dur}s"><g transform="translate(${x} ${y}) scale(${s})" fill="${P.light}"><circle cx="0" cy="0" r="24"/><circle cx="30" cy="-10" r="30"/><circle cx="62" cy="2" r="22"/><rect x="-10" y="0" width="80" height="22" rx="11"/></g></g>`;
    return sky(id, P, 200, 160) + cloud(60, 90, 1, 0, 18) + cloud(230, 70, 0.8, 4, 22) + cloud(150, 170, 0.6, 8, 15) +
      [110, 150, 200, 240].map((y, i) => `<path class="a-dash" style="animation-delay:-${i}s" d="M${20 + i * 20} ${y}Q120 ${y - 30} 220 ${y}T${380 - i * 10} ${y - 6}" stroke="${P.ivory}" stroke-opacity=".5" stroke-width="2" fill="none" stroke-linecap="round" stroke-dasharray="40 160"/>`).join("") +
      `<path d="M0 272Q200 256 400 272V300H0Z" fill="${P.night}"/>`;
  },
  children(id, P) {
    return sky(id, P, 280, 80) + stars(20, 51, P, 100) +
      `<g class="a-kite" style="transform-origin:280px 140px"><path d="M280 50L300 80L280 118L260 80Z" fill="${P.warm}"/><path d="M280 50V118M260 80H300" stroke="${P.night}" stroke-opacity=".4"/>
         <path d="M280 118Q270 140 284 156Q296 172 284 188" stroke="${P.light}" stroke-width="2" fill="none"/></g>
       <path d="M196 210Q236 160 280 118" stroke="${P.ivory}" stroke-opacity=".6" fill="none"/>` + hills(P, 250) +
      person(160, 262, 56, P.light, 0.5) + person(196, 262, 66, P.ivory, 1.4);
  },
  senses(id, P) {
    return sky(id, P, 200, 150) +
      [1, 2, 3].map(i => `<path class="a-tw" style="animation-delay:-${i * 0.5}s" d="M${96 - i * 14} ${150 - i * 16}Q${78 - i * 20} 150 ${96 - i * 14} ${150 + i * 16}" stroke="${P.light}" stroke-width="3" fill="none" stroke-linecap="round"/>`).join("") +
      `<circle cx="104" cy="150" r="6" fill="${P.light}"/>
       <g class="a-pulse"><path d="M200 186C160 160 160 118 186 118C196 118 200 126 200 132C200 126 204 118 214 118C240 118 240 160 200 186Z" fill="${P.warm}"/></g>` +
      Array.from({ length: 10 }, (_, k) => { const a = k * Math.PI / 5; return `<line class="a-tw" style="animation-delay:-${k * 0.3}s" x1="${(300 + 18 * Math.cos(a)).toFixed(1)}" y1="${(150 + 18 * Math.sin(a)).toFixed(1)}" x2="${(300 + 40 * Math.cos(a)).toFixed(1)}" y2="${(150 + 40 * Math.sin(a)).toFixed(1)}" stroke="${P.ivory}" stroke-width="2.5" stroke-linecap="round"/>`; }).join("") +
      `<circle cx="300" cy="150" r="11" fill="${P.ivory}"/>`;
  },
  sky(id, P) {
    const r = rng(61); let g = "";
    for (let i = 0; i < 14; i++) {
      const a = r() * Math.PI * 2, d = 50 + r() * 130, x = 200 + Math.cos(a) * d, y = 150 + Math.sin(a) * d * 0.8, rot = (r() * 180).toFixed(0);
      g += `<g transform="rotate(${rot} ${x.toFixed(0)} ${y.toFixed(0)})"><ellipse cx="${x.toFixed(0)}" cy="${y.toFixed(0)}" rx="${(8 + r() * 10).toFixed(0)}" ry="3" fill="${i % 2 ? P.light : P.warm}" opacity=".75"/><circle cx="${x.toFixed(0)}" cy="${y.toFixed(0)}" r="2" fill="${P.ivory}"/></g>`;
    }
    return sky(id, P, 200, 150) + stars(90, 71, P) + `<g class="a-expand" style="transform-origin:200px 150px">${g}</g><circle class="a-pulse" cx="200" cy="150" r="14" fill="${P.ivory}" opacity=".8"/>`;
  },

  rosette(id, P, text) {
    const petals = (n, r1, r2, fill, op) => Array.from({ length: n }, (_, k) => `<path d="M200 ${150 - r1}Q${200 + r2 * 0.5} ${150 - (r1 + r2) / 2} 200 ${150 - r2}Q${200 - r2 * 0.5} ${150 - (r1 + r2) / 2} 200 ${150 - r1}Z" fill="${fill}" opacity="${op}" transform="rotate(${(360 / n) * k} 200 150)"/>`).join("");
    const star = (r, rot, stroke) => `<g transform="rotate(${rot} 200 150)" fill="none" stroke="${stroke}" stroke-width="1.4"><rect x="${200 - r}" y="${150 - r}" width="${2 * r}" height="${2 * r}"/><rect x="${200 - r}" y="${150 - r}" width="${2 * r}" height="${2 * r}" transform="rotate(45 200 150)"/></g>`;
    return sky(id, P, 200, 150) + stars(40, 81, P) +
      `<g class="a-spin" style="transform-origin:200px 150px;animation-duration:120s">${petals(16, 40, 128, P.main, 0.35)}${star(96, 0, P.light)}</g>
       <g class="a-spin" style="transform-origin:200px 150px;animation-duration:80s;animation-direction:reverse">${petals(12, 30, 92, P.warm, 0.45)}${star(64, 22.5, P.ivory)}</g>
       <circle class="a-pulse" cx="200" cy="150" r="46" fill="${P.night}" opacity=".75"/><circle cx="200" cy="150" r="46" fill="none" stroke="${P.light}" stroke-width="1.5"/>` +
      (text ? `<text x="200" y="${text.length > 12 ? 158 : 164}" text-anchor="middle" font-family="Scheherazade New, Amiri, serif" font-size="${text.length > 12 ? 20 : 34}" fill="${P.ivory}" direction="rtl">${text}</text>` : `<circle cx="200" cy="150" r="8" fill="${P.ivory}"/>`);
  },
  lanterns(id, P) {
    const lamp = (x, len, s, d) => `<g class="a-swing" style="transform-origin:${x}px 0px;animation-delay:-${d}s"><line x1="${x}" y1="0" x2="${x}" y2="${len}" stroke="${P.light}" stroke-opacity=".6"/>
      <g transform="translate(${x} ${len}) scale(${s})"><circle class="a-pulse" cx="0" cy="34" r="34" fill="${P.warm}" opacity=".22"/>
      <path d="M-6 0h12l4 8h-20z" fill="${P.light}"/><path d="M-14 8h28l-4 46h-20z" fill="${P.sun}" opacity=".9"/><path d="M-14 8h28l-4 46h-20z" fill="none" stroke="${P.light}" stroke-width="1.5"/>
      <path d="M-8 14v34M0 12v40M8 14v34" stroke="${P.night}" stroke-opacity=".35"/><path d="M-10 54h20l-6 8h-8z" fill="${P.light}"/></g></g>`;
    return sky(id, P, 200, 120) + stars(50, 91, P, 260) + lamp(110, 70, 1, 0) + lamp(200, 110, 1.3, 1.5) + lamp(290, 60, 0.9, 3) + lamp(340, 140, 0.7, 2) + lamp(60, 150, 0.6, 4) +
      `<path d="M0 270Q200 252 400 270V300H0Z" fill="${P.night}"/>`;
  },
  tree(id, P) {
    const r = rng(101); let leaves = "", fall = "";
    for (let i = 0; i < 26; i++) { const a = r() * Math.PI * 2, d = r() * 70; leaves += `<circle cx="${(200 + Math.cos(a) * d * 1.3).toFixed(0)}" cy="${(110 + Math.sin(a) * d * 0.7).toFixed(0)}" r="${(16 + r() * 18).toFixed(0)}" fill="${i % 3 ? P.main : P.light}" opacity="${(0.55 + r() * 0.35).toFixed(2)}"/>`; }
    for (let i = 0; i < 6; i++) fall += `<ellipse class="a-fall" style="animation-delay:-${(r() * 4).toFixed(1)}s;animation-duration:${(3 + r() * 2).toFixed(1)}s" cx="${(130 + r() * 140).toFixed(0)}" cy="150" rx="4" ry="2.5" fill="${P.warm}"/>`;
    return sky(id, P, 200, 110) + stars(30, 103, P, 100) +
      `<path d="M0 232Q200 214 400 232V300H0Z" fill="${P.deep}"/>
       <g stroke="${P.light}" stroke-opacity=".35" stroke-width="2" fill="none"><path d="M200 236Q180 262 150 284M200 236Q222 264 256 286M200 236V296"/></g>
       <path d="M192 236Q196 180 182 150M208 236Q204 180 220 140M200 236V140" stroke="${P.night}" stroke-width="14" stroke-linecap="round" fill="none"/>
       <g class="a-sway" style="animation-duration:7s;transform-origin:200px 236px;transform-box:view-box">${leaves}</g>` + fall;
  },
  ship(id, P) {
    const wave = (y, c, o, d) => `<path class="a-wave" style="animation-delay:-${d}s" d="M-100 ${y}${Array.from({ length: 7 }, () => "q25 -8 50 0t50 0").join("")}V300H-100Z" fill="${c}" opacity="${o}"/>`;
    return sky(id, P, 290, 90) + stars(50, 111, P, 170) + `<circle cx="300" cy="80" r="22" fill="${P.ivory}" opacity=".9"/>` +
      wave(214, P.main, 0.5, 1) +
      `<g class="a-bob"><path d="M140 206h120l-18 26h-84z" fill="${P.night}"/><line x1="200" y1="206" x2="200" y2="110" stroke="${P.night}" stroke-width="3"/>
        <path d="M204 116Q246 160 204 200Z" fill="${P.ivory}" opacity=".92"/><path d="M196 124Q166 162 196 198Z" fill="${P.light}" opacity=".85"/></g>` +
      wave(230, P.deep, 0.9, 3) + wave(252, P.night, 1, 2);
  },
  ants(id, P) {
    const ant = (x, y, s) => `<g transform="translate(${x} ${y}) scale(${s})" fill="${P.night}"><ellipse cx="-9" cy="0" rx="6" ry="4.5"/><ellipse cx="0" cy="-1" rx="4" ry="3.2"/><circle cx="7" cy="-2" r="3.2"/>
      <path d="M-4 1l-5 6M0 2l0 7M3 1l5 6M-4 -2l-5 -5M3 -2l5 -5M8 -4l4 -5" stroke="${P.night}" stroke-width="1" fill="none"/></g>`;
    let line = ""; for (let i = 0; i < 9; i++) line += ant(-30 + i * 36, 238 + (i % 2) * 3, 1.1);
    return sky(id, P, 290, 110) + `<circle cx="290" cy="110" r="44" fill="${P.sun}" opacity=".7"/>` +
      `<path d="M0 248Q200 232 400 248V300H0Z" fill="${P.deep}"/><path d="M300 248Q340 196 380 248Z" fill="${P.main}" opacity=".7"/>` +
      `<g class="a-march">${line}</g>` +
      [262, 282, 388].map((x, i) => `<path class="a-sway" style="animation-delay:-${i}s" d="M${x} 262Q${x + 5} 240 ${x + 12} 226" stroke="${P.main}" stroke-width="3" fill="none" stroke-linecap="round"/>`).join("");
  },
  web(id, P) {
    const cx = 210, cy = 130, spokes = 12; let s = "", rings = "", drops = "";
    for (let k = 0; k < spokes; k++) { const a = k * Math.PI * 2 / spokes; s += `<line x1="${cx}" y1="${cy}" x2="${(cx + Math.cos(a) * 240).toFixed(0)}" y2="${(cy + Math.sin(a) * 240).toFixed(0)}"/>`; }
    for (let r = 18; r < 170; r += 18) rings += `<polygon points="${Array.from({ length: spokes }, (_, k) => { const a = k * Math.PI * 2 / spokes; return `${(cx + Math.cos(a) * r).toFixed(1)},${(cy + Math.sin(a) * r).toFixed(1)}`; }).join(" ")}"/>`;
    const rr = rng(121); for (let i = 0; i < 16; i++) { const a = Math.floor(rr() * spokes) * Math.PI * 2 / spokes, d = 18 * (1 + Math.floor(rr() * 8)); drops += `<circle class="a-tw" style="animation-delay:-${(rr() * 3).toFixed(1)}s" cx="${(cx + Math.cos(a) * d).toFixed(1)}" cy="${(cy + Math.sin(a) * d).toFixed(1)}" r="2.6" fill="${P.ivory}"/>`; }
    return sky(id, P, 210, 130) + `<circle cx="80" cy="70" r="26" fill="${P.ivory}" opacity=".85"/>` +
      `<g class="a-breathe" style="transform-origin:${cx}px ${cy}px;transform-box:view-box" stroke="${P.light}" stroke-opacity=".55" stroke-width="1" fill="none">${s}${rings}</g>` + drops;
  },
  ink(id, P) {
    return sky(id, P, 200, 140) + stars(30, 131, P, 120) +
      `<path class="a-draw" d="M70 190C110 120 150 230 190 160S260 100 290 170S340 210 350 150" stroke="${P.light}" stroke-width="7" stroke-linecap="round" fill="none" pathLength="100" stroke-dasharray="100" />
       <path class="a-draw" style="animation-delay:-2s" d="M90 230C140 210 200 250 250 222S320 200 340 226" stroke="${P.warm}" stroke-width="3" stroke-linecap="round" fill="none" pathLength="100" stroke-dasharray="100"/>
       <g class="a-write" style="transform-origin:300px 120px;transform-box:view-box"><rect x="296" y="40" width="10" height="90" rx="3" fill="${P.ivory}" transform="rotate(28 300 120)"/><path d="M296 128l5 16 5-16z" fill="${P.night}" transform="rotate(28 300 120)"/></g>
       ${[0, 1, 2].map(i => `<circle class="a-tw" style="animation-delay:-${i}s" cx="${120 + i * 70}" cy="${250 - i * 6}" r="3" fill="${P.light}"/>`).join("")}`;
  },
  fingerprint(id, P) {
    let arcs = "";
    for (let i = 1; i <= 13; i++) { const rx = i * 9, ry = i * 11; arcs += `<ellipse class="a-dash" style="animation-duration:${8 + i}s" cx="200" cy="${150 + i * 0.8}" rx="${rx}" ry="${ry}" fill="none" stroke="${i % 2 ? P.light : P.main}" stroke-width="2.2" stroke-linecap="round" stroke-dasharray="${(i * 9).toFixed(0)} ${(6 + i).toFixed(0)}" transform="rotate(${-8 + i} 200 150)"/>`; }
    return sky(id, P, 200, 150) + `<g class="a-pulse" style="animation-duration:8s">${arcs}</g><circle cx="200" cy="150" r="5" fill="${P.ivory}"/>`;
  },
};
function artSVG(key, color, text) {
  const id = "a" + (++ART_N), P = palette(color);
  return `<svg class="art" viewBox="0 0 400 300" preserveAspectRatio="xMidYMid slice" role="img" aria-hidden="true">${(SCENES[key] || SCENES.stars)(id, P, text)}</svg>`;
}
