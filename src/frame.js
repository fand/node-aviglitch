const AVIIF_LIST     = 0x00000001;
const AVIIF_KEYFRAME = 0x00000010;
const AVIIF_NO_TIME  = 0x00000100;

/**
 * Frame is the struct of the frame data and meta-data.
 * You can access this class through AviGlitch.Frames.
 * To modify the binary data, operate the `data` property.
 */
class Frame {
    // attr_accessor :data, :id, :flag

    /**
     * Creates a new AviGlitch::Frame object.
     *
     * The arguments are:
     * [+data+] just data, without meta-data
     * [+id+]   id for the stream number and content type code
     *          (like "00dc")
     * [+flag+] flag that describes the chunk type (taken from idx1)
     */
    constructor (data, id, flag) {
        this.is_frame = true;
        this.data     = data;
        this.id       = id;
        this.flag     = flag;

        if (!this.data) {
            this.data = new Buffer();
        }
    }

    /**
     * Returns if it is a video frame and also a key frame.
     */
    is_keyframe () {
        return this.is_videoframe() && (this.flag & AVIIF_KEYFRAME) !== 0;
    }

    /**
     * Alias for is_keyframe
     */
    is_iframe () { return this.is_keyframe(); }

    /**
     * Returns if it is a video frame and also not a key frame.
     */
    is_deltaframe () {
        return this.is_videoframe() && (this.flag & AVIIF_KEYFRAME) === 0;
    }

    /**
     * Alias for is_deltaframe?
     */
    is_pframe () {
        return this.is_deltaframe();
    }

    /**
     * Returns if it is a video frame.
     */
    is_videoframe () {
        return !! this.id.match(/^..d[bc]$/);
    }

    /**
     * Returns if it is an audio frame.
     */
    is_audioframe () {
        return !! this.id.match(/^..wb$/);
    }

}

module.exports = Frame;
