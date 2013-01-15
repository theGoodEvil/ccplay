module.exports = function(grunt) {

  grunt.initConfig({
    coffee: {
      src: "src/*.coffee"
    },
    watch: {
      files: "<config:coffee.src>",
      tasks: "coffee"
    },
    exec: {
      server: {
        command: "php -S 0.0.0.0:8000"
      }
    }
  });

  grunt.loadNpmTasks("grunt-coffee");
  grunt.loadNpmTasks("grunt-exec");

  grunt.registerTask("default", "coffee watch");
  grunt.registerTask("serve", "exec:server");

};
