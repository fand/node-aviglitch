# Frame is the struct of the frame data and meta-data.
# You can access this class through AviGlitch::Frames.
# To modify the binary data, operate the +data+ property.
class Frame

    AVIIF_LIST     = 0x00000001
    AVIIF_KEYFRAME = 0x00000010
    AVIIF_NO_TIME  = 0x00000100

    # attr_accessor :data, :id, :flag

    ##
    # Creates a new AviGlitch::Frame object.
    #
    # The arguments are:
    # [+data+] just data, without meta-data
    # [+id+]   id for the stream number and content type code
    #          (like "00dc")
    # [+flag+] flag that describes the chunk type (taken from idx1)
    #
    constructor: (data, id, flag) ->
        @is_frame = true
        @data = data
        @id = id
        @flag = flag

    ##
    # Returns if it is a video frame and also a key frame.
    is_keyframe: ->
      @is_videoframe() && !!@flag & AVIIF_KEYFRAME != 0

    ##
    # Alias for is_keyframe?
    is_iframe: -> @is_keyframe()

    ##
    # Returns if it is a video frame and also not a key frame.
    is_deltaframe: ->
      @is_videoframe() && !!@flag & AVIIF_KEYFRAME == 0

    ##
    # Alias for is_deltaframe?
    is_pframe: -> @is_deltaframe()

    ##
    # Returns if it is a video frame.
    is_videoframe: ->
      @id.match /^..d[bc]$/

    ##
    # Returns if it is an audio frame.
    is_audioframe: ->
      @id.match /^..wb$/


module.exports = Frame
