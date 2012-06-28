$(document).ready(function() {
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
        self.msg = ko.observable();
        self.editable = ko.observable(null);

        self.edit = function(channel) {
            console.log("In edit");
            self.code(channel.code());
            self.name(channel.name());
            self.id(channel.id);
            self.editable(channel);
            $('#edit-modal').modal('show');
        };

        self.buttonState = ko.computed(function() {
            if (self.id() == null)
                return "Create";
            else
                return "Update"
        });

        self.createOrUpdate = function() {
            var _chan = new Channel({ code : self.code(), name: self.name()});
            var _str = JSON.stringify(_chan.toJSON());
            if (self.id() == null) {
                $.post('/api/channels', _str,
                    function(data) {
                        _.extend(_chan, { id: data});
                        self.channels.push(_chan);
                        self.closeModal("Successfully added new channel " + self.name());
                    });
            }
            else
            {
                var url = "/api/channels/" + self.id();
                $.ajax({
                    url: url,
                    type: 'PATCH',
                    data: _str})
                    .success(function (data) {
                        self.editable().code(self.code());
                        self.editable().name(self.name());
                        self.editable(null);
                        self.closeModal("Successfully updated channel " + self.name());
                    });
            }

        };

        self.closeModal = function(msg) {
            $('#edit-modal').modal('hide');
            self.msg(msg);
            setTimeout(function(){
                self.msg(null);
            }, 2000 );

        };

        self.loadChannels = function() {
            $.ajax({
                type:"GET",
                url:"/api/channels",
                success:function (data) {
                    console.log("Success" + data);
                    if (_.isArray(data)) {
                        var models = [];
                        _.each(data, function (item) {
                            models.push(new Channel(item));
                        });
                        self.channels(models);
                    }
                }
            });
        }

        self.loadChannels();
    }

    if ($('#channels-div').length > 0)
        ko.applyBindings(new ChannelsApplication(), $("#channels-div")[0]);
});