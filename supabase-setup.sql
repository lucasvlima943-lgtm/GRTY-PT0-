create table if not exists public.global_progress (
    singleton_id smallint primary key check (singleton_id = 1),
    click_count bigint not null default 0 check (click_count >= 0),
    stage_2_clicks bigint not null default 1000,
    stage_3_clicks bigint not null default 2500,
    stage_4_clicks bigint not null default 5000,
    constraint global_progress_stage_thresholds_increasing
        check (stage_2_clicks > 0 and stage_3_clicks > stage_2_clicks and stage_4_clicks > stage_3_clicks),
    current_stage integer generated always as (
        case
            when click_count >= stage_4_clicks then 4
            when click_count >= stage_3_clicks then 3
            when click_count >= stage_2_clicks then 2
            else 1
        end
    ) stored
);

alter table public.global_progress
    add column if not exists stage_2_clicks bigint not null default 1000,
    add column if not exists stage_3_clicks bigint not null default 2500,
    add column if not exists stage_4_clicks bigint not null default 5000;

alter table public.global_progress
    add column if not exists current_stage integer generated always as (
        case
            when click_count >= stage_4_clicks then 4
            when click_count >= stage_3_clicks then 3
            when click_count >= stage_2_clicks then 2
            else 1
        end
    ) stored;

do $$
begin
    if not exists (
        select 1
        from pg_constraint
        where conrelid = 'public.global_progress'::regclass
          and conname = 'global_progress_stage_thresholds_increasing'
    ) then
        alter table public.global_progress
            add constraint global_progress_stage_thresholds_increasing
            check (
                stage_2_clicks > 0
                and stage_3_clicks > stage_2_clicks
                and stage_4_clicks > stage_3_clicks
            );
    end if;
end;
$$;

insert into public.global_progress (singleton_id, click_count, stage_2_clicks, stage_3_clicks, stage_4_clicks)
values (1, 0, 1000, 2500, 5000)
on conflict (singleton_id) do nothing;

drop function if exists public.register_global_click();
drop function if exists public.register_global_click(smallint, smallint, smallint, smallint);
drop function if exists public.register_global_click(uuid, smallint, smallint, smallint, smallint);

do $$
begin
    if exists (
        select 1
        from pg_publication_tables
        where pubname = 'supabase_realtime'
          and schemaname = 'public'
          and tablename = 'click_events'
    ) then
        alter publication supabase_realtime drop table public.click_events;
    end if;
end;
$$;

drop table if exists public.click_events;

create table if not exists public.click_visitors (
    visitor_id uuid primary key,
    hue smallint not null check (hue between 0 and 359),
    created_at timestamptz not null default now()
);

alter table public.click_visitors enable row level security;

revoke all on public.click_visitors from anon, authenticated;

alter table public.global_progress enable row level security;

drop policy if exists "Allow public read of global progress" on public.global_progress;
create policy "Allow public read of global progress"
    on public.global_progress
    for select
    to anon, authenticated
    using (true);

revoke all on public.global_progress from anon, authenticated;
grant select on public.global_progress to anon, authenticated;

create function public.register_global_click(
    p_visitor_id uuid,
    p_hue smallint,
    p_position_x smallint,
    p_position_y smallint,
    p_size_px smallint
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    progress_row public.global_progress%rowtype;
    visitor_row public.click_visitors%rowtype;
    click_event jsonb;
begin
    if p_visitor_id is null
        or p_hue not between 0 and 359
        or p_position_x not between 5 and 95
        or p_position_y not between 5 and 95
        or p_size_px not between 90 and 180 then
        raise exception 'Invalid visitor or click bubble data.';
    end if;

    insert into public.click_visitors (visitor_id, hue)
    values (p_visitor_id, p_hue)
    on conflict (visitor_id) do nothing;

    select *
    into visitor_row
    from public.click_visitors
    where visitor_id = p_visitor_id;

    update public.global_progress
    set click_count = click_count + 1
    where singleton_id = 1
    returning * into progress_row;

    if not found then
        raise exception 'Global progress row is missing.';
    end if;

    click_event := jsonb_build_object(
        'id', progress_row.click_count,
        'hue', visitor_row.hue,
        'position_x', p_position_x,
        'position_y', p_position_y,
        'size_px', p_size_px
    );

    return jsonb_build_object(
        'click_count', progress_row.click_count,
        'stage', progress_row.current_stage,
        'stage_2_clicks', progress_row.stage_2_clicks,
        'stage_3_clicks', progress_row.stage_3_clicks,
        'stage_4_clicks', progress_row.stage_4_clicks,
        'event', click_event
    );
end;
$$;

revoke all on function public.register_global_click(uuid, smallint, smallint, smallint, smallint) from public;
grant execute on function public.register_global_click(uuid, smallint, smallint, smallint, smallint) to anon, authenticated;

create or replace function public.get_global_progress()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    progress_row public.global_progress%rowtype;
begin
    select *
    into progress_row
    from public.global_progress
    where singleton_id = 1;

    if not found then
        raise exception 'Global progress row is missing.';
    end if;

    return jsonb_build_object(
        'click_count', progress_row.click_count,
        'stage', progress_row.current_stage,
        'stage_2_clicks', progress_row.stage_2_clicks,
        'stage_3_clicks', progress_row.stage_3_clicks,
        'stage_4_clicks', progress_row.stage_4_clicks
    );
end;
$$;

revoke all on function public.get_global_progress() from public;
grant execute on function public.get_global_progress() to anon, authenticated;

do $$
begin
    if not exists (
        select 1
        from pg_publication_tables
        where pubname = 'supabase_realtime'
          and schemaname = 'public'
          and tablename = 'global_progress'
    ) then
        alter publication supabase_realtime add table public.global_progress;
    end if;
end;
$$;
