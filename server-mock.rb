require 'em-websocket'
require 'json'

CONFIG = {
  config_for: 2,
  welcome_screen_for: 5,
  skip_calibration: false,
  marker_for: 2,
  markers: ["top left", "top", "top right", "bottom right", "bottom", "bottom left"],
  move_element_after: 2,
  remove_element_after: 6
}

def after(timeout)
  Thread.new do
    sleep timeout
    yield if block_given?
  end
end

EventMachine::WebSocket.start(host: "0.0.0.0", port: 8080) do |ws|
  # helper for sending a custom objects
  send = lambda do |type, message = {}|
    puts "send: [#{type}] #{message.inspect}"
    ws.send({ type: type, message: message }.to_json)
  end
  receive = lambda do |raw|
    json = JSON.parse(raw)
    puts "received: #{json.inspect}"
    [json["type"], json["message"]]
  end

  ws.onopen do
    puts "WebSocket open"
  end

  ws.onmessage do |raw|
    type, message = receive.(raw)

    case type
    when "configure:object_types"
      send.("reconfigured:object_types")

    when "configure:objects"
      send.("reconfigured:objects")

    when "configure:sizing"
      after(CONFIG[:config_for]) do
        send.("reconfigured:sizing")
      end

    when "calibration:listen_to_start"
      after(CONFIG[:welcome_screen_for]) do
        if CONFIG[:skip_calibration]
          send.("calibration:done")
        else
          markers = CONFIG[:markers].dup
          send.("calibration:start", markers: markers)

          markers.shift
          markers.each_with_index do |marker, i|
            delay = (i + 1) * CONFIG[:marker_for]
            after(delay) do
              send.("calibration:next_marker", marker: marker)
            end
          end

          after(CONFIG[:marker_for] * (CONFIG[:markers].count - 1)) do
            send.("calibration:done")
          end
        end
      end

    when "work:init"
      send.("work:start")

      after(0) do
        send.("object:create", name: "lion", type: "small-photo", top: 200, left: 200)
        send.("object:create", name: "simba", type: "small-photo", top: 200, left: 500)
      end

      after(CONFIG[:move_element_after]) do
        send.("object:move", name: "simba", top: 400, left: 700)
      end

      after(CONFIG[:remove_element_after]) do
        send.("object:remove", name: "lion")
      end
    end
  end

  ws.onclose do
    puts "WebSocket closed"
  end
end