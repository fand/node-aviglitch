const fs = require('fs-extra');
const IO = require('./io');
const Frames = require('./frames');

const BUFFER_SIZE = Math.pow(2, 24);

/**
 * Base is the object that provides interfaces mainly used.
 * To glitch, and save file. The instance is returned through AviGlitch#open.
 */
class Base {

  /**
   * AviGlitch::Frames object generated from the +file+.
   * attr_reader :frames
   * The input file (copied tempfile).
   * attr_reader :file
   */

  /**
   * Creates a new instance of AviGlitch::Base, open the file and
   * make it ready to manipulate.
   * It requires +path+ as Pathname.
   */
  constructor (path) {
    const f = new IO(path, 'r');
    this.is_base = true;

    // copy as tempfile
    this.file = IO.temp('w+');
    let d = f.read(BUFFER_SIZE);
    while (d.length > 0) {
      this.file.write(d);
      d = f.read(BUFFER_SIZE);
    }

    f.close();
    if (!Base.surely_formatted(this.file)) {
      throw new Error('Unsupported file passed.');
    }

    // TODO: close and remove the Tempfile.
    this.frames = new Frames(this.file);
  }

  /**
   * Outputs the glitched file to +path+, and close the file.
   */
  output (dst, do_file_close = true, callback) {
    const src = this.file.path;
    fs.copySync(src, dst);
    if (do_file_close) {
      this.close(callback);
    }
    else if (callback) {
      callback();
    }

    return this;
  }

  write () { return this.output(arguments[0]); }

  /**
   * An explicit file close.aviglitch.coffee
   */
  close (callback) {
    this.file.close(callback);
  }

  closeSync () {
    this.file.closeSync();
  }

  /**
   * Glitches each frame data.
   * It is a convenient method to iterate each frame.
   *
   * The argument +target+ takes symbols listed below:
   * [<tt>:keyframe</tt> or <tt>:iframe</tt>]   select video key frames (aka I-frame)
   * [<tt>:deltaframe</tt> or <tt>:pframe</tt>] select video delta frames (difference frames)
   * [<tt>:videoframe</tt>] select both of keyframe and deltaframe
   * [<tt>:audioframe</tt>] select audio frames
   * [<tt>:all</tt>]        select all frames
   *
   * It also requires a block. In the block, you take the frame data
   * as a String parameter.
   * To modify the data, simply return a modified data.
   * With a block it returns Enumerator, without a block it returns +self+.
   */
  glitch (target = 'all', _callback) {
    if (typeof target !== 'string' && !_callback) {
      _callback = target;
      target = 'all';
    }

    const wrapper = (callback) => {
      return this.frames.each((frame) => {
        if (this.valid_target(target, frame)) {
          // data = callback frame
          // frame.data = if data? then data else new Buffer(0)
          const data = callback(frame.data);
          if (data || data === null) {
            return data;
          }
          else {
            return frame.data;
          }
        }
        else {
          return frame.data;
        }
      });
    };

    if (_callback) {
      wrapper(_callback);
      return this;
    }
    else {
      return wrapper;
    }
  }

  /**
  * Do glitch with index.
  */
  glitch_with_index (target = 'all', _callback) {
    if (typeof target !== 'string' && !_callback) {
      _callback = target;
      target = 'all';
    }

    const wrapper = (callback) => {
      let i = 0;
      return this.frames.each((frame) => {
        if (this.valid_target(target, frame)) {
          const data = callback(frame.data, i);
          i++;
          if (data || data === null) {
            return data;
          }
          else {
            return frame.data;
          }
        }
        else {
          return frame.data;
        }
      });
    };

    if (_callback) {
      wrapper(_callback);
      return this;
    }
    else {
      return wrapper;
    }
  }

  /**
  * Mutates all (or in +range+) keyframes into deltaframes.
  * It's an alias for Frames.prototype.mutate_keyframes_into_deltaframes.
  */
  mutate_keyframes_into_deltaframes (range = null) {
    this.frames.mutate_keyframes_into_deltaframes(range);
    return this;
  }

  /**
  * Check if it has keyframes.
  */
  get has_keyframe () {
    let res = false;
    this.frames.each((f) => {
      res = res || f.is_keyframe;
    });
    return res;
  }

  get has_keyframes () { return this.has_keyframe; }

  /**
  * Removes all keyframes.
  * It is same as `glitch('keyframes', f => null);`
  */
  remove_all_keyframes () {
    this.glitch('keyframe', () => null);
  }

  /**
  * Swaps the frames with other Frames data.
  */
  swap_frames (other) {
    // raise TypeError unless other.kind_of?(Frames)
    this.frames.clear();
    this.frames.concat(other);
  }

  valid_target (target, frame) {
    if (target === 'all') { return true; }
    try {
      return frame[`is_${target.toString().replace(/frames$/, 'frame')}`];
    }
    catch (e) {
      return false;
    }
  }

  //    private :valid_target?

  /**
  * Checks if the +file+ is a correctly formetted AVI file.
  * `file`  can be String or Pathname or IO.
  * @static
  */
  static surely_formatted (file, debug = false) {
    let answer = true;
    const is_io = !!file.is_io;  // Probably IO.
    if (!is_io) {
      file = new IO(file, 'r');
    }

    try {
      file.seek(file.size());
      file.seek(0);

      if (file.read(4, 'a') !== 'RIFF') {
        throw new Error('RIFF sign is not found');
      }

      // Ignore file size.
      file.read(4, 'V');

      if (file.read(4, 'a') !== 'AVI ') {
        throw new Error('AVI sign is not found');
      }

      while (file.read(4, 'a').match(/^(?:LIST|JUNK)$/)) {
        file.move(file.read(4, 'V'));
      }

      file.move(-4);

      // we require idx1
      if (file.read(4, 'a') !== 'idx1') {
        throw new Error('idx1 is not found');
      }

      file.move(file.read(4, 'V'));
    }
    catch (err) {
      // console.log(err);
      if (debug) {
        console.error(`ERROR: ${err.message}`);
      }
      answer = false;
    }
    finally {
      if (!is_io) {
        file.close();
      }
    }

    return answer;
  }
}

module.exports = Base;
