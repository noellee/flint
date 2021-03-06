#!/usr/bin/env node

const nj = require('nunjucks');
const env = new nj.Environment();
const fs = require('fs');
const path = require('path');
const mkdirp = require('mkdirp');

env.addFilter('camelCase', str => str.charAt(0).toLowerCase() + str.substr(1));

for (const source of [
  'AST/ASTPass/ASTPass'
]) {
  let sourcePath = `Sources/${source}.template.swift`;
  let resultPath = `Sources/${source}.generated.swift`;
  let sourceTime = fs.statSync(sourcePath).mtimeMs;
  let resultTime = fs.existsSync(resultPath) ? fs.statSync(resultPath).mtimeMs : 0;
  if (sourceTime <= resultTime) {
    console.log(`Skipping ${source}.generated.swift`);
    continue;
  }
  console.log(`Processing ${source}.generated.swift ...`);
  fs.writeFileSync(
    resultPath,
    env.renderString(
      fs.readFileSync(sourcePath, 'utf8')
    )
  );
}
