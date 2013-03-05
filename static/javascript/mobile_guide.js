$(document).ready(function() {

    function MobileApp() {
        this.loading = ko.observable(true);
        this.channels = ko.observableArray([]);
        var self = this;
        $.getJSON("/api/guide", function(data) {
            _.each(data, function(c) {
                self.channels.push(new Channel(c));
            });

            self.loading(false);

            window.mySwipe = new Swipe(
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