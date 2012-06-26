var Channel = JS.Class({
   construct: function (data) {
       var self = this;

       self.id = data.id;
       self.code = ko.observable(data.code);
       self.name = ko.observable(data.name);
   }
});

function ChannelsApplication() {
    var self = this;

    self.channels = ko.observableArray([]);
    self.code = ko.observable();
    self.name = ko.observable();
    self.id = ko.observable(null);

    self.edit = function(channel) {
        console.log("In edit");
        self.code(channel.code());
        self.name(channel.name());
        self.id(channel.id);
    }

    self.buttonState = ko.computed(function() {
        console.log(self.id());
        if (self.id() == null)
            return "Create";
        else
            return "Update"
    });

    self.createOrUpdate = function() {
        if (self.id() == null) {
            $.ajax({
                type: "POST",
                url: "/api/channels",
                data: "",
                dataType: "json",
                success: function(data) {
                    console.log("Successfully created the record");
                }
            })
        }
        else
        {
            //updating a channel
        }
    }

    Sammy(function() {


        this.get('', function() {
            console.log('In the root path');

            $.ajax({
                type: "GET",
                url: "/api/channels",
                success: function(data) {
                    console.log("Success" + data);
                    if (_.isArray(data)) {
                        var models = [];
                        _.each(data, function(item) {
                            models.push(new Channel(item));
                        })
                        self.channels(models);
                    }
                }
            });
        });

    }).run();

}

$(document).ready(function() {
    ko.applyBindings(new ChannelsApplication(), $("#channels-div")[0]);
});