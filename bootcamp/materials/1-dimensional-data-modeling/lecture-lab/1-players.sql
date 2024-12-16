/*
The script below demonstrate how to create a cumulative tables which stores fixed dimensions together with seasonal
changing stats collapse into an array cumulatively.

The script also demonstrate the technique how to use yesterday-query (target) with today-query (source) as incremental load
*/

------------------------  GENERATING DATA TYPE TO STORE THE PLAYER'S SEASON STATS & DEFINE SCORING CLASS ------------------------
CREATE TYPE season_stats AS (
                         season Integer,
                         pts REAL,
                         ast REAL,
                         reb REAL,
                         weight INTEGER
                       );
 CREATE TYPE scoring_class AS
     ENUM ('bad', 'average', 'good', 'star');


------------------------  CREATE THE TABLE ------------------------
-- DROP TABLE players;
 CREATE TABLE players (
     player_name TEXT,
     height TEXT,
     college TEXT,
     country TEXT,
     draft_year TEXT,
     draft_round TEXT,
     draft_number TEXT,
     season_stats season_stats[],
     scoring_class scoring_class,
     years_since_last_active INTEGER,
--      is_active BOOLEAN,
     current_season INTEGER,
     PRIMARY KEY (player_name, current_season)
 );


------------------------ INSERT SPROC ----------------------------
-- TRUNCATE players;

CALL sp_players();

 CREATE OR REPLACE PROCEDURE sp_players()
     LANGUAGE plpgsql
 AS
 $$
 DECLARE
     yesterday_current_season INT = (SELECT COALESCE(MAX(current_season), 1995) FROM players);
     today_current_season     INT = (SELECT COALESCE(MAX(season), 1995) FROM player_seasons);
     update_season INT;

 BEGIN
    FOR update_season in
        SELECT * FROM generate_series(yesterday_current_season, today_current_season)
    LOOP

     INSERT INTO players ( player_name, height, college, country, draft_year, draft_round, draft_number, season_stats
                         , scoring_class, years_since_last_active, current_season)
     WITH yesterday     AS (SELECT * FROM players WHERE current_season = update_season)
        , today         AS (SELECT * FROM player_seasons WHERE season = update_season + 1)
     SELECT COALESCE(t.player_name, y.player_name)   AS player_name
          , COALESCE(t.height, y.height)             AS height
          , COALESCE(t.college, y.college)           AS college
          , COALESCE(t.country, y.country)           AS country
          , COALESCE(t.draft_year, y.draft_year)     AS draft_year
          , COALESCE(t.draft_round, y.draft_round)   AS draft_round
          , COALESCE(t.draft_number, y.draft_number) AS draft_number
          , CASE
         -- when the seed query cte yesterday just started, it is empty
                WHEN y.season_stats IS NULL
                    THEN ARRAY [ROW (t.season,t.gp, t.pts, t.reb, t.ast)::season_stats]
         -- player's can stop playing for some seasons,
         -- which could result in array full of nulls if not indicating condition below
                WHEN t.season IS NOT NULL
                    THEN y.season_stats || ARRAY [ROW (t.season, t.gp, t.pts, t.reb, t.ast)::season_stats]
                ELSE y.season_stats
         END                                         AS season_stats
          , CASE
                WHEN t.season IS NOT NULL THEN
                    CASE
                        WHEN t.pts > 20 THEN 'star'
                        WHEN t.pts > 15 THEN 'good'
                        WHEN t.pts > 10 THEN 'average'
                        ELSE 'bad'
                        END:: scoring_class
                ELSE y.scoring_class
         END                                         AS scoring_class
          , CASE
                WHEN t.season IS NULL
                    THEN y.years_since_last_active + 1
                ELSE 0
         END                                         AS years_since_last_active
          , COALESCE(t.season, y.current_season + 1) AS current_season
     FROM today t
              FULL OUTER JOIN yesterday y ON t.player_name = y.player_name;

     END LOOP;

 END
 $$;



