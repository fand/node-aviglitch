mocha = require 'mocha'
assert = require 'assert'

fs = require 'fs'
path = require 'path'
#helper = require path.join __dirname, '/spec_helper'
FILES_DIR = path.join __dirname, 'files'
OUTPUT_DIR = path.join FILES_DIR, 'output'

AviGlitch = require 'lib/aviglitch'
Base = require 'lib/aviglitch/base'
Frames = require 'lib/aviglitch/frames'


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
        @in = path.join FILES_DIR, 'sample.avi'
        @out = path.join OUTPUT_DIR, 'out.avi'

    afterEach (done) ->
        fs.readdir OUTPUT_DIR, (err, files) ->
            throw err if err
            fs.unlinkSync path.join(OUTPUT_DIR, file) for file in files
            done()

    after ->
        fs.rmdirSync OUTPUT_DIR

    it 'should save the same file when nothing is changed', ->
        avi = AviGlitch.open @in
        avi.frames.each ->
        avi.output @out
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
            if f.is_keyframe()
                f.data = new Buffer(f.data.toString().replace /\d/, '0')
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

    # it 'should read correct positions in #each', ->
    #     avi = AviGlitch.open @in
    #     frames = avi.frames
    #     frames.each (f) ->
    #         real_id = frames.get_real_id_with f
    #         assert real_id ==  f.id
    #     avi.close()

    it 'should promise the read frame data is not nil', ->
        avi = AviGlitch.open @in
        frames = avi.frames
        frames.each (f) ->
            assert f.data != null
        avi.close()

    # No private property for JavaScript objects.
    # it 'should hide the inner variables', ->
    #     avi = AviGlitch.open @in
    #     frames = avi.frames
    #     assert.throws (-> frames.meta()), /NoMethodError/
    #     assert.throws (-> frames.io()), /NoMethodError/
    #     assert.throws (-> frames.frames_data_as_io()), /NoMethodError/
    #     avi.close()

    it 'should save video frames count in header', (done) ->
        avi = AviGlitch.open @in
        c = 0
        avi.frames.each (f) ->
            c += 1 if f.is_videoframe()
        avi.output @out
        fs.readFile @out, (err, data) ->
            throw err if err
            data = new Buffer(data) unless Buffer.isBuffer data
            assert.equal data.readUInt32LE(48), c, 'frames count in header is correct'
            done()
            avi.close()

    it 'should evaluate the equality with owned contents', ->
        a = AviGlitch.open @in
        b = AviGlitch.open @in
        assert a.frames.equal b.frames
        a.close()
        b.close()

    it 'can generate AviGlitch::Base instance', ->
        a = AviGlitch.open @in
        b = a.frames.slice(0, 10)
        c = b.to_avi()

        # How can I do this?
        # c.should be_kind_of AviGlitch::Base

        c.output @out
        assert.ok Base.surely_formatted(@out, true)

    it 'can concat with other Frames instance with #concat, destructively', ->
        a = AviGlitch.open @in
        b = AviGlitch.open @in
        asize = a.frames.length()
        bsize = b.frames.length()
        assert.throws (->
            a.frames.concat([1,2,3])
        ), /TypeError/
        a.frames.concat(b.frames)
        assert.equal a.frames.length(), asize + bsize
        assert.equal b.frames.length(), bsize
        a.output @out
        b.close()
        assert Base.surely_formatted(@out, true)

    # Cannot overlaod operand in JS!
    # it 'can concat with other Frames instance with +', ->
    #     a = AviGlitch.open @in
    #     b = AviGlitch.open @in
    #     asize = a.frames.length
    #     bsize = b.frames.length
    #     c = a.frames + b.frames
    #     assert a.frames.length() == asize
    #     assert b.frames.length() == bsize
    #     # c.should be_kind_of AviGlitch::Frames
    #     assert c.length() == asize + bsize
    #     a.close()
    #     b.close()
    #     d = AviGlitch.open c
    #     d.output @out
    #     assert.ok Base.surely_formatted?(@out, true)

    it 'can slice frames using start pos and length', ->
        avi = AviGlitch.open @in
        a = avi.frames
        asize = a.length()
        c = Math.floor(asize / 3)
        b = a.slice(1, c+1)
        # b.should be_kind_of Frames
        assert b.length() == c
        assert.doesNotThrow ->
            b.each (x) -> x

        assert a.length() == asize  # make sure a is not destroyed
        assert.doesNotThrow ->
            a.each (x) -> x

        avi.frames.concat b
        avi.output @out
        assert Base.surely_formatted?(@out, true)

    it 'can slice frames using Range', ->
        avi = AviGlitch.open @in
        a = avi.frames
        asize = a.length
        c = (a.length / 3).floor
        spos = 3
        range = [spos..(spos + c)]
        b = a.slice(range)
        #b.should be_kind_of AviGlitch::Frames
        assert.lengthOf b, c + 1
        assert.doesNotThrow (->
            b.each (x) -> x
        )

        range = [spos..-1]
        d = a.slice(range)
        # d.should be_kind_of AviGlitch::Frames
        assert.lengthOf d, asize - spos
        assert.doesNotThrow (->
            d.each (x) -> x
        )

        x = -5
        range = [spos..x]
        e = a.slice(range)
        # e.should be_kind_of AviGlitch::Frames
        assert.lengthOf e, asize - spos + x + 1
        assert.doesNotThrow (->
            d.each (x) -> x
        )

    it 'can concat repeatedly the same sliced frames', ->
        a = AviGlitch.open @in
        b = a.frames.slice(0, 5)
        c = a.frames.slice(0, 10)
        for i in [0...10]
            b.concat(c)
        assert.lengthOf b, 5 + (10 * 10)

    it 'can get one single frame using slice(n)', ->
        a = AviGlitch.open @in
        pos = 10
        b = nil
        a.frames.each_with_index (f, i) ->
            b = f if i == pos
        c = a.frames.slice(pos)
        # c.should be_kind_of AviGlitch::Frame
        assert.equal c.data, b.data

    it 'can get one single frame using at(n)', ->
        a = AviGlitch.open @in
        pos = 10
        b = nil
        a.frames.each_with_index (f, i) ->
            b = f if i == pos
        c = a.frames.at(pos)
        # c.should be_kind_of AviGlitch::Frame
        assert.equal c.data, b.data

    it 'can get a first frame ussing first, a last frame using last', ->
        a = AviGlitch.open @in
        b0 = c0 = nil
        a.frames.each_with_index (f, i) ->
            b0 = f if i == 0
            c0 = f if i == a.frames.length - 1
        b1 = a.frames.first
        c1 = a.frames.last

        assert.equal b1.data, b0.data
        assert.equal c1.data, c0.data

    it 'can add a frame at last using push', ->
        a = AviGlitch.open @in
        s = a.frames.length
        b = a.frames[10]
        assert.throws (->
            a.frames.push 100
        ), /TypeError/
        c = a.frames + a.frames.slice(10, 1)

        x = a.frames.push b
        assert.equal a.frames.length, s + 1
        x.should == a.frames
        assert.equal a.frames, c
        assert.equal a.frames.last.data, c.last.data
        x = a.frames.push b
        assert.equal a.frames.length s + 2
        assert.equal x.should, a.frames

        a.output @out
        assert.ok Base.is_surely_formatted(@out, true)


    it 'can add a frame at last using <<', ->
        a = AviGlitch.open @in
        s = a.frames.length
        b = a.frames[10]

        x = a.frames << b
        assert.equal a.frames.length, s + 1
        assert.equal x == a.frames

        a.output @out
        assert.ok Base.is_surely_formatted(@out, true)

    it 'can delete all frames using clear', ->
        a = AviGlitch.open @in
        a.frames.clear()
        assert.equal a.frames.length, 0

    it 'can delete one frame using delete_at', ->
        a = AviGlitch.open @in
        l = a.frames.length
        b = a.frames[10]
        c = a.frames[11]
        x = a.frames.splice 10, 1

        assert.equal x.data, b.data
        assert.equal a.frames[10].data, c.data
        assert.equal a.frames.length, l - 1

        a.output @out
        asssert.ok Base.is_surely_formatted(@out, true)

    it 'can insert one frame into other frames using insert', ->
        a = AviGlitch.open @in
        l = a.frames.length
        b = a.frames[10]
        x = a.frames.insert 5, b

        assert.equal x, a.frames
        assert.equal a.frames[5].data, b.data
        assert.equal a.frames[11].data, b.data
        assert.equal a.frames.length, l + 1

        a.output @out
        asssert.ok Base.is_surely_formatted(@out, true)

    it 'can slice frames destructively using slice!', ->
        a = AviGlitch.open @in
        l = a.frames.length

        b = a.frames.splice(10, 1)
        # b.should be_kind_of AviGlitch::Frame
        assert.equal a.frames.length, l - 1

        c = a.frames.splice(0, 10)
        # c.should be_kind_of AviGlitch::Frames
        assert.equal a.frames.length, l - 1 - 10

        d = a.frames.slice_save([0..9])
        # d.should be_kind_of AviGlitch::Frames
        assert.equal a.frames.length, l - 1 - 10 - 10

    it 'can swap frame(s) using []=', ->
        a = AviGlitch.open @in
        l = a.frames.length
        assert.throws (->
            a.frames[10] = "xxx"
        ), /TypeError/

        b = a.frames[20]
        a.frames[10] = b
        assert.lengthOf a.frames, 1
        assert.equal a.frames[10].data, b.data

        a.output @out
        assert.ok Base.is_surely_formatted(@out, true)

        a = AviGlitch.open @in
        pl = 5
        pp = 3
        b = a.frames[20...20+pl]
        a.frames[10..(10 + pp)] = b
        assert.lengthOf a.frames, l - pp + pl - 1
        for i in [0...pp]
            assert.equal a.frames[10 + i].data, b[i].data

        assert.throws (->
            a.frames[10] = a.frames.slice(100, 1)
        ), /TypeError/

        a.output @out
        assert.ok Base.is_surely_formatted(@out, true)

    it 'can repeat frames using *', ->
        a = AviGlitch.open @in

        r = 20
        b = a.frames.slice(10, 20)
        c = b * r
        assert.lengthOf c, 10 * r

        c.to_avi.output @out
        assert.ok Base.is_surely_formatted(@out, true)

    it 'should manipulate frames like array does', ->
        avi = AviGlitch.open @in
        a = avi.frames
        x = Array.new a.length

        fa = a.slice(0, 100)
        fx = x.slice(0, 100)
        assert.lengthOf fa, fx.length

        fa = a.slice([100..-1])
        fx = x.slice([100..-1])
        assert.lengthOf fa, fx.length

        fa = a.slice([100..-10])
        fx = x.slice([100..-10])
        assert.lengthOf fa, fx.length

        fa = a.slice(-200, 10)
        fx = x.slice(-200, 10)
        assert.lengthOf fa, fx.length

        a[100] = a.at 200
        x[100] = x.at 200
        assert.lengthOf a, x.length

        a[100..150] = a.slice(100, 100)
        x[100..150] = x.slice(100, 100)
        assert.lengthOf a, x.length

    it 'should have the method alias to slice as []', ->
        a = AviGlitch.open @in

        b = a.frames[10]
        # b.should be_kind_of AviGlitch::Frame

        c = a.frames[0...10]
        # c.should be_kind_of AviGlitch::Frames
        assert.lengthOf c, 10

        d = a.frames[0..9]
        # d.should be_kind_of AviGlitch::Frames
        assert.lengthOf d, 10

    it 'should return nil when getting a frame at out-of-range index', ->
        a = AviGlitch.open @in

        x = a.frames.at(a.frames.length + 1)
        assert.isNull x

    it 'can modify frame flag and frame id', ->
        a = AviGlitch.open @in
        a.frames.each (f) ->
            f.flag = 0
            f.id = "02dc"

        a.output @out
        a = AviGlitch.open @out
        a.frames.each (f) ->
            assert.equal f.flag, 0
            assert.equal f.id, "02dc"

    it 'should mutate keyframes into deltaframe', ->
        a = AviGlitch.open @in
        a.frames.mutate_keyframes_into_deltaframes()
        a.output @out
        a = AviGlitch.open @out
        a.frames.each (f) ->
            assert.isFalse f.is_keyframe()
        end

        a = AviGlitch.open @in
        a.frames.mutate_keyframes_into_deltaframes [0..50]
        a.output @out
        a = AviGlitch.open @out
        a.frames.each_with_index (f, i) ->
            if i <= 50
                assert.isFalse f.is_keyframe()

    it 'should return Enumerator with #each', ->
        a = AviGlitch.open @in
        enumerate = a.frames.each
        enumerate.each (f, i) ->
            if f.is_keyframe()
                f.data = f.data.replace(/\d/, '')

        a.output @out
        assert.ok Base.is_surely_formatted(@out, true)
        asssert.ok File.size(@out) < File.size(@in)


    # it 'should use Enumerator as an external iterator',
    #       :skip => Gem::Version.new(RUBY_VERSION.dup) < Gem::Version.new('1.9.0') || RUBY_PLATFORM == 'java' do
    #     a = AviGlitch.open @in
    #     e = a.frames.each
    #     expect {
    #         while f = e.next do
    #             expect(f).to be_a(AviGlitch::Frame)
    #             if f.is_keyframe?
    #                 f.data = f.data.gsub(/\d/, '')
    #             end
    #         end
    #     }.to raise_error(StopIteration)
    #     a.output @out
    #     assert.ok Base.is_surely_formatted(@out, true)
    #     expect(File.size(@out)).to be < File.size(@in)
    # end


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

        a.close()

        assert kc1 == kc
        assert kc2 == kc
        assert kc3 == kc
        assert kc4 == kc

        assert dc1 == dc
        assert dc2 == dc
        assert dc3 == dc
        assert dc4 == dc

        assert vc1 == vc
        assert vc2 == vc

        assert ac1 == ac
        assert ac2 == ac
