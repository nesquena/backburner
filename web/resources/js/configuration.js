(function() {

    window.BACKBURNER.Configuration = Backbone.Model.extend({
        url: 'configuration',
        defaults: {
            "beanstalk_url":    [],
            "tube_namespace":   null,
            "default_priority": null,
            "respond_timeout":  null,
            "max_job_retries":  null,
            "retry_delay":      null,
            "default_worker":   null
        }
    });

    window.BACKBURNER.ConfigurationView = Backbone.Marionette.ItemView.extend({
        template: 'resources/templates/configuration_view.hbs'
    });

}());