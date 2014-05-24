fs = require 'fs'

class IO
    read_formats =
        V: 'readUInt32LE'
        a: 'toString'

    write_formats =
        V: 'writeUInt32LE'

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
            return false

        buf = new Buffer size
        @pos += fs.readSync(@fd, buf, 0, size, @pos)

        if format?
            return buf[IO.read_formats[format]]()
        else
            return buf

    write: (data, format) ->

        if format?
            size = Buffer.byteLength data
            buf = new Buffer size

            buf[IO.write_formats[format]](data)
        else
            buf = data
            size = buf.length

        @pos += fs.writeSync @fd, buf, 0, buf.length, @pos

    close: (cb) ->
        fs.close @fd, -> cb() if cb?

    truncate: (size) ->
        fs.ftruncateSync @fd, size


module.exports = IO
