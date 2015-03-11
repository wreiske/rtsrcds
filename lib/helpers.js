if (Meteor.isClient) {
Template.registerHelper('reactiveTime', function() {
    return moment(this.createdAt).from(TimeSync.serverTime());
});
}