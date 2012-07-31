$(document).ready(function() {
    var Channel = JS.Class({
        construct: function (data) {
            var self = this;

            self.id = data.id;
            self.code = ko.observable(data.code);
            self.name = ko.observable(data.name);
            self.calendar_id = ko.observable(data.calendar_id);
            self.shows = ko.observableArray([]);
        },

        toJSON: function() {
            var _struct = {
                "code" : this.code(),
                "name" : this.name(),
                "calendar_id" : this.calendar_id()
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
        self.calendar_id = ko.observable();
        self.id = ko.observable(null);
        self.msg = ko.observable();
        self.editable = ko.observable(null);
        self.selected = ko.observable(null);
        self.showName = ko.observable(null);
        self.showChannel = ko.observable(null);
        self.showDescription = ko.observable(null);
        self.showId = ko.observable(null);
        self.editableShow = ko.observable(null);


        //TODO: We can make this common between the different things we are editing
        self.edit = function(channel) {
            self.code(channel.code());
            self.name(channel.name());
            self.calendar_id(channel.calendar_id());
            self.id(channel.id);
            self.editable(channel);
            $('#channel-edit-modal').modal('show');
        };

        self.newChannel = function() {
            self.code(null);
            self.name(null);
            self.calendar_id(null);
            self.id(null);
            self.editable(null);
            $('#channel-edit-modal').modal('show');
        };

        self.newShow = function() {
            self.showName(null);
            self.showDescription(null);
            self.showId(null);
            self.editableShow(null);
            $('#show-edit-modal').modal('show');
        }

        self.editShow = function(show) {
            self.showName(show.name());
            self.showDescription(show.description());
            self.showId(show.id);
            self.editableShow(show);
            $('#show-edit-modal').modal('show');
        };

        self.buttonState = ko.computed(function() {
            if (self.id() == null)
                return "Create";
            else
                return "Update";
        });

        self.backHome = function() {
            self.selected(null);
        }

        self.createOrUpdateShow = function() {
            var _show = new Show({ name: self.showName(), description: self.showDescription(), channel: self.showChannel().id });
            var _str = JSON.stringify(_show.toJSON());

            if (self.showId() == null) {
                $.post('/api/shows', _str,
                    function(data) {
                        _.extend(_show, {id: data});
                        if (self.selected().id == self.showId())
                            self.selected().shows.push(_show);
                        self.closeModal("#show-edit-modal", "Successfully added new show " + self.showName());
                    });
            }
            else {
                var url = "/api/shows/" + self.showId();
                $.ajax({
                    url: url,
                    type: 'PATCH',
                    data: _str
                })
                    .success(function(data) {
                        self.editableShow().name(self.showName());
                        self.editableShow().description(self.showDescription());
                        self.editableShow(null);
                        self.closeModal("#show-edit-modal", "Successfully updated show " + self.showName());
                    });
            }
        };

        self.createOrUpdate = function() {
            var _chan = new Channel({ code : self.code(), name: self.name(), calendar_id: self.calendar_id()});
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
                        self.editable().calendar_id(self.calendar_id());
                        self.editable(null);
                        self.closeModal("#channel-edit-modal", "Successfully updated channel " + self.name());
                    });
            }

        };

        self.closeModal = function(modal, msg) {
            $(modal).modal('hide');
            bootbox.alert(msg);
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
                }
            });
        }

        self.reset = function() {
            bootbox.confirm("You will lose the currently saved information. Are you sure you want to reset?", function(result) {
                if (result) {
                    $.ajax({
                        type: "GET",
                        url: "/api/reset?username=guide@tivi.co.ke&password=sproutt1v!&create=true",
                        success: function(data) {
                            self.loadChannels();
                            self.showMsg("Reset the application");
                        }
                    });
                }
            });
        }

        self.syncSchedule = function(channel) {
            var btn = "#" + channel.code();
            $(btn).button('loading');
            $.ajax({
                type: "POST",
                url: "/api/channels/sync/" + channel.id,
                success: function(data) {
                    $(btn).button('reset');
                    bootbox.alert("Synced the schedule for channel " + channel.code());
                }
            })
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
    }

    if ($('#channels-div').length > 0)
        ko.applyBindings(new ChannelsApplication(), $("#channels-div")[0]);
});