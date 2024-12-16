/*
Following up from 1-players.sql
With cumulative tables, you can do historical analysis without doing any shuffle or group by
and increase query speed
*/

-------------------- Show the improvements of the players over the years
-------------------- Which players have the biggest improvement from their first season to their most recent season
SELECT player_name
     , season_stats
     , CARDINALITY(season_stats) as amount_seasons_played
     , season_stats[CARDINALITY(season_stats)] as latest_season
     , season_stats[1] as first_season
     , season_stats[CARDINALITY(season_stats)].pts /
        CASE
            WHEN (season_stats[1].pts) = 0 THEN 1
            ELSE (season_stats[1].pts) END
        AS improvement_ratio_latest_to_first
FROM players
WHERE current_season = 2021
ORDER BY improvement_ratio_latest_to_first desc;


