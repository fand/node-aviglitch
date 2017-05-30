#!/usr/bin/env node
const fs = require('fs');
const path = require('path');
const _ = require('lodash');

// eslint-disable-next-line
const logger = require('eazy-logger').Logger({
  useLevelPrefixes: true,
});
process.on('uncaughtException', (error) => {
  logger.error(error);
  process.exit(-1);
});

const AviGlitch = require('../lib/aviglitch');

// Parse options.
const meow = require('meow');
const cli = meow(`
	Usage
	  $ datamosh <input>

	Options
	  --output, -o  Specify output path. (Default: out.avi)
    --all, -a     Remove all keyframes. It remains a first keyframe by default.
    --fake, -f    Remains all keyframes as full pixel included deltaframe.
	Examples
	  $ datamosh input.avi -o out.avi
`, {
  alias: {
    a: 'all',
    f: 'fake',
    o: 'output',
  },
});

const output = cli.flags.output || 'out.avi';
const all    = cli.flags.all;
const fake   = cli.flags.fake;

if (fake && all) {
  logger.error('--fake cannot be used with --all');
  process.exit(-1);
}

// Check the input files.
cli.input.forEach((file) => {
  if (!fs.existsSync(file) || fs.lstatSync(file).isDirectory()) {
    logger.error(`File not found: ${file}`);
    process.exit(-1);
  }
});

// Open the first input file.
const a = (() => {
  try {
    return AviGlitch.open(cli.input.shift());
  }
  catch (e) {
    logger.error(e);
    process.exit(-1);
  }
})();

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
cli.input.forEach((file) => {
  const b = AviGlitch.open(file);
  if (!fake) {
    b.glitch('keyframe', () => new Buffer(0));
  }
  b.mutate_keyframes_into_deltaframes();
  a.frames.concat(b.frames);
});

// Output the result.
var dst = path.resolve(process.cwd(), output);
logger.info(`Writing to file: ${dst}`);
a.output(dst, null, () => {
  a.closeSync();
  logger.info('Complete!');
  process.exit(0);
});
