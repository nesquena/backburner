(function() {

    var Backburner = {};
    window.Backburner = Backburner;

    Backbone.Marionette.Renderer.render = function(template, data){
      if (!JST[template]) throw "Template '" + template + "' not found!";
      return JST[template](data);
    };

    Backburner.App = new Backbone.Marionette.Application();
    Backburner.App.addRegions({
        content: "#content"
    });

    Backburner.App.Router = Backbone.Marionette.AppRouter.extend({
        appRoutes: {
            "": "showDashboard",
            "queue/:name": "showJobs",
            "configuration": "showConfiguration"
        }
    });

    Backburner.App.Controller = Marionette.Controller.extend({
        configuration: null,
        stats: null,

        initialize: function(options) {
            this.configuration = options.configuration;
            this.stats = new Backburner.Stats({});
            this.stats.queues = new Backburner.QueueStatsCollection();
        },
        showDashboard: function() {
            var self = this,
                layout = new Backburner.DashboardLayout();
            Backburner.App.Spinner.startSpinner();
            Backburner.App.content.show(layout);
            this.stats.fetch({async: true}).
            success(function() {
                layout.stats.show(new Backburner.StatsView({model: self.stats}));
                layout.queue_stats.show(new Backburner.QueueStatsCollectionView({collection: self.stats.queues}));
                Backburner.App.Spinner.stopSpinner();

            }).
            error(function() {
                console.log("Failed to retrieve stats");
            });
        },
        showJobs: function(name) {
            var queue_stats = new Backburner.QueueStats({name: name}),
                jobs = new Backburner.JobCollection();
            Backburner.App.Spinner.startSpinner();
            jobs.queue_name = name;
            jobs.fetch({async: true}).
            success(function() {
                Backburner.App.content.show(new Backburner.JobCollectionView({model: queue_stats, collection: jobs}));
                Backburner.App.Spinner.stopSpinner();
            }).
            error(function() {
                console.log("Failed to retrieve jobs");
            });

        },
        showConfiguration: function() {
            Backburner.App.content.show(new Backburner.ConfigurationView({model: this.configuration}));
        }
    });

    Backburner.App.addInitializer(function(options) {
        var configuration = new Backburner.Configuration({});
        configuration.fetch({async: false}).
        success(function() {
            var controller = new Backburner.App.Controller({configuration: configuration}),
                router = new Backburner.App.Router({controller: controller});
        }).
        error(function() {
            console.log("Failed to retrieve configuration");
        });
    });

    Backburner.App.bind("initialize:after", function(options) {
        Backbone.history.start();
    });

    $(document).ready(function() {
        var options = {};
        Backburner.App.start(options);
    });

}());