$(document).ready(function() {
//    jQuery.timeago.settings.allowFuture = true;

    function MobileApp() {
        this.loading = ko.observable(true);
        this.channels = ko.observableArray([]);
        var self = this;
        $.getJSON("/api/guide", function(data) {
            _.each(data, function(c) {
                self.channels.push(new Channel(c));
            });

            self.loading(false);

            _.each(self.channels(), function(c) {
                if (c.currentShow() != null) {
                    var full_duration = Date.parse(c.currentShow().end_time) - Date.parse(c.currentShow().start_time);
                    var time_passed = new Date() - Date.parse(c.currentShow().start_time);
                    var progress = (time_passed * 100) / full_duration;

                    $( "#pb_" + c.code ).css('width', progress + '%');
                }

            });

            self.slider = new Swipe(
                document.getElementById('guide')
            );
        });
    }

    ko.applyBindings(new MobileApp());

//    function hideAddressBar()
//    {
//        if(!window.location.hash)
//        {
//            if(document.height < window.outerHeight)
//            {
//                document.body.style.height = (window.outerHeight + 50) + 'px';
//            }
//
//            setTimeout( function(){ window.scrollTo(0, 1); }, 50 );
//        }
//    }
//
//    window.addEventListener("load", function(){ if(!window.pageYOffset){ hideAddressBar(); } } );
//    window.addEventListener("orientationchange", hideAddressBar );
});