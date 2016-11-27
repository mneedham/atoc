public static void midPoint(double lat1,double lon1,double lat2,double lon2){

    double dLon = Math.toRadians(lon2 - lon1);

    //convert to radians
    lat1 = Math.toRadians(lat1);
    lat2 = Math.toRadians(lat2);
    lon1 = Math.toRadians(lon1);

    double Bx = Math.cos(lat2) * Math.cos(dLon);
    double By = Math.cos(lat2) * Math.sin(dLon);
    double lat3 = Math.atan2(Math.sin(lat1) + Math.sin(lat2), Math.sqrt((Math.cos(lat1) + Bx) * (Math.cos(lat1) + Bx) + By * By));
    double lon3 = lon1 + Math.atan2(By, Math.cos(lat1) + Bx);

    //print out in degrees
    System.out.println(Math.toDegrees(lat3) + " " + Math.toDegrees(lon3));
}


WITH 51.4931963543 AS lat1, -0.0475185810 AS lon1, 51.47908 AS lat2 , -0.05393950 AS lon2
WITH radians(lat1) AS rlat1, radians(lon1) AS rlon1, radians(lat2) AS rlat2, radians(lon2) AS rlon2, radians(lon2 - lon1) AS dLon
WITH rlat1, rlon1, rlat2, rlon2, cos(rlat2) * cos(dLon) AS Bx, cos(rlat2) * sin(dLon) AS By
WITH atan2(sin(rlat1) + sin(rlat2), sqrt( (cos(rlat1) + Bx) * (cos(rlat1) + Bx) + By * By )) AS lat3,
     rlon1 + atan2(By, cos(rlat1) + Bx) AS lon3
RETURN degrees(lat3), degrees(lon3)
