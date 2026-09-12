const fs = require('fs');
let t = fs.readFileSync('C:\\Users\\fedes\\Desktop\\try_to_deobf.txt', 'utf8');
t = t.replace(/0[xX][0-9a-fA-F]+|0[bB][01]+/g, (m) => {
  if (/^0[xX]/.test(m)) return m;
  return String(parseInt(m.slice(2), 2));
});
const suffix = ':N(...)';
if (!t.endsWith(suffix)) throw new Error('unexpected tail: ' + t.slice(-40));
t = t.slice(0, -suffix.length);
// original starts with "return(" ... ")" - strip leading return( and trailing )
t = t.trim();
if (!t.startsWith('return(')) throw new Error('unexpected head: ' + t.slice(0, 40));
t = t.slice('return('.length);
if (t.endsWith(')')) t = t.slice(0, -1);
fs.writeFileSync('target_table.lua', 'TBL = ' + t + '\nreturn TBL');
console.log('wrote target_table.lua, len', t.length);
