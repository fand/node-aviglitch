#!/usr/bin/env node

'use strict';
var fs = require('fs');
var path = require('path');

var AviGlitch = require('../lib/aviglitch');

var output = 'out.avi';
var all = false;
var fake = false;


// Parse options.
var command = require('commander');
command
  .usage('[options] <file ...>')
  .version('0.0.0')
  .option(
    '-o, --output [OUTPUT]', 'output the video to OUTPUT (./out.avi by default)',
    function(val) {
      output = val;
    })
  .option(
    '-a, --all', 'remove all keyframes (It remains a first keyframe by default)',
    function() {
      all = true;
    })
  .option(
    '-f, --fake', 'remains all keyframes as full pixel included deltaframe',
    function() {
      if (all) {
        console.error("The --fake option cannot use with -a/--all option.\n");
        process.exit(-1);
      }
      fake = true;
    })
  .parse(process.argv);


// Check the input files.
var input = command.args;
if (input.length < 1) {
  command.help();
  process.exit();
}
for (var i = 0; i < input.length; i++) {
  var file = input[i];
  if (!fs.existsSync(file) || fs.lstatSync(file).isDirectory()) {
    console.error("" + file + ": No such file.\n\n");
    process.exit(1);
  }
}


// Open the first input file.
var a = AviGlitch.open(input.shift());


// Glitch the frames.
if (!fake) {
  var frames = 0;
  a.glitch_with_index('keyframe', function(frame, i) {
    frames++;
    if ((!all) && i === 0) {
      return frame.data;
    } else {
      return new Buffer(0);
    }
  });
}


// Avoid glitching the first keyframe.
if (!(all || fake)) {
  var range = [];
  for (i = 1; i < a.frames.length(); i++) {
    range.push(i);
  }
  a.mutate_keyframes_into_deltaframes(range);
} else {
  a.mutate_keyframes_into_deltaframes();
}


// Process the rest of input files.
for (i = 0; i < input.length; i++) {
  file = input[i];
  var b = AviGlitch.open(file);
  if (!fake) {
    b.glitch('keyframe', function() {
      return new Buffer(0);
    });
  }
  b.mutate_keyframes_into_deltaframes();
  a.frames.concat(b.frames);
}


// Output the result.
var dst = path.resolve(__dirname, '..', output);
a.output(dst, null, function() {
  return process.exit();
});
