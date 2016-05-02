#!/usr/bin/env node
'use strict';
const fs   = require('fs');
const path = require('path');
const _    = require('lodash');

const AviGlitch = require('../lib/aviglitch');

let output = 'out.avi';
let all    = false;
let fake   = false;

// Parse options.
const command = require('commander');
command
  .usage('[options] <file ...>')
  .version('0.0.0')
  .option(
    '-o, --output [OUTPUT]', 'output the video to OUTPUT (./out.avi by default)',
    (val) => { output = val; }
  )
  .option(
    '-a, --all', 'remove all keyframes (It remains a first keyframe by default)',
    () => { all = true; }
  )
  .option(
    '-f, --fake', 'remains all keyframes as full pixel included deltaframe',
    () => {
      if (all) {
        console.error("The --fake option cannot use with -a/--all option.\n");
        process.exit(-1);
      }
      fake = true;
    }
  )
  .parse(process.argv);

// Check the input files.
var input = command.args;
if (input.length < 1) {
  command.help();
  process.exit();
}
input.forEach((file) => {
  if (!fs.existsSync(file) || fs.lstatSync(file).isDirectory()) {
    console.error(`${file}: No such file.\n`);
    process.exit(1);
  }
});

// Open the first input file.
const a = AviGlitch.open(input.shift());

// Glitch the frames.
if (!fake) {
  let frames = 0;
  a.glitch_with_index('keyframe', (frame, i) => {
    frames++;
    if ((!all) && i === 0) {
      return frame.data;
    }
    else {
      return new Buffer(0);
    }
  });
}

// Avoid glitching the first keyframe.
if (!(all || fake)) {
  a.mutate_keyframes_into_deltaframes(_.range(1, a.frames.length()));
}
else {
  a.mutate_keyframes_into_deltaframes();
}

// Process the rest of input files.
input.forEach((file) => {
  const b = AviGlitch.open(file);
  if (!fake) {
    b.glitch('keyframe', () => new Buffer(0));
  }
  b.mutate_keyframes_into_deltaframes();
  a.frames.concat(b.frames);
});

// Output the result.
var dst = path.resolve(__dirname, '..', output);

a.output(dst, null, () => {
  a.closeSync();
  return process.exit();
});
