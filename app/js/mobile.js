function resolveSubscription(misspelt) {
        var selectedShowId = $('#' + misspelt + ' :selected').val();
        var selectedShowName = $.trim($('#' + misspelt + ' :selected').text());
        var adminId = $('#adminId').val();
        if(selectedShowId === 'no_choice') {
                alert("You must select a show");
                return;
        }
        
    $.ajax({
        url: '/api/resolve_subscription',
        type: 'post',
        data: { show_name: selectedShowName, show_id: selectedShowId, subscription_id: misspelt, admin_id: adminId }})
        .success(function (data) {
            alert("Subscription resolved");
            window.location.reload();
        })
        .error(function(data) {
        	alert("Subscription has already been resolved");
        	window.location.reload();
        });
}

function subscribe(show_id, show_name) {

    var phone_number = prompt('Enter your phone number for reminders', 'Format: 254722123456');

    if(phone_number != null && phone_number.length == 12) {
        var str = JSON.stringify({phone_number: phone_number});

        $.ajax({
            type: 'POST',
            url: '/api/shows/subscribers/' + show_id,
            data:   str})
            .success(function (data) {
                alert("Successfully subscribed " + phone_number + " to " + show_name);
            })
            .error(function(data) {
                alert("Error. The technical team has been notified");
            });
    }
}