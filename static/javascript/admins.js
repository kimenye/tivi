$(document).ready(function() {
    
    var Admin = JS.Class({
        construct: function (data) {
            var self = this;

            self.id = data.id;
            self.email = ko.observable(data.email);
            self.password = ko.observable(data.password);
            self.phone_number = ko.observable(data.phone_number);
        },

        toJSON: function() {
            var _struct = {
                "email" : this.email(),
                "password" : this.password(),
                "phone_number" : this.phone_number()
            };
            if (this.id != null) {
                _.extend(_struct, { "id" : this.id })
            }
            return _struct;
        }

    });
    
    var Subscription = JS.Class({
        construct: function (data) {
            var self = this;

            self.id = data.id;
            self.show_name = ko.observable(data.show_name);
            self.subscriber_id = ko.observable(data.subscriber_id);
            self.show_id = ko.observable(data.show_id);
        },

        toJSON: function() {
            var _struct = {
                "show_name" : this.show_name(),
                "subscriber_id" : this.subscriber_id(),
                "show_id" : this.show_id()
            };
            if (this.id != null) {
                _.extend(_struct, { "id" : this.id })
            }
            return _struct;
        }

    });
    
    
    function AdminsApplication() {
        var self = this;

        self.email = ko.observable();
        self.password = ko.observable();
        self.phone_number = ko.observable();
        self.id = ko.observable(null);
        self.admins = ko.observableArray([]);
        self.misspelt = ko.observableArray([]);
        
        self.loadMisspelt = function() {
            $.ajax({
                type:"GET",
                url:"/api/subscriptions",
                success:function (data) {
                    if (_.isArray(data)) {
                        var models = [];
                        _.each(data, function (item) {
                        	if(item.misspelt) {
                            	models.push(new Subscription(item));
                        	}
                        });
                        self.misspelt(models);
                    }
                }
            });
        }
        
        self.loadAdmins = function() {
            $.ajax({
                type:"GET",
                url:"/api/admins",
                success:function (data) {
                    if (_.isArray(data)) {
                        var models = [];
                        _.each(data, function (item) {
                            models.push(new Admin(item));
                        });
                        self.admins(models);
                    }
                }
            });
        }
        
        self.loadMisspelt();
        self.loadAdmins()
        
        self.newAdmin = function() {
            self.email(null);
            self.password(null);
            self.phone_number(null);
            self.id(null);
            $('#admin-create-modal').modal('show');
        };
        
        self.edit = function(admin) {
            self.email(admin.email());
            self.phone_number(admin.phone_number());
            self.id(admin.id);
            $('#admin-edit-modal').modal('show');
        };
        
        self.resolveSubscription = function(misspelt) {
        	var selectedShowId = $('#show :selected').val();
        	var selectedShowName = $.trim($("#show :selected").text());
        	var url = "/api/resolve_subscription";
                $.ajax({
                    url: url,
                    type: 'post',
                    data: { show_name: selectedShowName, show_id: selectedShowId, subscription_id: misspelt.id }})
                    .success(function (data) {
                        bootbox.alert("Subscription resolved");
            			self.loadMisspelt();
                    });
        };
        
        self.deleteAdmin = function() {
        	$("#admin-edit-modal").modal('hide');
            bootbox.confirm("This action cannot be undone. Are you sure you want to delete the admin?", function(result) {
               if (result) {
                   $.ajax({
                       type: "DELETE",
                       url: "/api/admins/"+ self.id(),
                       success: function(data) {
                           bootbox.alert("Successfully deleted admin");
                           self.loadAdmins();
                       }
                   });
               }
            });
        };
        
        self.createAdmin = function() {
            var _adm = new Admin({ email : self.email(), password : self.password(), phone_number : self.phone_number() });
            var _str = JSON.stringify(_adm.toJSON());
            $.post('/api/admins', _str,
                function(data) {
                    _.extend(_adm, { id: data});
                    self.admins.push(_adm);
                    self.closeModal("#admin-create-modal","Successfully added new admin " + self.email());
                });
                self.loadAdmins();
        };
        
        self.editAdmin = function() {
        	var _adm = new Admin({ email : self.email(), phone_number : self.phone_number() });
            var _str = JSON.stringify(_adm.toJSON());
            
            var url = "/api/admins/" + self.id();
            $.ajax({
                url: url,
                type: 'PATCH',
                data: _str})
                .success(function (data) {
                    self.closeModal("#admin-edit-modal", "Successfully updated admin");
                });
                self.loadAdmins();

        };
        
        self.closeModal = function(modal, msg) {
            $(modal).modal('hide');
            bootbox.alert(msg);
        };

    }

    
    if ($('#admins-div').length > 0)
        ko.applyBindings(new AdminsApplication(), $("#admins-div")[0]);

});