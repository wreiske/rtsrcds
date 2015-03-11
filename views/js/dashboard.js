if (Meteor.isClient) {
    Meteor.subscribe('Players');
    Meteor.subscribe('EventLog');
    Meteor.subscribe('ChatLog');

    Template.chat.helpers({
        message: function() {
            // this helper returns a cursor of
            // all of the posts in the collection
            return ChatLog.find();
        },
        dead: function() {
            if (!this.content.isPlayerAlive && this.content.team != 1) {
                return true;
            }
            return false;
        },
        showTeam: function(team) {
            switch (this.content.team) {
                case 1:
                    return 'Spectator';
                    break;
                case 2:
                    return 'Red Team';
                    break;
                case 3:
                    return 'Blue Team';
                    break;
                default:
                    return 'Bad Team'
            }
        },
        teamColor: function() {
            /*
            Todo:
            Create actual team color css instead of using bootstraps alert colors.
            */
            switch (this.content.team) {
                case 1:
                    return 'default';
                    break;
                case 2:
                    return 'danger';
                    break;
                case 3:
                    return 'info';
                    break;
                default:
                    return 'success'
            }
        },
        userInfo: function() {
            return player = Players.findOne({
                'steamid': this.content.community_id
            });
        }
    });
    Template.eventlog.helpers({
        logevent: function() {
            return EventLog.find({}, {
                sort: {
                    createdAt: -1
                },
                limit: 15
            });
        }
    });

    //TODO: Add something like https://github.com/Holek/steam-friends-countries for location data.
    Template.playersOnline.helpers({
        player: function() {
            return Players.find({}, {
                sort: {
                    createdAt: -1
                }
            });
        }
    });
}