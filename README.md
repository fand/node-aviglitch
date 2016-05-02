# AviGlitch

[![Build Status](https://travis-ci.org/fand/node-aviglitch.svg?branch=master)](https://travis-ci.org/fand/node-aviglitch)
[![Coverage Status](https://coveralls.io/repos/fand/node-aviglitch/badge.png?branch=coveralls)](https://coveralls.io/r/fand/node-aviglitch?branch=coveralls)

[![NPM](https://nodei.co/npm/aviglitch.png?downloads=true&stars=true)](https://nodei.co/npm/aviglitch/)

A fork of ruby [AviGlitch](http://github.com/ucnv/aviglitch) gem by ucnv.

AviGlitch destroys your AVI files.

## Usage

```javascript
import AviGlitch from 'aviglitch';
const avi = AviGlitch.open('/path/to/your.avi');
avi.glitch('keyframe', (frame) => {
  return new Buffer(frame.toString('ascii').replace(/\d/, ''));
});
avi.output('/path/to/broken.avi');
```

This library also includes a command line tool named `datamosh`.
It creates the keyframes removed video.

```sh
$ datamosh /path/to/your.avi -o /path/to/broken.avi
```

## Installation

```sh
$ npm install -g aviglitch
```
