function otterHead(cx, cy, r, fur, earIn, eye) {
  var ex = r * 0.74;
  var ey = cy - r * 0.56;
  return '<g>'
    + '<circle cx="' + (cx - ex) + '" cy="' + ey + '" r="' + (r * 0.30) + '" fill="' + fur + '"/>'
    + '<circle cx="' + (cx + ex) + '" cy="' + ey + '" r="' + (r * 0.30) + '" fill="' + fur + '"/>'
    + '<circle cx="' + (cx - ex) + '" cy="' + ey + '" r="' + (r * 0.13) + '" fill="' + earIn + '"/>'
    + '<circle cx="' + (cx + ex) + '" cy="' + ey + '" r="' + (r * 0.13) + '" fill="' + earIn + '"/>'
    + '<ellipse cx="' + cx + '" cy="' + cy + '" rx="' + r + '" ry="' + (r * 0.78) + '" fill="' + fur + '"/>'
    + '<ellipse cx="' + cx + '" cy="' + (cy + r * 0.24) + '" rx="' + (r * 0.66) + '" ry="' + (r * 0.42) + '" fill="#FBF0DC"/>'
    + '<circle cx="' + (cx - r * 0.32) + '" cy="' + (cy - r * 0.06) + '" r="' + (r * 0.085) + '" fill="' + eye + '"/>'
    + '<circle cx="' + (cx + r * 0.32) + '" cy="' + (cy - r * 0.06) + '" r="' + (r * 0.085) + '" fill="' + eye + '"/>'
    + '<ellipse cx="' + cx + '" cy="' + (cy + r * 0.18) + '" rx="' + (r * 0.13) + '" ry="' + (r * 0.09) + '" fill="' + eye + '"/>'
    + '<path d="M' + cx + ' ' + (cy + r * 0.27) + ' v' + (r * 0.08) + ' M' + (cx - r * 0.10) + ' ' + (cy + r * 0.36) + ' q' + (r * 0.10) + ' ' + (r * 0.08) + ' ' + (r * 0.20) + ' 0" stroke="' + eye + '" stroke-width="' + (r * 0.05) + '" fill="none" stroke-linecap="round"/>'
    + '<g stroke="' + eye + '" stroke-width="' + (r * 0.035) + '" fill="none" stroke-linecap="round" opacity="0.55">'
    + '<path d="M' + (cx - r * 0.60) + ' ' + (cy + r * 0.20) + ' l' + (-r * 0.30) + ' ' + (-r * 0.04) + '"/><path d="M' + (cx - r * 0.60) + ' ' + (cy + r * 0.26) + ' l' + (-r * 0.32) + ' 0"/><path d="M' + (cx - r * 0.60) + ' ' + (cy + r * 0.32) + ' l' + (-r * 0.30) + ' ' + (r * 0.05) + '"/>'
    + '<path d="M' + (cx + r * 0.60) + ' ' + (cy + r * 0.20) + ' l' + (r * 0.30) + ' ' + (-r * 0.04) + '"/><path d="M' + (cx + r * 0.60) + ' ' + (cy + r * 0.26) + ' l' + (r * 0.32) + ' 0"/><path d="M' + (cx + r * 0.60) + ' ' + (cy + r * 0.32) + ' l' + (r * 0.30) + ' ' + (r * 0.05) + '"/>'
    + '</g>'
    + '</g>';
}
function iconC() {
  return '<svg viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg"><defs>'
    + '<linearGradient id="cBg" x1="0" y1="0" x2="0.8" y2="1"><stop offset="0" stop-color="#0D3B52"/><stop offset="0.55" stop-color="#08202D"/><stop offset="1" stop-color="#04121A"/></linearGradient>'
    + '<radialGradient id="cRay" cx="0.75" cy="0.15" r="0.8"><stop offset="0" stop-color="#6ED3E8" stop-opacity="0.45"/><stop offset="1" stop-color="#6ED3E8" stop-opacity="0"/></radialGradient>'
    + '</defs><rect width="512" height="512" fill="url(#cBg)"/><rect width="512" height="512" fill="url(#cRay)"/>'
    + '<g transform="rotate(-20 256 268)">'
    + '<path d="M120 282 c0 -40 44 -64 104 -64 h92 c42 0 70 26 70 58 c0 34 -30 58 -72 58 h-92 c-60 0 -102 -20 -102 -52 z" fill="#6EE7DA"/>'
    + '<path d="M132 296 c0 18 30 30 80 30 h88 c34 0 56 -10 60 -24 c-6 22 -32 36 -72 36 h-88 c-48 0 -80 -16 -80 -32 c0 -4 5 -8 12 -10z" fill="#C9F8F2" opacity="0.6"/>'
    + '<path d="M120 258 q-46 -14 -72 6 q-16 14 -4 24 q14 10 30 -2 q14 -8 26 -8 z" fill="#6EE7DA"/>'
    + otterHead(352, 268, 52, "#6EE7DA", "#3DBFB6", "#04222A")
    + '<path d="M150 240 q-24 -16 -34 -30" stroke="#6EE7DA" stroke-width="20" stroke-linecap="round" fill="none"/>'
    + '</g>'
    + fish(438, 372, 0.8, "#F2A65A")
    + '<circle cx="96" cy="372" r="12" fill="#8FE7F4" opacity="0.5"/><circle cx="128" cy="404" r="6" fill="#8FE7F4" opacity="0.45"/><circle cx="452" cy="230" r="5" fill="#8FE7F4" opacity="0.5"/>'
    + '</svg>';
}
function iconE() {
  return '<svg viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg"><defs>'
    + '<linearGradient id="eBg" x1="0" y1="0" x2="0.9" y2="1"><stop offset="0" stop-color="#1C6C7E"/><stop offset="0.55" stop-color="#124A58"/><stop offset="1" stop-color="#0A2E38"/></linearGradient>'
    + '</defs><rect width="512" height="512" fill="url(#eBg)"/>'
    + '<circle cx="120" cy="96" r="90" fill="#6ED3E8" opacity="0.10"/>'
    + '<circle cx="246" cy="250" r="112" fill="none" stroke="#F6E7CB" stroke-width="42"/>'
    + otterHead(360, 330, 58, "#F6E7CB", "#D9BE92", "#12303A")
    + '<path d="M320 372 q-26 36 -6 52 q18 14 36 -2" stroke="#F6E7CB" stroke-width="24" stroke-linecap="round" fill="none"/>'
    + ripples("#8FE3F2", 462, "0.65")
    + '</svg>';
}
var TPL = '<svg viewBox="0 0 32 32" fill="#000" xmlns="http://www.w3.org/2000/svg"><path d="M3 20c0-5 4-8 10-8 3 0 5 1 7 2 3-1 6 1 6 4 0 3-2 5-6 5h-2l2 4h-4l-2-3H8c-3 0-5-2-5-4z"/></svg>';
var ICONS = [
  { l: "A", name: "仰泳抱鱼", tag: "FLOAT + FISH", svg: iconA(), desc: "海獭仰躺在水面上，四爪抱着一条鱼。最经典的海獭姿势，一眼认出。" },
  { l: "B", name: "搓澡獭", tag: "BATH", svg: iconB(), desc: "坐在浴缸里、头上搭毛巾、爪子里攥着海绵，周围全是泡泡。直接把「爱干净」画出来。" },
  { l: "C", name: "深潜捕鱼", tag: "DIVE", svg: iconC(), desc: "斜向下潜、追着鱼，尾巴和身体拉成流线。深色背景 + 荧光青，适合默认深色主题。" },
  { l: "D", name: "温泉泡汤", tag: "ONSEN", svg: iconD(), desc: "泡在石池里，只露头和两只搭在池边的小爪子，热气往上飘。最松弛、最有温度。" },
  { l: "E", name: "尾巴卷成 O", tag: "TAIL O", svg: iconE(), desc: "水獭的尾巴卷成一个 O，獭头从旁边探出来。把 Otter 的首字母和动物合成一个符号。" },
  { l: "F", name: "墨线游獭", tag: "INK SWIM", svg: iconF(), desc: "米纸上的墨线：海獭横着游过、前面有条小鱼。最克制，和 D 纸水獭主题同源。" }
];
function iconD() {
  var steam = '<g stroke="#FFFFFF" fill="none" stroke-linecap="round" opacity="0.55">'
    + '<path d="M180 214 q-18 -26 0 -50 q18 -24 0 -46" stroke-width="9"/>'
    + '<path d="M256 190 q-18 -26 0 -50 q18 -24 0 -46" stroke-width="9"/>'
    + '<path d="M332 214 q-18 -26 0 -50 q18 -24 0 -46" stroke-width="9"/>'
    + '</g>';
  return '<svg viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg"><defs>'
    + '<linearGradient id="dBg" x1="0" y1="0" x2="0.7" y2="1"><stop offset="0" stop-color="#FFF3E3"/><stop offset="0.6" stop-color="#F6DFC6"/><stop offset="1" stop-color="#E9C6A2"/></linearGradient>'
    + '<linearGradient id="dWater" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#8FD3DF"/><stop offset="1" stop-color="#5FA9BC"/></linearGradient>'
    + '</defs><rect width="512" height="512" fill="url(#dBg)"/>'
    + steam
    + '<ellipse cx="256" cy="446" rx="196" ry="52" fill="#8B7A68"/>'
    + '<ellipse cx="256" cy="436" rx="172" ry="40" fill="#6E6153"/>'
    + '<ellipse cx="256" cy="430" rx="156" ry="32" fill="url(#dWater)"/>'
    + '<path d="M256 260 c-58 0 -96 34 -96 78 v62 h192 v-62 c0 -44 -38 -78 -96 -78z" fill="#8C5B3C"/>'
    + otterHead(256, 252, 60, "#8C5B3C", "#5F3824", "#2B1C12")
    + '<rect x="200" y="196" width="112" height="18" rx="9" fill="#FFF8EC" transform="rotate(-3 256 205)"/>'
    + '<ellipse cx="196" cy="418" rx="34" ry="18" fill="#8C5B3C"/>'
    + '<ellipse cx="316" cy="418" rx="34" ry="18" fill="#8C5B3C"/>'
    + '<circle cx="150" cy="410" r="8" fill="#FFFFFF" opacity="0.7"/><circle cx="372" cy="406" r="10" fill="#FFFFFF" opacity="0.65"/>'
    + '</svg>';
}
function iconF() {
  return '<svg viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg"><defs>'
    + '<pattern id="fDots" width="7" height="7" patternUnits="userSpaceOnUse"><circle cx="1.5" cy="1.5" r="1" fill="#2B2A26" opacity="0.10"/></pattern>'
    + '</defs><rect width="512" height="512" fill="#F4EEDF"/><rect width="512" height="512" fill="url(#fDots)"/>'
    + '<g fill="#FBF6EA" stroke="#2B2A26" stroke-width="9" stroke-linejoin="round" stroke-linecap="round">'
    + '<path d="M92 322 c0 -44 40 -68 92 -68 h84 c38 0 62 24 62 54 c0 34 -28 56 -66 56 h-84 c-52 0 -88 -14 -88 -42 z"/>'
    + '<circle cx="336" cy="272" r="46"/>'
    + '<circle cx="312" cy="232" r="15"/><circle cx="360" cy="232" r="15"/>'
    + '<path d="M92 322 q-40 2 -58 22 q-14 16 2 24 q14 8 30 -6 q14 -12 26 -14"/>'
    + '</g>'
    + '<circle cx="352" cy="264" r="6" fill="#2B2A26"/>'
    + '<path d="M372 292 q12 8 22 0" stroke="#2B2A26" stroke-width="6" fill="none" stroke-linecap="round"/>'
    + '<g fill="none" stroke="#3F6B5A" stroke-width="10" stroke-linecap="round">'
    + '<path d="M96 402 q50 -20 100 0 t100 0 t100 0"/>'
    + '<path d="M140 438 q44 -16 88 0 t88 0"/>'
    + '</g>'
    + '<g fill="none" stroke="#2B2A26" stroke-width="7" stroke-linecap="round" transform="translate(400 336) scale(0.6)">'
    + '<ellipse cx="0" cy="0" rx="36" ry="19"/><path d="M-30 0 L-56 -16 L-50 0 L-56 16 Z"/>'
    + '</g>'
    + '</svg>';
}
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
