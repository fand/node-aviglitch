var gulp = require('gulp');
var coffee = require('gulp-coffee');
var plumber = require('gulp-plumber');
var mocha = require('gulp-mocha');

gulp.task('coffee', function () {
  gulp.src('coffee/lib/**/*.coffee')
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
      timeout: 10000
    }));
});

gulp.task('default', ['coffee', 'test']);
gulp.task('watch', function () {
  gulp.watch('coffee/lib/**/*.coffee', ['coffee', 'test']);
  gulp.watch('test/*.coffee', ['test']);
  return;
});
