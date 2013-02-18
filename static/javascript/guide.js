$(document).ready(function() {
    function EmbeddedApp() {
        var self = this;
        this.channels = ko.observable([]);
        this.loading = ko.observable(true);

        $.getJSON("/api/guide", function(data) {
            _.each(data, function(c) {
                self.channels().push(new Channel(c));
            });

            self.loading(false);
        });

        this.show = function() {

        }
    }


    function Channel(data) {
        var json = $.parseJSON(data.channel);
        this.code = json.code;
        this.name = json.name;
        this.logo = json.logo_id;
    }

    function show() {
        $('body').toggleClass("transparent");
        $('.loading').hide();
    }

    ko.applyBindings(new EmbeddedApp());
});