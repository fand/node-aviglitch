fs = require 'fs-extra'
IO = require './io'
Frames = require './frames'

# Base is the object that provides interfaces mainly used.
# To glitch, and save file. The instance is returned through AviGlitch#open.
#
class Base

    # # AviGlitch::Frames object generated from the +file+.
    # attr_reader :frames
    # # The input file (copied tempfile).
    # attr_reader :file
    BUFFER_SIZE = 2 ** 20

    ##
    # Creates a new instance of AviGlitch::Base, open the file and
    # make it ready to manipulate.
    # It requires +path+ as Pathname.
    constructor: (path) ->
        f = new IO path, 'r'

        # copy as tempfile
        @file = new IO 'aviglitch'
        while d = f.read(BUFFER_SIZE)
            @file.write d

        f.close()

        unless Base.surely_formatted @file
            throw new Error 'Unsupported file passed.'

        @frames = new Frames @file
        # I believe Ruby's GC to close and remove the Tempfile..


    ##
    # Outputs the glitched file to +path+, and close the file.
    output: (dst, do_file_close = true) ->
        src = @file.path
        fs.copySync src, dst
        console.log 'copied'
        @close() if do_file_close
        return this

    ##
    # An explicit file close.
    close: (callback) -> @file.close(callback)

    ##
    # Glitches each frame data.
    # It is a convenient method to iterate each frame.
    #
    # The argument +target+ takes symbols listed below:
    # [<tt>:keyframe</tt> or <tt>:iframe</tt>]   select video key frames (aka I-frame)
    # [<tt>:deltaframe</tt> or <tt>:pframe</tt>] select video delta frames (difference frames)
    # [<tt>:videoframe</tt>] select both of keyframe and deltaframe
    # [<tt>:audioframe</tt>] select audio frames
    # [<tt>:all</tt>]        select all frames
    #
    # It also requires a block. In the block, you take the frame data
    # as a String parameter.
    # To modify the data, simply return a modified data.
    # With a block it returns Enumerator, without a block it returns +self+.
    glitch: (target = 'all', callback) ->
        return null unless callback?
        for frame in @frames
            if @valid_target target, frame
                frame.data = callback frame.data
        return this

    ##
    # Do glitch with index.
    glitch_with_index: (target = 'all', callback) ->
        return null unless calback?
        for frame, i of @frames
            if @valid_target target, frame
                frame.data = callback frame.data, i
        return this

    ##
    # Mutates all (or in +range+) keyframes into deltaframes.
    # It's an alias for Frames#mutate_keyframes_into_deltaframes!
    mutate_keyframes_into_deltaframes:  (range = nil) ->
        @frames.mutate_keyframes_into_deltaframes range
        return this

    ##
    # Check if it has keyframes.
    has_keyframe: ->
        result = false
        for f in @frames
            if f.is_keyframe()
                result = true
                break
        return result

    ##
    # Removes all keyframes.
    # It is same as +glitch(:keyframes){|f| nil }+
    remove_all_keyframes: ->
        @glitch 'keyframe', (f) -> null

    ##
    # Swaps the frames with other Frames data.
    swap_frames: (other) ->
#        raise TypeError unless other.kind_of?(Frames)
        @frames.clear()
        @frames.concat other

    # alias_method :write, :output
    # alias_method :has_keyframes?, :has_keyframe?

    valid_target: (target, frame) -> #:nodoc:
        return true if target == 'all'
        try
            frame.send "is_#{target.to_s.sub(/frames$/, 'frame')}?"
        finally
            false

#    private :valid_target?

    ##
    # Checks if the +file+ is a correctly formetted AVI file.
    # +file+ can be String or Pathname or IO.
    @surely_formatted = (file, debug = false) ->
        answer = true
        is_io = file.is_io?  # Probably IO.
        file = new IO(file) unless is_io
        try
            file.seek file.size()
            eof = file.pos
            file.seek 0

            unless file.read(4, 'a') == 'RIFF'
                answer = false
                console.error 'RIFF sign is not found' if debug

            len = file.read(4, 'V')

            unless file.read(4, 'a') == 'AVI '
                answer = false
                console.error 'AVI sign is not found' if debug

            while file.read(4, 'a').match /^(?:LIST|JUNK)$/
                s = file.read(4, 'V')
                file.move s

            file.move -4

            # we require idx1
            unless file.read(4, 'a') == 'idx1'
                answer = false
                console.error 'idx1 is not found' if debug

            s = file.read(4, 'V')
            file.move s

        catch err
            console.log err
            console.error err.message if debug
            answer = false
        finally
            file.close() unless is_io

        return answer


module.exports = Base
