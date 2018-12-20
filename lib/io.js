const fs = require('fs');
const path = require('path');
const tmp = require('tmp');

const read_formats = {
  V : (buf) => buf.readUInt32LE(0),
  a : (buf) => buf.toString(),
};

const write_formats = {
  a : (buf, data) => buf.write(data),
  V : (buf, data) => buf.writeUInt32LE(data, 0),
};

const size_formats = {
  a : 1,
  V : 4,
};

class IO {

  constructor (_path, flags, _pos = 0, callback) {
    this.path  = _path;
    this.pos   = _pos;
    this.is_io = true;
    this.fd    = fs.openSync(this.fullpath(), flags || 'w+');

    if (callback) { callback(); }
  }


  size ()  {
    return fs.fstatSync(this.fd)['size'];
  }

  seek (pos) {
    this.pos = pos;
  }

  seedEnd () {
    this.seek(this.size);
  }

  move (d) {
    this.pos += d;
  }

  read (size, format) {
    if (this.pos + size > this.size()) {
      size = this.size() - this.pos;
    }
    if (size <= 0) {
      return new Buffer(0);
    }

    const buf = new Buffer(size);
    this.pos += fs.readSync(this.fd, buf, 0, size, this.pos);

    if (format) {
      return read_formats[format](buf);
    }
    else {
      return buf;
    }
  }

  write (data, format, num_data = 1) {
    let buf;
    if (format) {
      buf = new Buffer(size_formats[format] * num_data);
      write_formats[format](buf, data);
    }
    else {
      buf = data;
    }

    if (!Buffer.isBuffer(data) && !format) {
      throw new TypeError('IO.prototype.write() requires the data format with a buffer');
    }

    this.pos += fs.writeSync(this.fd, buf, 0, buf.length, this.pos);
  }

  close (callback) {
    fs.close(this.fd, (err) => {
      if (err) { throw err; }
      if (callback) { callback(); }
    });
  }

  closeSync () {
    return fs.closeSync(this.fd);
  }

  truncate (size) {
    return fs.ftruncateSync(this.fd, size);
  }

  fullpath () {
    return path.resolve(__dirname, '../../', this.path);
  }

  /**
   * Pack data to a binary string.
   */
  static pack (format, data) {
    const bufs = [];
    Object.keys(format).forEach((i) => {
      const f = format[i];
      const buf = new Buffer(size_formats[f]);
      write_formats[f](buf, data[i]);
      bufs.push(buf);
    });
    return Buffer.concat(bufs);
  }

}

IO.tmp_id = 0;
IO.removeTmp = () => IO.tmpdirObj.removeCallback();
IO.temp = (flags, callback) => {
  if (!IO.has_tmp) {
    IO.has_tmp = true;
    IO.tmpdirObj = tmp.dirSync();
    process.removeAllListeners();
    // process.addListener 'exit', @removeTmp
    // process.addListener 'error', @removeTmp
  }

  const tmppath = path.resolve(IO.tmpdirObj.name, IO.tmp_id.toString());
  IO.tmp_id += 1;

  return new IO(tmppath, 'w+', 0, callback);
};

module.exports = IO;
