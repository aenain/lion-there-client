lion-there-client
=================

[AGH-UST] Simple client for the lion-there-server application written in CoffeeScript to replicate Put That There project from MIT.

We are replicating the project from MIT called Put That There using Kinect this time :)

The main part of the project is a server written in C# using Kinect SDK which communicates with the client using websockets.

lion-there-client is a sample app to present features of the server (https://github.com/KaMyLuS/PTT-Kinect-Server).

Run client application
----------------------

$ ruby client.rb # starts client application on localhost:4567.


Run server mock
---------------

$ ruby server-mock.rb # starts a websocket simulating put that there server on localhost:4649.


Build static html, css, javascripts, etc.
-----------------------------------------

$ ruby build.rb # build a whole package to build directory.
