$(document).ready(function() {
    var chanId = null;
    var showId = null;

    var Channel = JS.Class({
        construct: function (data) {
            var self = this;

            self.id = data.id;
            self.code = ko.observable(data.code);
            self.name = ko.observable(data.name);
            self.enabled = ko.observable(data.enabled);
            self.calendar_id = ko.observable(data.calendar_id);
            self.shows = ko.observableArray([]);
            self.logo_id = ko.observable(data.logo_id);
        },

        toJSON: function() {
            var _struct = {
                "code" : this.code(),
                "name" : this.name(),
                "enabled" : this.enabled(),
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
            self.show_logo_id = ko.observable(data.logo_id);
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
        self.enabled = ko.observable();
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
        self.logo_id = ko.observable('');
        self.get_logo_id = ko.computed(function() {
            return "/media/images/" + self.logo_id();
        }, self);
        self.show_logo_id = ko.observable('');
        self.get_show_logo_id = ko.computed(function() {
            return "/media/images/" + self.show_logo_id();
        }, self);


        //TODO: We can make this common between the different things we are editing
        self.edit = function(channel) {
            self.code(channel.code());
            self.name(channel.name());
            self.enabled(channel.enabled());
            self.calendar_id(channel.calendar_id());
            self.id(channel.id);
            self.editable(channel);
            $('#channel-edit-modal').modal('show');
        };

        self.newChannel = function() {
            self.code(null);
            self.name(null);
            self.enabled(false);
            self.calendar_id(null);
            self.id(null);
            self.editable(null);
            $('#channel-edit-modal').modal('show');
        };

        self.changeChannelLogo = function(channel) {
            chanId = channel.id;
            self.logo_id(channel.logo_id());
            $('#channel-image-upload-modal').modal('show');
        };

        self.changeShowLogo = function(show) {
            showId = show.id;
            self.show_logo_id(show.show_logo_id());
            $('#show-image-upload-modal').modal('show');
        };


        self.delete = function(channel) {
            bootbox.confirm("You will lose the currently saved shows and schedule data. Are you sure you want to delete " + channel.code() + "?", function(result) {
                if (result) {
                    $.ajax({
                        type : "DELETE",
                        url : "/api/channels/" + channel.id,
                        success: function(data) {
                            bootbox.alert("Successfully deleted " + channel.code());
                            self.loadChannels();
                        }
                    });
                }
            });
        };

        self.deleteShow = function(show) {
            bootbox.confirm("You will lose the currently saved subscriptions for this show. Are you sure you want to delete " + show.name() + "?", function(result) {
               if (result) {
                   $.ajax({
                       type: "DELETE",
                       url: "/api/shows/"+ show.id,
                       success: function(data) {
                           bootbox.alert("Successfully deleted " + show.name());
                           self.selectChannel(self.channel());
                       }
                   });
               }
            });
        }

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

        self.subscribeToShow = function(show) {
            bootbox.prompt("Enter the subscription phone number:", function(result) {

                if (result != null && result.length > 0) {
                    var _str = JSON.stringify({phone_number: result});
                    $.post('/api/shows/subscribers/' +show.id, _str,
                        function(data) {
                            bootbox.alert("Successfully subscribed " + result + " to " + show.name());
                        });
                }
            });
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
            var _chan = new Channel({ code : self.code(), name: self.name(), enabled: self.enabled(), calendar_id: self.calendar_id()});
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
                            bootbox.alert("Reset the application");
                        }
                    });
                }
            });
        }

        self.refreshCache = function() {
            bootbox.confirm("Are you sure you want to refresh what is in the cache?", function(result) {
               if (result) {
                   $.ajax({
                       type: "POST",
                       url: "/api/clear_cache",
                       success: function(data) {
                            bootbox.alert("The cache has been reset");
                       }
                   })
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

        var options = {
            //target:        '#output2',   // target element(s) to be updated with server response
            beforeSubmit:  showRequest,  // pre-submit callback
            success:       showResponse,  // post-submit callback
            clearForm: true,        // clear all form fields after successful submit
            resetForm: true,        // reset the form after successful submit
            data: { id: null }
        };

        $('#channel-logo').submit(function() {
            $(this).ajaxSubmit(options);

            return false;
        });

        function showRequest(formData, jqForm, options) {
            options.data.id = chanId;

            return true;
        }

        function showResponse(data)  {

            var jsonObj = $.parseJSON( data );
            self.logo_id(jsonObj.logoId);
        }

        var opt = {
            //target:        '#output2',   // target element(s) to be updated with server response
            beforeSubmit:  showReq,  // pre-submit callback
            success:       showRes,  // post-submit callback
            clearForm: true,        // clear all form fields after successful submit
            resetForm: true,        // reset the form after successful submit
            data: { id: null }
        };

        $('#show-logo').submit(function() {
            $(this).ajaxSubmit(opt);

            return false;
        });

        function showReq(formData, jqForm, options) {
            options.data.id = showId;

            return true;
        }

        function showRes(data)  {
            var jsonObj = $.parseJSON( data );
            self.show_logo_id(jsonObj.logoId);

        }
    }

    if ($('#channels-div').length > 0)
        ko.applyBindings(new ChannelsApplication(), $("#channels-div")[0]);


});