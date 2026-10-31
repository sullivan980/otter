function ripples(color, y, op) {
  return '<g stroke="' + color + '" fill="none" stroke-linecap="round" opacity="' + op + '">'
    + '<path d="M52 ' + y + ' q50 -18 100 0 t100 0 t100 0 t108 0" stroke-width="12"/>'
    + '<path d="M92 ' + (y + 32) + ' q44 -14 88 0 t88 0 t88 0 t80 0" stroke-width="8" opacity="0.55"/>'
    + '</g>';
}
function fish(cx, cy, s, color) {
  return '<g transform="translate(' + cx + ' ' + cy + ') scale(' + s + ')">'
    + '<ellipse cx="0" cy="0" rx="36" ry="19" fill="' + color + '"/>'
    + '<path d="M-30 0 L-56 -16 L-50 0 L-56 16 Z" fill="' + color + '"/>'
    + '<circle cx="21" cy="-4" r="3.6" fill="#12303A"/>'
    + '</g>';
}
function otterHead(cx, cy, r, fur, earIn, eye) {
  return '<g>'
    + '<circle cx="' + (cx - r * 0.62) + '" cy="' + (cy - r * 0.72) + '" r="' + (r * 0.34) + '" fill="' + fur + '"/>'
    + '<circle cx="' + (cx + r * 0.62) + '" cy="' + (cy - r * 0.72) + '" r="' + (r * 0.34) + '" fill="' + fur + '"/>'
    + '<circle cx="' + (cx - r * 0.62) + '" cy="' + (cy - r * 0.72) + '" r="' + (r * 0.16) + '" fill="' + earIn + '"/>'
    + '<circle cx="' + (cx + r * 0.62) + '" cy="' + (cy - r * 0.72) + '" r="' + (r * 0.16) + '" fill="' + earIn + '"/>'
    + '<ellipse cx="' + cx + '" cy="' + cy + '" rx="' + r + '" ry="' + (r * 0.92) + '" fill="' + fur + '"/>'
    + '<ellipse cx="' + cx + '" cy="' + (cy + r * 0.30) + '" rx="' + (r * 0.52) + '" ry="' + (r * 0.36) + '" fill="#FBF0DC"/>'
    + '<circle cx="' + (cx - r * 0.30) + '" cy="' + (cy - r * 0.10) + '" r="' + (r * 0.09) + '" fill="' + eye + '"/>'
    + '<circle cx="' + (cx + r * 0.30) + '" cy="' + (cy - r * 0.10) + '" r="' + (r * 0.09) + '" fill="' + eye + '"/>'
    + '<path d="M' + (cx - r * 0.12) + ' ' + (cy + r * 0.24) + ' q' + (r * 0.12) + ' -' + (r * 0.10) + ' ' + (r * 0.24) + ' 0 q-' + (r * 0.12) + ' ' + (r * 0.10) + ' -' + (r * 0.24) + ' 0" fill="' + eye + '"/>'
    + '</g>';
}
function iconA() {
  return '<svg viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg"><defs>'
    + '<linearGradient id="aBg" x1="0" y1="0" x2="0.8" y2="1"><stop offset="0" stop-color="#176070"/><stop offset="0.6" stop-color="#0B3A48"/><stop offset="1" stop-color="#06232C"/></linearGradient>'
    + '</defs><rect width="512" height="512" fill="url(#aBg)"/>'
    + '<circle cx="110" cy="86" r="86" fill="#6ED3E8" opacity="0.12"/><circle cx="430" cy="130" r="110" fill="#2E7D8F" opacity="0.16"/>'
    + '<path d="M0 372 q64 -26 128 0 t128 0 t128 0 t128 0 V512 H0 Z" fill="#0A3340"/>'
    + '<path d="M150 322 q-54 2 -78 28 q-16 20 4 28 q18 6 34 -10 q16 -14 36 -18 z" fill="#E7CAA0"/>'
    + '<ellipse cx="252" cy="330" rx="118" ry="58" fill="#EED6B0"/>'
    + '<ellipse cx="244" cy="338" rx="86" ry="34" fill="#F9E9CC"/>'
    + '<ellipse cx="214" cy="286" rx="26" ry="15" fill="#E0C298" transform="rotate(18 214 286)"/>'
    + '<ellipse cx="286" cy="282" rx="26" ry="15" fill="#E0C298" transform="rotate(-18 286 282)"/>'
    + fish(250, 240, 1.0, "#F2A65A")
    + otterHead(356, 302, 54, "#EED6B0", "#C99C6B", "#22333A")
    + ripples("#7FE3F2", 406, "0.8")
    + '<circle cx="120" cy="330" r="9" fill="#9FE7F1" opacity="0.55"/><circle cx="152" cy="300" r="5" fill="#9FE7F1" opacity="0.5"/><circle cx="404" cy="330" r="7" fill="#9FE7F1" opacity="0.45"/>'
    + '</svg>';
}
function iconB() {
  return '<svg viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg"><defs>'
    + '<linearGradient id="bBg" x1="0" y1="0" x2="0.7" y2="1"><stop offset="0" stop-color="#FFF7EC"/><stop offset="0.55" stop-color="#F7E6D0"/><stop offset="1" stop-color="#EFD3B1"/></linearGradient>'
    + '</defs><rect width="512" height="512" fill="url(#bBg)"/>'
    + '<circle cx="96" cy="110" r="52" fill="#FFFFFF" opacity="0.7"/><circle cx="420" cy="176" r="66" fill="#FFFFFF" opacity="0.55"/><circle cx="150" cy="70" r="18" fill="#FFFFFF" opacity="0.6"/>'
    + '<rect x="64" y="356" width="384" height="104" rx="42" fill="#FBF4E8"/>'
    + '<rect x="84" y="368" width="344" height="76" rx="34" fill="#9FD6E2"/>'
    + '<ellipse cx="256" cy="372" rx="172" ry="16" fill="#BDE7EF"/>'
    + '<path d="M256 250 c-62 0 -104 52 -104 112 c0 60 46 92 104 92 s104 -32 104 -92 c0 -60 -42 -112 -104 -112z" fill="#8C5B3C"/>'
    + '<ellipse cx="256" cy="360" rx="66" ry="86" fill="#C99468"/>'
    + '<circle cx="256" cy="222" r="66" fill="#8C5B3C"/>'
    + '<circle cx="206" cy="176" r="22" fill="#8C5B3C"/><circle cx="306" cy="176" r="22" fill="#8C5B3C"/>'
    + '<circle cx="206" cy="176" r="10" fill="#5F3824"/><circle cx="306" cy="176" r="10" fill="#5F3824"/>'
    + '<ellipse cx="256" cy="250" rx="38" ry="27" fill="#F7E4CC"/>'
    + '<path d="M222 214 q10 -10 20 0" stroke="#2B1C12" stroke-width="6" fill="none" stroke-linecap="round"/>'
    + '<path d="M270 214 q10 -10 20 0" stroke="#2B1C12" stroke-width="6" fill="none" stroke-linecap="round"/>'
    + '<path d="M246 236 q10 8 20 0" stroke="#2B1C12" stroke-width="5" fill="none" stroke-linecap="round"/>'
    + '<ellipse cx="256" cy="238" rx="9" ry="7" fill="#2B1C12"/>'
    + '<rect x="196" y="160" width="120" height="18" rx="9" fill="#FFF8EC" transform="rotate(-4 256 169)"/>'
    + '<g transform="rotate(-16 330 330)"><rect x="296" y="306" width="70" height="48" rx="14" fill="#F2C94C"/><rect x="304" y="314" width="54" height="32" rx="10" fill="#F8DC8A"/></g>'
    + '<circle cx="368" cy="292" r="16" fill="#FFFFFF" opacity="0.85"/><circle cx="394" cy="318" r="11" fill="#FFFFFF" opacity="0.8"/><circle cx="374" cy="342" r="7" fill="#FFFFFF" opacity="0.75"/><circle cx="150" cy="286" r="10" fill="#FFFFFF" opacity="0.8"/><circle cx="176" cy="262" r="6" fill="#FFFFFF" opacity="0.7"/>'
    + '<circle cx="416" cy="256" r="20" fill="#FFFFFF" opacity="0.55"/><circle cx="446" cy="230" r="10" fill="#FFFFFF" opacity="0.5"/>'
    + '</svg>';
}
