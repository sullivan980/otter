var C = {
  ink: '#171717',
  ochre: '#C99A4E',
  ochreL: '#DBB36E',
  cream: '#F2E4C6',
  creamL: '#FAF1DC',
  blue: '#5E82A6',
  blueL: '#8FAFC6',
  deep: '#35597A',
  coral: '#D96A4A'
};
function ears() {
  return '<polygon points="150,284 134,262 166,270" fill="' + C.ochre + '" stroke="' + C.ink + '" stroke-width="6"/>'
    + '<polygon points="362,284 378,262 346,270" fill="' + C.ochre + '" stroke="' + C.ink + '" stroke-width="6"/>'
    + '<polygon points="150,280 144,268 160,272" fill="' + C.ink + '" opacity="0.6"/>'
    + '<polygon points="362,280 368,268 352,272" fill="' + C.ink + '" opacity="0.6"/>';
}
function water() {
  return '<polygon points="0,372 96,358 192,374 288,360 384,376 512,362 512,512 0,512" fill="' + C.deep + '" stroke="' + C.ink + '" stroke-width="6"/>'
    + '<polygon points="0,420 110,408 220,424 330,410 440,426 512,414 512,512 0,512" fill="#2A4A66"/>'
    + '<polygon points="0,462 120,452 240,466 360,454 480,468 512,460 512,512 0,512" fill="#1F3A52"/>'
    + '<g stroke="' + C.blueL + '" stroke-width="6" fill="none" stroke-linecap="round" opacity="0.7"><path d="M70 398 q60 -14 120 0 t120 0 t120 0"/></g>';
}
function headFront() {
  return '<polygon points="148,302 160,260 202,230 256,220 310,230 352,260 364,302 352,338 300,362 212,360 160,334" fill="' + C.ochre + '" stroke="' + C.ink + '" stroke-width="7" stroke-linejoin="round"/>'
    + '<polygon points="202,230 310,230 300,274 212,276" fill="' + C.ochreL + '" stroke="' + C.ink + '" stroke-width="7"/>'
    + '<polygon points="160,260 212,276 212,360 160,334" fill="' + C.cream + '" stroke="' + C.ink + '" stroke-width="7"/>'
    + '<polygon points="310,230 352,260 364,302 352,338 300,362 300,274" fill="' + C.blue + '" stroke="' + C.ink + '" stroke-width="7"/>'
    + '<polygon points="190,300 322,298 314,346 198,344" fill="' + C.creamL + '" stroke="' + C.ink + '" stroke-width="7"/>'
    + '<polygon points="212,276 300,274 296,300 216,302" fill="' + C.ochreL + '" stroke="' + C.ink + '" stroke-width="7" opacity="0.85"/>'
    + '<circle cx="208" cy="288" r="9" fill="' + C.creamL + '" stroke="' + C.ink + '" stroke-width="5"/>'
    + '<circle cx="208" cy="290" r="4.5" fill="' + C.ink + '"/>'
    + '<polygon points="296,278 318,284 306,300" fill="' + C.creamL + '" stroke="' + C.ink + '" stroke-width="5"/>'
    + '<circle cx="306" cy="288" r="4.5" fill="' + C.ink + '"/>'
    + '<polygon points="244,318 268,318 256,334" fill="' + C.ink + '"/>'
    + '<path d="M256 334 v12" stroke="' + C.ink + '" stroke-width="5" stroke-linecap="round"/>'
    + '<g stroke="' + C.ink + '" stroke-width="4" stroke-linecap="round">'
    + '<path d="M194 316 L142 304"/><path d="M194 328 L138 326"/><path d="M194 340 L144 352"/>'
    + '<path d="M318 314 L370 302"/><path d="M318 326 L374 324"/><path d="M318 338 L368 350"/>'
    + '</g>'
    + '<polygon points="236,240 274,238 268,256 242,258" fill="' + C.ochreL + '" opacity="0.5"/>'
    + '<polygon points="282,240 304,244 298,260 278,258" fill="#8A6A3E" opacity="0.35"/>';
}
function v1() {
  return '<svg viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg"><rect width="512" height="512" fill="' + C.cream + '"/>'
    + '<polygon points="0,0 512,0 512,150 300,96 0,180" fill="' + C.blueL + '" opacity="0.55"/>'
    + '<polygon points="0,0 220,0 120,120 0,150" fill="' + C.ochreL + '" opacity="0.5"/>'
    + water()
    + '<polygon points="196,368 316,368 286,440 226,440" fill="#1B3348" opacity="0.35"/>'
    + headFront()
    + '<ellipse cx="256" cy="386" rx="112" ry="13" fill="' + C.creamL + '" opacity="0.3"/>'
    + '</svg>';
}
function v2() {
  return '<svg viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg"><rect width="512" height="512" fill="' + C.cream + '"/>'
    + '<polygon points="0,0 512,0 512,190 260,120 0,210" fill="' + C.blueL + '" opacity="0.5"/>'
    + water()
    + '<polygon points="150,306 170,250 224,224 292,220 340,244 366,272 372,300 352,320 322,326 292,344 230,352 180,340" fill="' + C.ochre + '" stroke="' + C.ink + '" stroke-width="7" stroke-linejoin="round"/>'
    + '<polygon points="170,250 150,306 180,340 230,352 224,224" fill="' + C.blue + '" stroke="' + C.ink + '" stroke-width="7"/>'
    + '<polygon points="224,224 292,220 300,272 232,278" fill="' + C.ochreL + '" stroke="' + C.ink + '" stroke-width="7"/>'
    + '<polygon points="340,296 402,288 408,320 344,328" fill="' + C.creamL + '" stroke="' + C.ink + '" stroke-width="7"/>'
    + '<polygon points="392,300 408,296 406,320 388,320" fill="' + C.ink + '"/>'
    + '<circle cx="244" cy="284" r="11" fill="' + C.creamL + '" stroke="' + C.ink + '" stroke-width="5"/>'
    + '<circle cx="244" cy="286" r="5" fill="' + C.ink + '"/>'
    + '<polygon points="292,266 314,272 302,288" fill="' + C.ink + '"/>'
    + '<polygon points="152,284 138,264 168,272" fill="' + C.ochre + '" stroke="' + C.ink + '" stroke-width="6"/>'
    + '<g stroke="' + C.ink + '" stroke-width="4" stroke-linecap="round"><path d="M352 304 L306 302"/><path d="M354 314 L310 318"/></g>'
    + '<ellipse cx="258" cy="392" rx="118" ry="13" fill="' + C.creamL + '" opacity="0.28"/>'
    + '</svg>';
}
function v3() {
  return '<svg viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg"><rect width="512" height="512" fill="' + C.cream + '"/>'
    + '<polygon points="0,0 512,0 512,150 300,96 0,180" fill="' + C.blueL + '" opacity="0.55"/>'
    + '<polygon points="0,0 220,0 120,120 0,150" fill="' + C.ochreL + '" opacity="0.5"/>'
    + water()
    + '<polygon points="196,368 316,368 286,440 226,440" fill="#1B3348" opacity="0.35"/>'
    + headFront()
    + '<polygon points="132,386 190,372 202,400 148,414" fill="' + C.creamL + '" stroke="' + C.ink + '" stroke-width="6"/>'
    + '<polygon points="380,386 322,372 310,400 364,414" fill="' + C.creamL + '" stroke="' + C.ink + '" stroke-width="6"/>'
    + '<g stroke="' + C.ink + '" stroke-width="6">'
    + '<polygon points="356,442 420,424 466,442 420,462" fill="' + C.coral + '"/>'
    + '<polygon points="466,442 496,426 490,442 496,458" fill="' + C.coral + '"/>'
    + '</g><circle cx="428" cy="438" r="4" fill="' + C.ink + '"/>'
    + '</svg>';
}
var ICONS = [
  { l: "C1", name: "正面 · 宽脸浮水", tag: "CUBIST FRONT", svg: v1(), desc: "去掉放射毛和高竖的耳朵：耳朵改成两侧低位小三角，脸更宽、吻部横贯，配胡须和水线。" },
  { l: "C2", name: "半侧面 · 吻部前伸", tag: "CUBIST PROFILE", svg: v2(), desc: "3/4 侧面，吻部缩短、不再像狗；一只眼 + 侧面轮廓 + 水线。" },
  { l: "C3", name: "正面 · 抱鱼", tag: "CUBIST + FISH", svg: v3(), desc: "C1 加两只搭水的爪子和一条珊瑚色鱼。" }
];
var TPL = '<svg viewBox="0 0 32 32" fill="#000" xmlns="http://www.w3.org/2000/svg"><ellipse cx="16" cy="15" rx="9.6" ry="6.6"/><circle cx="6.6" cy="10.6" r="2.4"/><circle cx="25.4" cy="10.6" r="2.4"/><rect x="3" y="24" width="26" height="3" rx="1.5"/></svg>';
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