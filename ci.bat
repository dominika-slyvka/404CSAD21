@echo off
setlocal

call npm install
call node scripts/build.js
call npm test -- --runInBand
