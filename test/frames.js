import assert from 'assert';
import fs     from 'fs';
import path   from 'path';
import _      from 'lodash';

const FILES_DIR  = path.join(__dirname, 'files');
const OUTPUT_DIR = path.join(FILES_DIR, 'output');
const TMP_DIR    = 'tmp';

import AviGlitch from '../lib/aviglitch';
import Base      from '../lib/base';
import Frames    from '../lib/frames';
import Frame     from '../lib/frame';


describe('Frames', () => {
  let out, src;

  before(() => {
    Frames.prototype.get_real_id_with = function (frame) {
      const pos = this.io.pos;
      this.io.pos -= frame.data.length;
      this.io.pos -= 8;
      const id = this.io.read(4);
      this.io.pos = pos;
      return id;
    };

    if (!fs.existsSync(OUTPUT_DIR)) {
      fs.mkdirSync(OUTPUT_DIR);
    }
    if (!fs.existsSync(TMP_DIR)) {
      fs.mkdirSync(TMP_DIR);
    }

    src  = path.join(FILES_DIR, 'sample.avi');
    out = path.join(OUTPUT_DIR, 'out.avi');
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

  it('should save the same file when nothing is changed', () => {
    const avi = AviGlitch.open(src);
    avi.frames.each(() => {});
    avi.output(out, false);
    // FileUtils.cmp(@src, @out).should be true
    assert(fs.existsSync(out), 'out.avi exists');

    const f_in  = fs.readFileSync(src);
    const f_out = fs.readFileSync(out);
    assert(f_in, 'in file exists');
    assert(f_out, 'out file exists');
    assert.deepEqual(f_in, f_out, 'nothing changed');
    avi.close();
  });

  it('can manipulate each frame', (done) => {
    const avi = AviGlitch.open(src);
    avi.frames.each((f) => {
      if (f.is_keyframe) {
        f.data = new Buffer(f.data.toString('ascii').replace(/\d/, '0'));
      }
    });

    avi.output(out, true, () => {
      assert(Base.surely_formatted(out, true));
      done();
    });
  });

  it('should remove a frame when returning null', () => {
    let avi = AviGlitch.open(src);
    const in_frame_size = avi.frames.length();

    let rem_count = 0;
    avi.glitch('keyframe', () => {
      rem_count += 1;
      return null;
    });

    avi.output(out, false, () => {
      assert(Base.surely_formatted(out, true));
    });

    // frames length in the output file is correct
    avi = AviGlitch.open(out);
    const out_frame_size = avi.frames.length();
    assert.equal(out_frame_size, in_frame_size - rem_count);
    avi.close();
  });

  it('should read correct positions in #each', (done) => {
    const avi = AviGlitch.open(src);
    avi.frames.each((f) => {
      const real_id = avi.frames.get_real_id_with(f);
      assert.equal(real_id, f.id);
    });
    avi.close(done);
  });

  it('should promise the read frame data is not nil', () => {
    const avi = AviGlitch.open(src);
    avi.frames.each((f) => {
      assert(f.data !== null);
    });
    avi.close();
  });

  it('should save video frames count open(src) header', (done) => {
    const avi = AviGlitch.open(src);
    let c = 0;
    avi.frames.each((f) => {
      if (f.is_videoframe) { c += 1; }
    });

    avi.output(out, false);
    fs.readFile(out, (err, data) => {
      if (err) { throw err; }
      if (!Buffer.isBuffer) {
        data = new Buffer(data);
      }
      assert.equal(data.readUInt32LE(48), c, 'frames count in header is correct');
      avi.close(done);
    });
  });

  it('should evaluate the equality with owned contents', (done) => {
    const a = AviGlitch.open(src);
    const b = AviGlitch.open(src);
    assert(a.frames.equal(b.frames));
    a.close(() => b.close(done));
  });

  it('can generate AviGlitch::Base instance', (done) => {
    const a = AviGlitch.open(src);
    const b = a.frames.slice(0, 10);
    const c = b.to_avi();

    assert(c instanceof Base);

    c.output(out, false);
    assert(Base.surely_formatted(out, true));
    a.close(() => c.close(done));
  });

  it('can concat with other Frames instance with #concat, destructively', () => {
    const a = AviGlitch.open(src);
    const b = AviGlitch.open(src);
    const asize = a.frames.length();
    const bsize = b.frames.length();

    assert.throws(() => {
      a.frames.concat([1, 2, 3]);
    }, TypeError);

    a.frames.concat(b.frames);
    assert.equal(a.frames.length(), asize + bsize);
    assert.equal(b.frames.length(), bsize);
    a.output(out);
    b.close();
    assert(Base.surely_formatted(out, true));
  });

  it('can slice frames using start pos and length', () => {
    const avi = AviGlitch.open(src);
    const a = avi.frames;
    const asize = a.length();
    const c = Math.floor(asize / 3);
    const b = a.slice(1, c + 1);
    assert(b instanceof Frames);
    assert.equal(b.length(), c);
    assert.doesNotThrow(() => b.each(x => x));

    assert(a.length() === asize);  // make sure a is not destroyed
    assert.doesNotThrow(() => a.each(x => x));

    avi.frames.concat(b);
    avi.output(out);
    assert(Base.surely_formatted(out, true));
  });

  it('can slice frames using Range as an Array', (done) => {
    const avi = AviGlitch.open(src);
    const a = avi.frames;
    const asize = a.length();
    const c = Math.floor(asize / 3);
    const spos = 3;

    let range = _.range(spos, spos + c);
    const b = a.slice(range);
    assert(b instanceof Frames);
    assert.equal(b.length(), c);
    assert.doesNotThrow(() => b.each((x) => x));

    // negative value to represent the distance from last.
    range = [spos, -1];
    const d = a.slice(range);
    assert(d instanceof Frames);
    assert.equal(d.length(), asize - spos - 1);
    assert.doesNotThrow(() => d.each((x) => x));

    const x = -5;
    range = _.range(spos, x);  // gives [spos, x+1] as range
    const e = a.slice(range);
    assert(e instanceof Frames);
    assert.equal(e.length(), asize - spos + x + 1);
    assert.doesNotThrow(() => d.each(xx => xx));

    avi.close(done);
  });

  it('can concat repeatedly the same sliced frames', () => {
    const a = AviGlitch.open(src);
    const b = a.frames.slice(0, 5);
    const c = a.frames.slice(0, 10);
    _.range(0, 10).forEach(() => b.concat(c));
    assert(b.length() === 5 + (10 * 10));
  });

  it('can get all frames after n using slice(n)', (done) => {
    const a = AviGlitch.open(src);
    const pos = 10;
    const b = a.frames.slice(pos, a.frames.length());
    const c = a.frames.slice(pos);
    assert(c instanceof Frames);
    assert.deepEqual(c.meta, b.meta);
    a.close(done);
  });

  it('can get one single frame using at(n)', (done) => {
    const a = AviGlitch.open(src);
    const pos = 10;
    let b = null;
    a.frames.each_with_index((f, i) => {
      if (i === pos) { b = f; }
    });

    const c = a.frames.at(pos);
    assert(c instanceof Frame);
    assert.deepEqual(c.data, b.data);
    a.close(done);
  });

  it('can get the first / last frame with first() / last()', (done) => {
    const a = AviGlitch.open(src);
    let b0 = null;
    let c0 = null;
    a.frames.each_with_index((f, i) => {
      if (i === 0) {
        b0 = f;
      }
      if (i === a.frames.length() - 1) {
        c0 = f;
      }
    });
    const b1 = a.frames.first();
    const c1 = a.frames.last();

    assert.deepEqual(b1.data, b0.data);
    assert.deepEqual(c1.data, c0.data);
    a.close(done);
  });

  it('can add a frame at last using push', () => {
    const a = AviGlitch.open(src);
    const s = a.frames.length();
    const b = a.frames.at(10);
    assert.throws(() => {
      a.frames.push(100);
    }, TypeError);

    const c = a.frames.add(a.frames.slice(10, 11));
    let x = a.frames.push(b);

    assert.equal(a.frames.length(), s + 1);
    assert.equal(x, a.frames);

    assert.deepEqual(a.frames.meta, c.meta);
    assert.deepEqual(a.frames.last().data, c.last().data);

    x = a.frames.push(b);
    assert.equal(a.frames.length(), s + 2);
    assert.equal(x, a.frames);

    a.output(out);
    assert(Base.surely_formatted(out, true));
  });

  it('can delete all frames using clear', (done) => {
    const a = AviGlitch.open(src);
    a.frames.clear();
    assert.equal(a.frames.length(), 0);
    a.close(done);
  });

  it('can delete one frame using delete_at', () => {
    const a = AviGlitch.open(src);
    const l = a.frames.length();
    const b = a.frames.at(10);
    const c = a.frames.at(11);
    const x = a.frames.delete_at(10);

    assert.deepEqual(x.data, b.data);
    assert.deepEqual(a.frames.at(10).data, c.data);
    assert.equal(a.frames.length(), l - 1);

    a.output(out);
    assert(Base.surely_formatted(out, true));
  });

  it('can insert one frame into other frames using insert', () => {
    const a = AviGlitch.open(src);
    const l = a.frames.length();
    const b = a.frames.at(10);
    const x = a.frames.insert(5, b);

    assert.equal(x, a.frames);
    assert.deepEqual(a.frames.at(5).data, b.data);
    assert.deepEqual(a.frames.at(11).data, b.data);
    assert.equal(a.frames.length(), l + 1);

    a.output(out);
    assert(Base.surely_formatted(out, true));
  });

  it('can slice frames destructively using slice_save', (done) => {
    const a = AviGlitch.open(src);
    const l = a.frames.length();

    const b = a.frames.slice_save(10, 11);
    assert(b instanceof Frame);
    assert.equal(a.frames.length(), l - 1);

    const c = a.frames.slice_save(0, 10);
    assert(c instanceof Frames);
    assert.equal(a.frames.length(), l - 1 - 10);

    const d = a.frames.slice_save(_.range(0, 10));
    assert(d instanceof Frames);
    assert.equal(a.frames.length(), l - 1 - 10 - 10);
    a.close(done);
  });

  it('provides correct range info with get_head_and_tail', (done) => {
    const a = AviGlitch.open(src);
    const f = a.frames;
    assert.deepEqual(f.get_head_and_tail(3, 10), [3, 10]);
    assert.deepEqual(f.get_head_and_tail(40, -1), [40, f.length() - 1]);
    assert.deepEqual(f.get_head_and_tail(10), [10, f.length()]);
    assert.deepEqual(f.get_head_and_tail(60, -10), f.get_head_and_tail(_.range(60, -11)));
    assert.deepEqual(f.get_head_and_tail(0, 0), [0, 0]);
    assert.throws(() => {
      f.get_head_and_tail(100, 10);
    }, RangeError);
    a.close(done);
  });

  it('can splice frame(s) using splice', () => {
    let a = AviGlitch.open(src);
    const l = a.frames.length();
    assert.throws(() => {
      a.frames.splice(10, 1, 'xxx');
    }, TypeError);

    let b = a.frames.at(20);
    a.frames.splice(10, 1, b);
    assert.equal(a.frames.length(), l);
    assert.deepEqual(a.frames.at(10).data, b.data);

    a.output(out, false);
    assert(Base.surely_formatted(out, true));
    a.closeSync();

    a = AviGlitch.open(src);
    const pl = 5;
    const pp = 3;

    b = a.frames.slice(20, 20 + pl);
    a.frames.splice(10, pp, b);

    assert.equal(a.frames.length(), l - pp + pl);
    _.range(0, pp).forEach((i) => {
      assert.deepEqual(a.frames.at(10 + i).data, b.at(i).data);
    });

    assert.throws(() => {
      a.frames.splice(10, 1, a.frames.slice(100, 1));
    }, RangeError);

    a.output(out);
    assert(Base.surely_formatted(out, true));
  });

  it('can repeat frames using mul', (done) => {
    const a = AviGlitch.open(src);

    const r = 20;
    const b = a.frames.slice(10, 20);
    const c = b.mul(r);
    assert.equal(c.length(), 10 * r);

    c.to_avi().output(out);
    assert(Base.surely_formatted(out, true));
    a.close(done);
  });

  it('should manipulate frames like array does', (done) => {
    const avi = AviGlitch.open(src);
    const a = avi.frames;
    const x = new Array(a.length());

    let fa = a.slice(0, 100);
    let fx = x.slice(0, 100);
    assert.equal(fa.length(), fx.length);

    fa = a.slice(100, -1);
    fx = x.slice(100, -1);
    assert.equal(fx.length, fa.length());
    assert.equal(fa.length(), fx.length);

    // Array.prototype.slice does not accept array as the argument!
    fa = a.slice(_.range(100, -11));
    fx = x.slice(_.range(100, -11));
    assert.equal(a.length(), fx.length);
    assert.notEqual(fa.length(), fx.length);

    assert.throws(() => {
      fa = a.slice(-200, 10);
    }, RangeError);
    assert.doesNotThrow(() => {
      fx = x.slice(-200, 10);
    }, RangeError);

    a.splice(100, 1, a.at(200));
    x.splice(100, 1, x[200]);
    assert.equal(a.length(), x.length);

    // Do not accept empty frames.
    a.splice(100, 50, a.slice(100, 100));
    x.splice(100, 50, x.slice(100, 100));
    assert.equal(a.length(), x.length - 1);

    avi.close(done);
  });

  it('should return nil when getting a frame at out-of-range index', (done) => {
    const a = AviGlitch.open(src);

    const x = a.frames.at(a.frames.length + 1);
    assert(x === null);
    a.close(done);
  });

  it('can modify frame flag and frame id', (done) => {
    let a = AviGlitch.open(src);
    a.frames.each((f) => {
      f.flag = 0;
      f.id = '02dc';
    });

    a.output(out, false);
    a.closeSync();

    a = AviGlitch.open(out);
    a.frames.each((f) => {
      assert.equal(f.flag, 0);
      assert.equal(f.id, '02dc');
    });

    a.close(done);
  });

  it('should mutate keyframes into deltaframe', (done) => {
    let a = AviGlitch.open(src);
    a.frames.mutate_keyframes_into_deltaframes();
    a.output(out);

    a = AviGlitch.open(out);
    a.frames.each((f) => {
      assert(!f.is_keyframe);
    });

    a = AviGlitch.open(src);
    a.frames.mutate_keyframes_into_deltaframes(_.range(0, 51));
    a.output(out, false);
    a.closeSync();

    a = AviGlitch.open(out);
    a.frames.each_with_index((f, i) => {
      if (i <= 50) {
        assert(!f.is_keyframe);
      }
    });
    a.close(done);
  });

  it('should return function with Frames.prototype.each', () => {
    const a = AviGlitch.open(src);
    a.frames.each((f) => {
      if (f.is_keyframe) {
        f.data = new Buffer(f.data.toString('ascii').replace(/\d/, ''));
      }
    });

    a.output(out);
    assert(Base.surely_formatted(out, true));
    assert(fs.statSync(out).size < fs.statSync(src).size);
  });

  it('should count the size of specific frames', () => {
    const a = AviGlitch.open(src);
    const f = a.frames;

    const kc1 = f.size_of('keyframes');
    const kc2 = f.size_of('keyframe');
    const kc3 = f.size_of('iframes');
    const kc4 = f.size_of('iframe');

    const dc1 = f.size_of('deltaframes');
    const dc2 = f.size_of('deltaframe');
    const dc3 = f.size_of('pframes');
    const dc4 = f.size_of('pframe');

    const vc1 = f.size_of('videoframes');
    const vc2 = f.size_of('videoframe');

    const ac1 = f.size_of('audioframes');
    const ac2 = f.size_of('audioframe');

    let kc = 0;
    let dc = 0;
    let vc = 0;
    let ac = 0;
    a.frames.each((x) => {
      vc += x.is_videoframe ? 1 : 0;
      kc += x.is_keyframe   ? 1 : 0;
      dc += x.is_deltaframe ? 1 : 0;
      ac += x.is_audioframe ? 1 : 0;
    });

    a.closeSync();

    assert.equal(kc1, kc);
    assert.equal(kc2, kc);
    assert.equal(kc3, kc);
    assert.equal(kc4, kc);

    assert.equal(dc1, dc);
    assert.equal(dc2, dc);
    assert.equal(dc3, dc);
    assert.equal(dc4, dc);

    assert.equal(vc1, vc);
    assert.equal(vc2, vc);

    assert.equal(ac1, ac);
    assert.equal(ac2, ac);
  });

});
