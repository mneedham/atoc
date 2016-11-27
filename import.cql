CREATE CONSTRAINT ON (l:Location)
ASSERT l.code is unique;

load csv with headers from "file:///locations.csv" AS row
MERGE (l:Location {code: row.code})
ON CREATE SET l.name = row.description;

CREATE CONSTRAINT ON (s:Stop)
ASSERT s.id is unique;

USING PERIODIC COMMIT 10000
load csv with headers from "file:///routes.csv" AS row
MERGE (stop:Stop {id: row.routeId + "_" + row.location})
ON CREATE SET stop.departure = row.departure,
              stop.arrival = row.arrival,
              stop.passedThrough = row.passedThrough,
              stop.position = toInteger(row.position),
              stop.routeId = row.routeId;

USING PERIODIC COMMIT 10000
load csv with headers from "file:///routes.csv" AS row
MATCH (location:Location {code: row.location})
MATCH (stop:Stop {id: row.routeId + "_" + row.location})
MERGE (location)-[:HAS_STOP]->(stop);

MATCH (stop:Stop)
WITH stop ORDER BY stop.routeId, stop.position
WITH stop.routeId AS routeId, COLLECT(stop) AS stops
UNWIND RANGE(0, SIZE(stops) - 2) AS idx
WITH stops[idx] AS from, stops[idx+1] AS to
MERGE (from)-[:NEXT]->(to);

CREATE CONSTRAINT ON (r:Route)
ASSERT r.id IS UNIQUE;

call apoc.periodic.commit('
  MATCH (stop:Stop)
  WHERE NOT stop:Process
  WITH stop LIMIT {limit}

  SET stop:Process
  RETURN COUNT(*)
',{limit:10000})

call apoc.periodic.commit('
  MATCH (stop:Stop)
  WHERE stop:Process
  WITH stop LIMIT {limit}

  MERGE (route:Route {id: stop.routeId})
  MERGE (route)-[:HAS_STOP]->(stop)

  REMOVE stop:Process
  RETURN COUNT(*)
',{limit:500})


MATCH (r:Route)
SET r:Process;

// batch the linked list
call apoc.periodic.commit('
  MATCH (r:Route)
  WHERE r:Process
  WITH r LIMIT {limit}

  MATCH (r)-[:HAS_STOP]->(stop:Stop)
  WITH r, stop ORDER BY stop.routeId, stop.position
  WITH r, stop.routeId AS routeId, COLLECT(stop) AS stops
  UNWIND RANGE(0, SIZE(stops) - 2) AS idx
  WITH r, stops[idx] AS from, stops[idx+1] AS to
  MERGE (from)-[:NEXT]->(to)

  REMOVE r:Process
  RETURN COUNT(*)
',{limit:500})

create index on :Location(name);
create index on :Stop(departure);

// add property as seconds for easier calculation later
call apoc.periodic.commit('
  MATCH (stop:Stop)
  WHERE stop:Process
  WITH stop LIMIT {limit}

  UNWIND ["arrival", "departure", "passedThrough"] AS key
  WITH stop,
       key,
       toInteger(substring(stop[key], 0, 2)) AS hours,
       toInteger(substring(stop[key], 2, 2)) AS minutes,
       CASE WHEN substring(stop[key], 4,1) = "H" THEN 30 ELSE 0 END As seconds
  WITH stop, key, (hours * 60 * 60) + (minutes * 60) + seconds AS secondsSinceStartOfDay
  WHERE NOT secondsSinceStartOfDay is NULL
  WITH stop, key + "SecondsSinceStartOfDay" AS newKey, secondsSinceStartOfDay
  CALL apoc.create.setProperty(stop, newKey, secondsSinceStartOfDay) YIELD node
  REMOVE stop:Process
  RETURN COUNT(*)
',{limit:500})

// add time in seconds to `NEXT` relationships
call apoc.periodic.commit('
  MATCH (r:Route)
  WHERE r:Process
  WITH r LIMIT {limit}

  MATCH (r)-[:HAS_STOP]->(stop:Stop)
  WITH r, stop ORDER BY stop.routeId, stop.position
  WITH r, stop.routeId AS routeId, COLLECT(stop) AS stops
  UNWIND RANGE(0, SIZE(stops) - 2) AS idx
  WITH r, stops[idx] AS from, stops[idx+1] AS to
  MATCH (from)-[next:NEXT]->(to)
  WITH r, from, next, to, coalesce(from.departureSecondsSinceStartOfDay, from.passedThroughSecondsSinceStartOfDay) AS fromTime, coalesce(to.arrivalSecondsSinceStartOfDay, to.passedThroughSecondsSinceStartOfDay) AS toTime
  SET next.time =  toTime - fromTime

  REMOVE r:Process
  RETURN COUNT(*)
',{limit:500})

// put a 'time' property onto the `HAS_STOP` relationship
call apoc.periodic.commit('
  MATCH (l:Location)
  WHERE NOT l:Process
  WITH l LIMIT {limit}

  SET l:Process
  RETURN COUNT(*)
',{limit:10000})

// add time property
call apoc.periodic.commit('
  MATCH (l:Location)
  WHERE l:Process
  WITH l LIMIT {limit}

  MATCH (l)-[hasStop:HAS_STOP]->()
  SET hasStop.time = 0

  REMOVE l:Process
  RETURN COUNT(*)
',{limit:500})
