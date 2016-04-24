mocha  = require 'mocha'
assert = require('chai').assert

fs   = require 'fs'
path = require 'path'

FILES_DIR  = path.join __dirname, 'files'
OUTPUT_DIR = path.join FILES_DIR, 'output'
TMP_DIR    = 'tmp'

AviGlitch = require '../lib/aviglitch'
Base      = require '../lib/base'
Frames    = require '../lib/frames'
Frame     = require '../lib/frame'


describe 'Frames', ->

    before ->
        Frames.prototype.get_real_id_with = (frame) ->
            pos = @io.pos
            @io.pos -= frame.data.length
            @io.pos -= 8
            id = @io.read 4
            @io.pos = pos
            id

        fs.mkdirSync OUTPUT_DIR unless fs.existsSync OUTPUT_DIR
        fs.mkdirSync TMP_DIR unless fs.existsSync TMP_DIR
        @in = path.join FILES_DIR, 'sample.avi'
        @out = path.join OUTPUT_DIR, 'out.avi'

    afterEach (done) ->
        fs.readdir OUTPUT_DIR, (err, files) ->
            throw err if err
            fs.unlinkSync path.join(OUTPUT_DIR, file) for file in files
            done()

    after (done) ->
        fs.rmdirSync OUTPUT_DIR
        fs.readdir TMP_DIR, (err, files) ->
            throw err if err
            fs.unlinkSync path.join(TMP_DIR, file) for file in files
            fs.rmdirSync TMP_DIR
            done()

    it 'should save the same file when nothing is changed', ->
        avi = AviGlitch.open @in
        avi.frames.each ->
        avi.output @out, false
        # FileUtils.cmp(@in, @out).should be true
        assert fs.existsSync @out, 'out.avi exists'
        f_in = fs.readFileSync @in
        f_out = fs.readFileSync @out
        assert f_in?, 'in file exists'
        assert f_out?, 'out file exists'
        assert.deepEqual f_in, f_out, 'nothing changed'
        avi.close()

    it 'can manipulate each frame', (done) ->
        avi = AviGlitch.open @in
        avi.frames.each (f) ->
            if f.is_keyframe
                f.data = new Buffer(f.data.toString('ascii').replace(/\d/, '0'))

        avi.output @out, true, =>
            assert Base.surely_formatted(@out, true)
            done()

    it 'should remove a frame when returning null', ->
        avi = AviGlitch.open @in
        in_frame_size = avi.frames.length()
        rem_count = 0
        avi.glitch 'keyframe', (kf) ->
            rem_count += 1
            null

        avi.output @out, false, =>
            assert Base.surely_formatted(@out, true)

        # frames length in the output file is correct
        avi = AviGlitch.open @out
        out_frame_size = avi.frames.length()
        assert.equal out_frame_size, in_frame_size - rem_count
        avi.close()

    it 'should read correct positions in #each', (done) ->
        avi = AviGlitch.open @in
        frames = avi.frames
        frames.each (f) ->
            real_id = frames.get_real_id_with f
            assert.equal real_id, f.id
        avi.close -> done()

    it 'should promise the read frame data is not nil', ->
        avi = AviGlitch.open @in
        frames = avi.frames
        frames.each (f) ->
            assert f.data != null
        avi.close()

    it 'should save video frames count in header', (done) ->
        avi = AviGlitch.open @in
        c = 0
        avi.frames.each (f) ->
            c += 1 if f.is_videoframe
        avi.output @out, false
        fs.readFile @out, (err, data) ->
            throw err if err
            data = new Buffer(data) unless Buffer.isBuffer data
            assert.equal data.readUInt32LE(48), c, 'frames count in header is correct'
            avi.close -> done()

    it 'should evaluate the equality with owned contents', (done) ->
        a = AviGlitch.open @in
        b = AviGlitch.open @in
        assert a.frames.equal b.frames
        a.close -> b.close -> done()

    it 'can generate AviGlitch::Base instance', (done) ->
        a = AviGlitch.open @in
        b = a.frames.slice(0, 10)
        c = b.to_avi()

        assert.instanceOf c, Base

        c.output @out, false
        assert.ok Base.surely_formatted(@out, true)
        a.close -> c.close -> done()

    it 'can concat with other Frames instance with #concat, destructively', ->
        a = AviGlitch.open @in
        b = AviGlitch.open @in
        asize = a.frames.length()
        bsize = b.frames.length()

        assert.throws (->
            a.frames.concat([1,2,3])
        ), TypeError
        a.frames.concat(b.frames)
        assert.equal a.frames.length(), asize + bsize
        assert.equal b.frames.length(), bsize
        a.output @out
        b.close()
        assert Base.surely_formatted(@out, true)

    it 'can slice frames using start pos and length', ->
        avi = AviGlitch.open @in
        a = avi.frames
        asize = a.length()
        c = Math.floor(asize / 3)
        b = a.slice(1, c+1)
        assert.instanceOf b, Frames
        assert.equal b.length(), c
        assert.doesNotThrow ->
            b.each (x) -> x

        assert a.length() == asize  # make sure a is not destroyed
        assert.doesNotThrow ->
            a.each (x) -> x

        avi.frames.concat b
        avi.output @out
        assert Base.surely_formatted?(@out, true)

    it 'can slice frames using Range as an Array', (done) ->
        avi = AviGlitch.open @in
        a = avi.frames
        asize = a.length()
        c = Math.floor(asize / 3)
        spos = 3
        range = [spos...(spos + c)]
        b = a.slice(range)
        assert.instanceOf b, Frames
        assert.equal b.length(), c
        assert.doesNotThrow ->
            b.each (x) -> x

        # negative value to represent the distance from last.
        range = [spos, -1]
        d = a.slice(range)
        assert.instanceOf d, Frames
        assert.equal d.length(), asize - spos - 1
        assert.doesNotThrow ->
            d.each (x) -> x

        x = -5
        range = [spos...x]    # gives [spos, x+1] as range
        e = a.slice(range)
        assert.instanceOf e, Frames
        assert.equal e.length(), asize - spos + x + 1
        assert.doesNotThrow ->
            d.each (x) -> x

        avi.close -> done()

    it 'can concat repeatedly the same sliced frames', ->
        a = AviGlitch.open @in
        b = a.frames.slice(0, 5)
        c = a.frames.slice(0, 10)
        for i in [0...10]
            b.concat(c)
        assert b.length() ==  5 + (10 * 10)

    it 'can get all frames after n using slice(n)', (done) ->
        a = AviGlitch.open @in
        pos = 10
        b = a.frames.slice(pos, a.frames.length())
        c = a.frames.slice(pos)
        assert.instanceOf c, Frames
        assert.deepEqual c.meta, b.meta
        a.close -> done()

    it 'can get one single frame using at(n)', (done) ->
        a = AviGlitch.open @in
        pos = 10
        b = null
        a.frames.each_with_index (f, i) ->
            b = f if i == pos
        c = a.frames.at(pos)
        assert.instanceOf c, Frame
        assert.deepEqual c.data, b.data
        a.close -> done()

    it 'can get the first / last frame with first() / last()', (done) ->
        a = AviGlitch.open @in
        b0 = c0 = null
        a.frames.each_with_index (f, i) ->
            b0 = f if i == 0
            c0 = f if i == a.frames.length() - 1
        b1 = a.frames.first()
        c1 = a.frames.last()

        assert.deepEqual b1.data, b0.data
        assert.deepEqual c1.data, c0.data
        a.close -> done()

    it 'can add a frame at last using push', ->
        a = AviGlitch.open @in
        s = a.frames.length()
        b = a.frames.at(10)
        assert.throws (->
            a.frames.push 100
        ), TypeError
        c = a.frames.add a.frames.slice(10, 11)

        x = a.frames.push b
        assert.equal a.frames.length(), s + 1
        assert.equal x, a.frames

        assert.deepEqual a.frames.meta, c.meta
        assert.deepEqual a.frames.last().data, c.last().data
        x = a.frames.push b
        assert.equal a.frames.length(), s + 2
        assert.equal x, a.frames

        a.output @out
        assert Base.surely_formatted(@out, true)

    it 'can delete all frames using clear', (done) ->
        a = AviGlitch.open @in
        a.frames.clear()
        assert.equal a.frames.length(), 0
        a.close -> done()

    it 'can delete one frame using delete_at', ->
        a = AviGlitch.open @in
        l = a.frames.length()
        b = a.frames.at(10)
        c = a.frames.at(11)
        x = a.frames.delete_at 10

        assert.deepEqual x.data, b.data
        assert.deepEqual a.frames.at(10).data, c.data
        assert.equal a.frames.length(), l - 1

        a.output @out
        assert.ok Base.surely_formatted(@out, true)

    it 'can insert one frame into other frames using insert', ->
        a = AviGlitch.open @in
        l = a.frames.length()
        b = a.frames.at(10)
        x = a.frames.insert 5, b

        assert.equal x, a.frames
        assert.deepEqual a.frames.at(5).data, b.data
        assert.deepEqual a.frames.at(11).data, b.data
        assert.equal a.frames.length(), l + 1

        a.output @out
        assert.ok Base.surely_formatted(@out, true)

    it 'can slice frames destructively using slice_save', (done) ->
        a = AviGlitch.open @in
        l = a.frames.length()

        b = a.frames.slice_save(10, 11)
        assert.instanceOf b, Frame
        assert.equal a.frames.length(), l - 1

        c = a.frames.slice_save(0, 10)
        assert.instanceOf c, Frames
        assert.equal a.frames.length(), l - 1 - 10

        d = a.frames.slice_save([0...10])
        assert.instanceOf d, Frames
        assert.equal a.frames.length(), l - 1 - 10 - 10
        a.close -> done()

    it 'provides correct range info with get_head_and_tail', (done) ->
        a = AviGlitch.open @in
        f = a.frames
        assert.deepEqual f.get_head_and_tail(3, 10), [3, 10]
        assert.deepEqual f.get_head_and_tail(40, -1), [40, f.length() - 1]
        assert.deepEqual f.get_head_and_tail(10), [10, f.length()]
        assert.deepEqual f.get_head_and_tail(60, -10), f.get_head_and_tail([60..-10])
        assert.deepEqual f.get_head_and_tail(0, 0), [0, 0]
        assert.throws (->
            f.get_head_and_tail(100, 10)
        ), RangeError
        a.close -> done()

    it 'can splice frame(s) using splice', ->
        a = AviGlitch.open @in
        l = a.frames.length()
        assert.throws (->
            a.frames.splice 10, 1, "xxx"
        ), TypeError

        b = a.frames.at(20)
        a.frames.splice 10, 1, b
        assert.equal a.frames.length(), l
        assert.deepEqual a.frames.at(10).data, b.data

        a.output @out, false
        assert.ok Base.surely_formatted(@out, true)
        a.closeSync()

        a = AviGlitch.open @in
        pl = 5
        pp = 3

        b = a.frames.slice 20, 20 + pl
        a.frames.splice 10, pp, b

        assert.equal a.frames.length(), l - pp + pl
        for i in [0...pp]
            assert.deepEqual a.frames.at(10 + i).data, b.at(i).data

        assert.throws (->
            a.frames.splice 10, 1, a.frames.slice(100, 1)
        ), RangeError

        a.output @out
        assert.ok Base.surely_formatted(@out, true)

    it 'can repeat frames using mul', (done) ->
        a = AviGlitch.open @in

        r = 20
        b = a.frames.slice(10, 20)
        c = b.mul r
        assert.equal c.length(), 10 * r

        c.to_avi().output @out
        assert.ok Base.surely_formatted(@out, true)
        a.close -> done()

    it 'should manipulate frames like array does', (done) ->
        avi = AviGlitch.open @in
        a = avi.frames
        x = new Array a.length()

        fa = a.slice(0, 100)
        fx = x.slice(0, 100)
        assert.equal fa.length(), fx.length

        fa = a.slice(100, -1)
        fx = x.slice(100, -1)
        assert.equal fx.length, fa.length()
        assert.equal fa.length(), fx.length

        # JS Array::slice does not accept array as the argument!
        fa = a.slice([100..-10])
        fx = x.slice([100..-10])
        assert.equal a.length(), fx.length
        assert.notEqual fa.length(), fx.length

        assert.throws ->
            fa = a.slice(-200, 10)
        , RangeError
        assert.doesNotThrow ->
            fx = x.slice(-200, 10)
        , RangeError

        a.splice 100, 1, a.at 200
        x.splice 100, 1, x[200]
        assert.equal a.length(), x.length

        # Do not accept empty frames.
        a.splice 100, 50, a.slice(100, 100)
        x.splice 100, 50, x.slice(100, 100)
        assert.equal a.length(), x.length - 1

        avi.close -> done()

    it 'should return nil when getting a frame at out-of-range index', (done) ->
        a = AviGlitch.open @in

        x = a.frames.at(a.frames.length + 1)
        assert.isNull x
        a.close -> done()

    it 'can modify frame flag and frame id', (done) ->
        a = AviGlitch.open @in
        a.frames.each (f) ->
            f.flag = 0
            f.id = "02dc"

        a.output @out, false
        a.closeSync()

        a = AviGlitch.open @out
        a.frames.each (f) ->
            assert.equal f.flag, 0
            assert.equal f.id, "02dc"

        a.close -> done()

    it 'should mutate keyframes into deltaframe', (done) ->
        a = AviGlitch.open @in
        a.frames.mutate_keyframes_into_deltaframes()
        a.output @out
        a = AviGlitch.open @out
        a.frames.each (f) ->
            assert.isFalse f.is_keyframe

        a = AviGlitch.open @in
        a.frames.mutate_keyframes_into_deltaframes [0..50]
        a.output @out, false
        a.closeSync()
        a = AviGlitch.open @out
        a.frames.each_with_index (f, i) ->
            if i <= 50
                assert.isFalse f.is_keyframe
        a.close -> done()

    it 'should return function with #each', ->
        a = AviGlitch.open @in
        enumerate = (callback) -> a.frames.each callback
        enumerate (f, i) ->
            if f.is_keyframe
                f.data = new Buffer(f.data.toString('ascii').replace /\d/, '')

        a.output @out
        assert Base.surely_formatted(@out, true)

        in_size = fs.statSync(@in).size
        out_size = fs.statSync(@out).size
        assert fs.statSync(@out).size < fs.statSync(@in).size

    it 'should count the size of specific frames', ->
        a = AviGlitch.open @in
        f = a.frames

        kc1 = f.size_of 'keyframes'
        kc2 = f.size_of 'keyframe'
        kc3 = f.size_of 'iframes'
        kc4 = f.size_of 'iframe'

        dc1 = f.size_of 'deltaframes'
        dc2 = f.size_of 'deltaframe'
        dc3 = f.size_of 'pframes'
        dc4 = f.size_of 'pframe'

        vc1 = f.size_of 'videoframes'
        vc2 = f.size_of 'videoframe'

        ac1 = f.size_of 'audioframes'
        ac2 = f.size_of 'audioframe'

        kc = dc = vc = ac = 0
        a.frames.each (x) ->
            vc += if x.is_videoframe then 1 else 0
            kc += if x.is_keyframe then 1 else 0
            dc += if x.is_deltaframe then 1 else 0
            ac += if x.is_audioframe then 1 else 0

        a.closeSync()

        assert.equal kc1, kc
        assert.equal kc2, kc
        assert.equal kc3, kc
        assert.equal kc4, kc

        assert.equal dc1, dc
        assert.equal dc2, dc
        assert.equal dc3, dc
        assert.equal dc4, dc

        assert.equal vc1, vc
        assert.equal vc2, vc

        assert.equal ac1, ac
        assert.equal ac2, ac
