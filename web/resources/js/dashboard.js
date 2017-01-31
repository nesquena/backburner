(function(Backburner) {

    Backburner.Stats = Backbone.Model.extend({
        url: 'stats',
        defaults: {
            "current_jobs_urgent":   0,
            "current_jobs_ready": 0,
            "current_jobs_reserved":  0,
            "current_jobs_delayed":  0,
            "current_jobs_buried":      0,
            "job_timeouts":   0,
            "total_jobs":   0,
            "current_connections":   0,
            "current_producers":   0,
            "current_workers":   0,
            "current_waiting":   0
        },
        queues: null,

        parse: function(response, options) {
            if (response.queues) {
                this.queues.set(response.queues);
            }
            return response;
        }
    });

    Backburner.QueueStats = Backbone.Model.extend({
        defaults: {
            "name":   null,
            "current_jobs_urgent":   0,
            "current_jobs_ready": 0,
            "current_jobs_reserved":  0,
            "current_jobs_delayed":  0,
            "current_jobs_buried":      0,
            "total_jobs":   0,
            "current_using":   0,
            "current_waiting":   0,
            "current_watching":   0
        }
    });

    Backburner.QueueStatsCollection = Backbone.Collection.extend({
        model: Backburner.QueueStats
    });

    Backburner.DashboardLayout = Backbone.Marionette.Layout.extend({
        template: 'resources/templates/dashboard_view.hbs',

        regions: {
            stats: "#stats",
            queue_stats: "#queue_stats"
        }
    });

    Backburner.StatsView = Backbone.Marionette.ItemView.extend({
        template: 'resources/templates/stats_view.hbs'
    });

    Backburner.QueueStatsView = Backbone.Marionette.ItemView.extend({
        template: 'resources/templates/queue_stats_view.hbs'
    });

    Backburner.QueueStatsCollectionView = Backbone.Marionette.CollectionView.extend({
        itemView: Backburner.QueueStatsView
    });

}(window.Backburner));