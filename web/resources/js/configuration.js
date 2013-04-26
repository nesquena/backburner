(function(Backburner) {

    Backburner.Configuration = Backbone.Model.extend({
        url: 'configuration',
        defaults: {
            "version":          null,
            "beanstalk_url":    null,
            "tube_namespace":   null,
            "default_priority": null,
            "respond_timeout":  null,
            "max_job_retries":  null,
            "retry_delay":      null,
            "default_worker":   null
        }
    });

    Backburner.ConfigurationView = Backbone.Marionette.ItemView.extend({
        template: 'resources/templates/configuration_view.hbs'
    });

}(window.Backburner));