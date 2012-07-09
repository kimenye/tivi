$(document).ready(function() {
    var Channel = JS.Class({
        construct: function (data) {
            var self = this;

            self.id = data.id;
            self.code = ko.observable(data.code);
            self.name = ko.observable(data.name);
            self.shows = ko.observableArray([]);
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

    var Show = JS.Class({
        construct: function(data) {
            var self = this;
            self.id = data.id;
            self.channelId = data.channel;
            self.name = ko.observable(data.name);
            self.description = ko.observable(data.description);
        },

        toJSON: function() {
            var _struct = {
                "channel": this.channelId,
                "name": this.name(),
                "description": this.description()
            }
            if (this.id != null)
                _.extend(_struct, {"id" : this.id });
            return _struct;
        }
    })


    function ChannelsApplication() {
        var self = this;

        self.channels = ko.observableArray([]);
        self.code = ko.observable();
        self.name = ko.observable();
        self.id = ko.observable(null);
        self.msg = ko.observable();
        self.editable = ko.observable(null);
        self.selected = ko.observable(null);
        self.showName = ko.observable(null);
        self.showChannel = ko.observable(null);
        self.showDescription = ko.observable(null);
        self.showId = ko.observable(null);

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
                return "Update";
        });

        self.createOrUpdateShow = function() {
            var _show = new Show({ name: self.showName(), description: self.showDescription(), channel: self.showChannel().id });
            var _str = JSON.stringify(_show.toJSON());

            console.log("Str is ", _str)

            if (self.showId() == null) {
                debugger;
                $.post('/api/shows', _str,
                    function(data) {
                        _.extend(_show, {id: data});
                        self.selected().shows.push(_show);
                        self.closeModal("#show-edit-modal", "Successfully added new show " + self.showName());
                    });
            }
            else {
                var url = "/api/shows";
            }
        };

        self.createOrUpdate = function() {
            var _chan = new Channel({ code : self.code(), name: self.name()});
            var _str = JSON.stringify(_chan.toJSON());
            if (self.id() == null) {
                $.post('/api/channels', _str,
                    function(data) {
                        _.extend(_chan, { id: data});
                        self.channels.push(_chan);
                        self.closeModal("#channel-edit-modal","Successfully added new channel " + self.name());
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

        self.closeModal = function(modal, msg) {
            $(modal).modal('hide');
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
                    if (_.isArray(data)) {
                        var models = [];
                        _.each(data, function (item) {
                            models.push(new Channel(item));
                        });
                        self.channels(models);
                    }
                    self.selectChannel(_.first(self.channels()));
                }
            });
        }

        self.selectChannel = function(channel) {
            self.selected(channel);

            //the edit channel is to default to the same
            self.showChannel(channel);

            //load shows

            $.ajax({
                type: "GET",
                url: "/api/channels/shows/" + channel.id,
                success: function(data) {
                    if (_.isArray(data)) {
                        var models = [];
                        _.each(data, function(item) {
                            models.push(new Show(item));
                        });
                        self.selected().shows(models);
                    }
                }
            });
        }

        self.loadChannels();
//        Sammy(function() {
//
//            this.get('', function() {
////                self.selectedView(null);
//                self.loadChannels();
//            });
//
//            this.get('#:channel', function() {
//                console.log("Params: ", this.params.channel);
//                self.selectChannel
//            })
//
//        }).run();
    }

    if ($('#channels-div').length > 0)
        ko.applyBindings(new ChannelsApplication(), $("#channels-div")[0]);
});