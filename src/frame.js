/**
 *  AVIIF_LIST     : 0x00000001
 *  AVIIF_KEYFRAME : 0x00000010
 *  AVIIF_NO_TIME  : 0x00000100
 */
const AVIIF_KEYFRAME = 0x00000010;

/**
 * Frame is the struct of the frame data and meta-data.
 * You can access this class through AviGlitch.Frames.
 * To modify the binary data, operate the `data` property.
 */
class Frame {

  /**
   * Creates a new AviGlitch::Frame object.
   * @param {Buffer|String} data - just data, without meta-data
   * @param {string} id - id for the stream number and content type code (like "00dc")
   * @param {string} flag - flag that describes the chunk type (taken from idx1)
   */
  constructor (data, id, flag) {
    this.data     = data;
    this.id       = id;
    this.flag     = flag;

    if (!this.data) {
      this.data = new Buffer();
    }
  }

  get is_frame () { return true; }

  /**
   * Returns if it is a video frame and also a key frame.
   */
  get is_keyframe () {
    return this.is_videoframe && (this.flag & AVIIF_KEYFRAME) !== 0;
  }

  /**
   * Alias for is_keyframe
   */
  get is_iframe () { return this.is_keyframe; }

  /**
   * Returns if it is a video frame and also not a key frame.
   */
  get is_deltaframe () {
    return this.is_videoframe && (this.flag & AVIIF_KEYFRAME) === 0;
  }

  /**
   * Alias for is_deltaframe?
   */
  get is_pframe () {
    return this.is_deltaframe;
  }

  /**
   * Returns if it is a video frame.
   */
  get is_videoframe () {
    return !!this.id.match(/^..d[bc]$/);
  }

  /**
   * Returns if it is an audio frame.
   */
  get is_audioframe () {
    return !!this.id.match(/^..wb$/);
  }

}

module.exports = Frame;
