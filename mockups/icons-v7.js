var DEFS = '<defs>'
  + '<linearGradient id="bgA" x1="0" y1="0" x2="0.6" y2="1"><stop offset="0" stop-color="#15596B"/><stop offset="0.6" stop-color="#0B3543"/><stop offset="1" stop-color="#06222C"/></linearGradient>'
  + '<linearGradient id="furA" x1="0" y1="0" x2="0.35" y2="1"><stop offset="0" stop-color="#F7E7CB"/><stop offset="0.55" stop-color="#EAD3AE"/><stop offset="1" stop-color="#D2B488"/></linearGradient>'
  + '<linearGradient id="waterA" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#3F97B4"/><stop offset="1" stop-color="#17495E"/></linearGradient>'
  + '</defs>';
function frame(inner) {
  return '<svg viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg">' + DEFS
    + '<rect width="512" height="512" fill="url(#bgA)"/>' + inner + '</svg>';
}
function ripples(y, color, op) {
  return '<g fill="none" stroke="' + color + '" stroke-linecap="round" opacity="' + op + '">'
    + '<ellipse cx="256" cy="' + y + '" rx="168" ry="20" stroke-width="6" opacity="0.5"/>'
    + '<ellipse cx="256" cy="' + (y + 20) + '" rx="118" ry="14" stroke-width="5" opacity="0.35"/>'
    + '<ellipse cx="256" cy="' + (y - 14) + '" rx="210" ry="26" stroke-width="4" opacity="0.18"/>'
    + '</g>';
}
// 海獭头部：宽脸、耳朵在两侧偏低、眼睛小而分开、宽吻部
function otterHead(cx, cy, rx, ry, fur, tone, eye) {
  var earY = cy - ry * 0.30;
  var earX = rx * 0.92;
  var g = '';
  g += '<circle cx="' + (cx - earX) + '" cy="' + earY + '" r="' + (rx * 0.20) + '" fill="' + fur + '"/>';
  g += '<circle cx="' + (cx + earX) + '" cy="' + earY + '" r="' + (rx * 0.20) + '" fill="' + fur + '"/>';
  g += '<circle cx="' + (cx - earX) + '" cy="' + earY + '" r="' + (rx * 0.085) + '" fill="' + tone + '"/>';
  g += '<circle cx="' + (cx + earX) + '" cy="' + earY + '" r="' + (rx * 0.085) + '" fill="' + tone + '"/>';
  g += '<ellipse cx="' + cx + '" cy="' + cy + '" rx="' + rx + '" ry="' + ry + '" fill="' + fur + '"/>';
  g += '<ellipse cx="' + (cx - rx * 0.30) + '" cy="' + (cy + ry * 0.55) + '" rx="' + (rx * 0.34) + '" ry="' + (ry * 0.36) + '" fill="#FDF6E7"/>';
  g += '<ellipse cx="' + (cx + rx * 0.30) + '" cy="' + (cy + ry * 0.55) + '" rx="' + (rx * 0.34) + '" ry="' + (ry * 0.36) + '" fill="#FDF6E7"/>';
  g += '<circle cx="' + (cx - rx * 0.34) + '" cy="' + (cy - ry * 0.02) + '" r="' + (rx * 0.085) + '" fill="' + eye + '"/>';
  g += '<circle cx="' + (cx + rx * 0.34) + '" cy="' + (cy - ry * 0.02) + '" r="' + (rx * 0.085) + '" fill="' + eye + '"/>';
  g += '<circle cx="' + (cx - rx * 0.37) + '" cy="' + (cy - ry * 0.07) + '" r="' + (rx * 0.028) + '" fill="#FFFFFF" opacity="0.9"/>';
  g += '<circle cx="' + (cx + rx * 0.31) + '" cy="' + (cy - ry * 0.07) + '" r="' + (rx * 0.028) + '" fill="#FFFFFF" opacity="0.9"/>';
  g += '<path d="M' + (cx - rx * 0.14) + ' ' + (cy + ry * 0.28) + ' q' + (rx * 0.14) + ' -' + (ry * 0.10) + ' ' + (rx * 0.28) + ' 0 q-' + (rx * 0.05) + ' ' + (ry * 0.18) + ' -' + (rx * 0.14) + ' ' + (ry * 0.18) + ' q-' + (rx * 0.09) + ' 0 -' + (rx * 0.14) + ' -' + (ry * 0.18) + ' z" fill="' + eye + '"/>';
  return g;
}
function waterline(y) {
  return '<path d="M0 ' + y + ' q64 -16 128 0 t128 0 t128 0 t128 0 V512 H0 Z" fill="url(#waterA)"/>';
}
function g1() {
  return frame(
    '<circle cx="256" cy="236" r="184" fill="#6ED3E8" opacity="0.08"/>'
    + otterHead(256, 226, 132, 96, 'url(#furA)', '#C9A778', '#1D2E36')
    + '<ellipse cx="164" cy="352" rx="30" ry="19" fill="url(#furA)"/><ellipse cx="348" cy="352" rx="30" ry="19" fill="url(#furA)"/>'
    + waterline(344)
    + ripples(376, "#BFF2FA", "0.55")
  );
}
function g2() {
  return frame(
    '<path d="M96 344 a160 160 0 0 1 320 0 z" fill="url(#furA)"/>'
    + '<circle cx="120" cy="214" r="26" fill="url(#furA)"/><circle cx="392" cy="214" r="26" fill="url(#furA)"/>'
    + '<circle cx="120" cy="214" r="10" fill="#C9A778"/><circle cx="392" cy="214" r="10" fill="#C9A778"/>'
    + '<circle cx="212" cy="262" r="12" fill="#1D2E36"/><circle cx="300" cy="262" r="12" fill="#1D2E36"/>'
    + '<circle cx="208" cy="257" r="4" fill="#FFFFFF" opacity="0.9"/><circle cx="296" cy="257" r="4" fill="#FFFFFF" opacity="0.9"/>'
    + '<ellipse cx="232" cy="310" rx="46" ry="32" fill="#FDF6E7"/><ellipse cx="280" cy="310" rx="46" ry="32" fill="#FDF6E7"/>'
    + '<path d="M242 292 q14 -10 28 0 q-5 18 -14 18 q-9 0 -14 -18 z" fill="#1D2E36"/>'
    + '<rect x="0" y="344" width="512" height="168" fill="url(#waterA)"/>'
    + '</g>'
    + ripples(374, "#BFF2FA", "0.55")
  );
}
function g3() {
  return '<svg viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg">' + DEFS
    + '<rect width="512" height="512" fill="url(#furA)"/>'
    + '<g fill="#0B3543">'
    + '<circle cx="146" cy="196" r="26"/><circle cx="366" cy="196" r="26"/>'
    + '<ellipse cx="256" cy="244" rx="132" ry="96"/>'
    + '</g>'
    + '<path d="M0 372 q64 -14 128 0 t128 0 t128 0 t128 0 V512 H0 Z" fill="url(#waterA)"/>'
    + '<ellipse cx="216" cy="252" rx="16" ry="13" fill="#F7ECDA"/><ellipse cx="296" cy="252" rx="16" ry="13" fill="#F7ECDA"/>'
    + '<ellipse cx="232" cy="306" rx="46" ry="32" fill="#F7ECDA"/><ellipse cx="280" cy="306" rx="46" ry="32" fill="#F7ECDA"/>'
    + '<path d="M242 288 q14 -10 28 0 q-5 18 -14 18 q-9 0 -14 -18 z" fill="#0B3543"/>'
    + '<g fill="none" stroke="#F7ECDA" stroke-linecap="round" opacity="0.35"><ellipse cx="256" cy="410" rx="150" ry="18" stroke-width="6"/></g>'
    + '</svg>';
}
function g4() {
  return frame(
    '<circle cx="256" cy="312" r="178" fill="url(#waterA)" opacity="0.95"/>'
    + otterHead(256, 214, 124, 90, 'url(#furA)', '#C9A778', '#1D2E36')
    + '<path d="M78 380 q60 -14 120 0 t120 0 t120 0" fill="none" stroke="#BFF2FA" stroke-width="8" opacity="0.55"/>'
    + '<circle cx="256" cy="312" r="178" fill="none" stroke="#BFF2FA" stroke-width="3" opacity="0.22"/>'
  );
}
function g5() {
  return frame(
    '<circle cx="256" cy="256" r="176" fill="none" stroke="#F1DCBB" stroke-width="15" opacity="0.9"/>'
    + '<path d="M120 300 a136 116 0 0 1 272 0" fill="none" stroke="#F1DCBB" stroke-width="17" stroke-linecap="round"/>'
    + '<circle cx="150" cy="228" r="24" fill="none" stroke="#F1DCBB" stroke-width="13"/>'
    + '<circle cx="362" cy="228" r="24" fill="none" stroke="#F1DCBB" stroke-width="13"/>'
    + '<circle cx="210" cy="268" r="11" fill="#F1DCBB"/><circle cx="302" cy="268" r="11" fill="#F1DCBB"/>'
    + '<path d="M236 306 q20 -12 40 0" fill="none" stroke="#F1DCBB" stroke-width="11" stroke-linecap="round"/>'
    + '<path d="M104 366 q70 -18 140 0 t140 0" fill="none" stroke="#6ED3E8" stroke-width="9" stroke-linecap="round" opacity="0.7"/>'
    + '<path d="M138 402 q56 -14 112 0 t112 0" fill="none" stroke="#6ED3E8" stroke-width="6" stroke-linecap="round" opacity="0.4"/>'
  );
}
function g6() {
  return '<svg viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg">' + DEFS
    + '<rect width="512" height="512" fill="#F1E5D0"/>'
    + '<circle cx="256" cy="412" r="192" fill="#17495E"/>'
    + '<ellipse cx="256" cy="236" rx="136" ry="100" fill="#B98A5E"/>'
    + '<circle cx="140" cy="192" r="26" fill="#B98A5E"/><circle cx="372" cy="192" r="26" fill="#B98A5E"/>'
    + '<ellipse cx="256" cy="242" rx="120" ry="84" fill="none" stroke="#0B3543" stroke-width="9" opacity="0.85"/>'
    + '<circle cx="204" cy="234" r="12" fill="#0B3543"/><circle cx="308" cy="234" r="12" fill="#0B3543"/>'
    + '<ellipse cx="226" cy="292" rx="44" ry="30" fill="#F1E5D0"/><ellipse cx="286" cy="292" rx="44" ry="30" fill="#F1E5D0"/>'
    + '<path d="M242 276 q14 -10 28 0 q-5 17 -14 17 q-9 0 -14 -17 z" fill="#0B3543"/>'
    + '<path d="M108 366 q72 -16 144 0 t144 0" fill="none" stroke="#F1E5D0" stroke-width="8" stroke-linecap="round" opacity="0.75"/>'
    + '</svg>';
}
var TPL = '<svg viewBox="0 0 32 32" fill="#000" xmlns="http://www.w3.org/2000/svg"><ellipse cx="16" cy="14" rx="9.6" ry="6.4"/><circle cx="6.4" cy="9.6" r="2.4"/><circle cx="25.6" cy="9.6" r="2.4"/><rect x="3" y="23" width="26" height="3" rx="1.5"/></svg>';
var ICONS = [
  { l: "G1", name: "圆脸浮水", tag: "HEAD ABOVE WATER", svg: g1(), desc: "宽脸 + 侧小耳 + 水面 + 两只小爪子：全部是圆和弧，但比例按海獭来，不是熊。" },
  { l: "G2", name: "半圆出水", tag: "SEMICIRCLE", svg: g2(), desc: "头是半圆从水线里升起，耳朵贴在两侧。几何感最强，缩到 16px 只剩「圆 + 水线」。" },
  { l: "G3", name: "负空间海獭", tag: "NEGATIVE SPACE", svg: g3(), desc: "奶油底里挖出海獭剪影，脸用留白。不画五官也能认出，最像品牌图形。" },
  { l: "G4", name: "双圆重叠", tag: "TWO CIRCLES", svg: g4(), desc: "一个圆是头、一个圆是水，两个圆相交。三个圆加几个点，也能出「浮在水面」的感觉。" },
  { l: "G5", name: "极简线标", tag: "LINE MARK", svg: g5(), desc: "圆环里两段弧 + 两个点，勾出海獭的头和水线。最克制，适合做品牌标。" },
  { l: "G6", name: "几何拼贴", tag: "BAUHAUS", svg: g6(), desc: "米色底、棕色宽头、深蓝水，三个圆拼出海报感，偏品牌/包装。" }
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
