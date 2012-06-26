var Channel = JS.Class({
   construct: function (data) {
       var self = this;

       self.id = data.id;
       self.code = ko.observable(data.code);
       self.name = ko.observable(data.name);
   },

    toJSON: function() {
        var _struct = {
            "code" : this.code(),
            "name" : this.name()
        };
        if (this.id != null) {
            _.extend(_struct, { "id" : this.id })
        }
        return _struct;
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
    };

    self.buttonState = ko.computed(function() {
        if (self.id() == null)
            return "Create";
        else
            return "Update"
    });

    self.createOrUpdate = function() {
        var _chan = new Channel({ code : self.code(), name: self.name()});
        if (self.id() == null) {
            $.post('/api/channels', JSON.stringify(_chan.toJSON()),
                function(data) {
                    console.log("Successfully added channel with id ", data);
                });
        }
        else
        {
            //updating a channel
        }

    };

    Sammy(function() {

        this.post('/api/channels', function() {
            console.log("In the request");
            debugger;
        });

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
                        });
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