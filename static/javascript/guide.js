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
                adaptiveHeight: true,
                mode: 'horizontal',
                nextSelector: '.next-slide',
                nextText: '',
                prevSelector: '.previous-slide',
                prevText: '',
                //startSlide: 2,
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
            var bottomMargin = 35;
            var topBarH = 50;
            var fHeight = $('.embedded-guide').height() + bottomMargin;
            var featuredHeight = $('#channel-' + ch + ' .featured').height();
            var accordionHeight = $('#channel-' + ch + ' .accordion').height();
            var aggr = topBarH + featuredHeight + accordionHeight + bottomMargin;
//            console.log("Featured : %d", featuredHeight);
//            console.log("Accordion : %d", accordionHeight);
//            console.log("Current: ", ch);
            console.log("Full height : %d", fHeight);
            console.log("Calcululated: %d", aggr);
            var height = Math.max(fHeight, aggr)
            $('.bx-viewport').height(aggr);
            window.parent.postMessage(['setHeight', aggr], '*');
        }

        this.show = function() {

        }
    }

    function show() {
        $('body').toggleClass("transparent");
        $('.loading').hide();
    }

    ko.applyBindings(new EmbeddedApp());

});