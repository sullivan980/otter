var HEAD = '<svg viewBox="0 0 32 32" fill="#000" xmlns="http://www.w3.org/2000/svg"><ellipse cx="16" cy="15" rx="9.6" ry="6.6"/><circle cx="6.6" cy="10.6" r="2.4"/><circle cx="25.4" cy="10.6" r="2.4"/><rect x="3" y="24" width="26" height="3" rx="1.5"/></svg>';

function otterSil(cx, cy, s, fur, face, eye) {
  return '<g transform="translate(' + cx + ' ' + cy + ') scale(' + s + ')">'
    + '<ellipse cx="0" cy="-14" rx="62" ry="44" fill="' + fur + '"/>'
    + '<circle cx="-46" cy="-42" r="16" fill="' + fur + '"/><circle cx="46" cy="-42" r="16" fill="' + fur + '"/>'
    + '<ellipse cx="0" cy="6" rx="40" ry="26" fill="' + face + '"/>'
    + '<circle cx="-26" cy="-8" r="7" fill="' + eye + '"/><circle cx="26" cy="-8" r="7" fill="' + eye + '"/>'
    + '<path d="M-8 6 q8 -6 16 0 q-3 9 -8 9 q-5 0 -8 -9 z" fill="' + eye + '"/>'
    + '</g>';
}

// ---------- M1 莫奈：印象派水面 ----------
function monet() {
  var dabs = '';
  var pal = ['#A9C6DC', '#C7D6EA', '#7FA9BC', '#5C8AA0', '#E6D8C4', '#B9CBE0'];
  for (var i = 0; i < 110; i++) {
    var x = (i * 71 + 30) % 540 - 14;
    var y = 180 + ((i * 97 + 40) % 320);
    var w = 14 + (i * 13) % 44;
    var h = 4 + (i * 7) % 8;
    dabs += '<rect x="' + x + '" y="' + y + '" width="' + w + '" height="' + h + '" rx="' + (h / 2) + '" fill="' + pal[i % pal.length] + '" opacity="' + (0.30 + (i % 4) * 0.10) + '"/>';
  }
  var lilies = '';
  [[96, 408, 40], [170, 448, 30], [388, 424, 36], [440, 468, 24], [58, 338, 22], [300, 470, 26]].forEach(function (p, k) {
    lilies += '<ellipse cx="' + p[0] + '" cy="' + p[1] + '" rx="' + p[2] + '" ry="' + (p[2] * 0.42) + '" fill="#6F9A74" opacity="0.9"/>'
      + '<circle cx="' + (p[0] + 7) + '" cy="' + (p[1] - 5) + '" r="6" fill="#E8B7C8"/>'
      + '<circle cx="' + (p[0] - 9) + '" cy="' + (p[1] - 2) + '" r="4" fill="#F2D3DE"/>';
  });
  return '<svg viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg"><defs>'
    + '<linearGradient id="mSky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#E2DDEE"/><stop offset="0.32" stop-color="#AFC7DA"/><stop offset="0.68" stop-color="#6E9DB0"/><stop offset="1" stop-color="#3E6F86"/></linearGradient>'
    + '<filter id="mBlur"><feGaussianBlur stdDeviation="3"/></filter>'
    + '</defs><rect width="512" height="512" fill="url(#mSky)"/>'
    + dabs
    + '<g filter="url(#mBlur)" opacity="0.96">'
    + otterSil(244, 286, 1.9, '#5E4432', '#EBD7B8', '#241A12')
    + '</g>'
    + '<ellipse cx="244" cy="420" rx="120" ry="20" fill="#3E6F86" opacity="0.4"/>'
    + lilies
    + '<g stroke="#F7FBFF" stroke-width="3" fill="none" opacity="0.55" stroke-linecap="round">'
    + '<path d="M50 236 q44 -8 88 0"/><path d="M300 210 q54 -10 104 0"/><path d="M120 160 q48 -6 96 0"/><path d="M330 150 q40 -6 80 0"/>'
    + '</g>'
    + '</svg>';
}
function picasso() {
  return '<svg viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg">'
    + '<rect width="512" height="512" fill="#EFE2C8"/>'
    + '<polygon points="0,140 200,60 512,120 512,0 0,0" fill="#D9C9A8" opacity="0.7"/>'
    + '<g stroke="#141414" stroke-width="7" stroke-linejoin="round">'
    + '<polygon points="118,214 176,128 272,104 360,140 410,232 386,330 300,392 196,380 132,318" fill="#C9A05A"/>'
    + '<polygon points="272,104 360,140 336,214 262,196" fill="#5C7FA3"/>'
    + '<polygon points="118,214 132,318 214,300 176,200" fill="#B48A46"/>'
    + '<polygon points="386,330 410,232 336,214 320,300" fill="#8FA9C0"/>'
    + '<polygon points="196,380 300,392 320,300 214,300" fill="#E4D2AC"/>'
    + '</g>'
    // ears
    + '<g stroke="#141414" stroke-width="7">'
    + '<polygon points="120,170 150,104 190,132 160,186" fill="#8A6A3E"/>'
    + '<polygon points="392,180 372,108 330,130 356,190" fill="#8A6A3E"/>'
    + '</g>'
    // eyes (两个不同高度/形状 - 立体主义)
    + '<circle cx="206" cy="222" r="18" fill="#F4EAD4" stroke="#141414" stroke-width="7"/>'
    + '<circle cx="210" cy="226" r="8" fill="#141414"/>'
    + '<polygon points="286,206 330,214 322,246 284,240" fill="#F4EAD4" stroke="#141414" stroke-width="7"/>'
    + '<circle cx="308" cy="226" r="8" fill="#141414"/>'
    // 鼻子（侧面轮廓嵌入正面）
    + '<path d="M252 196 L252 286 L214 296" fill="none" stroke="#141414" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/>'
    + '<polygon points="252,286 292,300 262,326" fill="#141414"/>'
    // 嘴
    + '<path d="M210 340 q52 22 104 -4" fill="none" stroke="#141414" stroke-width="8" stroke-linecap="round"/>'
    // 胡须
    + '<g stroke="#141414" stroke-width="4" stroke-linecap="round" opacity="0.8">'
    + '<path d="M206 300 L132 288"/><path d="M206 314 L128 314"/><path d="M206 328 L134 340"/>'
    + '<path d="M306 300 L380 286"/><path d="M306 314 L384 312"/><path d="M306 328 L378 342"/>'
    + '</g>'
    + '<rect x="0" y="392" width="512" height="120" fill="#C9A05A" opacity="0.35"/>'
    + '</svg>';
}

// ---------- M3 北斋：浮世绘浪与獭 ----------
function hokusai() {
  var foam = '';
  var crest = [[150, 250], [176, 226], [206, 210], [238, 204], [268, 212], [292, 232], [304, 258], [306, 286]];
  crest.forEach(function (p, i) {
    foam += '<circle cx="' + p[0] + '" cy="' + p[1] + '" r="' + (20 - i * 1.2) + '" fill="#F7F1E3"/>';
    foam += '<circle cx="' + (p[0] - 12) + '" cy="' + (p[1] + 8) + '" r="' + (11 - i * 0.6) + '" fill="#F7F1E3"/>';
    foam += '<circle cx="' + (p[0] + 12) + '" cy="' + (p[1] + 10) + '" r="' + (9 - i * 0.5) + '" fill="#F7F1E3"/>';
  });
  return '<svg viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg"><defs>'
    + '<linearGradient id="hWave" x1="0" y1="0" x2="0.6" y2="1"><stop offset="0" stop-color="#3B7E9E"/><stop offset="1" stop-color="#123B56"/></linearGradient>'
    + '<linearGradient id="hDeep" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#1C5A7C"/><stop offset="1" stop-color="#0B2C42"/></linearGradient>'
    + '</defs><rect width="512" height="512" fill="#F1E6CF"/>'
    + '<circle cx="402" cy="118" r="60" fill="#D7583C"/>'
    // 远处浪
    + '<path d="M0 512 V316 C60 300 100 312 140 340 C118 296 132 252 176 242 C220 232 252 266 256 306 C286 266 338 258 372 288 C412 324 460 352 512 360 V512 Z" fill="url(#hDeep)" opacity="0.5"/>'
    // 主浪
    + '<path d="M-20 512 V402 C50 356 108 320 176 312 C152 268 168 226 214 216 C260 206 296 244 296 288 C330 252 386 258 418 296 C456 340 490 380 512 392 V512 Z" fill="url(#hWave)" stroke="#0E2A3C" stroke-width="5"/>'
    // 浪冠卷
    + '<path d="M176 312 C150 262 170 218 218 208 C266 198 302 232 300 276 C288 250 258 236 232 246 C206 256 198 282 208 300 Z" fill="#2E7B9B" stroke="#0E2A3C" stroke-width="4"/>'
    + foam
    // 獭（浮在浪谷，抱着鱼）
    + otterSil(340, 372, 1.55, '#2A2F33', '#F0DCBE', '#12181B')
    + '<g fill="#E2583E"><ellipse cx="300" cy="392" rx="30" ry="13"/><path d="M276 392 L256 380 L262 392 L256 404 Z"/></g>'
    + '<ellipse cx="340" cy="420" rx="96" ry="14" fill="#F7F1E3" opacity="0.35"/>'
    + '<g fill="#F7F1E3" opacity="0.8"><circle cx="110" cy="356" r="6"/><circle cx="136" cy="338" r="4"/><circle cx="88" cy="384" r="4"/><circle cx="452" cy="330" r="5"/></g>'
    + '</svg>';
}
function matisse() {
  return '<svg viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg">'
    + '<rect width="512" height="512" fill="#F3E7D0"/>'
    + '<path d="M0 300 C90 270 160 290 230 320 C300 350 380 340 512 300 V512 H0 Z" fill="#2B4C9B"/>'
    + '<path d="M0 360 C100 330 170 350 240 378 C320 410 400 396 512 356 V512 H0 Z" fill="#3E63B5" opacity="0.9"/>'
    + '<g fill="#E2583E">'
    + '<ellipse cx="118" cy="414" rx="46" ry="20"/>'
    + '<path d="M84 414 L40 392 L52 414 L40 436 Z"/>'
    + '<circle cx="146" cy="406" r="4" fill="#F3E7D0"/>'
    + '</g>'
    + '<g fill="#6E9A5E">'
    + '<path d="M60 300 C60 240 90 200 130 190 C120 250 100 280 60 300 Z"/>'
    + '<path d="M430 300 C430 240 400 200 360 190 C370 250 390 280 430 300 Z"/>'
    + '</g>'
    // 剪纸海獭：几何化的身体 + 负空间脸
    + '<g>'
    + '<path d="M256 250 C314 250 356 288 356 338 C356 384 316 410 256 410 C196 410 156 384 156 338 C156 288 198 250 256 250 Z" fill="#1B2B33"/>'
    + '<circle cx="186" cy="246" r="24" fill="#1B2B33"/><circle cx="326" cy="246" r="24" fill="#1B2B33"/>'
    + '<path d="M196 330 C196 300 224 288 256 288 C288 288 316 300 316 330 C316 352 288 364 256 364 C224 364 196 352 196 330 Z" fill="#F3E7D0"/>'
    + '<circle cx="222" cy="310" r="9" fill="#1B2B33"/><circle cx="290" cy="310" r="9" fill="#1B2B33"/>'
    + '<path d="M244 330 q12 -8 24 0 q-4 14 -12 14 q-8 0 -12 -14 z" fill="#1B2B33"/>'
    + '</g>'
    + '</svg>';
}

var ICONS = [
  { l: "M1", name: "莫奈 · 睡莲水面", tag: "IMPRESSIONISM", svg: monet(), desc: "碎笔触的水面、睡莲、柔光；海獭在中间只剩一个暖色轮廓。最像「一幅画」，16px 会变成一团柔光。" },
  { l: "M2", name: "毕加索 · 立体主义獭", tag: "CUBISM", svg: picasso(), desc: "拆成切面的獭脸、两只不同高度的眼睛、侧面轮廓嵌进正面，赭石/蓝/黑三色。最图形化。" },
  { l: "M3", name: "北斋 · 浪里的獭", tag: "UKIYO-E", svg: hokusai(), desc: "神奈川巨浪的构图，海獭浮在浪谷。平涂 + 浪花 + 红日，缩到 16px 仍是一个强剪影。" },
  { l: "M4", name: "马蒂斯 · 剪纸獭", tag: "CUT-OUT", svg: matisse(), desc: "钴蓝水面、珊瑚鱼、剪纸獭。纯色块、无描边，最像现代海报。" }
];

var grid = document.getElementById("grid");
var tpl = document.getElementById("tpl");
ICONS.forEach(function (it) {
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
  node.querySelector(".glyph").innerHTML = HEAD;
  grid.appendChild(node);
});