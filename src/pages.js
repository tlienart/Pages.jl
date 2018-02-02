"use strict";

var Pages = (function () {

    var location = window.location,
        route = location.pathname,
        href = location.href;

    function uuid4() {
        return ([1e7]+-1e3+-4e3+-8e3+-1e11).replace(/[018]/g, c =>
            (c ^ crypto.getRandomValues(new Uint8Array(1))[0] & 15 >> c / 4).toString(16)
        )
    }
    var id = uuid4();

    var sock = new WebSocket("ws"+href.substr(4,href.length));
    sock.onmessage = function( message ){
        var msg = JSON.parse(message.data);
        var type = msg.type,
            data = msg.data;
        switch(type) {
            case "script":
                eval(data);
                break
            case "say":
                console.log(data);
                break
        }
    }
    
    function callback(name,args) {
        sock.send(JSON.stringify({"id":id,"name":name,"route":route,"args":args}))
    }
    function notify(name) {
        callback("notify",name);
    }
    function message(id,type,data) {
        callback("message",{"id":id,"type":type,"data":data});
    }
    function broadcast(type,data) {
        callback("broadcast",{"type":type, "data":data});
    }

    sock.onopen = function () {
        callback("connected");
    };

    window.onbeforeunload = function () {
        callback("unloaded");
    };

    var addget = function (c, name) {
		Object.defineProperty(c, name, {
			get: function () { return eval(name); },
			enumerable: true,
			configurable: true
		});
		return c;
	};

    var c = {};
    c = addget(c, "sock");
    c = addget(c, "notify");
    c = addget(c, "message");
    c = addget(c, "broadcast");
    c = addget(c, "callback");
	return c;
})();