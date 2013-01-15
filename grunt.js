module.exports = function(grunt) {

  grunt.initConfig({
    coffee: {
      src: "src/*.coffee"
    },
    watch: {
      files: "<config:coffee.src>",
      tasks: "coffee"
    }
  });

  grunt.loadNpmTasks('grunt-coffee');

  grunt.registerTask('default', 'coffee');
  grunt.registerTask('dev', 'coffee watch');

};
