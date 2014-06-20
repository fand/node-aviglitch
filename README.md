# AviGlitch
[![Build Status](https://travis-ci.org/fand/aviglitch.svg?branch=master)](https://travis-ci.org/fand/aviglitch)

A fork of ruby [AviGlitch](http://github.com/ucnv/aviglitch) gem by ucnv.

AviGlitch destroys your AVI files.

## Usage

```javascript
  var AviGlitch = require('aviglitch');

  var avi = AviGlitch.open('/path/to/your.avi');
  avi.glitch('keyframe', function(frame){
    new Buffer(frame.toString('ascii').replace(/\d/, ''));
  })
  avi.output('/path/to/broken.avi');
```

This library also includes a command line tool named `datamosh`.
It creates the keyframes removed video.

```sh
  $ datamosh /path/to/your.avi -o /path/to/broken.avi
```

## Installation

```sh
  npm install -g aviglitch
```
