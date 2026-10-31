var TPL = '<svg viewBox="0 0 32 32" fill="#000" xmlns="http://www.w3.org/2000/svg"><path d="M3 20c0-5 4-8 10-8 3 0 5 1 7 2 3-1 6 1 6 4 0 3-2 5-6 5h-2l2 4h-4l-2-3H8c-3 0-5-2-5-4z"/></svg>';

function paw() {
  var toes = '';
  var pos = [[194,300,25,33],[224,266,25,35],[256,252,26,37],[288,266,25,35],[318,300,25,33]];
  pos.forEach(function (p) { toes += '<ellipse cx="' + p[0] + '" cy="' + p[1] + '" rx="' + p[2] + '" ry="' + p[3] + '" fill="#F3E2C4"/>'; });
  return '<svg viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg"><defs>'
    + '<linearGradient id="pBg" x1="0" y1="0" x2="0.9" y2="1"><stop offset="0" stop-color="#12586A"/><stop offset="0.55" stop-color="#0B3948"/><stop offset="1" stop-color="#06222C"/></linearGradient>'
    + '<radialGradient id="pGlow" cx="0.2" cy="0.1" r="0.9"><stop offset="0" stop-color="#6ED3E8" stop-opacity="0.28"/><stop offset="1" stop-color="#6ED3E8" stop-opacity="0"/></radialGradient>'
    + '</defs><rect width="512" height="512" fill="url(#pBg)"/><rect width="512" height="512" fill="url(#pGlow)"/>'
    + '<circle cx="256" cy="290" r="158" fill="none" stroke="#8FE3F2" stroke-width="2" opacity="0.22"/>'
    + '<circle cx="256" cy="290" r="196" fill="none" stroke="#8FE3F2" stroke-width="1.5" opacity="0.10"/>'
    + toes
    + '<path d="M256 322 C214 322 186 352 186 386 C186 418 216 438 256 438 C296 438 326 418 326 386 C326 352 298 322 256 322 Z" fill="#F3E2C4"/>'
    + '<circle cx="150" cy="168" r="7" fill="#9FE7F1" opacity="0.55"/><circle cx="392" cy="416" r="5" fill="#9FE7F1" opacity="0.45"/>'
    + '</svg>';
}
function waveFish() {
  return '<svg viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg"><defs>'
    + '<linearGradient id="wBg" x1="0" y1="0" x2="0.8" y2="1"><stop offset="0" stop-color="#0E4152"/><stop offset="0.6" stop-color="#082A36"/><stop offset="1" stop-color="#041820"/></linearGradient>'
    + '</defs><rect width="512" height="512" fill="url(#wBg)"/>'
    + '<g fill="none" stroke="#F3E2C4" stroke-linecap="round">'
    + '<path d="M92 420 q84 -34 168 0 t168 0" stroke-width="16" opacity="0.9"/>'
    + '<path d="M110 374 q76 -28 152 0 t152 0" stroke-width="12" opacity="0.55"/>'
    + '<path d="M128 330 q68 -24 136 0 t136 0" stroke-width="9" opacity="0.30"/>'
    + '</g>'
    + '<g fill="#F2A65A"><ellipse cx="316" cy="212" rx="86" ry="44"/><path d="M236 212 L182 172 L196 212 L182 252 Z"/></g>'
    + '<circle cx="362" cy="196" r="7" fill="#06222C"/>'
    + '<path d="M300 160 q18 -26 46 -18" stroke="#F2A65A" stroke-width="10" fill="none" stroke-linecap="round"/>'
    + '<circle cx="120" cy="200" r="9" fill="#9FE7F1" opacity="0.5"/><circle cx="156" cy="160" r="5" fill="#9FE7F1" opacity="0.4"/>'
    + '</svg>';
}
function oWave() {
  return '<svg viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg"><defs>'
    + '<linearGradient id="oBg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#1E7A8C"/><stop offset="0.6" stop-color="#124C5B"/><stop offset="1" stop-color="#0A2E3A"/></linearGradient>'
    + '<linearGradient id="oRing" x1="0" y1="0" x2="0.4" y2="1"><stop offset="0" stop-color="#FFF6E6"/><stop offset="1" stop-color="#E7CFA6"/></linearGradient>'
    + '</defs><rect width="512" height="512" fill="url(#oBg)"/>'
    + '<circle cx="256" cy="252" r="132" fill="none" stroke="url(#oRing)" stroke-width="58"/>'
    + '<path d="M132 318 q44 -30 88 0 t88 0 t88 0" stroke="#7FE3F2" stroke-width="14" fill="none" stroke-linecap="round"/>'
    + '<path d="M176 366 q40 -22 80 0 t80 0" stroke="#7FE3F2" stroke-width="9" fill="none" stroke-linecap="round" opacity="0.5"/>'
    + '</svg>';
}
function oGlass() {
  return '<svg viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg"><defs>'
    + '<linearGradient id="gBg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#123A52"/><stop offset="0.5" stop-color="#0A2233"/><stop offset="1" stop-color="#05131E"/></linearGradient>'
    + '<linearGradient id="gPanel" x1="0" y1="0" x2="0.6" y2="1"><stop offset="0" stop-color="#FFFFFF" stop-opacity="0.20"/><stop offset="1" stop-color="#FFFFFF" stop-opacity="0.04"/></linearGradient>'
    + '<linearGradient id="gRing" x1="0" y1="0" x2="0.3" y2="1"><stop offset="0" stop-color="#FFFFFF" stop-opacity="0.9"/><stop offset="1" stop-color="#6ED3E8" stop-opacity="0.55"/></linearGradient>'
    + '<radialGradient id="gAur" cx="0.25" cy="0.15" r="0.9"><stop offset="0" stop-color="#6ED3E8" stop-opacity="0.4"/><stop offset="1" stop-color="#6ED3E8" stop-opacity="0"/></radialGradient>'
    + '</defs><rect width="512" height="512" fill="url(#gBg)"/><rect width="512" height="512" fill="url(#gAur)"/>'
    + '<rect x="46" y="46" width="420" height="420" rx="86" fill="url(#gPanel)" stroke="#FFFFFF" stroke-opacity="0.18" stroke-width="2"/>'
    + '<circle cx="256" cy="256" r="118" fill="none" stroke="url(#gRing)" stroke-width="34" opacity="0.95"/>'
    + '<circle cx="256" cy="256" r="118" fill="none" stroke="#061722" stroke-width="8" opacity="0.35"/>'
    + '<path d="M150 300 q52 -26 104 0 t104 0" stroke="#BFF2FA" stroke-width="10" fill="none" stroke-linecap="round" opacity="0.85"/>'
    + '<path d="M150 340 q52 -22 104 0 t104 0" stroke="#BFF2FA" stroke-width="7" fill="none" stroke-linecap="round" opacity="0.45"/>'
    + '</svg>';
}
function lineOtter() {
  return '<svg viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg"><defs>'
    + '<pattern id="lDots" width="7" height="7" patternUnits="userSpaceOnUse"><circle cx="1.5" cy="1.5" r="1" fill="#2B2A26" opacity="0.08"/></pattern>'
    + '</defs><rect width="512" height="512" fill="#F5EFE3"/><rect width="512" height="512" fill="url(#lDots)"/>'
    + '<g fill="none" stroke="#242322" stroke-width="12" stroke-linecap="round" stroke-linejoin="round">'
    + '<path d="M118 316 C136 284 172 266 214 262 C252 258 284 266 308 284 C326 296 332 312 324 322 C316 334 294 336 278 328 C266 322 258 314 248 310 C234 330 202 340 170 334 C144 330 126 324 118 316 Z"/>'
    + '<path d="M118 316 C96 312 78 300 64 282"/>'
    + '<path d="M286 264 q6 -14 18 -6"/><path d="M266 262 q4 -14 16 -8"/>'
    + '</g>'
    + '<circle cx="304" cy="296" r="7" fill="#242322"/>'
    + '<g fill="none" stroke="#242322" stroke-width="7" stroke-linecap="round" opacity="0.75">'
    + '<path d="M318 306 q14 4 22 -2"/><path d="M316 316 q14 6 23 2"/>'
    + '</g>'
    + '<g fill="none" stroke="#3F6B5A" stroke-width="10" stroke-linecap="round">'
    + '<path d="M96 404 q56 -22 112 0 t112 0 t96 0"/>'
    + '<path d="M150 442 q48 -18 96 0 t96 0"/>'
    + '</g>'
    + '<g fill="none" stroke="#242322" stroke-width="8" stroke-linecap="round" transform="translate(408 348) scale(0.62)">'
    + '<ellipse cx="0" cy="0" rx="36" ry="19"/><path d="M-30 0 L-56 -16 L-50 0 L-56 16 Z"/><circle cx="20" cy="-4" r="3.5" fill="#242322"/>'
    + '</g>'
    + '</svg>';
}
function otterGraphic() {
  return '<svg viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg"><defs>'
    + '<linearGradient id="qBg" x1="0" y1="0" x2="0.8" y2="1"><stop offset="0" stop-color="#12586A"/><stop offset="0.55" stop-color="#0B3948"/><stop offset="1" stop-color="#06222C"/></linearGradient>'
    + '<radialGradient id="qGlow" cx="0.75" cy="0.1" r="0.9"><stop offset="0" stop-color="#6ED3E8" stop-opacity="0.3"/><stop offset="1" stop-color="#6ED3E8" stop-opacity="0"/></radialGradient>'
    + '</defs><rect width="512" height="512" fill="url(#qBg)"/><rect width="512" height="512" fill="url(#qGlow)"/>'
    + '<g fill="#F3E2C4">'
    + '<ellipse cx="246" cy="318" rx="112" ry="46" transform="rotate(-14 246 318)"/>'
    + '<circle cx="352" cy="280" r="50"/>'
    + '<circle cx="322" cy="238" r="16"/><circle cx="382" cy="236" r="16"/>'
    + '<path d="M146 300 q-48 -22 -72 -2 q-16 14 -4 26 q14 12 32 0 q14 -10 30 -10 z"/>'
    + '<ellipse cx="196" cy="270" rx="20" ry="14" transform="rotate(-10 196 270)"/>'
    + '<ellipse cx="282" cy="262" rx="20" ry="14" transform="rotate(-10 282 262)"/>'
    + '</g>'
    + '<g fill="#F2A65A"><ellipse cx="238" cy="212" rx="54" ry="27"/><path d="M190 212 L154 192 L162 212 L154 232 Z"/></g>'
    + '<circle cx="368" cy="268" r="6" fill="#06222C"/>'
    + '<g stroke="#8FE3F2" fill="none" stroke-linecap="round" opacity="0.7"><path d="M96 400 q52 -20 104 0 t104 0 t104 0" stroke-width="10"/><path d="M150 438 q46 -16 92 0 t96 0" stroke-width="7" opacity="0.5"/></g>'
    + '<circle cx="132" cy="180" r="6" fill="#9FE7F1" opacity="0.5"/>'
    + '</svg>';
}
var FAMILIES = [
  { title: "符号系", en: "SYMBOL", note: "不画动物全貌，用「爪印 / 水纹+鱼」做符号。最容易缩小，也最有工具感。",
    items: [
      { l: "A1", name: "爪印涟漪", tag: "PAW", svg: paw(), desc: "海獭的五趾爪印 + 水圈。一个符号，不画脸；小到 16px 也能认出。" },
      { l: "A2", name: "水纹游鱼", tag: "RIPPLE + FISH", svg: waveFish(), desc: "三层水纹 + 一条鱼：干净的水和清理的暗示，极简，几乎不会画丑。" }
    ] },
  { title: "字体与玻璃系", en: "TYPE / GLASS", note: "用 Otter 的首字母 O 做主体，水波做细节；可选扁平或 macOS 26 玻璃。",
    items: [
      { l: "B1", name: "O · 水波", tag: "TYPE O", svg: oWave(), desc: "一个厚 O + 内部水波。像品牌字标，放在 Dock 里很稳，不依赖卡通。" },
      { l: "B2", name: "O · 玻璃", tag: "GLASS O", svg: oGlass(), desc: "玻璃面板里压出 O 和水波，带边缘高光。最贴默认 E 主题。" }
    ] },
  { title: "线条与剪影系", en: "LINE / SILHOUETTE", note: "一条线或一块剪影来说「海獭在水里」，克制、偏插画。",
    items: [
      { l: "C1", name: "单线游獭", tag: "ONE LINE", svg: lineOtter(), desc: "一笔画完的海獭侧影（背、头、尾、爪）+ 小鱼。留白多，像签绘。" },
      { l: "C2", name: "剪影抱鱼", tag: "PICTOGRAM", svg: otterGraphic(), desc: "整块奶油色剪影：仰泳的海獭抱着鱼。没有卡通五官，只留一个眼睛点，像一枚标识。" }
    ] }
];

var out = document.getElementById("out");
var tpl = document.getElementById("tpl");
FAMILIES.forEach(function (fam) {
  var sec = document.createElement("section"); sec.className = "family";
  sec.innerHTML = '<h2>' + fam.title + '<span>' + fam.en + '</span></h2><div class="note">' + fam.note + '</div>';
  var grid = document.createElement("div"); grid.className = "grid";
  fam.items.forEach(function (it) {
    var node = tpl.content.firstElementChild.cloneNode(true);
    node.querySelector(".tag").textContent = it.tag + " · " + it.l;
    node.querySelector(".name").textContent = it.name;
    node.querySelector(".desc").textContent = it.desc;
    node.querySelector(".shape").innerHTML = it.svg;
    var sizes = node.querySelector(".sizes");
    [128, 64, 32, 16].forEach(function (px) {
      var d = document.createElement("div"); d.className = "s";
      var b = document.createElement("div"); b.className = "box"; b.style.width = px + "px"; b.style.height = px + "px";
      b.innerHTML = it.svg;
      var lab = document.createElement("span"); lab.textContent = px;
      d.appendChild(b); d.appendChild(lab); sizes.appendChild(d);
    });
    node.querySelector(".glyph").innerHTML = TPL;
    grid.appendChild(node);
  });
  sec.appendChild(grid); out.appendChild(sec);
});