const fs = require('fs');
const path = require('path');

const projectRoot = path.join(__dirname, '..');
const srcFile = path.join(projectRoot, 'src', 'hello.js');
const distDir = path.join(projectRoot, 'dist');
const outFile = path.join(distDir, 'hello.js');

fs.mkdirSync(distDir, { recursive: true });
const content = fs.readFileSync(srcFile, 'utf8');
fs.writeFileSync(outFile, content, 'utf8');
