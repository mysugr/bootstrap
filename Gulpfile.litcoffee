Deploy Script for mySugr Bootstrap
==================================
The primary purpose of this script is to provide a well-defined location for the mySugr Bootstrap css file while cache-busting the contents on updates.

## Installing

```
$ npm install
```

## Running

The following environment variables need to be set:

  * `AWS_ACCESS_KEY_ID`
  * `AWS_SECRET_ACCESS_KEY`
  * `AWS_REGION`

```
$ gulp
```

will upload the newest `bootstrap.css` to `mysugr-elements.com`.

## Using

```
<link rel="stylesheet" href="//mysugr-elements.com/bootstrap.css">
```

## Technical Implementation Strategy
We provide a CSS-files with non-caching headers, namely `bootstrap.css`. This file `@import`s the actual CSS file, which has a hash appended to its filename (for caching) and long expiry headers.

```
@import "bootstrap-87fa525a.css"
```

### Implementation

    gulp = require 'gulp'
    gutil= require 'gulp-util'
    less = require 'gulp-less'
    path = require 'path'
    rev  = require 'gulp-rev'
    s3   = require 'gulp-s3'

    s3Credentials =
      key:    process.env.AWS_ACCESS_KEY_ID
      secret: process.env.AWS_SECRET_ACCESS_KEY
      region: process.env.AWS_REGION
      bucket: 'mysugr-elements.com'

    s3CacheLong =
      headers:'cache-control': 'max-age=315360000, no-transform, public'

    s3CacheOff =
      headers:'cache-control': 'private, max-age=0, no-cache, must-revalidate'

    string_src = (filename, contents)->
      src = require('stream').Readable objectMode:true
      src._read = ()->
        @push new gutil.File cwd: '', base: '', path: filename, contents: new Buffer contents
        @push null
      return src

    gulp.task 'deploy:less', ->
      gulp.src './less/bootstrap.less'
      .pipe less paths: [path.join(__dirname, 'less'), path.join(__dirname, 'less/mixins')]
      .pipe gulp.dest 'dist/css'

    gulp.task 'deploy:minify',['deploy:less'],->
      minifyCss = require 'gulp-minify-css'
      rename    = require 'gulp-rename'

      gulp.src 'dist/css/bootstrap.css'
      .pipe minifyCss()
      .pipe rename suffix:'.min'
      .pipe gulp.dest 'dist/css/'

    gulp.task 'deploy:rev',['deploy:minify'],->
      gulp.src 'dist/css/bootstrap.min.css'
        .pipe rev()
        .pipe gulp.dest 'dist/s3'
        .pipe s3 s3Credentials, s3CacheLong
        .pipe rev.manifest()
        .pipe gulp.dest 'dist/s3'

    gulp.task 'deploy:css', ['deploy:rev'],->
      rev = require './dist/s3/rev-manifest.json'
      importClause = """
        /* This file was generated automatically on #{(new Date()).toISOString()} */
        @import \"#{rev['bootstrap.min.css']}\"
      """

      string_src 'bootstrap.css', importClause
        .pipe gulp.dest 'dist/s3'
        .pipe s3 s3Credentials, s3CacheOff

    gulp.task 'default', ['deploy:css']