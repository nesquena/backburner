(function() {
    
    var BACKBURNER = {};
    window.BACKBURNER = BACKBURNER;

    Backbone.Marionette.Renderer.render = function(template, data){
      if (!JST[template]) throw "Template '" + template + "' not found!";
      return JST[template](data);
    };

    BACKBURNER.App = new Backbone.Marionette.Application();
    BACKBURNER.App.addRegions({
        content: "#content"
    });

    BACKBURNER.App.Router = Backbone.Marionette.AppRouter.extend({
        appRoutes: {
            "": "showMonitoring",
            "configuration": "showConfiguration"
        }
    });

    BACKBURNER.App.Controller = Marionette.Controller.extend({
        configuration: null,

        initialize: function(options) {
            this.configuration = options.configuration;
        },
        showMonitoring: function() {
            BACKBURNER.App.content.show(new window.BACKBURNER.MonitoringView());
        },

        showConfiguration: function() {
            BACKBURNER.App.content.show(new window.BACKBURNER.ConfigurationView({model: this.configuration}));
        }
    });

    BACKBURNER.App.bind("initialize:after", function(optionns) {
        Backbone.history.start();
        BACKBURNER.App.Spinner.stopSpinner();
    });

    BACKBURNER.App.addInitializer(function(options) {
        var configuration = new window.BACKBURNER.Configuration({});
        configuration.fetch({async: false}).
        success(function() {
            var controller = new BACKBURNER.App.Controller({configuration: configuration});
            var router = new BACKBURNER.App.Router({controller: controller});
        }).
        error(function() {
            console.log("Failed to retrieve configuration");
        });
    });

    $(document).ready(function() {
        var options = {

        };
        BACKBURNER.App.start(options);
    });


}());