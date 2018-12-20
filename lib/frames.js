const _ = require('lodash');
const dedent = require('dedent');
const Readline = require('readline');
const readline = Readline.createInterface({ input: process.stdin, output: process.stdout });

const Frame = require('./frame');
const IO = require('./io');

const BUFFER_SIZE = 2 ** 24;
const SAFE_FRAMES_COUNT = 150000;


/**
 * Frames provides the interface to access each frame
 * in the AVI file.
 * It is implemented as Enumerable. You can access this object
 * through AviGlitch.frames, for example:
 *
 * ```
 * const avi = new AviGlitch('/path/to/your.avi');
 * const frames = avi.frames;
 * frames.each((frame) => {
 *   // frame is a reference of an AviGlitch::Frame object
 *   frame.data = frame.data.replace(/\d/, '0')
 * }
 * ```
 *
 * In the block passed into iteration method, the parameter is a reference
 * of AviGlitch/Frame object.
 */
class Frames {

  /**
   * Creates a new AviGlitch::Frames object.
   * @param {IO} io
   */
  constructor (io) {
    this.io = io;
    this.warn_if_frames_are_too_large = true;

    this.io.seek(12);  // /^RIFF[\s\S]{4}AVI $/

    while (this.io.read(4, 'a').match(/^(?:LIST|JUNK)$/)) {
      const s = this.io.read(4, 'V');
      if (this.io.read(4, 'a') === 'movi') {
        this.pos_of_movi = this.io.pos - 4;
      }
      this.io.move(s - 4);
    }

    this.pos_of_idx1 = this.io.pos - 4;  // here must be idx1
    const s = this.io.read(4, 'V') + this.io.pos;

    this.meta = [];
    let chunk_id = this.io.read(4, 'a');
    while (chunk_id.length > 0) {
      if (this.io.pos >= s) { break; }
      this.meta.push({
        id     : chunk_id,
        flag   : this.io.read(4, 'V'),
        offset : this.io.read(4, 'V'),
        size   : this.io.read(4, 'V'),
      });

      chunk_id = this.io.read(4, 'a');
    }

    this.fix_offsets_if_needed(this.io);

    if (!this.safe_frames_count(this.meta.length)) {
      this.io.close();
      process.exit();
    }

    this.io.seek(0);
  }

  get is_frames () { return true; }

  /**
   * Enumerates the frames.
   * It returns Enumerator if a callback is not given.
   */
  each (callback) {
    if (!callback) { return null; }
    const temp = IO.temp();
    this.frames_data_as_io(temp, callback);
    this.overwrite(temp);
  }

  each_with_index (callback) {
    this.each(callback);
  }

  /**
   * Returns the number of frames.
   */
  length () { return this.meta.length; }
  size   () { return this.meta.length; }

  /**
   * Returns the number of the specific +frame_type+.
   */
  size_of (frame_type) {
    const suffix = frame_type.toString().replace(/frames$/, 'frame');
    const detection = `is_${suffix}`;
    const filtered = this.meta.filter((m) => {
      const f = new Frame(new Buffer(0), m.id, m.flag);
      return f[detection];
    });
    return filtered.length;
  }

  frames_data_as_io (io_dst, callback) {
    if (typeof io_dst === 'undefined') {
      io_dst = new IO('temp');
    }

    this.meta = this.meta.filter((m, i) => {
      this.io.seek(this.pos_of_movi + m.offset + 8);  // 8 for id and size
      const frame = new Frame(this.io.read(m.size), m.id, m.flag);

      // accept the variable callback
      if (callback) {
        const data = callback(frame, i);
        if (Buffer.isBuffer(data) || data === null) {
          frame.data = data;
        }
      }
      if (frame.data) {
        if (frame.data === null) { return false; }
        m.offset = io_dst.pos + 4;  // 4 for 'movi'
        m.size   = frame.data.length;
        m.flag   = frame.flag;
        m.id     = frame.id;
        io_dst.write(m.id, 'a', 4);
        io_dst.write(frame.data.length, 'V');
        io_dst.write(frame.data);
        if (frame.data.length % 2 === 1) {
          io_dst.write('\x00', 'a', 1);
        }
        return true;
      }
      else {
        return false;
      }
    });
    return io_dst;
  }

  /**
   * @param {IO} data
   */
  overwrite (data) {
    if (!this.safe_frames_count(this.meta.length)) {
      this.io.close();
      process.exit();
    }

    // Overwrite the file
    this.io.seek(this.pos_of_movi - 4);        // 4 for size
    this.io.write(data.size() + 4, 'V');   // 4 for 'movi'
    this.io.write('movi', 'a', 4);
    data.seek(0);
    let d = data.read(BUFFER_SIZE);
    while (Buffer.isBuffer(d) && d.length > 0) {
      this.io.write(d);
      d = data.read(BUFFER_SIZE);
    }

    this.io.write('idx1', 'a', 4);
    this.io.write(this.meta.length * 16, 'V');
    const idxs = [];
    this.meta.forEach((m) => {
      idxs.push(new Buffer(m.id));
      idxs.push(IO.pack('VVV', [m.flag, m.offset, m.size]));
    });
    this.io.write(Buffer.concat(idxs));

    const eof = this.io.pos;
    this.io.truncate(eof);

    // Fix info
    // file size
    this.io.seek(4);
    this.io.write(eof - 8, 'V');

    // frame count
    this.io.seek(48);
    const vid_frames = this.meta.filter((m) => {
      return m.id.match(/^..d[bc]$/);
    });

    this.io.write(vid_frames.length, 'V');
    return this.io.pos;
  }

  /**
   * Removes all frames and returns self.
   */
  clear () {
    this.meta = [];
    this.overwrite(IO.temp());
    return this;
  }

  /**
   * Appends the frames in the other Frames into the tail of self.
   * It is destructive like Array does.
   */
  concat (other_frames) {
    // raise TypeError unless other_frames.kind_of?(Frames)
    if (!other_frames.is_frames) {
      throw new TypeError();
    }

    // data
    const this_data  = IO.temp();
    const other_data = IO.temp();

    // Reconstruct idx data.
    this.frames_data_as_io(this_data);
    other_frames.frames_data_as_io(other_data);

    // Write other_data after EOF of this_data.
    const this_size = this_data.size();
    this_data.seek(this_size);
    other_data.seek(0);
    let d = other_data.read(BUFFER_SIZE);
    while (Buffer.isBuffer(d) && d.length > 0) {
      this_data.write(d);
      d = other_data.read(BUFFER_SIZE);
    }
    other_data.close();

    // Concat meta.
    const other_meta = other_frames.meta.map((m) => {
      return {
        offset : m.offset + this_size,
        size   : m.size,
        flag   : m.flag,
        id     : m.id,
      };
    });
    this.meta = this.meta.concat(other_meta);

    // Close.
    this.overwrite(this_data);
    this_data.close();
  }

  /**
   * Returns a concatenation of the two Frames as a new Frames instance.
   */
  add (other_frames) {
    const r = this.to_avi();
    r.frames.concat(other_frames);
    return r.frames;
  }

  /**
   * Returns the new Frames as a +times+ times repeated concatenation
   * of the original Frames.
   */
  mul (times) {
    const result = this.slice(0, 1);
    result.clear();
    const frames = this.slice(0);
    _.times(times, () => result.concat(frames));
    return result;
  }

  /**
   * Returns the Frame object at the given index or
   * returns new Frames object that sliced with the given index and length
   * or with the Range.
   * Just like JS Array, not a Ruby Array.
   */
  slice (_head, _tail) {
    // return @at head unless head.length? or tail?  # Ruby like Array needs this line.
    const [head, tail] = this.get_head_and_tail(_head, _tail);  // allow negative tail.
    const r = this.to_avi();
    r.frames.each_with_index((f, i) => {
      if (!(head <= i && i < tail)) {
        f.data = null;
      }
    });
    return r.frames;
  }

  /**
   * Removes frame(s) at the given index or the range (same as slice).
   * Returns the new Frames contains removed frames.
   */
  slice_save (head, tail) {
    [head, tail] = this.get_head_and_tail(head, tail);
    let length = tail - head;
    let [header, sliced, footer] = [];
    sliced = length > 1 ? this.slice(head, tail) : this.at(head);
    header = this.slice(0, head);
    if (length === undefined) {
      length = 1;
    }
    footer = this.slice(tail);
    this.clear();

    this.concat(header);
    this.concat(footer);
    return sliced;
  }

  /**
   * Removes frame(s) at the given index or the range (same as []).
   * Inserts the given Frame or Frames's contents into the removed index.
   */
  splice (index, howmany) {
    const offset        = Array.isArray(index) ? 1 : 2;
    const _replacements = [...arguments].slice(offset);
    const replacements  = [];

    _replacements.forEach((r) => {
      if (r.is_frames || r.is_frame) {
        replacements.push(r);
      }
      else if (Array.isArray(r)) {
        r.forEach((rr) => {
          if (!(rr.is_frames || rr.is_frame)) {
            throw new TypeError('Cannot splice frames with non-frame objects.');
          }
          replacements.push(rr);
        });
      }
      else {
        throw new TypeError('Cannot splice frames with non-frame objects.');
      }
    });

    const [head, tail] = [index, index + howmany];

    const header = this.slice(0, head);
    const footer = this.slice(tail);

    replacements.forEach((r) => {
      if (r.is_frame) {
        header.push(r);
      }
      else {
        header.concat(r);
      }
    });

    const new_frames = header.add(footer);
    this.clear();
    this.concat(new_frames);
  }

  /**
   * Returns one Frame object at the given index.
   */
  at (n) {
    const m = this.meta[n];
    if (!m) { return null; }

    this.io.seek(this.pos_of_movi + m.offset + 8);

    const frame = new Frame(this.io.read(m.size), m.id, m.flag);
    this.io.seek(0);
    return frame;
  }

  /**
   * Returns the first Frame object.
   */
  first () { return this.at(0); }

  /**
   * Returns the last Frame object.
   */
  last () { return this.at(this.length() - 1); }

  /**
   * Appends the given Frame into the tail of self.
   */
  push (frame) {
    if (!frame.is_frame) {
      throw new TypeError();
    }

    // data
    const this_data = IO.temp();
    this.frames_data_as_io(this_data);
    const this_size = this_data.size();

    this_data.seek(this_size + 3);   // ????
    this_data.write(frame.id, 'a');
    this_data.write(frame.data.length, 'V');
    this_data.write(frame.data);
    if (frame.data.length % 2 === 1) {
      this_data.write(new Buffer('\x00'));
    }

    // meta
    this.meta.push({
      id     : frame.id,
      flag   : frame.flag,
      offset : this_size + 4, // 4 for 'movi'
      size   : frame.data.length,
    });

    // close
    this.overwrite(this_data);
    this_data.close();
    return this;
  }

  /**
   * Inserts the given Frame objects into the given index.
   */
  insert (n, ...frames) {
    const new_frames = this.slice(0, n);
    frames.forEach(f => new_frames.push(f));

    new_frames.concat(this.slice(n));
    this.clear();
    this.concat(new_frames);
    return this;
  }

  /**
   * Deletes one Frame at the given index.
   */
  delete_at (n) { return this.slice_save(n, n + 1); }

  /**
   * Mutates keyframes into deltaframes at given range, or all.
   */
  mutate_keyframes_into_deltaframes (_range = null) {
    const range = _range || _.range(this.size());
    this.each_with_index((frame, i) => {
      if (range.indexOf(i) !== -1 && frame.is_keyframe) {
        frame.flag = 0;
      }
    });
  }

  /**
   * Generates new AviGlitch::Base instance using self.
   */
  to_avi () {
    const AviGlitch = require('./aviglitch');
    return AviGlitch.open(this.io.fullpath());
  }

  inspect () {
    // "#<#{@constructor.name }:#{sprintf("0x%x", object_id)} @io=#{@io.inspect} size=#{self.size}>"
    JSON.stringify(this.meta.slice(0, 10));
  }

  get_head_and_tail (head, tail) {
    if (head.length) {
      [head, tail] = [head[0], head[head.length - 1] + 1];
      if (tail <= 0) {
        tail -= 1;
      }
    }
    head = head >= 0 ? head : this.meta.length + head;
    if (tail != null) {
      if (tail < 0) {
        tail += this.meta.length;
      }
      else if (tail < head) {
        // JS Array.prototype.slice does not raise Error in such case...
        throw new RangeError('Wrong range passed.');
      }
    }
    else {
      tail = this.meta.length;
    }
    return [head, tail];
  }

  safe_frames_count (count) {
    let r = true;
    if (Frames.warn_if_frames_are_too_large && count >= SAFE_FRAMES_COUNT) {
      process.on('SIGINT', () => {
        this.io.close();
        process.exit();
      });
      const m = dedent`
        WARNING: The avi data has too many frames (${count}).
        It may use a large memory to process.
        We recommend to chop the movie to smaller chunks before you glitch.
        Do you want to continue anyway? [yN]
      `;

      readline.question(m, (answer) => {
        r = (answer === 'y');
        Frames.warn_if_frames_are_too_large = !r;
        return r;
      });
    }
    return r;
  }

  fix_offsets_if_needed (io) {
    // Rarely data offsets begin from 0 of the file.
    if (this.meta.length === 0) { return; }
    const pos = this.io.pos;
    const m0  = this.meta[0];
    io.seek(this.pos_of_movi + m0.offset);
    if (io.read(4, 'a') !== m0.id) {
      this.meta.forEach(m => { m.offset -= this.pos_of_movi; });
    }
    io.seek(pos);
  }

  /**
   * Returns true if +other+'s frames are same as self's frames.
   */
  equal (that) {
    if (!that.is_frames) { return false; }

    return this.meta.every((m_this, i) => {
      const m_that = that.meta[i];
      return (
        m_this.id     === m_that.id &&
        m_this.flag   === m_that.flag &&
        m_this.offset === m_that.offset &&
        m_this.size   === m_that.size
      );
    });
  }

}

module.exports = Frames;
