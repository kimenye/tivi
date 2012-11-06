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
};