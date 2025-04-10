/*
Backfill query for `actors_history_scd` - "backfill" query that can populate the entire `actors_history_scd` table in a single query.
*/

insert into actors_history_scd
with previous_data as (select actor,
                              quality_class,
                              is_active,
                              current_year,
                              lag(quality_class, 1) over (partition by actor order by current_year) as previous_quality_class,
                              lag(is_active, 1) over (partition by actor order by current_year)     as previous_is_active
                       from actors
                       where current_year <= (select max(current_year) - 1 from actors)
),
with_change_indicator as(
select *,
    case when quality_class <> previous_quality_class then 1
        when is_active <> previous_is_active then 1
        else 0
    end as change_indicator
from previous_data)

,streaks_count as (
select * ,
    sum(change_indicator)
        over (partition by actor order by current_year) as streak_identifier
from with_change_indicator)

select
    actor,
    quality_class,
    is_active,
    MIN(current_year) as start_date,
    MAX(current_year) as end_date,
    (select max(current_year)-1 from actors) as current_year -- can be parameterized in prod
from streaks_count
group by actor, quality_class, is_active, streak_identifier
order by actor, streak_identifier;
