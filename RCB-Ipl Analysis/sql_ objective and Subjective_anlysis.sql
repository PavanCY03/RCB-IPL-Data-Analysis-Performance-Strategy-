-- 1.List the different dtypes of columns in table “ball_by_ball” (using information schema)
SELECT 
    COLUMN_NAME,
    DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME   = 'ball_by_ball';

--  2.What is the total number of runs scored in 1st season by RCB (bonus: also include the extra runs using the extra runs table)
SELECT 
COALESCE(SUM(b.Runs_Scored),0) + COALESCE(SUM(e.Extra_Runs),0) AS total_runs
FROM ball_by_ball b
JOIN matches m 
  ON m.Match_Id = b.Match_Id
LEFT JOIN extra_runs e
  ON e.Match_Id = b.Match_Id
 AND e.Over_Id = b.Over_Id
 AND e.Ball_Id = b.Ball_Id
 AND e.Innings_No = b.Innings_No
WHERE m.Season_Id = (
      SELECT MIN(Season_Id) FROM matches
)
AND b.Team_Batting = (
    SELECT Team_Id 
    FROM team 
    WHERE Team_Name = 'Royal Challengers Bangalore'
);

-- 3.How many players were more than the age of 25 during season 2014?
SELECT 
COUNT(DISTINCT pm.Player_Id) AS players_above_25
FROM player_match pm
JOIN matches m 
  ON m.Match_Id = pm.Match_Id
JOIN season s 
  ON s.Season_Id = m.Season_Id
JOIN player p 
  ON p.Player_Id = pm.Player_Id
WHERE s.Season_Year = 2014
AND TIMESTAMPDIFF(YEAR, p.DOB, m.Match_Date) > 25;

-- 4.How many matches did RCB win in 2013? 
SELECT 
COUNT(*) AS matches_won
FROM matches m
JOIN team t 
  ON t.Team_Id = m.Match_Winner
JOIN season s 
  ON s.Season_Id = m.Season_Id
WHERE t.Team_Name = 'Royal Challengers Bangalore'
AND s.Season_Year = 2013;

-- 5.List the top 10 players according to their strike rate in the last 4 seasons
SELECT 
p.Player_Name,
ROUND(SUM(b.Runs_Scored) / COUNT(*) * 100, 2) AS strike_rate
FROM ball_by_ball b
JOIN matches m 
  ON m.Match_Id = b.Match_Id
JOIN season s 
  ON s.Season_Id = m.Season_Id
JOIN player p 
  ON p.Player_Id = b.Striker
WHERE s.Season_Year >= (
        SELECT MAX(Season_Year) - 3 FROM season
)
GROUP BY p.Player_Id, p.Player_Name
HAVING COUNT(*) > 50
ORDER BY strike_rate DESC
LIMIT 10;

-- 6.What are the average runs scored by each batsman considering all the seasons?
SELECT 
    p.Player_Id,
    p.Player_Name,
    ROUND(SUM(b.Runs_Scored) / COUNT(DISTINCT b.Match_Id), 2) AS avg_runs
FROM ball_by_ball b
JOIN player p 
    ON p.Player_Id = b.Striker
WHERE b.Team_Batting = 2
GROUP BY p.Player_Id, p.Player_Name
ORDER BY avg_runs DESC;

-- 7.What are the average wickets taken by each bowler considering all the seasons?
SELECT 
    p.Player_Id,
    p.Player_Name,
    ROUND(COUNT(*) / COUNT(DISTINCT b.Match_Id), 2) AS avg_wickets
FROM ball_by_ball b
JOIN wicket_taken w
    ON b.Match_Id = w.Match_Id
   AND b.Over_Id = w.Over_Id
   AND b.Ball_Id = w.Ball_Id
JOIN player p
    ON p.Player_Id = b.Bowler
WHERE b.Team_Bowling = 2
  AND w.Kind_Out != 'run out'
GROUP BY p.Player_Id, p.Player_Name
ORDER BY avg_wickets DESC;

-- 8.List all the players who have average runs scored greater than the overall average and who have taken wickets greater than the overall average
WITH bat AS (
    SELECT 
        Striker AS Player_Id,
        SUM(Runs_Scored) / COUNT(DISTINCT Match_Id) AS avg_runs
    FROM ball_by_ball
    GROUP BY Striker
),
bowl AS (
    SELECT 
        b.Bowler AS Player_Id,
        COUNT(w.Player_Out) / COUNT(DISTINCT b.Match_Id) AS avg_wkts
    FROM ball_by_ball b
    JOIN wicket_taken w
      ON w.Match_Id = b.Match_Id
     AND w.Over_Id = b.Over_Id
     AND w.Ball_Id = b.Ball_Id
     AND w.Innings_No = b.Innings_No
    GROUP BY b.Bowler
),
overall AS (
    SELECT 
        (SELECT AVG(avg_runs) FROM bat) AS overall_bat_avg,
        (SELECT AVG(avg_wkts) FROM bowl) AS overall_bowl_avg
)
SELECT 
    p.Player_Name,
    bat.avg_runs,
    bowl.avg_wkts
FROM bat
JOIN bowl 
  ON bat.Player_Id = bowl.Player_Id
JOIN player p 
  ON p.Player_Id = bat.Player_Id
JOIN overall o
WHERE bat.avg_runs > o.overall_bat_avg
AND bowl.avg_wkts > o.overall_bowl_avg
ORDER BY bat.avg_runs DESC, bowl.avg_wkts DESC;

-- 9.Create a table rcb_record table that shows the wins and losses of RCB in an individual venue.
SELECT 
v.Venue_Name,
SUM(CASE WHEN m.Match_Winner = r.Team_Id THEN 1 ELSE 0 END) AS wins,
SUM(CASE 
        WHEN m.Match_Winner IS NOT NULL 
         AND m.Match_Winner <> r.Team_Id THEN 1 
        ELSE 0 
    END) AS losses
FROM matches m
JOIN venue v 
  ON v.Venue_Id = m.Venue_Id
JOIN team r 
  ON r.Team_Name = 'Royal Challengers Bangalore'
WHERE m.Team_1 = r.Team_Id 
   OR m.Team_2 = r.Team_Id
GROUP BY v.Venue_Name;

-- 10. What is the impact of bowling style on wickets taken?
SELECT 
bs.Bowling_skill,
COUNT(w.Player_Out) AS total_wickets
FROM ball_by_ball b
JOIN wicket_taken w
  ON w.Match_Id = b.Match_Id
 AND w.Over_Id = b.Over_Id
 AND w.Ball_Id = b.Ball_Id
 AND w.Innings_No = b.Innings_No
JOIN player p
  ON p.Player_Id = b.Bowler
JOIN bowling_style bs
  ON bs.Bowling_Id = p.Bowling_skill
GROUP BY bs.Bowling_skill
ORDER BY total_wickets DESC;

-- 11. Write the SQL query to provide a status of whether the performance of the team is better than the previous year's performance on the basis of the number of runs scored by the team in the season and the number of wickets taken 
WITH runs AS (
    SELECT 
        m.Season_Id,
        b.Team_Batting AS Team_Id,
        SUM(b.Runs_Scored) AS total_runs
    FROM ball_by_ball b
    JOIN matches m 
      ON m.Match_Id = b.Match_Id
    GROUP BY m.Season_Id, b.Team_Batting
),
wkts AS (
    SELECT 
        m.Season_Id,
        b.Team_Bowling AS Team_Id,
        COUNT(w.Player_Out) AS total_wickets
    FROM ball_by_ball b
    JOIN wicket_taken w
      ON w.Match_Id = b.Match_Id
     AND w.Over_Id = b.Over_Id
     AND w.Ball_Id = b.Ball_Id
     AND w.Innings_No = b.Innings_No
    JOIN matches m 
      ON m.Match_Id = b.Match_Id
    GROUP BY m.Season_Id, b.Team_Bowling
),
perf AS (
    SELECT 
        r.Season_Id,
        r.Team_Id,
        r.total_runs,
        COALESCE(w.total_wickets,0) AS total_wickets
    FROM runs r
    LEFT JOIN wkts w
      ON r.Season_Id = w.Season_Id
     AND r.Team_Id = w.Team_Id
)
SELECT 
    t.Team_Name,
    s.Season_Year,
    p.total_runs,
    p.total_wickets,
    CASE
        WHEN p.total_runs  > LAG(p.total_runs)  OVER (PARTITION BY p.Team_Id ORDER BY s.Season_Year)
         AND p.total_wickets > LAG(p.total_wickets) OVER (PARTITION BY p.Team_Id ORDER BY s.Season_Year)
        THEN 'Better'
        ELSE 'Not Better'
    END AS performance_status
FROM perf p
JOIN team t 
  ON t.Team_Id = p.Team_Id
JOIN season s 
  ON s.Season_Id = p.Season_Id
ORDER BY t.Team_Name, s.Season_Year; 

-- 12. Can you derive more KPIs for the team strategy?
-- step1: Win Percentage (Season Performance KPI)
SELECT 
    Season_Id,
    COUNT(*) AS total_matches,
    SUM(CASE WHEN Match_Winner = 2 THEN 1 ELSE 0 END) AS wins,
    ROUND((SUM(CASE WHEN Match_Winner = 2 THEN 1 ELSE 0 END) / COUNT(*)) * 100, 2) AS win_percentage
FROM matches
WHERE Team_1 = 2 OR Team_2 = 2
GROUP BY Season_Id
ORDER BY Season_Id;

-- step2: Batting Average Per Match (Team Strength)
SELECT 
    ROUND(SUM(Runs_Scored) / COUNT(DISTINCT Match_Id), 2) AS avg_runs_per_match
FROM ball_by_ball
WHERE Team_Batting = 2;

-- step3: Death Over Economy (Bowling Weakness Indicator)
SELECT 
    ROUND(SUM(Runs_Scored) / COUNT(Over_Id), 2) AS death_over_economy
FROM ball_by_ball
WHERE Team_Bowling = 2
  AND Over_Id BETWEEN 16 AND 20;
  
-- step4: Powerplay Run Rate (Aggression KPI)
SELECT 
    ROUND(SUM(Runs_Scored) / COUNT(Over_Id), 2) AS powerplay_run_rate
FROM ball_by_ball
WHERE Team_Batting = 2
  AND Over_Id BETWEEN 1 AND 6;
  
-- step5: Top 3 Dependency Ratio (Fragility KPI)
SELECT 
    ROUND(
        (SUM(CASE WHEN Striker_Batting_Position <= 3 THEN Runs_Scored ELSE 0 END) 
        / SUM(Runs_Scored)) * 100,
        2
    ) AS top3_dependency_percentage
FROM ball_by_ball
WHERE Team_Batting = 2;

-- step6: Bowling Strike Rate (Wicket Efficiency)
SELECT 
    ROUND(COUNT(b.Ball_Id) / COUNT(w.Match_Id), 2) AS bowling_strike_rate
FROM ball_by_ball b
JOIN wicket_taken w
    ON b.Match_Id = w.Match_Id
   AND b.Over_Id = w.Over_Id
   AND b.Ball_Id = w.Ball_Id
WHERE b.Team_Bowling = 2
  AND w.Kind_Out != 'run out';

-- 13. Using SQL, write a query to find out the average wickets taken by each bowler in each venue. Also, rank the gender according to the average value.
SELECT 
    m.Venue_Id,
    v.Venue_Name,
    b.Bowler AS player_id,
    p.Player_Name AS bowler_name,
    ROUND(COUNT(w.Match_Id) / COUNT(DISTINCT m.Match_Id), 2) AS avg_wickets,
    RANK() OVER (
        PARTITION BY m.Venue_Id
        ORDER BY COUNT(w.Match_Id) / COUNT(DISTINCT m.Match_Id) DESC
    ) AS venue_rank
FROM matches m
JOIN venue v
    ON m.Venue_Id = v.Venue_Id
JOIN ball_by_ball b
    ON m.Match_Id = b.Match_Id
JOIN wicket_taken w
    ON w.Match_Id = b.Match_Id
   AND w.Over_Id = b.Over_Id
   AND w.Ball_Id = b.Ball_Id
JOIN player p
    ON b.Bowler = p.Player_Id
WHERE b.Team_Bowling = 2
  AND w.Kind_Out != 'run out'
GROUP BY 
    m.Venue_Id,
    v.Venue_Name,
    b.Bowler,
    p.Player_Name
ORDER BY 
    m.Venue_Id,
    venue_rank;

-- 14. Which of the given players have consistently performed well in past seasons? (will you use any visualization to solve the problem)

SELECT
    p.Player_Name,
    s.Season_Year,
    SUM(b.Runs_Scored) AS total_runs,
    COUNT(w.Player_Out) AS total_wickets
FROM ball_by_ball b
JOIN matches m
    ON m.Match_Id = b.Match_Id
JOIN season s
    ON s.Season_Id = m.Season_Id
JOIN player p
    ON p.Player_Id = b.Striker
LEFT JOIN wicket_taken w
    ON w.Match_Id = b.Match_Id
    AND w.Over_Id = b.Over_Id
    AND w.Ball_Id = b.Ball_Id
    AND w.Innings_No = b.Innings_No
WHERE b.Team_Batting = (
    SELECT Team_Id
    FROM team
    WHERE Team_Name = 'Royal Challengers Bangalore'
)
GROUP BY p.Player_Name, s.Season_Year
ORDER BY p.Player_Name, s.Season_Year DESC;

-- 15. Are there players whose performance is more suited to specific venues or conditions? (how would you present this using charts?) 
WITH venue_perf AS (
    SELECT 
        b.Striker AS Player_Id,
        m.Venue_Id,
        SUM(b.Runs_Scored) / COUNT(DISTINCT b.Match_Id) AS avg_runs_venue
    FROM ball_by_ball b
    JOIN matches m 
      ON m.Match_Id = b.Match_Id
    GROUP BY b.Striker, m.Venue_Id
),
overall_perf AS (
    SELECT 
        Striker AS Player_Id,
        SUM(Runs_Scored) / COUNT(DISTINCT Match_Id) AS avg_runs_overall
    FROM ball_by_ball
    GROUP BY Striker
)
SELECT 
    p.Player_Name,
    v.Venue_Name,
    ROUND(vp.avg_runs_venue,2) AS venue_avg,
    ROUND(op.avg_runs_overall,2) AS overall_avg,
    ROUND(vp.avg_runs_venue - op.avg_runs_overall,2) AS performance_boost
FROM venue_perf vp
JOIN overall_perf op 
  ON vp.Player_Id = op.Player_Id
JOIN player p 
  ON p.Player_Id = vp.Player_Id
JOIN venue v 
  ON v.Venue_Id = vp.Venue_Id
WHERE vp.avg_runs_venue > op.avg_runs_overall
ORDER BY performance_boost DESC;

-------------------------------------- Subjective Part ------------------------------------------------------------------------------

-- 1.How does the toss decision affect the result of the match? (which visualizations could be used to present your answer better) And is the impact limited to only specific venues?
SELECT 
v.Venue_Name,
td.Toss_Name AS toss_decision,
COUNT(*) AS matches_played,
SUM(CASE 
      WHEN m.Toss_Winner = m.Match_Winner 
      THEN 1 ELSE 0 
    END) AS toss_win_and_match_win,
ROUND(
SUM(CASE 
      WHEN m.Toss_Winner = m.Match_Winner 
      THEN 1 ELSE 0 
    END) * 100 / COUNT(*), 2
) AS win_percentage
FROM matches m
JOIN venue v 
  ON v.Venue_Id = m.Venue_Id
JOIN toss_decision td 
  ON td.Toss_Id = m.Toss_Decide
GROUP BY v.Venue_Name, td.Toss_Name
ORDER BY v.Venue_Name, win_percentage DESC;

-- 2. Suggest some of the players who would be best fit for the team.
WITH bat AS (
    SELECT 
        Striker AS Player_Id,
        SUM(Runs_Scored) AS total_runs,
        SUM(Runs_Scored) / COUNT(DISTINCT Match_Id) AS avg_runs,
        SUM(Runs_Scored) / COUNT(*) * 100 AS strike_rate
    FROM ball_by_ball
    GROUP BY Striker
),
bowl AS (
    SELECT 
        b.Bowler AS Player_Id,
        COUNT(w.Player_Out) AS total_wickets,
        COUNT(w.Player_Out) / COUNT(DISTINCT b.Match_Id) AS avg_wkts
    FROM ball_by_ball b
    JOIN wicket_taken w
      ON w.Match_Id = b.Match_Id
     AND w.Over_Id = b.Over_Id
     AND w.Ball_Id = b.Ball_Id
     AND w.Innings_No = b.Innings_No
    GROUP BY b.Bowler
)
SELECT 
p.Player_Name,
bat.total_runs,
ROUND(bat.avg_runs,2) AS avg_runs,
ROUND(bat.strike_rate,2) AS strike_rate,
bowl.total_wickets,
ROUND(bowl.avg_wkts,2) AS avg_wkts
FROM bat
JOIN bowl 
  ON bat.Player_Id = bowl.Player_Id
JOIN player p 
  ON p.Player_Id = bat.Player_Id
WHERE bat.total_runs > 500
AND bowl.total_wickets > 20
ORDER BY bat.avg_runs DESC, bowl.avg_wkts DESC
LIMIT 15; 

-- 3. What are some of the parameters that should be focused on while selecting the players?
WITH player_stats AS (
    SELECT
        p.Player_Id,
        p.Player_Name,
        COUNT(DISTINCT b.Match_Id) AS matches_played,
        -- Batting Metrics
        SUM(CASE WHEN b.Striker = p.Player_Id 
                 THEN b.Runs_Scored ELSE 0 END) AS total_runs,
        SUM(CASE WHEN b.Striker = p.Player_Id 
                 THEN 1 ELSE 0 END) AS balls_faced,
        -- Bowling Metrics
        SUM(CASE WHEN b.Bowler = p.Player_Id 
                 THEN 1 ELSE 0 END) AS balls_bowled,
        COUNT(CASE WHEN b.Bowler = p.Player_Id 
                   THEN w.Player_Out END) AS wickets_taken,
        SUM(CASE WHEN b.Bowler = p.Player_Id 
                 THEN b.Runs_Scored ELSE 0 END) AS runs_conceded
    FROM player p
    LEFT JOIN ball_by_ball b
      ON p.Player_Id IN (b.Striker, b.Bowler)
    LEFT JOIN wicket_taken w
      ON w.Match_Id = b.Match_Id
     AND w.Over_Id = b.Over_Id
     AND w.Ball_Id = b.Ball_Id
     AND w.Innings_No = b.Innings_No
     AND b.Bowler = p.Player_Id
    GROUP BY p.Player_Id, p.Player_Name
)
SELECT 
    Player_Name,
    matches_played,
    ROUND(total_runs / NULLIF(matches_played,0),2) AS avg_runs,
    ROUND(total_runs / NULLIF(balls_faced,0) * 100,2) AS strike_rate,
    ROUND(wickets_taken / NULLIF(matches_played,0),2) AS avg_wickets,
    ROUND(runs_conceded / NULLIF(balls_bowled/6,0),2) AS economy,
    -- Composite Selection Score
    ROUND(
        (total_runs / NULLIF(matches_played,0)) * 0.35 +
        (total_runs / NULLIF(balls_faced,0) * 100) * 0.25 +
        (wickets_taken / NULLIF(matches_played,0)) * 0.25 -
        (runs_conceded / NULLIF(balls_bowled/6,0)) * 0.15
    ,2) AS selection_score
FROM player_stats
WHERE matches_played >= 20
ORDER BY selection_score DESC
LIMIT 15;

-- 4. Which players offer versatility in their skills and can contribute effectively with both bat and ball? (can you visualize the data for the same)
WITH player_stats AS (
    SELECT 
        p.Player_Id,
        p.Player_Name,
        COUNT(DISTINCT b.Match_Id) AS matches_played,
        -- Batting
        SUM(CASE WHEN b.Striker = p.Player_Id 
                 THEN b.Runs_Scored ELSE 0 END) AS total_runs,
        SUM(CASE WHEN b.Striker = p.Player_Id 
                 THEN 1 ELSE 0 END) AS balls_faced,
        -- Bowling
        COUNT(CASE WHEN b.Bowler = p.Player_Id 
                   THEN w.Player_Out END) AS wickets_taken
    FROM player p
    LEFT JOIN ball_by_ball b
      ON p.Player_Id IN (b.Striker, b.Bowler)
    LEFT JOIN wicket_taken w
      ON w.Match_Id = b.Match_Id
     AND w.Over_Id = b.Over_Id
     AND w.Ball_Id = b.Ball_Id
     AND w.Innings_No = b.Innings_No
     AND b.Bowler = p.Player_Id
    GROUP BY p.Player_Id, p.Player_Name
)
SELECT 
    Player_Name,
    matches_played,
    ROUND(total_runs / NULLIF(matches_played,0),2) AS avg_runs,
    ROUND(total_runs / NULLIF(balls_faced,0) * 100,2) AS strike_rate,
    ROUND(wickets_taken / NULLIF(matches_played,0),2) AS avg_wickets
FROM player_stats
WHERE matches_played >= 20
AND total_runs > 500
AND wickets_taken > 20
ORDER BY avg_runs DESC, avg_wickets DESC;

-- 5.Are there players whose presence positively influences the morale and performance of the team? (justify your answer using visualization)
SELECT 
p.Player_Name,
COUNT(DISTINCT pm.Match_Id) AS matches_played,
SUM(CASE 
        WHEN m.Match_Winner = pm.Team_Id 
        THEN 1 ELSE 0 
    END) AS wins_with_player,
ROUND(
SUM(CASE WHEN m.Match_Winner = pm.Team_Id THEN 1 ELSE 0 END)
/ COUNT(DISTINCT pm.Match_Id) * 100
,2) AS win_pct_with_player
FROM player_match pm
JOIN matches m 
  ON m.Match_Id = pm.Match_Id
JOIN player p 
  ON p.Player_Id = pm.Player_Id
GROUP BY p.Player_Id, p.Player_Name
HAVING matches_played >= 20
ORDER BY win_pct_with_player DESC
LIMIT 15;

-- 6. What would you suggest to RCB before going to the mega auction? 
-- ansewr: 
-- Step 1: Identify RCB’s Win %
SELECT 
ROUND(
SUM(CASE WHEN m.Match_Winner = t.Team_Id THEN 1 ELSE 0 END)
/ COUNT(*) * 100,2
) AS rcb_win_pct
FROM matches m
JOIN team t 
  ON t.Team_Name = 'Royal Challengers Bangalore'
WHERE m.Team_1 = t.Team_Id 
   OR m.Team_2 = t.Team_Id;

-- Step 2: Check Batting Dependency

SELECT 
p.Player_Name,
SUM(b.Runs_Scored) AS total_runs
FROM ball_by_ball b
JOIN player p 
  ON p.Player_Id = b.Striker
WHERE b.Team_Batting = (
    SELECT Team_Id 
    FROM team 
    WHERE Team_Name = 'Royal Challengers Bangalore'
)
GROUP BY p.Player_Id, p.Player_Name
ORDER BY total_runs DESC;

-- Step 3: Bowling Economy (Major RCB Issue Historically)

SELECT 
ROUND(SUM(b.Runs_Scored)/(COUNT(*)/6),2) AS rcb_economy
FROM ball_by_ball b
WHERE b.Team_Bowling = (
    SELECT Team_Id 
    FROM team 
    WHERE Team_Name = 'Royal Challengers Bangalore'
);

-- 7.What do you think could be the factors contributing to the high-scoring matches and the impact on viewership and team strategies

SELECT 
v.Venue_Name,
ROUND(SUM(b.Runs_Scored)/COUNT(DISTINCT b.Match_Id),2) AS avg_match_runs
FROM ball_by_ball b
JOIN matches m ON m.Match_Id = b.Match_Id
JOIN venue v ON v.Venue_Id = m.Venue_Id
GROUP BY v.Venue_Name
ORDER BY avg_match_runs DESC;

-- 8.Analyze the impact of home-ground advantage on team performance and identify strategies to maximize this advantage for RCB

WITH Home_Ground AS (
SELECT
    pm.Team_Id,
    c.City_Name,
    t.Team_Name,
    SUM(bb.Runs_Scored) / COUNT(bb.Ball_Id) AS Avg_Runs,
    COUNT(bb.Ball_Id) AS Total_Balls,
    COUNT(*) AS Total_Wickets,
    COUNT(DISTINCT m.Match_Id) AS Total_Matches
FROM Player_Match pm
JOIN Ball_by_Ball bb ON bb.Match_Id = pm.Match_Id
JOIN Matches m ON m.Match_Id = pm.Match_Id
LEFT JOIN Wicket_Taken wt ON wt.Match_Id = pm.Match_Id
JOIN Venue v ON v.Venue_Id = m.Venue_Id
JOIN City c ON c.City_Id = v.City_Id
JOIN Team t ON t.Team_Id = pm.Team_Id
WHERE t.Team_Id = 2
GROUP BY pm.Team_Id, c.City_Name
ORDER BY Avg_Runs DESC
)

SELECT
    City_Name,
    Team_Name,
    Avg_Runs,
    Total_Balls,
    Total_Wickets,
    Total_Matches
FROM Home_Ground;

-- 9.Come up with a visual and analytical analysis of the RCB's past season's performance and potential reasons for them not winning a trophy.
-- ansewr::
-- Step 1: Season-wise Performance Trend
SELECT 
s.Season_Year,
COUNT(*) AS matches_played,
SUM(CASE WHEN m.Match_Winner = t.Team_Id THEN 1 ELSE 0 END) AS wins,
ROUND(
SUM(CASE WHEN m.Match_Winner = t.Team_Id THEN 1 ELSE 0 END)
/ COUNT(*) * 100,2
) AS win_pct
FROM matches m
JOIN season s ON s.Season_Id = m.Season_Id
JOIN team t ON t.Team_Name = 'Royal Challengers Bangalore'
WHERE m.Team_1 = t.Team_Id 
   OR m.Team_2 = t.Team_Id
GROUP BY s.Season_Year
ORDER BY s.Season_Year;

-- step 2:Batting Dependency Analysis – Top Run Contributors
SELECT 
p.Player_Name,
SUM(b.Runs_Scored) AS total_runs
FROM ball_by_ball b
JOIN player p ON p.Player_Id = b.Striker
WHERE b.Team_Batting = (
    SELECT Team_Id FROM team 
    WHERE Team_Name = 'Royal Challengers Bangalore'
)
GROUP BY p.Player_Id, p.Player_Name
ORDER BY total_runs DESC;

-- step 3: Bowling Weakness (Major Factor) – RCB Economy Rate by Season
SELECT 
s.Season_Year,
ROUND(SUM(b.Runs_Scored)/(COUNT(*)/6),2) AS economy
FROM ball_by_ball b
JOIN matches m ON m.Match_Id = b.Match_Id
JOIN season s ON s.Season_Id = m.Season_Id
WHERE b.Team_Bowling = (
    SELECT Team_Id FROM team 
    WHERE Team_Name = 'Royal Challengers Bangalore'
)
GROUP BY s.Season_Year
ORDER BY s.Season_Year;

-- 11.In the "Match" table, some entries in the "Opponent_Team" column are incorrectly spelled as "Delhi_Capitals" instead of "Delhi_Daredevils". Write an SQL query to replace all occurrences of "Delhi_Capitals" with "Delhi_Daredevils".
UPDATE team
SET Team_Name = 'Delhi Daredevils'
WHERE Team_Name = 'Delhi Capitals';
