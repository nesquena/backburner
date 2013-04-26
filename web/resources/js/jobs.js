(function(Backburner) {

    Backburner.Job = Backbone.Model.extend({
    });

    Backburner.JobCollection = Backbone.Collection.extend({
        model: Backburner.Job,
        url: function() {
            return 'queue/' + this.queue_name + "/jobs";
        },
        queue_name: null
    });

    Backburner.JobView = Backbone.Marionette.ItemView.extend({
        template: 'resources/templates/job_view.hbs',
        tagName: 'tr'
    });
    Backburner.JobCollectionView = Backbone.Marionette.CompositeView.extend({
        template: 'resources/templates/jobs_view.hbs',
        itemView: Backburner.JobView,
        itemViewContainer: "tbody"
    });

}(window.Backburner));