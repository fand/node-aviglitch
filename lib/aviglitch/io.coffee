fs = require 'fs'

class IO
    read_formats =
        V: 'readUInt32LE'

    write_formats =
        V: 'writeUInt32LE'

    constructor: (@path, @pos = 0, cb) ->
        @fd = fs.openSync @path, 'w+'

    size: -> fs.fstatSync(@fd)["size"]
    seek: (@pos) -> @pos
    seedEnd: -> @seek @size()
    move: (d) -> @pos += d


    read: (size, format) ->
        buf = new Buffer size
        @pos += fs.readSync(@fd, buf, 0, size, @pos)

        if format?
            return buf[IO.read_formats[format]]()
        else
            return buf.toString()

    write: (data, format) ->
        size = buf.length
        buf = new Buffer size

        if format?
            buf[IO.write_formats[format]](data)
        else
            buf.write data

        @pos += fs.writeSync @fd, buf, 0, size, @pos

    close: (cb) ->
        fs.close @fd, -> cb() if cb?

    truncate: (size) ->
        fs.ftruncateSync @fd, size


module.exports = IO
