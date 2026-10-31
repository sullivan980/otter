var DEFS = '<defs>'
  + '<linearGradient id="wBg" x1="0" y1="0" x2="0.7" y2="1"><stop offset="0" stop-color="#1B6377"/><stop offset="0.55" stop-color="#0C3A4A"/><stop offset="1" stop-color="#061F29"/></linearGradient>'
  + '<linearGradient id="wWater" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#3E93AE"/><stop offset="1" stop-color="#123B4E"/></linearGradient>'
  + '<linearGradient id="wFur" x1="0" y1="0" x2="0.3" y2="1"><stop offset="0" stop-color="#6E4E36"/><stop offset="0.55" stop-color="#563A26"/><stop offset="1" stop-color="#3A2618"/></linearGradient>'
  + '<linearGradient id="wFace" x1="0" y1="0" x2="0.4" y2="1"><stop offset="0" stop-color="#F7E7CB"/><stop offset="1" stop-color="#D8B98D"/></linearGradient>'
  + '<filter id="rough" x="-25%" y="-25%" width="150%" height="150%">'
  +   '<feTurbulence type="fractalNoise" baseFrequency="0.022" numOctaves="4" seed="17" result="n"/>'
  +   '<feDisplacementMap in="SourceGraphic" in2="n" scale="26" xChannelSelector="R" yChannelSelector="G"/>'
  + '</filter>'
  + '<filter id="roughSoft" x="-25%" y="-25%" width="150%" height="150%">'
  +   '<feTurbulence type="fractalNoise" baseFrequency="0.03" numOctaves="3" seed="7" result="n"/>'
  +   '<feDisplacementMap in="SourceGraphic" in2="n" scale="12" xChannelSelector="R" yChannelSelector="G"/>'
  + '</filter>'
  + '<filter id="roughHeavy" x="-30%" y="-30%" width="160%" height="160%">'
  +   '<feTurbulence type="fractalNoise" baseFrequency="0.014" numOctaves="5" seed="4" result="n"/>'
  +   '<feDisplacementMap in="SourceGraphic" in2="n" scale="44" xChannelSelector="R" yChannelSelector="G"/>'
  + '</filter>'
  + '<filter id="grain"><feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="2" stitchTiles="stitch"/></filter>'
  + '</defs>';
function furPath(cx, cy, rx, ry, seed, amp) {
  var pts = [];
  var n = 72;
  for (var i = 0; i < n; i++) {
    var a = i / n * Math.PI * 2;
    var w = 1
      + (amp || 0.05) * Math.sin(a * 7 + seed)
      + (amp || 0.05) * 0.7 * Math.sin(a * 13 + seed * 2.3)
      + (i % 4 === 0 ? 0.035 : 0);
    pts.push([cx + Math.cos(a) * rx * w, cy + Math.sin(a) * ry * w]);
  }
  var d = 'M' + pts[0][0].toFixed(1) + ' ' + pts[0][1].toFixed(1);
  for (var i = 1; i < pts.length; i++) d += ' L' + pts[i][0].toFixed(1) + ' ' + pts[i][1].toFixed(1);
  return d + ' Z';
}
function strands(cx, topY, color, op) {
  var s = '<g stroke="' + color + '" stroke-width="3.2" fill="none" stroke-linecap="round" opacity="' + op + '">';
  for (var i = -6; i <= 6; i++) {
    var x = cx + i * 13;
    var h = 18 + Math.abs(Math.sin(i * 1.7)) * 16;
    s += '<path d="M' + x + ' ' + topY + ' q' + (i * 0.8) + ' ' + (-h) + ' ' + (i * 2.4) + ' ' + (-h - 6) + '"/>';
  }
  return s + '</g>';
}
function scene(inner, waterY) {
  return '<svg viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg">' + DEFS
    + '<rect width="512" height="512" fill="url(#wBg)"/>'
    + '<circle cx="256" cy="250" r="190" fill="#6ED3E8" opacity="0.07"/>'
    + inner
    + '<path d="M0 ' + waterY + ' q64 -18 128 0 t128 0 t128 0 t128 0 V512 H0 Z" fill="url(#wWater)" filter="url(#roughSoft)"/>'
    + '</svg>';
}
// W1：湿毛剪影（最克制，先看形状）
function w1() {
  var head = furPath(256, 232, 134, 104, 1.7, 0.055);
  var earL = furPath(140, 176, 34, 32, 4.2, 0.09);
  var earR = furPath(372, 176, 34, 32, 9.1, 0.09);
  return scene(
    '<g filter="url(#rough)">'
    + '<path d="' + earL + '" fill="url(#wFace)"/><path d="' + earR + '" fill="url(#wFace)"/>'
    + '<path d="' + head + '" fill="url(#wFace)"/>'
    + '</g>'
    + strands(256, 142, '#C9A77A', '0.55')
    + '<circle cx="212" cy="240" r="12" fill="#1D2B31"/><circle cx="300" cy="240" r="12" fill="#1D2B31"/>'
    + '<ellipse cx="214" cy="292" rx="44" ry="31" fill="#FDF6E7" opacity="0.9"/><ellipse cx="298" cy="292" rx="44" ry="31" fill="#FDF6E7" opacity="0.9"/>'
    + '<path d="M242 276 q14 -10 28 0 q-5 18 -14 18 q-9 0 -14 -18 z" fill="#1D2B31"/>'
    + '<path d="M186 356 q10 26 -2 40 q-10 -16 -4 -40 z" fill="#CFEFF5" opacity="0.5"/>'
    + '<path d="M330 360 q8 22 -2 34 q-8 -14 -3 -34 z" fill="#CFEFF5" opacity="0.4"/>',
    344);
}
// W2：湿毛上色版（深棕湿毛 + 奶油脸 + 湿亮高光）
function w2() {
  var head = furPath(256, 226, 138, 110, 2.4, 0.06);
  var earL = furPath(134, 168, 36, 34, 5.5, 0.10);
  var earR = furPath(378, 168, 36, 34, 8.2, 0.10);
  return scene(
    '<g filter="url(#rough)">'
    + '<path d="' + earL + '" fill="url(#wFur)"/><path d="' + earR + '" fill="url(#wFur)"/>'
    + '<path d="' + head + '" fill="url(#wFur)"/>'
    + '</g>'
    + '<ellipse cx="256" cy="306" rx="108" ry="86" fill="url(#wFace)" filter="url(#roughSoft)"/>'
    + '<g filter="url(#roughSoft)"><ellipse cx="212" cy="224" rx="54" ry="30" fill="#7B5940" opacity="0.55"/><ellipse cx="300" cy="224" rx="54" ry="30" fill="#7B5940" opacity="0.55"/></g>'
    + strands(256, 140, '#8A6446', '0.7')
    + '<path d="M168 206 q22 -26 54 -30" stroke="#E9D9BE" stroke-width="5" fill="none" stroke-linecap="round" opacity="0.55"/>'
    + '<path d="M300 176 q26 4 44 22" stroke="#E9D9BE" stroke-width="4" fill="none" stroke-linecap="round" opacity="0.4"/>'
    + '<circle cx="210" cy="250" r="13" fill="#151F24"/><circle cx="302" cy="250" r="13" fill="#151F24"/>'
    + '<circle cx="205" cy="245" r="3.6" fill="#FFFFFF" opacity="0.9"/><circle cx="297" cy="245" r="3.6" fill="#FFFFFF" opacity="0.9"/>'
    + '<ellipse cx="232" cy="300" rx="46" ry="32" fill="#FDF6E7"/><ellipse cx="280" cy="300" rx="46" ry="32" fill="#FDF6E7"/>'
    + '<path d="M240 284 q16 -11 32 0 q-6 19 -16 19 q-10 0 -16 -19 z" fill="#151F24"/>'
    + '<path d="M256 304 v10" stroke="#151F24" stroke-width="4" stroke-linecap="round"/>'
    + '<path d="M188 362 q8 22 -2 34 q-8 -14 -2 -34 z" fill="#CFEFF5" opacity="0.35"/>',
    350);
}
// W3：水墨笔刷（宣纸 + 浓墨湿毛）
function w3() {
  var head = furPath(256, 236, 130, 100, 3.1, 0.07);
  return '<svg viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg">' + DEFS
    + '<rect width="512" height="512" fill="#F1EADA"/>'
    + '<rect width="512" height="512" filter="url(#grain)" opacity="0.055"/>'
    + '<g filter="url(#roughHeavy)">'
    + '<path d="' + furPath(150, 188, 32, 30, 6.2, 0.12) + '" fill="#2E241C"/>'
    + '<path d="' + furPath(362, 188, 32, 30, 7.8, 0.12) + '" fill="#2E241C"/>'
    + '<path d="' + head + '" fill="#2E241C"/>'
    + '</g>'
    + '<ellipse cx="256" cy="300" rx="96" ry="72" fill="#F7EFDF" filter="url(#roughSoft)"/>'
    + '<circle cx="210" cy="250" r="12" fill="#F7EFDF"/><circle cx="302" cy="250" r="12" fill="#F7EFDF"/>'
    + '<ellipse cx="234" cy="300" rx="42" ry="29" fill="#F7EFDF"/><ellipse cx="278" cy="300" rx="42" ry="29" fill="#F7EFDF"/>'
    + '<path d="M242 286 q14 -10 28 0 q-5 17 -14 17 q-9 0 -14 -17 z" fill="#2E241C"/>'
    + '<g stroke="#2E241C" stroke-width="7" fill="none" stroke-linecap="round" opacity="0.9">'
    + '<path d="M0 372 q64 -22 128 0 t128 0 t128 0 t128 0"/>'
    + '<path d="M40 412 q56 -16 112 0 t112 0 t112 0"/>'
    + '</g>'
    + '<g fill="#2E241C" opacity="0.75">'
    + '<circle cx="112" cy="330" r="7"/><circle cx="404" cy="342" r="5"/><circle cx="150" cy="120" r="4"/><circle cx="372" cy="110" r="3"/>'
    + '</g>'
    + '</svg>';
}
// W4：低多边形湿毛（尖角毛束 + 水面切面）
function w4() {
  var head = furPath(256, 232, 136, 106, 2.0, 0.11);
  var facets = '';
  var cols = ['#4E3726', '#5E432D', '#6E4F35', '#3E2A1C'];
  var tris = [
    '256 132 190 210 320 214', '190 210 168 290 268 286', '320 214 300 300 360 246',
    '168 290 206 360 268 286', '300 300 268 286 206 360'
  ];
  tris.forEach(function (t, i) {
    var p = t.split(' ');
    facets += '<polygon points="' + p[0] + ',' + p[1] + ' ' + p[2] + ',' + p[3] + ' ' + p[4] + ',' + p[5] + '" fill="' + cols[i % cols.length] + '" opacity="0.85"/>';
  });
  return '<svg viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg">' + DEFS
    + '<rect width="512" height="512" fill="url(#wBg)"/>'
    + '<polygon points="0,376 128,344 256,372 384,340 512,368 512,512 0,512" fill="#164B60"/>'
    + '<polygon points="0,412 140,388 268,414 396,386 512,408 512,512 0,512" fill="#0E3648"/>'
    + '<g>'
    + '<path d="' + furPath(140, 178, 34, 32, 6.3, 0.14) + '" fill="#4E3726"/>'
    + '<path d="' + furPath(372, 178, 34, 32, 7.1, 0.14) + '" fill="#4E3726"/>'
    + '<path d="' + head + '" fill="#5E432D"/>'
    + facets
    + '</g>'
    + '<polygon points="180,286 256,262 332,288 300,352 212,350" fill="#F1DCBB"/>'
    + '<polygon points="180,286 256,262 256,352 212,350" fill="#E2C69E"/>'
    + '<circle cx="208" cy="248" r="13" fill="#101C22"/><circle cx="304" cy="248" r="13" fill="#101C22"/>'
    + '<polygon points="238,268 274,268 256,312" fill="#101C22"/>'
    + '<g stroke="#9FD8E6" stroke-width="6" fill="none" stroke-linecap="round" opacity="0.55">'
    + '<path d="M96 424 q64 -14 128 0 t128 0 t64 0"/>'
    + '</g>'
    + '</svg>';
}
var TPL = '<svg viewBox="0 0 32 32" fill="#000" xmlns="http://www.w3.org/2000/svg"><ellipse cx="16" cy="14" rx="9.6" ry="6.4"/><circle cx="6.4" cy="9.6" r="2.4"/><circle cx="25.6" cy="9.6" r="2.4"/><rect x="3" y="23" width="26" height="3" rx="1.5"/></svg>';
var ICONS = [
  { l: "W1", name: "湿毛剪影", tag: "WET SILHOUETTE", svg: w1(), desc: "只保留形状：毛边轮廓 + 头顶毛束 + 下巴滴水 + 水线。最克制，也最不容易「丑」。" },
  { l: "W2", name: "湿毛上色", tag: "WET SHADED", svg: w2(), desc: "深棕湿毛 + 奶油脸 + 湿亮高光 + 毛束，最接近照片里「被打湿」的质感。" },
  { l: "W3", name: "水墨湿毛", tag: "INK", svg: w3(), desc: "宣纸 + 浓墨 + 毛边笔触。像画出来的，不像图标工厂的产物。" },
  { l: "W4", name: "低多边形湿毛", tag: "FACETED", svg: w4(), desc: "尖角毛束 + 水面切面，硬边几何但保留湿毛的乱。" }
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
  node.querySelector(".glyph").innerHTML = TPL;
  grid.appendChild(node);
});
