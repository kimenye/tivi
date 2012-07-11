glow.ready(function() {
    console.log("Glow is ready");

    var channelId = $('')


//    function _dFormat(d) {
//        return (d.getHours()   / 100).toFixed(2).split('.')[1] +
//            ":" +
//            (d.getMinutes() / 100).toFixed(2).split('.')[1];
//    }
//
//    function scaleMe(data) {
//        var start = data.start,
//            hours = Math.floor(data.start.valueOf() / 3600000) % 24,
//            ampm = ["am", "pm"][Math.floor(hours / 12)],
//            hh = ((hours - 24) % 12) + 12;
//
//        return hh + ampm;
//    }
//
//    var tt = new glow.widgets.Timetable(
//        "#timetable",
//        "1 January 2009 00:00", "1 January 2009 11:00",
//        "1 January 2009 00:30", "1 January 2009 02:30",
//        {
//            keepItemContentInView: true,
//            vertical: false,
//            size: 600,
//            itemTemplate: function(item) {
//                return glow.lang.interpolate(
//                    "<" + "strong>{trackTitle}, {title}</" + "strong><" + "br/>{start} to {end}",
//                    {
//                        trackTitle: item.track.title,
//                        title: item.title,
//                        start: _dFormat(item.start),
//                        end: _dFormat(item.end),
//                        id: item.id.substring(glow.UID.length + 14)
//                    }
//                );
//            },
//            trackHeader: "<" + "h2>{title}<" + "/h2>",
//            collapseTrackBorders: false,
////            trackFooter: "<" + "p>{title} footer<" + "/p>",
//            tracks: [
//                ["Monday", 50, {items: [["Item 1", "1 January 2009 00:00", "1 January 2009 01:00"], ["Item 2", "1 January 2009 01:00", "1 January 2009 07:00"], ["Item 3", "1 January 2009 07:00", "1 January 2009 09:00"], ["Item 4", "1 January 2009 09:00", "1 January 2009 10:45"]]}],
//                ["Tuesday", 50, {items: [["Item 1", "1 January 2009 00:00", "1 January 2009 03:00"], ["Item 2", "1 January 2009 03:00", "1 January 2009 06:00"], ["Item 3", "1 January 2009 06:00", "1 January 2009 08:00"], ["Item 4", "1 January 2009 08:00", "1 January 2009 10:45"]]}],
//                ["Wednesday", 50, {items: [["Item 1", "1 January 2009 00:00", "1 January 2009 03:00"], ["Item 2", "1 January 2009 03:00", "1 January 2009 06:00"], ["Item 3", "1 January 2009 06:00", "1 January 2009 08:00"], ["Item 4", "1 January 2009 08:00", "1 January 2009 10:45"]]}],
//                ["Thursday", 50, {items: [["Item 1", "1 January 2009 00:00", "1 January 2009 03:00"], ["Item 2", "1 January 2009 03:00", "1 January 2009 06:00"], ["Item 3", "1 January 2009 06:00", "1 January 2009 08:00"], ["Item 4", "1 January 2009 08:00", "1 January 2009 10:45"]]}],
//                ["Friday", 50, {items: [["Item 1", "1 January 2009 00:00", "1 January 2009 03:00"], ["Item 2", "1 January 2009 03:00", "1 January 2009 06:00"], ["Item 3", "1 January 2009 06:00", "1 January 2009 08:00"], ["Item 4", "1 January 2009 08:00", "1 January 2009 10:45"]]}]
//            ]
//        }
//    ).setBanding("hour")
//        .addScale("hour", "left", 30, {template: scaleMe})
////        .addScrollbar("hour", "right", 15, {template: scaleMe})
//        .draw();
});