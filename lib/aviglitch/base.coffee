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
        d = f.read(BUFFER_SIZE)
        while d.length > 0
            @file.write d
            d = f.read(BUFFER_SIZE)

        f.close()
        console.error 'file: ' + JSON.stringify @file
        unless Base.surely_formatted @file
            throw new Error 'Unsupported file passed.'

        @frames = new Frames @file
        # I believe Ruby's GC to close and remove the Tempfile..


    ##
    # Outputs the glitched file to +path+, and close the file.
    output: (dst, do_file_close = true, callback) ->
        src = @file.path
        fs.copySync src, dst
        if do_file_close
            @close(callback)
        else
            callback() if callback?
        return this

    # alias_method :write, :output
    write: -> @output(arguments)


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
        @frames.each (frame) =>
            if @valid_target target, frame
                # data = callback frame
                # frame.data = if data? then data else new Buffer(0)
                data = callback frame
                if data? or data == null
                    data
                else
                    frame.data
            else
                frame.data
        return this

    ##
    # Do glitch with index.
    glitch_with_index: (target = 'all', callback) ->
        return null unless callback?
        i = 0
        @frames.each (frame) =>
            if @valid_target target, frame
                data = callback frame, i
                i++
                if data? or data == null
                    data
                else
                    frame.data
            else
                frame.data

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

    # alias_method :has_keyframes, :has_keyframe
    has_keyframes: -> @has_keyframe()

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

    valid_target: (target, frame) -> #:nodoc:
        return true if target == 'all'
        try
            frame["is_#{target.toString().replace(/frames$/, 'frame')}"]()
        finally
            false

#    private :valid_target?

    ##
    # Checks if the +file+ is a correctly formetted AVI file.
    # +file+ can be String or Pathname or IO.
    @surely_formatted = (file, debug = false) ->
        answer = true
        is_io = file.is_io?  # Probably IO.

        file = new IO(file, 'r') unless is_io

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
            console.error 'ERROR: ' + err.message if debug
            answer = false
        finally
            file.close() unless is_io

        return answer


module.exports = Base
