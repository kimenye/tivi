$(document).ready(function() {

    var startTime = 0;
    var endTime = 0;

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

            _.each(self.channels(), function(c) {
                var full_duration = Date.parse(c.currentShow().end_time) - Date.parse(c.currentShow().start_time);
                var time_passed = new Date() - Date.parse(c.currentShow().start_time);
                var progress = (time_passed * 100) / full_duration;
                console.log(c.code + progress);

                $( "#pb_" + c.code ).progressbar({
                    value: progress
                });
            });


        });

        this.show = function() {

        }
    }

    function Channel(data) {
        var self = this;
        var json = $.parseJSON(data.channel);
        this.code = json.code;
        this.name = json.name;
        this.logo = json.logo_id;

        this.currentShow = ko.observable();
        this.nextShow = ko.observable();
        this.restOfShows = ko.observableArray([]);

        self.currentShow(new Show($.parseJSON(data.current)));
        self.nextShow(new Show($.parseJSON(data.next)));

        var rest = $.parseJSON(data.rest);

        for (var i in rest) {
            var show = new Show(rest[i]);
            self.restOfShows.push(show);
        }
    }

    /*function Show(data) {
        var json = $.parseJSON(data.show);
        this.name = json.name;
        this.currentShow = ko.observable();
        this.nextShow = ko.observable();
        this.restOfShows = ko.observableArray([]);

        self.currentShow(new Show($.parseJSON(data.current)));
        self.nextShow(new Show($.parseJSON(data.next)));

        var rest = $.parseJSON(data.rest);

        for (var i in rest) {
            var show = new Show(rest[i]);
            self.restOfShows.push(show);
        }
    }*/

    function Show(data) {

        this.start_time = new Date(data.start_time).toString('HH:mm');
        this.end_time = new Date(data.end_time).toString('HH:mm');
        this.promo_text = data.promo_text;
        var show = $.parseJSON(data.show);
        this.name = show.name;
        this.logo_id = show.logo_id;
        this.description = show.description;
    }

    function show() {
        $('body').toggleClass("transparent");
        $('.loading').hide();
    }

    ko.applyBindings(new EmbeddedApp());

});