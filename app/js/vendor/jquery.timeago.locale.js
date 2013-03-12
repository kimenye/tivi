$(document).ready(function() {
    jQuery.timeago.settings.allowFuture = true;

    jQuery.timeago.settings.strings = {
        prefixAgo: null,
        prefixFromNow: null,
        suffixAgo: "ago",
        suffixFromNow: "",
        seconds: "now",
        minute: "in %d min",
        minutes: "in %d min",
        hour: "in an hour",
        hours: "in %d hours",
        day: "in a day",
        days: "in %d days",
        month: "in a month",
        months: "in %d months",
        year: "in about a year",
        years: "%d years",
        wordSeparator: " ",
        numbers: []
    };
});