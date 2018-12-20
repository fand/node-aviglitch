const path = require('path');
const Base = require('./base');

/**
 * AviGlitch provides the ways to glitch AVI formatted video files.
 * You can manipulate each frame, like:
 *
 * ```javascript
 * const avi = AviGlitch.open('/path/to/your.avi');
 * avi.frames.each((frame) => {
 *   if (frame.is_keyframe) {
 *     frame.data = frame.data.gsub(/\d/, '0')
 *   }
 * });
 * avi.output('/path/to/broken.avi');
 * ```
 *
 * Using the method glitch, it can be written like:
 *
 * ```javascript
 * const avi = AviGlitch.open('/path/to/your.avi');
 * avi.glitch('keyframe', (data) => {
 *   data.gsub(/\d/, '0');
 * });
 * avi.output('/path/to/broken.avi');
 * ```
 */
class AviGlitch {

  static get VERSION () { return '0.0.0'; }
  static get BUFFER_SIZE () { return 2 ** 24; }

  /**
   * Returns AviGlitch::Base instance.
   * It requires +path_or_frames+ as String or Pathname, or Frames instance.
   * @static
   */
  static open (path_or_frames) {
    if (path_or_frames.is_frames) {
      return path_or_frames.to_avi();
    }
    else {
      return new Base(path.resolve(path_or_frames), AviGlitch.BUFFER_SIZE);
    }
  }

}

module.exports = AviGlitch;
