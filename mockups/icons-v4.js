function waterBg(id) {
  return '<defs>'
    + '<radialGradient id="' + id + 'Bg" cx="0.5" cy="0.12" r="1.05"><stop offset="0" stop-color="#A8DDF1"/><stop offset="0.45" stop-color="#4D9DC2"/><stop offset="1" stop-color="#0F3D57"/></radialGradient>'
    + '<linearGradient id="' + id + 'Fur" x1="0" y1="0" x2="0.4" y2="1"><stop offset="0" stop-color="#7A5A42"/><stop offset="0.55" stop-color="#5C4230"/><stop offset="1" stop-color="#3E2B1E"/></linearGradient>'
    + '<linearGradient id="' + id + 'FurLight" x1="0" y1="0" x2="0.3" y2="1"><stop offset="0" stop-color="#C9A57D"/><stop offset="1" stop-color="#8E6A4C"/></linearGradient>'
    + '<radialGradient id="' + id + 'Muzzle" cx="0.5" cy="0.3" r="0.8"><stop offset="0" stop-color="#F2E1C9"/><stop offset="1" stop-color="#D6BB98"/></radialGradient>'
    + '<radialGradient id="' + id + 'Eye" cx="0.35" cy="0.3" r="0.8"><stop offset="0" stop-color="#4A3527"/><stop offset="0.6" stop-color="#231812"/><stop offset="1" stop-color="#120C08"/></radialGradient>'
    + '<linearGradient id="' + id + 'Water" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#7EC4E4"/><stop offset="1" stop-color="#2C7396"/></linearGradient>'
    + '</defs>';
}
function otterFace(id, cx, cy, s, tilt) {
  var g = '<g transform="translate(' + cx + ' ' + cy + ') scale(' + s + ') rotate(' + tilt + ')">';
  g += '<g fill="url(#' + id + 'Fur)">'
    + '<circle cx="-96" cy="-78" r="26"/><circle cx="96" cy="-78" r="26"/>'
    + '</g>';
  g += '<circle cx="-96" cy="-78" r="12" fill="#33231A"/><circle cx="96" cy="-78" r="12" fill="#33231A"/>';
  // head
  g += '<ellipse cx="0" cy="0" rx="118" ry="96" fill="url(#' + id + 'Fur)"/>';
  // fluff tufts
  g += '<path d="M-118 10 q-18 22 -6 40 q10 -18 26 -22 z" fill="url(#' + id + 'Fur)"/>'
    + '<path d="M118 10 q18 22 6 40 q-10 -18 -26 -22 z" fill="url(#' + id + 'Fur)"/>'
    + '<path d="M-90 -70 q-6 -26 12 -40 q2 22 14 30 z" fill="url(#' + id + 'Fur)"/>'
    + '<path d="M90 -70 q6 -26 -12 -40 q-2 22 -14 30 z" fill="url(#' + id + 'Fur)"/>';
  // cheeks highlight
  g += '<ellipse cx="-52" cy="34" rx="52" ry="40" fill="url(#' + id + 'FurLight)" opacity="0.55"/>'
    + '<ellipse cx="52" cy="34" rx="52" ry="40" fill="url(#' + id + 'FurLight)" opacity="0.55"/>';
  // muzzle
  g += '<ellipse cx="-26" cy="40" rx="46" ry="34" fill="url(#' + id + 'Muzzle)"/>'
    + '<ellipse cx="26" cy="40" rx="46" ry="34" fill="url(#' + id + 'Muzzle)"/>';
  // eyes
  g += '<circle cx="-46" cy="-6" r="17" fill="url(#' + id + 'Eye)"/><circle cx="46" cy="-6" r="17" fill="url(#' + id + 'Eye)"/>'
    + '<circle cx="-52" cy="-12" r="5.5" fill="#FFFFFF" opacity="0.95"/><circle cx="40" cy="-12" r="5.5" fill="#FFFFFF" opacity="0.95"/>'
    + '<circle cx="-40" cy="0" r="2.6" fill="#FFFFFF" opacity="0.6"/><circle cx="52" cy="0" r="2.6" fill="#FFFFFF" opacity="0.6"/>';
  // nose + mouth
  g += '<path d="M-17 22 q17 -11 34 0 q-6 16 -17 16 q-11 0 -17 -16 z" fill="#2A1C14"/>';
  g += '<path d="M0 38 v10 M-12 52 q12 9 24 0" stroke="#3A281D" stroke-width="4.5" fill="none" stroke-linecap="round"/>';
  // whiskers
  g += '<g stroke="#F6EBDD" stroke-width="3" fill="none" stroke-linecap="round" opacity="0.85">'
    + '<path d="M-52 30 q-42 -8 -66 -22"/><path d="M-54 40 q-44 2 -68 0"/><path d="M-50 50 q-40 12 -62 24"/>'
    + '<path d="M52 30 q42 -8 66 -22"/><path d="M54 40 q44 2 68 0"/><path d="M50 50 q40 12 62 24"/>'
    + '</g>';
  g += '</g>';
  return g;
}
function ripples(cy, id) {
  return '<g fill="none" stroke="#EAF8FF" opacity="0.6">'
    + '<ellipse cx="256" cy="' + cy + '" rx="196" ry="26" stroke-width="5" opacity="0.35"/>'
    + '<ellipse cx="256" cy="' + (cy + 18) + '" rx="150" ry="18" stroke-width="4" opacity="0.25"/>'
    + '<ellipse cx="256" cy="' + (cy - 12) + '" rx="236" ry="32" stroke-width="3" opacity="0.18"/>'
    + '</g>';
}
function iconA() {
  var id = 'a';
  return '<svg viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg">' + waterBg(id)
    + '<rect width="512" height="512" fill="url(#' + id + 'Bg)"/>'
    + '<circle cx="110" cy="90" r="120" fill="#FFFFFF" opacity="0.10"/>'
    + '<ellipse cx="256" cy="300" rx="250" ry="150" fill="#0F3D57" opacity="0.18"/>'
    + otterFace(id, 256, 250, 1.05, 0)
    + '<path d="M0 372 q66 -22 132 0 t132 0 t132 0 t116 0 V512 H0 Z" fill="url(#' + id + 'Water)" opacity="0.85"/>'
    + ripples(374, id)
    + '<ellipse cx="256" cy="392" rx="120" ry="18" fill="#0B3248" opacity="0.35"/>'
    + '</svg>';
}
function iconB() {
  var id = 'b';
  return '<svg viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg">' + waterBg(id)
    + '<rect width="512" height="512" fill="url(#' + id + 'Bg)"/>'
    + '<circle cx="410" cy="80" r="100" fill="#FFFFFF" opacity="0.10"/>'
    + '<ellipse cx="256" cy="330" rx="250" ry="140" fill="#0F3D57" opacity="0.2"/>'
    // tail
    + '<path d="M112 340 q-62 -6 -92 26 q-18 22 4 32 q22 8 40 -12 q16 -18 40 -22 z" fill="url(#' + id + 'Fur)"/>'
    // body
    + '<ellipse cx="248" cy="356" rx="146" ry="76" fill="url(#' + id + 'Fur)"/>'
    + '<ellipse cx="252" cy="372" rx="112" ry="54" fill="url(#' + id + 'FurLight)" opacity="0.75"/>'
    // paws
    + '<ellipse cx="196" cy="312" rx="30" ry="20" transform="rotate(-16 196 312)" fill="url(#' + id + 'Fur)"/>'
    + '<ellipse cx="300" cy="306" rx="30" ry="20" transform="rotate(16 300 306)" fill="url(#' + id + 'Fur)"/>'
    + '<ellipse cx="214" cy="370" rx="28" ry="18" fill="url(#' + id + 'Fur)"/>'
    + '<ellipse cx="292" cy="366" rx="28" ry="18" fill="url(#' + id + 'Fur)"/>'
    // fish
    + '<g fill="#F0A35C"><ellipse cx="252" cy="286" rx="56" ry="28"/><path d="M200 286 L164 266 L172 286 L164 306 Z"/></g>'
    + '<circle cx="284" cy="278" r="4.5" fill="#12303A"/>'
    // head
    + otterFace(id, 356, 250, 0.92, 6)
    + '<path d="M0 404 q66 -20 132 0 t132 0 t132 0 t116 0 V512 H0 Z" fill="url(#' + id + 'Water)" opacity="0.85"/>'
    + ripples(406, id)
    + '</svg>';
}
function iconC() {
  var id = 'c';
  return '<svg viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg">' + waterBg(id)
    + '<rect width="512" height="512" fill="url(#' + id + 'Bg)"/>'
    + '<circle cx="120" cy="120" r="120" fill="#FFFFFF" opacity="0.10"/>'
    + otterFace(id, 176, 260, 0.78, -10)
    + otterFace(id, 336, 260, 0.78, 10)
    // held paws
    + '<ellipse cx="228" cy="336" rx="26" ry="18" transform="rotate(-18 228 336)" fill="url(#' + id + 'Fur)"/>'
    + '<ellipse cx="284" cy="336" rx="26" ry="18" transform="rotate(18 284 336)" fill="url(#' + id + 'Fur)"/>'
    + '<path d="M0 396 q66 -20 132 0 t132 0 t132 0 t116 0 V512 H0 Z" fill="url(#' + id + 'Water)" opacity="0.85"/>'
    + ripples(398, id)
    + '</svg>';
}
var TPL = '<svg viewBox="0 0 32 32" fill="#000" xmlns="http://www.w3.org/2000/svg"><path d="M6 16c0-5 4.5-9 10-9 2.6 0 5 .9 6.7 2.4 2.2 0 3.8 1.7 3.8 4 0 2.2-1.5 3.8-3.6 4.1-1.4 2.9-4 4.5-7 4.5-5.5 0-9.9-3.4-9.9-6z"/></svg>';
var ICONS = [
  { l: "A", name: "浮水面露头", tag: "SURFACE", svg: iconA(), desc: "只露头和肩膀在水面，水波纹绕一圈。最接近你搜到的那张「海獭浮在水里看镜头」，干净、直接。" },
  { l: "B", name: "仰泳抱鱼", tag: "FLOAT + FISH", svg: iconB(), desc: "仰躺在水面、四爪把小鱼抱在肚皮上。经典海獭姿势，有场景、有故事。" },
  { l: "C", name: "牵手两只", tag: "HOLDING PAWS", svg: iconC(), desc: "两只海獭在水里牵着手（照片里最出名的一幕），中间两只小爪子碰到一起。" }
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
