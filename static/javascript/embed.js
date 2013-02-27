(function(d) {
    var url = "http://www.guide.tivi.co.ke/embed"; //TODO: Make this configurable with localhost
//    var url = "http://localhost:3000/embed"; //TODO: Make this configurable with localhost
    var a = d.createElement("iframe");
    a.setAttribute("allowTransparency","true");
    a.setAttribute("frameBorder", "0");
    a.setAttribute("id","tivi-guide-frame");
    a.setAttribute("width", "100%");
    a.src = url;

    document.getElementById("tivi-guide").appendChild(a);

    //need to listen to window
    if (window.postMessage) {
        if (window.addEventListener) {
            window.addEventListener('message', function(e) {
                var eventName = e.data[0];
                var data = e.data[1];

                console.log("Event name: %s, Data: %s ", eventName, data);

                switch (eventName) {
                    case 'setHeight':
                        $('#tivi-guide-frame').height(data);
                        break;
                }
            } , false);
        }
    }
}) (document);