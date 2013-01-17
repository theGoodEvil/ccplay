module.exports = function(grunt) {

  grunt.initConfig({
    coffee: {
      src: "src/*.coffee"
    },
    compass: {
      dev: {
        src: "sass/",
        dest: "css/",
        require: [
          "animation"
        ],
        bundleExec: true,
        linecomments: false
      }
    },
    watch: {
      coffee: {
        files: "<config:coffee.src>",
        tasks: "coffee"
      },
      compass: {
        files: "sass/*.sass",
        tasks: "compass"
      }
    },
    exec: {
      server: {
        command: "php -S 0.0.0.0:8000"
      }
    }
  });

  grunt.loadNpmTasks("grunt-coffee");
  grunt.loadNpmTasks("grunt-compass");
  grunt.loadNpmTasks("grunt-exec");

  grunt.registerTask("serve", "exec:server");
  grunt.registerTask("compile", "coffee compass");
  grunt.registerTask("default", "compile watch");

};
