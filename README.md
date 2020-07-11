# GaugeServer
Raspberry Pi DHT11 temperature and humidity server in LCARS HTML and JSON formats. Free Pascal/Lazarus.

## Intro
I have accumulated Raspberry Pis over the years. One to run my website, another as the beta development machine. As I've upgraded those Pis, I've tried to find uses for the previous ones. 

#### Star Trek LCARS-inspired in HTML (See Resources)
![Web page](/GaugeServer.jpg)

#### JSON format
```json
{"hostname":"BETABANG","temp":"29","hum":"33","time":"10-7-20 23:26:56"}
```

## IoT security caution
I recommend against exposing this server directly to the Internet; keep it behind a router on the LAN. For example, there is currently no protection against URLs with relative paths that access files outside the project. There may be other issues.

## Resources
* [Device Trees, overlays, and parameters](https://www.raspberrypi.org/documentation/configuration/device-tree.md)
* [From Data to Graph. a Web Journey With Flask and SQLite](https://www.instructables.com/id/From-Data-to-Graph-a-Web-Jorney-With-Flask-and-SQL/), mjrovai.
* [LCARS CSS Grid](https://home.hmt3design.com/wp-content/projects/lcars_css_grid/)
* [3926 Free "Farm-Fresh Web Icons" by FatCow Web Hosting](https://www.fatcow.com/free-icons)
