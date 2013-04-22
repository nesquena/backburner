module.exports = function(grunt) {

  // Project configuration.
  grunt.initConfig({
    pkg: grunt.file.readJSON('package.json'),
    concat: {
      js: {
        src: ['components/jquery/jquery.js',
              'components/underscore/underscore.js',
              'components/backbone/backbone.js',
              'components/marionette/lib/backbone.marionette.js',
              'components/handlebars/handlebars.js',
              'components/bootstrap/docs/assets/js/bootstrap.js',
              'components/spin.js/spin.js',
              'resources/js/**/*.js'],
        dest: 'dist/<%= pkg.name %>.js'
      },
      css: {
        src: ['components/bootstrap/docs/assets/css/bootstrap.css',
              'resources/css/sticky_footer.css',
              'resources/css/app.css'],
        dest: 'dist/<%= pkg.name %>.css'
      }
    },
    jshint: {
      beforeconcat: ['resources/js/app.js',
                     'resources/js/spinner.js']
    },
    uglify: {
      build: {
        src: 'dist/<%= pkg.name %>.js',
        dest: 'dist/<%= pkg.name %>.min.js'
      }
    }
  });

  grunt.loadNpmTasks('grunt-contrib-jshint');
  grunt.loadNpmTasks('grunt-contrib-concat');
  grunt.loadNpmTasks('grunt-contrib-uglify');

  // Default task(s).
  grunt.registerTask('default', ['jshint', 'concat', 'uglify']);

};