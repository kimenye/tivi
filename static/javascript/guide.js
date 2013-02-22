$(document).ready(function() {
    function EmbeddedApp() {
        var self = this;
        this.channels = ko.observableArray([]);
        this.loading = ko.observable(true);
        this.slideIdx = ko.observable(0);
        this.current = ko.computed(function() {
            if (self.channels().length > 0)
                return self.channels()[self.slideIdx()].code;
            else
                return ""
        });

        $.getJSON("/api/guide", function(data) {
            _.each(data, function(c) {
                self.channels.push(new Channel(c));
            });



            self.loading(false);

            $('#slider-id').liquidSlider({

                dynamicTabs : false,
                dynamicArrows: false,
                responsive: true,
                customArrows: true,
                customArrowLeft: 'previous-slide',
                customArrowRight: 'next-slide',
                callbackFunction: function() {
                    console.log("Panel has changed");
                }
            });
        });

        this.show = function() {

        }
    }


    function Channel(data) {
        var json = $.parseJSON(data.channel);
        this.code = json.code;
        this.name = json.name;
        this.logo = json.logo_id;

        this.current = ko.observable(new Show($.parseJSON(data.current)));
        this.next = ko.observable(null);
        this.rest = ko.observableArray([]);
    }

    function Show(data) {
        var json = $.parseJSON(data.show);
        this.name = json.name;
    }

    function show() {
        $('body').toggleClass("transparent");
        $('.loading').hide();
    }

    ko.applyBindings(new EmbeddedApp());
});