var gulp = require('gulp');
var coffee = require('gulp-coffee');
var plumber = require('gulp-plumber');
var mocha = require('gulp-mocha');
var istanbul = require('gulp-istanbul');

gulp.task('coffee', function () {
  return gulp.src('coffee/lib/**/*.coffee')
    .pipe(plumber())
    .pipe(coffee())
    .pipe(gulp.dest('lib'));
});

gulp.task('test', function () {
  require('coffee-script/register');
  return gulp.src('test/*.coffee')
    .pipe(plumber())
    .pipe(mocha({
      ui: 'bdd',
      reporter: 'spec',
      timeout: 100000
    }))
    .once('end', function () {
      process.exit();
    });
});

gulp.task('coverage', ['coffee'], function () {
  require('coffee-script/register');
  return gulp.src(['lib/**/*.js'])
    .pipe(istanbul())
    .on('finish', function () {
      gulp.src(['test/*.coffee'])
        .pipe(mocha({
          ui: 'bdd',
          reporter: 'spec',
          timeout: 100000
        }))
        .pipe(istanbul.writeReports({
          dir: './coverage',
          reporters: ['lcov']
        }))
        .once('end', function () {
          process.exit();
        });
    });
});

gulp.task('test-coffee', ['coffee'], function () {
  gulp.start('test');
});
gulp.task('watch-coffee', ['coffee', 'test-coffee']);

gulp.task('watch', function () {
  gulp.watch('coffee/lib/**/*.coffee', ['watch-coffee']);
  gulp.watch('test/*.coffee', ['test']);
});
gulp.task('default', ['coffee', 'test-coffee']);
