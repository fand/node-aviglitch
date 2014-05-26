fs = require 'fs'

class IO
    read_formats =
        V: (buf) -> buf.readUInt32LE(0)
        a: (buf) -> buf.toString()

    write_formats =
        a: (buf, data) -> buf.write(data)
        V: (buf, data) -> buf.writeUInt32LE(data, 0)

    size_formats =
        a: 1
        V: 4

    constructor: (@path, flags, @pos = 0, cb) ->
        @is_io = true
        flags = if flags? then flags else 'w+'
        @fd = fs.openSync @path, flags

    size: -> fs.fstatSync(@fd)["size"]
    seek: (@pos) -> @pos
    seedEnd: -> @seek @size()
    move: (d) -> @pos += d

    read: (size, format) ->

        if @pos + size > @size()
            size = @size() - @pos
        if size <= 0
            return new Buffer(0)
#            return undefined

        buf = new Buffer size
        @pos += fs.readSync(@fd, buf, 0, size, @pos)

        if format?
            return read_formats[format](buf)
        else
            return buf

    write: (data, format, num_data = 1) ->
        if format?
            buf = new Buffer size_formats[format] * num_data
            write_formats[format](buf, data)
        else
            buf = data
            size = buf.length
        console.log data if !Buffer.isBuffer(data) and !format?
        @pos += fs.writeSync @fd, buf, 0, buf.length, @pos

    close: (callback) ->
        fs.close @fd, -> callback() if callback?

    truncate: (size) ->
        fs.ftruncateSync @fd, size

    ##
    # Pack data to a binary string.
    @pack = (format, data) ->
        bufs = []
        for i, f of format
            buf = new Buffer size_formats[f]
            write_formats[f](buf, data[i])
            bufs.push buf
        return Buffer.concat bufs

module.exports = IO
