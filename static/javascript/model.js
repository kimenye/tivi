function Channel(data) {
    var self = this;
    var json = $.parseJSON(data.channel);
    this.code = json.code;
    this.name = json.name;
    this.logo = json.logo_id;

    this.currentShow = ko.observable(null);
    this.nextShow = ko.observable(null);
    this.restOfShows = ko.observableArray([]);
    this.timeToNextShow = ko.observable();

    var current = $.parseJSON(data.current);
    if(current)
        self.currentShow(new Show(current));


    var next = $.parseJSON(data.next);
    if (next) {
        self.nextShow(new Show(next));
//        var time_to_next_show = Math.round((new Date(next.start_time) - new Date()) / 60000);
        var time_to_next_show = jQuery.timeago(new Date(next.start_time));
//        console.log("Time : ", time_to_next_show);
        this.timeToNextShow(time_to_next_show);

    }

    var rest = $.parseJSON(data.rest);

    for (var i in rest) {
        if (rest[i] != null) {
            var show = new Show(rest[i]);
            self.restOfShows.push(show);
        }
    }
}

function Show(data) {

    this.start_time = new Date(data.start_time).toString('h:mm tt');
    this.end_time = new Date(data.end_time).toString('h:mm tt');
    this.promo_text = data.promo_text;
    var show = $.parseJSON(data.show);
    this.name = show.name;
    this.logo_id = show.logo_id;
    this.logo_url = "/media/images/" + this.logo_id;
    this.description = show.description;
}