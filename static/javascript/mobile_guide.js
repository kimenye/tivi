$(document).ready(function() {

    function MobileApp() {
        this.loading = ko.observable(true);
    }

    ko.applyBindings(new MobileApp());
});