(function() {

    window.BACKBURNER.Monitoring = Backbone.Model.extend({});

    window.BACKBURNER.MonitoringView = Backbone.Marionette.ItemView.extend({
        template: '#monitoringView'
    });

}());