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
                return "";
        });

        this.channel_title = ko.observable();

        $.getJSON("/api/guide", function(data) {
            _.each(data, function(c) {
                self.channels.push(new Channel(c));
            });

            self.loading(false);
            $('#channels').bxSlider({
                adaptiveHeight: false,
                mode: 'horizontal',
                nextSelector: '.previous-slide',
                nextText: '',
                prevSelector: '.next-slide',
                prevText: '',
                pager: false,
                onSliderLoad: function(idx) {
                    self.channel_title(self.channels()[idx].name);
                    self.resize();

                },
                onSlideAfter: function(element, oldIdx, newIdx) {
                    self.channel_title(self.channels()[newIdx].name);
                    self.slideIdx(newIdx);
                    self.resize();
                }
            });

            _.each(self.channels(), function(c) {
                //need to check if the current show is null
                if (c.currentShow() != null) {
                    var full_duration = Date.parse(c.currentShow().end_time) - Date.parse(c.currentShow().start_time);
                    var time_passed = new Date() - Date.parse(c.currentShow().start_time);
                    var progress = (time_passed * 100) / full_duration;
//                    console.log(c.code + progress);

                    $( "#pb_" + c.code ).css('width', progress + '%');
                }

            });

            SHOTGUN.listen("resize", function() {
                self.resize();
            });
            self.resize();
        });

        this.resize = function() {
            var idx = this.slideIdx();
            var ch = this.current();
            var bottomMargin = 30;
            var topBarH = 50;
            var height = $('.embedded-guide').height() + bottomMargin;
            var featuredHeight = $('#channel-' + ch + ' .featured').height();
            var accordionHeight = $('#channel-' + ch + ' .accordion').height();
            var aggr = topBarH + featuredHeight + accordionHeight + bottomMargin;
//            console.log("Featured : %d", featuredHeight);
//            console.log("Accordion : %d", accordionHeight);
//            console.log("Current: ", ch);
            console.log("Full height : %d", height);
            console.log("Calcululated: %d", aggr);
            window.parent.postMessage(['setHeight', aggr], '*');
        }

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

        var current = $.parseJSON(data.current);
        if(current) {
            self.currentShow(new Show(current));
        }
        else {
            self.currentShow(null);
        }

        self.nextShow(new Show($.parseJSON(data.next)));

        var rest = $.parseJSON(data.rest);

        for (var i in rest) {
            if (rest[i] != null) {
                var show = new Show(rest[i]);
                self.restOfShows.push(show);
            }
            else
                console.log("Null encountered in ", this.name);
        }
    }

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