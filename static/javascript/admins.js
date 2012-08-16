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
    
    
    function AdminsApplication() {
        var self = this;

        self.email = ko.observable();
        self.password = ko.observable();
        self.phone_number = ko.observable();
        self.id = ko.observable(null);
        self.msg = ko.observable();
        self.editable = ko.observable(null);
        self.admins = ko.observableArray([]);
        
        self.newAdmin = function() {
            self.email(null);
            self.password(null);
            self.phone_number(null);
            self.id(null);
            self.editable(null);
            $('#admin-create-modal').modal('show');
        };
        
        self.edit = function(admin) {
            self.email(admin.email());
            self.phone_number(admin.phone_number());
            self.id(admin.id);
            self.editable(admin);
            $('#admin-edit-modal').modal('show');
        };
        
        self.deleteAdmin = function(admin) {
            bootbox.confirm("This action cannot be undone. Are you sure you want to delete the admin?", function(result) {
               if (result) {
                   $.ajax({
                       type: "DELETE",
                       url: "/api/admins/"+ admin.id,
                       success: function(data) {
                           bootbox.alert("Successfully deleted admin");
                           self.loadAdmins();
                       }
                   });
               }
            });
        }
        
        self.createAdmin = function() {
            var adm = new Admin({ email : self.email(), password : self.password(), phone_number : phone_number() });
            var _str = JSON.stringify(_adm.toJSON());
            $.post('/api/admins', _str,
                function(data) {
                    _.extend(_adm, { id: data});
                    self.admins.push(_adm);
                    self.closeModal("#admin-create-modal","Successfully added new admin " + self.email());
                });
        };
        
        self.editAdmin = function() {
        	var adm = new Admin({ email : self.email(), phone_number : phone_number() });
            var _str = JSON.stringify(_adm.toJSON());
            
            var url = "/api/admins/" + self.id();
            $.ajax({
                url: url,
                type: 'PATCH',
                data: _str})
                .success(function (data) {
                    self.editable().email(self.email());
                    self.editable().phone_number(self.phone_number());
                    self.editable(null);
                    self.closeModal("#admin-edit-modal", "Successfully updated admin");
                });

        };
        
        self.closeModal = function(modal, msg) {
            $(modal).modal('hide');
            bootbox.alert(msg);
        };
        
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

    }

    
    if ($('#admins-div').length > 0)
        ko.applyBindings(new AdminsApplication(), $("#admins-div")[0]);

});