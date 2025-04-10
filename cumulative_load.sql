/*
Cumulative table generation query that populates the `actors` table one year at a time.
*/

insert into actors
with yesterday as (
    select *
    from actors
    where current_year = 1974
),
 today as (
     select actor,
            year,
            array_agg(row(filmid, film,votes,rating)::films) as films,
            avg(rating) as avg_rating
     from actor_films
     where year = 1975
     group by actor, year
 )

select
    coalesce(y.actor, t.actor) as actor,
    coalesce(t.films, y.films) as films,
    case when t.year is not null then
        case when t.avg_rating > 8 then 'star'
             when t.avg_rating > 7 then 'good'
             when t.avg_rating > 6 then 'average'
             else 'bad'
        end::quality_class
    else y.quality_class
    end as quality_class,
    t.year is not null as is_active,
    coalesce(t.year, y.current_year + 1) as current_year
from today t
full outer join yesterday y
on y.actor = t.actor;