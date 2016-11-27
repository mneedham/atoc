<!doctype html>
<html>

  <head>
    <title>National Rail Graph -  {{from_station}} to {{to_station}} </title>
    <link rel="stylesheet" href="/css/main.css">
  </head>

  <body>

    <div class="header">
      <nav><strong>{{from_station}} to {{to_station}}</strong></nav>
    </div>

    <h1>Journey from {{from_station}} to {{to_station}}</h1>

    <ul>
     % for row in stops:
         <li><a href="/locations/{{row['location']['code']}}">{{row["location"]["name"]}}</a>, {{row["stop"]["time"]}}, <a href="/routes/{{row['route']['id']}}">{{row["stop"]["routeId"]}}</a></li>
     % end
    </ul>

    <div class="footer">
      <code>(graphs)-[:ARE]->(everywhere)</code>
      <p>With &hearts; from Sweden &amp; the <a href="http://neo4j.com/community/">Neo4j Community</a></p>
    </div>

  </body>

</html>
