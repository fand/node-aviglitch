const assert = require('assert');
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

const FILES_DIR  = path.join(__dirname, 'files');
const OUTPUT_DIR = path.join(FILES_DIR, 'output');
const TMP_DIR    = 'tmp';

const AviGlitch = require('../lib/aviglitch');
const Base      = require('../lib/base');

describe('datamosh cli', () => {
  let src, dst, total;

  before(() => {
    if (!fs.existsSync(OUTPUT_DIR)) { fs.mkdirSync(OUTPUT_DIR); }
    if (!fs.existsSync(TMP_DIR)) { fs.mkdirSync(TMP_DIR); }
    src = path.join(FILES_DIR, 'sample.avi');
    dst = path.join(OUTPUT_DIR, 'out.avi');
  });

  beforeEach((done) => {
    const a = AviGlitch.open(src);
    let keys = 0;
    a.frames.each((f) => {
      if (f.is_keyframe) { keys++; }
    });
    total = a.frames.length();
    a.close(done);
  });

  afterEach((done) => {
    fs.readdir(OUTPUT_DIR, (err, files) => {
      if (err) { throw err; }
      files.forEach(f => fs.unlinkSync(path.join(OUTPUT_DIR, f)));
      done();
    });
  });

  after((done) => {
    fs.rmdirSync(OUTPUT_DIR);
    fs.readdir(TMP_DIR, (err, files) => {
      if (err) { throw err; }
      files.forEach(f => fs.unlinkSync(path.join(TMP_DIR, f)));
      fs.rmdirSync(TMP_DIR);
      done();
    });
  });

  it('should work correctly without options', (done) => {
    const d1  = spawn('node', ['bin/datamosh.js', src, '-o', dst]);
    d1.stdout.pipe(process.stdout);
    d1.stderr.pipe(process.stderr);
    d1.on('exit', () => {
      const o = AviGlitch.open(dst);
      assert.equal(o.frames.length(), total);
      assert(o.frames.first().is_keyframe);
      assert(o.has_keyframe);
      o.close();
      assert(Base.surely_formatted(dst, true));
      done();
    });
  });

  it('should work correctly w/ --all', (done) => {
    const d2  = spawn('node', ['bin/datamosh.js', src, '-o', dst, '-a']);
    d2.stderr.pipe(process.stderr);
    d2.on('exit', () => {
      const o = AviGlitch.open(dst);
      assert.equal(o.frames.length(), total);
      assert(!o.frames.first().is_keyframe);
      assert(!o.has_keyframe);
      o.close();
      assert(Base.surely_formatted(dst, true));
      done();
    });
  });

  it('should concat frames w/ multiple input files', (done) => {
    const d3  = spawn('node', ['bin/datamosh.js', '-o', dst, src, src, src]);
    d3.stderr.pipe(process.stderr);
    d3.on('exit', () => {
      const o = AviGlitch.open(dst);
      assert.equal(o.frames.length(), total * 3);
      assert(o.frames.first().is_keyframe);
      o.close();
      assert(Base.surely_formatted(dst, true));
      done();
    });
  });

  it('should not glitch the video w/ --fake', (done) => {
    const d4  = spawn('node', ['bin/datamosh.js', '-o', dst, src, '--fake']);
    d4.stderr.pipe(process.stderr);
    d4.on('exit', () => {
      const o = AviGlitch.open(dst);
      assert(!o.has_keyframe);
      o.close();
      done();
    });
  });

});
