Frame = require './frame'
IO = require './io'
Readline = require 'readline'
readline = Readline.createInterface input: process.stdin, output: process.stdout

# Frames provides the interface to access each frame
# in the AVI file.
# It is implemented as Enumerable. You can access this object
# through AviGlitch#frames, for example:
#
#   avi = new AviGlitch '/path/to/your.avi'
#   frames = avi.frames
#   frames.each (frame) ->
#       ## frame is a reference of an AviGlitch::Frame object
#       frame.data = frame.data.replace(/\d/, '0')
#
# In the block passed into iteration method, the parameter is a reference
# of AviGlitch::Frame object.
#
class Frames

    BUFFER_SIZE = 2 ** 24
    SAFE_FRAMES_COUNT = 150000
    @warn_if_frames_are_too_large = true

    # attr_reader :meta

    ##
    # Creates a new AviGlitch::Frames object.
    constructor: (@io) ->
        @is_frames = true

        @io.seek 12    # /^RIFF[\s\S]{4}AVI $/
        while @io.read(4, 'a').match(/^(?:LIST|JUNK)$/)
            s = @io.read(4, 'V')
            @pos_of_movi = @io.pos - 4 if @io.read(4, 'a') == 'movi'
            @io.move(s - 4)

        @pos_of_idx1 = @io.pos - 4 # here must be idx1
        s = @io.read(4, 'V') + @io.pos

        @meta = []
        chunk_id = @io.read(4, 'a')
        while chunk_id.length? and chunk_id.length > 0
            break if @io.pos >= s
            @meta.push
                id:     chunk_id,
                flag:   @io.read(4, 'V'),
                offset: @io.read(4, 'V'),
                size:   @io.read(4, 'V')

            chunk_id = @io.read(4, 'a')

        @fix_offsets_if_needed @io

        unless @safe_frames_count @meta.length
            @io.close()
            process.exit()

        @io.seek 0

    ##
    # Enumerates the frames.
    # It returns Enumerator if a callback is not given.
    each: (callback) ->
        return null unless callback?
        temp = IO.temp()
        @frames_data_as_io temp, callback
        @overwrite temp

    each_with_index: (callback) ->
        @each callback

    ##
    # Returns the number of frames.
    length: -> @meta.length
    size: -> @meta.length

    ##
    # Returns the number of the specific +frame_type+.
    size_of: (frame_type) ->
        detection = "is_" + frame_type.toString().replace(/frames$/, "frame")
        filtered = @meta.filter (m) ->
            f = new Frame(new Buffer(), m.id, m.flag)
            f[detection]()
        filtered.length

    frames_data_as_io: (io_dst, callback) ->
        io_dst = new IO 'temp' unless io_dst?
        @meta = @meta.filter (m, i) =>
            @io.seek @pos_of_movi + m.offset + 8   # 8 for id and size
            frame = new Frame(@io.read(m.size), m.id, m.flag)
            if callback?   # accept the variable callback
                data = callback(frame, i)
                if Buffer.isBuffer(data) or data == null
                    frame.data = data
            if frame.data?
                return false if frame.data == null
                m.offset = io_dst.pos + 4   # 4 for 'movi'
                m.size = frame.data.length
                m.flag = frame.flag
                m.id = frame.id
                io_dst.write m.id, 'a', 4
                io_dst.write frame.data.length, 'V'
                io_dst.write frame.data
                io_dst.write "\x00", 'a', 1 if frame.data.length % 2 == 1
                return true
            else
                return false
        return io_dst

    overwrite: (data) ->  #:nodoc:
        unless @safe_frames_count @meta.length
            @io.close()
            process.exit()

        # Overwrite the file
        @io.seek @pos_of_movi - 4        # 4 for size
        @io.write data.size() + 4, 'V'   # 4 for 'movi'
        @io.write 'movi', 'a', 4
        data.seek 0
        d = data.read(BUFFER_SIZE)
        while Buffer.isBuffer(d) and d.length > 0
            @io.write d
            d = data.read(BUFFER_SIZE)

        @io.write 'idx1', 'a', 4
        @io.write @meta.length * 16, 'V'
        idxs = []
        for m in @meta
            idxs.push new Buffer(m.id)
            idxs.push IO.pack('VVV', [m.flag, m.offset, m.size])
        @io.write Buffer.concat idxs
        eof = @io.pos
        @io.truncate eof

        # Fix info
        ## file size
        @io.seek 4
        @io.write eof - 8, 'V'

        ## frame count
        @io.seek 48
        vid_frames = @meta.filter (m) ->
            m.id.match /^..d[bc]$/

        @io.write vid_frames.length, 'V'
        return @io.pos

    ##
    # Removes all frames and returns self.
    clear: ->
        @meta = []
        @overwrite IO.temp()
        this

    ##
    # Appends the frames in the other Frames into the tail of self.
    # It is destructive like Array does.
    concat: (other_frames) ->
        #raise TypeError unless other_frames.kind_of?(Frames)
        throw new TypeError() unless other_frames.is_frames?

        # data
        this_data  = IO.temp()
        other_data = IO.temp()

        # Reconstruct idx data.
        @frames_data_as_io this_data
        other_frames.frames_data_as_io other_data

        # Write other_data after EOF of this_data.
        this_size = this_data.size()
        this_data.seek this_size
        other_data.seek 0
        d = other_data.read(BUFFER_SIZE)
        while Buffer.isBuffer(d) and d.length > 0
            this_data.write d
            d = other_data.read(BUFFER_SIZE)
        other_data.close()

        # Concat meta.
        other_meta = other_frames.meta.map (m) ->
            x =
                offset: m.offset + this_size
                size:   m.size
                flag:   m.flag
                id:     m.id
            return x
        @meta = @meta.concat other_meta

        # Close.
        @overwrite this_data
        this_data.close()

    ##
    # Returns a concatenation of the two Frames as a new Frames instance.
    add: (other_frames) ->
        r = @to_avi()
        r.frames.concat other_frames
        r.frames

    # ##
    # # Returns the new Frames as a +times+ times repeated concatenation
    # # of the original Frames.
    # mul: (times) ->
    #     result = @slice 0, 0
    #     frames = @slice 0..-1
    #     for i in [0...times]
    #         result.concat frames
    #     result

    ##
    # Returns the Frame object at the given index or
    # returns new Frames object that sliced with the given index and length
    # or with the Range.
    # Just like Array.
    slice: (head, tail) ->
        [head, tail] = @get_head_and_tail head, tail    # allow negative tail.
        if tail?
            count = 0
            r = @to_avi()
            r.frames.each_with_index (f, i) ->
                unless head <= i && i < tail
                    f.data = null
            return r.frames
        else
            return @at head

    ##
    # Removes frame(s) at the given index or the range (same as slice).
    # Returns the new Frames contains removed frames.
    slice_save: (head, tail) ->
        [head, tail] = @get_head_and_tail head, tail
        length = tail - head
        [header, sliced, footer] = []
        sliced = if length? then @slice(head, length) else @slice(head)
        head = @slice(0, head)
        length = 1 unless length?
        tail = @slice((head + length), -1)
        @clear()
        @concat header + footer
        return sliced

    ##
    # Returns one Frame object at the given index.
    at: (n) ->
        m = @meta[n]
        return null unless m?
        @io.seek @pos_of_movi + m.offset + 8
        frame = new Frame(@io.read(m.size), m.id, m.flag)
        @io.seek 0
        return frame

    ##
    # Returns the first Frame object.
    first: -> @slice(0)

    ##
    # Returns the last Frame object.
    last: -> @slice(@length() - 1)

    ##
    # Appends the given Frame into the tail of self.
    push: (frame) ->
        throw new TypeError() unless frame.is_frame?

        # data
        this_data = IO.temp()
        @frames_data_as_io this_data
        this_size = this_data.size()

        this_data.seek this_size + 3   # ????
        this_data.write frame.id, 'a'
        this_data.write frame.data.length, 'V'
        this_data.write frame.data
        this_data.write new Buffer("\x00") if frame.data.length % 2 == 1

        # meta
        @meta.push
            id:     frame.id,
            flag:   frame.flag,
            offset: this_size + 4, # 4 for 'movi'
            size:   frame.data.length,

        # close
        @overwrite this_data
        this_data.close()
        return this

    ##
    # Inserts the given Frame objects into the given index.
    insert: (n) ->
        new_frames = @slice(0, n)
        arguments.slice(1).each (f) ->
            new_frames.push f
        new_frames.concat @slice(n)

        @clear()
        @concat new_frames
        return this

    ##
    # Deletes one Frame at the given index.
    delete_at: (n) -> @slice_save n

    ##
    # Mutates keyframes into deltaframes at given range, or all.
    mutate_keyframes_into_deltaframes: (range = nil) ->
        range = [0...@size()] unless range?
        @each_with_index (frame, i) ->
            if i in range and frame.is_keyframe()
                frame.flag = 0

    ##
    # Returns true if +other+'s frames are same as self's frames.
    equal: (other) ->
        @meta == other.meta

    ##
    # Generates new AviGlitch::Base instance using self.
    to_avi: ->
        AviGlitch = require '../aviglitch'
        AviGlitch.open @io.fullpath()

    inspect: ->
        # "#<#{@constructor.name }:#{sprintf("0x%x", object_id)} @io=#{@io.inspect} size=#{self.size}>"
        JSON.stringify @meta.slice(0, 10)

    get_head_and_tail: (head, tail) ->
        if head.length?
            [head, tail] = [head[0], head[head.length - 1]]
        head = if head >= 0 then head else @meta.length + head
        tail = @meta.length + tail + 1 if tail? and tail < 0
        return [head, tail]

    safe_frames_count: (count) ->
        r = true
        if Frames.warn_if_frames_are_too_large && count >= SAFE_FRAMES_COUNT
            process.on 'SIGINT', ->
                @io.close()
                process.exit()
            m = [ "WARNING: The avi data has too many frames (#{count}).\n",
                  "It may use a large memory to process. ",
                  "We recommend to chop the movie to smaller chunks before you glitch.\n",
                  "Do you want to continue anyway? [yN] " ].join('')

            readline.question m, (answer) ->
                r = (answer == 'y')
                Frames.warn_if_frames_are_too_large = !r
                return r
        return r


    fix_offsets_if_needed: (io) ->
        # rarely data offsets begin from 0 of the file
        return if @meta.length == 0
        pos = @io.pos
        m = @meta[0]
        io.seek @pos_of_movi + m.offset
        unless io.read(4, 'a') == m.id
            x.offset -= @pos_of_movi for x in @meta.each
        io.seek pos


    # protected :frames_data_as_io, :meta
    # private :overwrite, :get_head_and_length, :fix_offsets_if_needed


    equal: (that) ->
        return false unless that.is_frames?
        for i in [0...@meta.length]
            m_this = @meta[i]
            m_that = that.meta[i]
            if m_this.id != m_that.id or
            m_this.flag != m_that.flag or
            m_this.offset != m_that.offset or
            m_this.size != m_that.size
                return false
        return true


module.exports = Frames
