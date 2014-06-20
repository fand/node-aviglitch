var gulp = require('gulp');
var coffee = require('gulp-coffee');
var plumber = require('gulp-plumber');
var mocha = require('gulp-mocha');

gulp.task('coffee', function () {
  return gulp.src('coffee/lib/**/*.coffee')
    .pipe(plumber())
    .pipe(coffee())
    .pipe(gulp.dest('lib'));
});

gulp.task('test', function () {
  require('coffee-script/register');
  gulp.src('test/*.coffee')
    .pipe(plumber())
    .pipe(mocha({
      ui: 'bdd',
      reporter: 'spec',
      timeout: 100000
    }));
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
