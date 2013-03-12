$(document).ready(function() {

    SHOTGUN.listen("resize", function() {
        var height = $('#guide').height();
        height += 20;
        window.parent.postMessage(['setHeight', height], '*');
    });
});