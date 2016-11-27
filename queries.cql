// Sutton to Blackfriars
MATCH (:Location {name: "SUTTON (SURREY)"})-[:HAS_STOP]->(stop),
      path = (stop)-[:NEXT*]->(finalStop),
      (finalStop)<-[:HAS_STOP]-(:Location {name: "LONDON BLACKFRIARS"})
WITH path LIMIT 1
UNWIND NODES(path) AS stop
MATCH (location:Location)-[:HAS_STOP]->(stop)
RETURN location.name, stop.arrival, stop.departure, stop.passedThrough;

// Sutton to Blackfriars after a certain time
MATCH (:Location {name: "SUTTON (SURREY)"})-[:HAS_STOP]->(stop),
      path = (stop)-[:NEXT*]->(finalStop),
      (finalStop)<-[:HAS_STOP]-(:Location {name: "LONDON BLACKFRIARS"})
WHERE stop.departure > "0738"
WITH path  ORDER BY stop.departure
LIMIT 1
UNWIND NODES(path) AS stop
MATCH (location:Location)-[:HAS_STOP]->(stop)
RETURN location.name, stop.arrival, stop.departure, stop.passedThrough

// fastest route from Sutton to Blackfriars
MATCH (:Location {name: "SUTTON (SURREY)"})<-[:AT]-(start),
      (finish)-[:AT]->(:Location {name: "LONDON BLACKFRIARS"})
CALL apoc.algo.dijkstra(start, finish, 'NEXT>', 'time') YIELD path, weight
RETURN *


MATCH (:Location {name: "SUTTON (SURREY)"})<-[:AT]-(start),
      (finish)-[:AT]->(:Location {name: "LONDON BLACKFRIARS"})
CALL apoc.algo.dijkstra(start, finish, 'NEXT>', 'time') YIELD path, weight
UNWIND NODES(path) AS stop
MATCH (stop)-[:AT]->(station)
RETURN station.name, stop.arrival, stop.departure, stop.passedThrough;

// Sutton to Victoria leaving at 7.30
MATCH (:Location {name: "SUTTON (SURREY)"})<-[:AT]-(start:OutPlatform)

WITH start
WHERE start.departureSecondsSinceStartOfDay > 7*60*60

WITH start
ORDER BY start.departureSecondsSinceStartOfDay
LIMIT 1

MATCH (finish:INPlatform)-[:AT]->(:Location {name: "LONDON VICTORIA"})
CALL apoc.algo.dijkstra(start, finish, 'NEXT>|WAIT>', 'time') YIELD path, weight

WITH path LIMIT 1
UNWIND NODES(path) AS stop
MATCH (stop)-[:AT]->(station)
RETURN station.name, stop.arrival, stop.departure, stop.passedThrough, stop.routeId;


// with platforms
MATCH (:Station {name: "SUTTON (SURREY)"})<-[:AT]-(start:OutPlatform)
WITH start
WHERE start.timeSecondsSinceStartOfDay > 7*60*60
WITH start
ORDER BY start.timeSecondsSinceStartOfDay
LIMIT 1
MATCH (finish:InPlatform)-[:AT]->(:Station {name: "LONDON BLACKFRIARS"})
CALL apoc.algo.dijkstra(start, finish, 'NEXT>|WAIT>', 'time') YIELD path, weight
WITH path LIMIT 1
UNWIND NODES(path) AS node
MATCH fullPath = (node)-[:AT]->(station)
RETURN fullPath

// sutton to victoria
MATCH (:Station {name: "SUTTON (SURREY)"})<-[:AT]-(start:OutPlatform)
WITH start
WHERE start.timeSecondsSinceStartOfDay > 7*60*60
WITH start
ORDER BY start.timeSecondsSinceStartOfDay
LIMIT 1
MATCH (finish:Station {name: "LONDON VICTORIA"})
CALL apoc.algo.dijkstra(start, finish, 'NEXT>|WAIT>|AT>', 'time') YIELD path, weight
WITH path LIMIT 1
UNWIND [x in nodes(path) WHERE x:Stop | x ] AS stop
MATCH (stop)-[:AT]->(location)
WITH stop.routeId AS route, location, COLLECT(stop) AS stops
RETURN location.name,
       route,
       CASE WHEN SIZE(stops) = 2 THEN stops[1].time ELSE stops[0].time END AS time
ORDER BY stops[0].time

// sutton to guildford
MATCH (:Station {name: "SUTTON (SURREY)"})<-[:AT]-(start:OutPlatform)
WHERE start.timeSecondsSinceStartOfDay > 7*60*60
WITH start
ORDER BY start.timeSecondsSinceStartOfDay
LIMIT 1
MATCH (finish:Station {name: "GUILDFORD"})
CALL apoc.algo.dijkstra(start, finish, 'NEXT>|WAIT>|AT>', 'time') YIELD path, weight
WITH path LIMIT 1
UNWIND [x in nodes(path) WHERE x:Stop | x ] AS stop
MATCH newPath = (stop)-[:AT]->(location)
return newPath, path

// nicer format for quick view
MATCH (:Station {name: "SUTTON (SURREY)"})<-[:AT]-(start:OutPlatform)
WITH start
WHERE start.timeSecondsSinceStartOfDay > (7*60*60) + (37*60)
WITH start
ORDER BY start.timeSecondsSinceStartOfDay
LIMIT 1
MATCH (finish:Station {name: "LONDON BLACKFRIARS"})
CALL apoc.algo.dijkstra(start, finish, 'NEXT>|WAIT>|AT>', 'time') YIELD path, weight
RETURN [x in nodes(path) WHERE x:Stop | [x.id, x.time] ], weight


// Hangs forever
MATCH (start:OutPlatform {id: "W72901_SUTTON_out"})
MATCH (finish:Station {name: "DORKING"})
CALL apoc.algo.dijkstra(start, finish, 'NEXT>|WAIT>|AT>', 'time') YIELD path, weight
WITH path ORDER BY weight  LIMIT 1
return path

// adding lat/lon for some A* fun
load csv with headers from "file:///locations.csv" AS row
MATCH (stop:Location {code: row.code})
WITH stop, toFloat(row.lat) AS lat, toFloat(row.lon) AS lon
SET stop.lat = lat, stop.lon = lon;

CALL apoc.periodic.iterate(
  'MATCH (location:Location) WHERE EXISTS(location.lat) AND EXISTS(location.lon) RETURN location',
  'WITH {location} AS location
   MATCH (location)<-[:AT]-(platform)
   SET platform.lon = location.lon, platform.lat = location.lat',
  {batchSize:100,parallel:false})
YIELD batches, total;

MATCH (:Station {name: "SUTTON (SURREY)"})<-[:AT]-(start:OutPlatform)
WITH start
WHERE start.timeSecondsSinceStartOfDay > (18*60*60)
WITH start
ORDER BY start.timeSecondsSinceStartOfDay
LIMIT 1
MATCH (finish:Station {name: "LEATHERHEAD"})
CALL apoc.algo.aStar(start, finish, 'NEXT>|WAIT>|AT>', 'time', 'lat', 'lon') YIELD path, weight
WITH path ORDER BY weight  LIMIT 1
return path

// find stations that don't have lat/lon and the stations either side don't either
match (s:Stop)
WHERE NOT EXISTS(s.lat)
optional match (s)-[:NEXT]->(next)
optional match (prev)-[:NEXT]->(s)
WITH s, prev, next
WHERE NOT(EXISTS(prev.lat)) AND NOT(EXISTS(next.lat))
return DISTINCT s.id, next.id, prev.id

// update locations from stops
MATCH (location:Location)
WHERE NOT EXISTS(location.lat)
MATCH (location)<-[:AT]-(stop)
WHERE EXISTS(stop.lat)
WITH location, COLLECT(stop)[0] AS stop
SET location.lat = stop.lat, location.lon = stop.lon

// check for negative times between stops
match (prev)-[rel:NEXT|:WAIT]->(next)
WHERE rel.time < 0
return prev, rel.time, TYPE(rel),  next

// find if there are any routes with duplicate positions
match (route:Route)-[:HAS_STOP|:PASSED_THROUGH]-(stop {position: 0})
WITH route, COUNT(*) AS stops
WHERE stops > 1
RETURN route.id, stops

// fill in locations with the locations of their stops
CALL apoc.periodic.iterate(
  'MATCH (location:Location) WHERE NOT EXISTS(location.lat) RETURN location',
  'WITH {location} AS location
   match (location)<-[:AT]-(stop)
   WHERE EXISTS(stop.lat)
   WITH location, stop
   LIMIT 1
   SET location.lat = toFloat(stop.lat), location.lon = toFloat(stop.lon)
   RETURN COUNT(*)',
  {batchSize:1000,parallel:true})
YIELD batches, total;

// fill in stops with the locations of their location
CALL apoc.periodic.iterate(
  'MATCH (stop:Stop) WHERE NOT EXISTS(stop.lat) RETURN stop',
  'WITH {stop} AS stop
   match (location)<-[:AT]-(stop)
   WHERE EXISTS(location.lat)
   SET stop.lat = toFloat(location.lat), stop.lon = toFloat(location.lon)
   RETURN COUNT(*)',
  {batchSize:1000,parallel:true})
YIELD batches, total;

// more missing lat/longs
load csv with headers from "file:///extrapolatedLatLons.csv" AS row
MATCH (stop:Location {code: row.code})
WITH stop, toFloat(row.lat) AS lat, toFloat(row.lon) AS lon
SET stop.lat = lat, stop.lon = lon;
