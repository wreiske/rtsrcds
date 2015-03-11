Players = new Mongo.Collection('Players');
EventLog = new Mongo.Collection('EventLog');
ChatLog = new Mongo.Collection('ChatLog');
var debug_output = true;

function log_debug(ret) {
    if (debug_output) {
        console.log('rtSRCDS DEBUG:', ret);
    }
}
if (Meteor.isServer) {
    Meteor.startup(function() {
        Meteor.publish('Players', function() {
            return Players.find({}, {
                sort: {
                    createdAt: -1
                }
            });
        });
        Meteor.publish('EventLog', function() {
            return EventLog.find({}, {
                sort: {
                    createdAt: -1
                },
                limit: 15
            });
        });
        Meteor.publish('ChatLog', function() {
            return ChatLog.find({
                'event': 'player_say'
            }, {
                sort: {
                    createdAt: -1
                },
                limit: 15
            });
        });
    });
}

Router.map(function() {
    this.route('dashboard', {
        path: '/',
    });
});

Router.route('/api', {
    where: 'server'
})
    .get(function() {
        this.response.end('Get requests are not supported in rtSRCDS.\n');
    })
    .post(function() {
        var req = this.request;
        var res = this.response;
        var now = new Date().valueOf();
        var eventJson = JSON.parse(req.body.json);

        eventJson.createdAt = now;

        if (debug_output) {
            log_debug(eventJson);
        }

        if (eventJson.event == 'OnClientAuthorized') {
            if (Players.findOne({
                'steamid': eventJson.content.community_id
            })) {
                log_debug('FOUND PLAYER!');
            } else {
                log_debug('Player not found... Querying Steam API...');
                Meteor.http.call('GET', 'http://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/?key=STEAM_API_KEY&steamids=' + eventJson.content.community_id, function(error, result) {
                    if (result.statusCode == 200) {
                        var steamApiRes = result.data;
                        log_debug(steamApiRes.response.players[0]);
                        Players.insert(steamApiRes.response.players[0]);
                        log_debug('Added player to Players collection.');
                    } else {
                        log_debug(error);
                    }
                });
            }
        }

        //event switch:
        switch (eventJson.event) {
            case 'player_say':
                ChatLog.insert(eventJson);
                break;
            default:
                EventLog.insert(eventJson);
        }

        res.end('Logged event ('+eventJson.event+')! Thanks for using rtSRCDS.\n');
    });