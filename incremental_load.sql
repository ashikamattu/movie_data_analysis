/*
Incremental query for `actors_history_scd` - An incremental load query that combines the previous year's SCD data with new incoming data from the `actors` table.
*/
create type actors_scd as (quality_class quality_class,
                          is_active boolean,
                          start_date integer,
                          end_date integer);

with last_year_data as (select *
                        from actors_history_scd
                        where current_year = (select max(current_year) - 1 from actors)
                          and end_date = (select max(current_year) - 1 from actors)
    ),

    historic_data as (
        select actor,
               quality_class,
               is_active,
               start_date,
               end_date
            from actors_history_scd
            where current_year = (select max(current_year) - 1 from actors)
              and end_date < (select max(current_year) - 1 from actors)
    ),

    this_year_data as (
    select *
    from actors where current_year = (select max(current_year) from actors)
    ),

unchanged_data as (
    select
        tyd.actor,
        tyd.quality_class,
        tyd.is_active,
        lyd.start_date,
        tyd.current_year as end_date
    from this_year_data tyd
    join last_year_data lyd
    on tyd.actor = lyd.actor
    where tyd.quality_class = lyd.quality_class
        and tyd.is_active = lyd.is_active
),
changed_data as (
    select
        tyd.actor,
        unnest(array[row(lyd.quality_class,
                lyd.is_active,
                lyd.start_date,
                lyd.end_date)::actors_scd,

            row(tyd.quality_class,
                tyd.is_active,
                tyd.current_year,
                tyd.current_year)::actors_scd]) as track_changes

    from this_year_data tyd
        left join last_year_data lyd
    on tyd.actor = lyd.actor
    where tyd.quality_class <> lyd.quality_class
        or tyd.is_active <> lyd.is_active
    ),
    unnested_changed_data as (
        select actor,
               (track_changes::actors_scd).quality_class,
               (track_changes::actors_scd).is_active,
               (track_changes::actors_scd).start_date,
               (track_changes::actors_scd).end_date
               from changed_data
    ),

new_data as (
    select
        tyd.actor,
        tyd.quality_class,
        tyd.is_active,
        lyd.start_date,
        tyd.current_year as end_date
    from this_year_data tyd
        left join last_year_data lyd
        on tyd.actor = lyd.actor
    where lyd.actor is null
)

select *, (select max(current_year) from actors) as current_season from (
    select * from historic_data
    union all
    select * from unchanged_data
    union all
    select * from unnested_changed_data
    union all
    select * from new_data
    order by actor) a ;