"""
Broadcast a message to all connected web pages to be interpreted by WebSocket listener. For example, in JavaScript:

var sock = new WebSocket('ws://'+window.location.host);
sock.onmessage = function( message ){
    var msg = JSON.parse(message.data);
    console.log(msg);
}
"""
function broadcast(route,args::Dict)
    if haskey(connections,route)
        for (cid,client) in connections[route]
            if isopen(client)
                write(client, json(args))
            end
        end
    end
end
broadcast(r,t,d) = broadcast(r,Dict("type"=>t,"data"=>d)) 

function broadcast(args::Dict)
    for route in keys(connections)
        for (cid,client) in connections[route]
            if isopen(client)
                write(client, json(args))
            end
        end
    end
end
broadcast(t,d) = broadcast(Dict("type"=>t,"data"=>d)) 
broadcast(d) = broadcast(Dict("type"=>"say","data"=>d))

"""
Send a message to the specified connection to be interpreted by WebSocket listener. For example, in JavaScript:

var sock = new WebSocket('ws://'+window.location.host);
sock.onmessage = function( message ){
    var msg = JSON.parse(message.data);
    console.log(msg);
}
"""
function message(route,args::Dict)
    id = pop!(args,"id"); 
    if haskey(connections,route) && haskey(connections[route],id)
        client = connections[route][id]
        if isopen(client)
            write(client,json(args))
        end
    end
end
message(route,mid,mtype,mdata) = message(route,Dict("id" => mid, "type" => mtype, "data" => mdata))
message(route,mid,mdata) = message(route,Dict("id" => mid, "type" => "say", "data" => mdata))

"""
Block Julia control flow until until callback["notify"](name) is called.
"""
function block(f::Function,name)
    conditions[name] = Condition()
    f()
    wait(conditions[name])
    delete!(conditions,name)
    return nothing
end

"""Add a JS library to the current page from a url."""
function add_library(url)
    name = basename(url)
    block(name) do
        Pages.broadcast("script","
            var script = document.createElement('script');
            script.charset = 'utf-8';
            script.type = 'text/javascript';
            script.src = '$(url)';
            script.onload = function() {
                Pages.notify('$(name)');
            };
            document.head.appendChild(script);
        ")
    end
end

mutable struct Element
    id::String
    tag::String
    name::String
    attributes::Dict{String,String}
    style::Dict{String,String}
    innerHTML::String
    parent_id::String

    function Element(;id,tag="div", name="element", attributes=Dict{String,String}(), style=Dict{String,String}(), innerHTML="", parent_id="body")
        new(id,tag,name,attributes,style,innerHTML,parent_id)
    end
end

function update(io::IO,element::Element)
    # Add attributes to element
    for (key,value) in element.attributes
        print(io,"document.getElementById('$(element.id)').setAttribute('$(key)','$(value)');")
    end
    # Add element style
    ioStyle = IOBuffer()
    for (key,value) in element.style
        print(ioStyle,"$(key): $(value);")
    end
    style = String(take!(ioStyle))
    isempty(style) || print(io,"document.getElementById('$(element.id)').setAttribute('style','$(style)');")
    # Add innerHTML to element
    isempty(element.innerHTML) || print(io,"document.getElementById('$(element.id)').innerHTML = '$(element.innerHTML)';")
    return io
end
function update(element::Element)
    script = String(take!(update(IOBuffer(),element)))
    Pages.broadcast("script",script)
end

function append(io::IO,element::Element)
    # Add element if it doesn't already exist
    print(io,"
        var parent = document.getElementById('$(element.parent_id)');
    ")
    if !isempty(element.id)
        print(io,"
            var element = document.getElementById('$(element.id)');
            if (element === null) {
                element = document.createElement('$(element.tag)');
                element.setAttribute('id','$(element.id)');
                parent.appendChild(element);
            };
        ")
    else
        print(io,"parent.appendChild(document.createElement('$(element.tag)'))")
    end
    update(io,element)
end
function append(element::Element)
    script = String(take!(append(IOBuffer(),element)))
    Pages.broadcast("script",script)
end

function remove(io::IO,id::String)
    print(io,"
        var element = document.getElementById('$(id)');
        element.parentNode.removeChild(element);
    ")
    return io
end
function remove(id::String)
    script = String(take!(remove(IOBuffer(),id)))
    Pages.broadcast("script",script)
end

# function add_select(io::IO,options,element::Element)
#     element.tag == "select" || return warn("Element must have tag = select.")
#     add(io,element)
#     remove(io,"option",parent=element.name)
#     # print(io,"""
#     #     $(element.name).selectAll("option").remove();
#     # """)
#     for key in keys(options)
#         print(io,"""
#             $(element.name).append("option").attr("value","$(key)").text("$(options[key])");
#         """)
#     end
#     io
# end
# function add_select(options,element::Element)
#     Pages.broadcast("script",String(take!(add_select(IOBuffer(),options,element))))
# end

# function add_table(io::IO,df::DataFrame;table = Element(tag="table",name="table"),tr = Element(tag="tr",name="row"),th = Element(tag="th",name="header"),td = Element(tag="td",name="cell"))
#     table.tag == "table" || return warn("Element must have tag = table.")
#     tr.tag == "tr" || return warn("Element must have tag = tr.")
#     th.tag == "th" || return warn("Element must have tag = th.")
#     td.tag == "td" || return warn("Element must have tag = td.")
#     add(io,table)
#     remove(io,"tr",parent=table.name)
#     # ==========================================================================
#     # Add header
#     print(io,"""
#         var $(tr.name) = null;
#     """)
#     append(io,tr,parent=table.name)
#     print(io,"""
#         var $(th.name) = null;
#     """)
#     for name in names(df)
#         th.html = string(name)
#         append(io,th,parent=tr.name)
#     end
#     # ==========================================================================
#     # Add data
#     print(io,"""
#         var $(td.name) = null;
#     """)
#     for irow in 1:size(df,1)
#         row = df[irow,:]
#         append(io,tr,parent=table.name)
#         for name in names(df)
#             td.html = string(row[name][1])
#             append(io,td,parent=tr.name)
#         end
#     end
#     io
# end
# function add_table(df::DataFrame;table = Element(tag="table",name="table"),tr = Element(tag="tr",name="row"),th = Element(tag="th",name="header"),td = Element(tag="td",name="cell"))
#     Pages.broadcast("script",String(take!(add_table(IOBuffer(),df,table=table,tr=tr,th=th,td=td))))
# end
