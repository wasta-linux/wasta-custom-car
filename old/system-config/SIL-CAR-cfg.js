// Thunderbird preferences set by SIL-CAR

// Default to sort descending instead of ascending
pref("mailnews.default_news_sort_order", 2);
pref("mailnews.default_sort_order", 2);

// Limit auto-download size of new messages
pref("mail.server.server1.limit_offline_message_size", true);
pref("mail.server.server1.max_size", 1024);
pref("mail.server.server2.limit_offline_message_size", true);
pref("mail.server.server2.max_size", 1024);

// Auto-detect network state
pref("offline.autoDetect", true);

// Disable sharing of telemetry data
pref("toolkit.telemetry.prompted", 2);

// Accept lightning calendar integration
pref("calendar.integration.notify", false);
