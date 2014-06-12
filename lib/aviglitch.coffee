path = require 'path'

Base   = require './aviglitch/base.coffee'
Frame  = require './aviglitch/frame.coffee'
Frames = require './aviglitch/frames.coffee'
IO     = require './aviglitch/io.coffee'

# AviGlitch provides the ways to glitch AVI formatted video files.
#
# == Synopsis:
#
# You can manipulate each frame, like:
#
#   avi = AviGlitch.open '/path/to/your.avi'
#   avi.frames.each do |frame|
#     if frame.is_keyframe?
#       frame.data = frame.data.gsub(/\d/, '0')
#     end
#   end
#   avi.output '/path/to/broken.avi'
#
# Using the method glitch, it can be written like:
#
#   avi = AviGlitch.open '/path/to/your.avi'
#   avi.glitch(:keyframe) do |data|
#     data.gsub(/\d/, '0')
#   end
#   avi.output '/path/to/broken.avi'
#

class AviGlitch

    VERSION = '0.0.0'

    BUFFER_SIZE = 2 ** 24

    ##
    # Returns AviGlitch::Base instance.
    # It requires +path_or_frames+ as String or Pathname, or Frames instance.
    @open = (path_or_frames) ->
        if path_or_frames.is_frames?
            path_or_frames.to_avi()
        else
            new Base path.resolve(path_or_frames), BUFFER_SIZE


module.exports = AviGlitch
    # Base: Base
    # Frame: Frame
    # Frames: Frames
    # IO: IO
    # VERSION: 0.0.0
    # BUFFER_SIZE = 2 ** 24
    # open:
