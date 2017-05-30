import assert from 'assert';
import fs     from 'fs';
import path   from 'path';
import _      from 'lodash';

const FILES_DIR  = path.join(__dirname, 'files');
const OUTPUT_DIR = path.join(FILES_DIR, 'output');

import AviGlitch from '../lib/aviglitch';
import Base      from '../lib/base';

describe('AviGlitch', () => {
  let src, dst;

  before(() => {
    if (!fs.existsSync(OUTPUT_DIR)) { fs.mkdirSync(OUTPUT_DIR); }
    src = path.join(FILES_DIR, 'sample.avi');
    dst = path.join(OUTPUT_DIR, 'out.avi');
  });

  afterEach((done) => {
    fs.readdir(OUTPUT_DIR, (err, files) => {
      if (err) { throw err; }
      files.forEach(f => fs.unlinkSync(path.join(OUTPUT_DIR, f)));
      done();
    });
  });

  after(() => {
    fs.rmdirSync(OUTPUT_DIR);
  });

  it('should raise an error against unsupported files', () => {
    assert.throws(() => { AviGlitch.open(__filename); });
  });

  it('should return AviGlitch::Base object through the method #open', () => {
    const avi = AviGlitch.open(src);
    assert(avi instanceof Base);
  });

  it('should save the same file when nothing is changed', () => {
    const avi = AviGlitch.open(src);
    avi.glitch(d => d);
    avi.output(dst);

    const f_in  = fs.readFileSync(src);
    const f_out = fs.readFileSync(dst);
    assert(f_in, 'in file exists');
    assert(f_out, 'out file exists');
    assert.deepEqual(f_in, f_out, 'nothing changed');
  });

  it('can glitch each keyframe', () => {
    const avi = AviGlitch.open(src);
    let n = 0;
    avi.glitch('keyframe', (kf) => {
      n++;
      return kf.slice(10);
    });

    avi.output(dst);
    const i_size = fs.statSync(src).size;
    const o_size = fs.statSync(dst).size;
    assert.equal(o_size, i_size - (10 * n));
    assert(Base.surely_formatted(dst, true));
  });

  it('can glitch each keyframe with index', () => {
    const avi = AviGlitch.open(src);

    let a_size = 0;
    avi.glitch('keyframe', (f) => {
      a_size++;
      return f;
    });

    let b_size = 0;
    avi.glitch_with_index('keyframe', (kf, idx) => {
      b_size++;
      if (idx < 25) {
        return kf.slice(10);
      }
      else {
        return kf;
      }
    });

    assert.equal(a_size, b_size);

    avi.output(dst);
    const i_size = fs.statSync(src).size;
    const o_size = fs.statSync(dst).size;
    assert.equal(o_size, i_size - (10 * 25));
    assert(Base.surely_formatted(dst, true));
  });

  it('should have some alias methods', () => {
    assert.doesNotThrow(() => {
      const avi = AviGlitch.open(src);
      avi.write(dst);
    });
    assert(Base.surely_formatted(dst, true));
  });

  it('can glitch with :*frames instead of :*frame', () => {
    const avi = AviGlitch.open(src);
    let count = 0;
    avi.glitch('keyframes', (kf) => {
      count++;
      return kf;
    });

    avi.close();
    assert(count > 0);
  });

  it('should close file when output', (done) => {
    const avi = AviGlitch.open(src);
    avi.output(dst, true, () => {
      assert.throws(() => {
        avi.glitch(f => f);
      }, Error);
      done();
    });
  });

  it('can explicit close file', (done) => {
    const avi = AviGlitch.open(src);
    avi.close(() => {
      assert.throws(() => {
        avi.glitch(f => f);
      }, Error);
      done();
    });
  });

  it('should offer one liner style coding', () => {
    assert.doesNotThrow(() => {
      AviGlitch.open(src).glitch('keyframe', (d) => {
        const buf = new Buffer(d.length);
        buf.fill('0');
        return buf;
      }).output(dst);
    });
    assert(Base.surely_formatted(dst, true));
  });

  it('should not raise error in multiple glitches', () => {
    assert.doesNotThrow(() => {
      const avi = AviGlitch.open(src);
      avi.glitch('keyframe', (d) => {
        d.data = new Buffer(d.toString('ascii').replace(/\d/, ''));
      });
      avi.glitch('keyframe', () => null);
      avi.glitch('audioframe', d => Buffer.concat([d, d]));
      avi.output(dst);
    });
    assert(Base.surely_formatted(dst, true));
  });

  it('can work with another frames instance', (done) => {
    const tmp = `${dst}x.avi`;
    const a = AviGlitch.open(src);
    a.glitch('keyframe', () => null);
    a.output(tmp, false);
    const b = AviGlitch.open(src);
    const c = AviGlitch.open(src);
    b.frames = c.frames;
    b.output(dst, false);

    assert(Base.surely_formatted(dst, true));
    a.close(() => b.close(() => c.close(() => fs.unlink(tmp, done))));
  });

  it('should mutate keyframes into deltaframes', () => {
    let a = AviGlitch.open(src);
    a.mutate_keyframes_into_deltaframes();
    a.output(dst);
    a = AviGlitch.open(dst);
    a.frames.each(f => assert(!f.is_keyframe));

    a = AviGlitch.open(src);
    a.mutate_keyframes_into_deltaframes(_.range(0, 51));
    a.output(dst);
    a = AviGlitch.open(dst);
    a.frames.each_with_index((f, i) => {
      if (i <= 50) {
        assert(!f.is_keyframe);
      }
    });
  });

  it('should check if keyframes exist.', () => {
    const a = AviGlitch.open(src);
    assert(a.has_keyframe);
    a.glitch('keyframe', () => null);
    assert(!a.has_keyframe);
  });

  it('should #remove_all_keyframes!', () => {
    const a = AviGlitch.open(src);
    assert(a.has_keyframe);
    a.remove_all_keyframes();
    assert(!a.has_keyframe);
  });

  it('should count same number of specific frames', () => {
    const a = AviGlitch.open(src);
    let dc1 = 0;
    let dc2 = 0;
    a.frames.each((f) => {
      if (f.is_deltaframe) {
        dc1++;
      }
    });
    a.glitch('deltaframe', (d) => {
      dc2++;
      return d;
    });
    assert.equal(dc1, dc2);
  });

});
