# CSMH

### What is CSMH?
CSMH is a Client and Server Message Handler framework for communication between Eluna and the WoW interface. It has been tested on Mangos and TrinityCore 3.3.5a, but it will probably work for other versions as well.

CSMH consists of two parts, the Client Message Handler and the Server Message Handler respectively.

### How does this compare to AIO?
While AIO is the most used solution of this kind, it has its drawbacks as well. While it allows you to write all your code server-side, it also limits you to the Lua API only. AIO also sends the full addon code to the client on startup and reload, which is fairly network intensive. Upside of AIO is its ease of distribution compared to dedicated client-side addons.

CSMH is only meant to transport data between the client and the server, and is therefore not as network intensive as AIO. You write your server-side code on the server, and you distribute your client-side code either as an addon, or in a patch. This allows you to use XML and templates, as well as the full Lua API.

Both AIO and CSMH uses smallfolk for serialization, and is compatible with each other. You can use both AIO and CSMH in the same project.

### What does CSMH do and *not* do?
CSMH intentionally does not do certain things, primarily for ease of integration and personal preferences around implementations like; Flood protection, data validation, packet filtering etc.

CSMH **does** verify the sender and recipient of a message, to prevent messages being sent and accepted on someone else's behalf.

CSMH **does not** natively check and verify what is being sent to and from the client and server. It is up to you to sanity check data being sent back and forth. A good rule of thumb is to never inherently trust data being sent to the server from the client, you need to verify data before accepting it.

CSMH also **does not** have any form of built in flood protection. This is again up to you to decide on an implementation  of your choice.

### How do I use CSMH?
I would recommend going through the examples provided in this repo to get a feel for how registering, sending and receiving data on both the client and the server works. A full API and how-to will be posted soon™.

## Installation:

### Server:
- Copy everything from the Server directory to your Eluna scripts directory. That's it!

### Client:
The CMH can be distributed either as a stand-alone addon, or through a patch. Files are provided for both solutions in the Client directory, but be aware of the differences:

#### Addon:
- Copy **CMH.Lua**, **CMH.toc** and **smallfolk.lua** to **Interface\AddOns\CMH**

#### MPQ Patch:
- Copy **CMH.Lua**, **FrameXML.toc** and **smallfolk.lua** to **Interface\FrameXML**

## API:
Soon™

## Credits:
- [Stoneharry](https://github.com/stoneharry)
- [Terrorblade](https://github.com/Terrorblade)
- Kaev
- [Rochet / AIO](https://github.com/Rochet2)
- [Eluna](https://github.com/ElunaLuaEngine/Eluna)
- [smallfolk](https://github.com/gvx/Smallfolk)