<!doctype html>
<html>

  <head>
    <title>National Rail Graph -  {{location}} </title>
    <link rel="stylesheet" href="/css/main.css">
  </head>

  <body>

    <div class="header">
      <nav><strong>{{location}}</strong></nav>
    </div>

    <h1>{{location}}</h1>

    <ul>
     % for row in platforms:
         <li>{{row['platform']['time']}}, <a href="/routes/{{row['route']['id']}}">{{row['platform']['routeId']}}</a></li>
     % end
    </ul>

    <div class="footer">
      <code>(graphs)-[:ARE]->(everywhere)</code>
      <p>With &hearts; from Sweden &amp; the <a href="http://neo4j.com/community/">Neo4j Community</a></p>
    </div>

  </body>

</html>
