(function(Backburner) {

    Backburner.App.module("Spinner", function(myModule, App, Backbone, Marionette, $, _) {
        // Private Data And Functions
        var spinner = null;
        var target = null;

        var createSpinner = function() {
            var opts = {
              lines: 13, // The number of lines to draw
              length: 6, // The length of each line
              width: 2, // The line thickness
              radius: 8, // The radius of the inner circle
              corners: 1, // Corner roundness (0..1)
              rotate: 0, // The rotation offset
              direction: 1, // 1: clockwise, -1: counterclockwise
              color: '#fff', // #rgb or #rrggbb
              speed: 1, // Rounds per second
              trail: 60, // Afterglow percentage
              shadow: false, // Whether to render a shadow
              hwaccel: false, // Whether to use hardware acceleration
              className: 'spinner', // The CSS class to assign to the spinner
              zIndex: 2e9, // The z-index (defaults to 2000000000)
              top: '4px', // Top position relative to parent in px
              left: 'auto' // Left position relative to parent in px
            };
            return new window.Spinner(opts).spin(target);
        };


        // Public Data And Functions
        myModule.startSpinner = function() {
            if (spinner === null) {
                target = document.getElementById('spinner');
                spinner = createSpinner();
            }
            spinner.spin(target);
        };

        myModule.stopSpinner = function() {
            if (spinner !== null) {
              spinner.stop();
            }
        };
    });

}(window.Backburner));