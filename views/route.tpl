<!doctype html>
<html>

  <head>
    <title>National Rail Graph -  {{route_id}}</title>
    <link rel="stylesheet" href="/css/main.css">
  </head>

  <body>

    <div class="header">
      <nav><strong>Route {{route_id}}</strong></nav>
    </div>

    <h1>Route {{route_id}}</h1>

    <ul>
     % for row in platforms:
         <li>{{row['platform']['id']}}, {{row['platform']['time']}}</li>
     % end
    </ul>

    <div class="footer">
      <code>(graphs)-[:ARE]->(everywhere)</code>
      <p>With &hearts; from Sweden &amp; the <a href="http://neo4j.com/community/">Neo4j Community</a></p>
    </div>

  </body>

</html>
