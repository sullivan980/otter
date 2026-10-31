function ptsHead(cx, cy, rx, ry, seed, n, amp) {
  var pts = [];
  for (var i = 0; i < n; i++) {
    var a = i / n * Math.PI * 2;
    var k = 1
      + amp * Math.sin(a * 3 + seed)
      + amp * 0.6 * Math.sin(a * 7 + seed * 1.7)
      + ((i % 5 === 0) ? amp * 0.8 : 0);
    pts.push([cx + Math.cos(a) * rx * k, cy + Math.sin(a) * ry * k]);
  }
  return pts;
}
function path(pts) {
  return 'M' + pts.map(function (p) { return p[0].toFixed(1) + ' ' + p[1].toFixed(1); }).join(' L ') + ' Z';
}
function ellipsePts(cx, cy, rx, ry, n, start, end) {
  var pts = [];
  for (var i = 0; i <= n; i++) {
    var a = start + (end - start) * i / n;
    pts.push([cx + Math.cos(a) * rx, cy + Math.sin(a) * ry]);
  }
  return pts;
}
var FUR = ['#3B2719', '#4E3321', '#63452C', '#7A5738', '#8E6742'];
var FACE = ['#F6E6C6', '#FCF1D8', '#E7CCA0'];
var WATER = ['#0B3546', '#114B5F', '#186379', '#21798D'];

function build(opts) {
  var bg1 = opts.night ? '#0E4356' : '#16596B';
  var bg2 = opts.night ? '#071F29' : '#0A2E3B';
  var s = '<svg viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg"><defs>'
    + '<linearGradient id="bg' + opts.id + '" x1="0" y1="0" x2="0.7" y2="1"><stop offset="0" stop-color="' + bg1 + '"/><stop offset="0.6" stop-color="' + bg2 + '"/><stop offset="1" stop-color="#04161D"/></linearGradient>'
    + '<linearGradient id="wt' + opts.id + '" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="' + WATER[2] + '"/><stop offset="1" stop-color="' + WATER[0] + '"/></linearGradient>'
    + '</defs><rect width="512" height="512" fill="url(#bg' + opts.id + ')"/>'
    + '<ellipse cx="256" cy="268" rx="200" ry="170" fill="#6ED3E8" opacity="0.06"/>';

  // ---- 头（低多边形） ----
  var headPts = ptsHead(256, 232, 136, 104, 2.1, 34, 0.085);
  s += '<path d="' + path(headPts) + '" fill="' + FUR[2] + '"/>';
  // 切面：按光照方向给每两个相邻点组成三角形
  for (var i = 0; i < headPts.length - 1; i += 2) {
    var p0 = headPts[i], p1 = headPts[i + 1];
    var a = Math.atan2((p0[1] + p1[1]) / 2 - 232, (p0[0] + p1[0]) / 2 - 256);
    var b = Math.cos(a - 3.9);
    var tone = b > 0.35 ? FUR[4] : (b > -0.1 ? FUR[3] : (b > -0.5 ? FUR[2] : FUR[1]));
    s += '<polygon points="256,232 ' + p0[0].toFixed(1) + ',' + p0[1].toFixed(1) + ' ' + p1[0].toFixed(1) + ',' + p1[1].toFixed(1) + '" fill="' + tone + '" opacity="0.9"/>';
  }
  // 耳朵：两侧低位的三角
  s += '<polygon points="112,232 140,200 150,238" fill="' + FUR[1] + '"/><polygon points="146,214 132,208 140,232" fill="#2A1B11"/>';
  s += '<polygon points="400,232 372,200 362,238" fill="' + FUR[1] + '"/><polygon points="366,214 380,208 372,232" fill="#2A1B11"/>';
  // 头顶毛束（有方向的尖角）
  var tufts = [[150,150,196,168],[188,132,222,158],[232,122,252,154],[272,122,286,154],[312,132,330,160],[348,152,370,172]];
  tufts.forEach(function (t, k) {
    s += '<polygon points="' + t[0] + ',' + t[1] + ' ' + t[2] + ',' + t[3] + ' ' + (t[0]+t[2])/2 + ',' + (t[1]+46) + '" fill="' + (k % 2 ? FUR[3] : FUR[4]) + '" opacity="0.75"/>';
  });

  // ---- 脸（宽吻 + 分面） ----
  var faceOuter = ellipsePts(256, 306, 110, 70, 16, 0.05, Math.PI - 0.05).reverse().concat(ellipsePts(256, 306, 110, 70, 10, Math.PI, Math.PI * 2 - 0.02));
  // 简化：直接用两个半椭圆拼一个宽脸
  var facePts = [];
  facePts = facePts.concat(ellipsePts(256, 302, 108, 66, 14, 0, Math.PI)); // 下半
  facePts = facePts.concat(ellipsePts(256, 302, 108, 66, 14, Math.PI, Math.PI * 2).reverse());
  s += '<path d="' + path(facePts) + '" fill="' + FACE[0] + '"/>';
  s += '<polygon points="256,240 362,300 316,350 256,366" fill="' + FACE[2] + '" opacity="0.55"/>';
  s += '<polygon points="150,300 256,240 256,366 196,350" fill="' + FACE[1] + '" opacity="0.5"/>';

  // ---- 五官 ----
  s += '<ellipse cx="214" cy="274" rx="11" ry="12" fill="#101C22"/><ellipse cx="298" cy="274" rx="11" ry="12" fill="#101C22"/>'
    + '<circle cx="210" cy="270" r="3.2" fill="#FFFFFF" opacity="0.9"/><circle cx="294" cy="270" r="3.2" fill="#FFFFFF" opacity="0.9"/>'
    + '<path d="M240 306 q16 -12 32 0 q-6 20 -16 20 q-10 0 -16 -20 z" fill="#101C22"/>'
    + '<path d="M256 326 v10" stroke="#101C22" stroke-width="4" stroke-linecap="round"/>'
    + '<path d="M238 346 q18 12 36 0" stroke="#101C22" stroke-width="4" fill="none" stroke-linecap="round"/>';
  if (!opts.minimal) {
    s += '<g stroke="#C9A77A" stroke-width="3" fill="none" stroke-linecap="round" opacity="0.65">'
      + '<path d="M186 300 q-38 -6 -58 -18"/><path d="M186 312 q-40 2 -62 0"/><path d="M186 324 q-36 10 -56 20"/>'
      + '<path d="M326 300 q38 -6 58 -18"/><path d="M326 312 q40 2 62 0"/><path d="M326 324 q36 10 56 20"/>'
      + '</g>';
  }

  // ---- 湿毛高光 ----
  s += '<polygon points="176,214 226,186 246,214 206,236" fill="#A9855C" opacity="0.35"/>'
    + '<polygon points="300,186 350,208 322,232 288,210" fill="#A9855C" opacity="0.25"/>';

  // ---- 水 ----
  s += '<path d="M0 366 L64 352 L128 366 L192 350 L256 364 L320 350 L384 366 L448 352 L512 366 V512 H0 Z" fill="url(#wt' + opts.id + ')"/>'
    + '<path d="M0 402 L72 390 L144 404 L216 388 L288 404 L360 388 L432 402 L512 390 V512 H0 Z" fill="' + WATER[1] + '" opacity="0.85"/>'
    + '<path d="M0 446 L80 436 L160 448 L240 434 L320 448 L400 436 L512 446 V512 H0 Z" fill="' + WATER[0] + '"/>'
    + '<g stroke="#8FE3F2" stroke-width="5" fill="none" stroke-linecap="round" opacity="0.45">'
    + '<path d="M96 392 q56 -14 112 0 t112 0 t96 0"/>'
    + '<path d="M136 428 q48 -10 96 0 t96 0"/>'
    + '</g>';

  // ---- 可选细节：爪子 + 水珠 ----
  if (!opts.minimal) {
    s += '<polygon points="150,372 196,360 208,384 162,396" fill="' + FACE[1] + '"/>'
      + '<polygon points="162,374 194,366 200,382 170,390" fill="' + FACE[2] + '" opacity="0.6"/>'
      + '<polygon points="362,372 316,360 304,384 350,396" fill="' + FACE[1] + '"/>'
      + '<polygon points="350,374 318,366 312,382 342,390" fill="' + FACE[2] + '" opacity="0.6"/>'
      + '<path d="M238 372 q6 10 0 18 q-6 -8 0 -18 z" fill="#BFEFF8" opacity="0.8"/>'
      + '<path d="M300 384 q5 8 0 14 q-5 -6 0 -14 z" fill="#BFEFF8" opacity="0.6"/>';
  }
  s += '</svg>';
  return s;
}

var ICONS = [
  { l: "V1", name: "基础版", tag: "LOW-POLY", svg: build({ id: 'a', minimal: true }), desc: "只留头、脸、水线：毛束方向和分面先做对，细节最少，16px 最稳。" },
  { l: "V2", name: "加爪子水珠", tag: "LOW-POLY +", svg: build({ id: 'b', minimal: false }), desc: "加了两只搭在水面的小爪子和下巴水珠，更完整，也更像照片里的姿态。" },
  { l: "V3", name: "深色高对比", tag: "NIGHT", svg: build({ id: 'c', minimal: false, night: true }), desc: "背景压深、脸提亮，和高对比度的 Dock 环境更搭。" }
];

var TPL = '<svg viewBox="0 0 32 32" fill="#000" xmlns="http://www.w3.org/2000/svg"><polygon points="16,6 21,9 25,7 27,12 25,16 27,20 22,22 20,26 16,24 12,26 10,22 5,20 7,16 5,12 7,7 11,9"/></svg>';
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
