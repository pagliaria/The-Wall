-- The Wall: Supabase schema for async versus (ghost) snapshots.
-- Run ONCE in Supabase Dashboard > SQL Editor. Safe to re-run.
--
-- Security model (the game ships the publishable key, so assume it is public):
--   * anon can INSERT snapshots. Nothing else on the table: no select, update, delete.
--   * anon can call get_opponent_snapshot(), which returns ONE random snapshot.
--     Nobody can dump the table.
--   * Row checks cap sizes and ranges so junk inserts stay small.
--   * Snapshot contents are still untrusted: the game sanitizes every
--     snapshot it downloads (wave_manager.gd sanitize_snapshot).

-- ── Table ───────────────────────────────────────────────────────────────────
create table if not exists public.defense_snapshots (
  id            bigint generated always as identity primary key,
  player_id     text        not null check (player_id ~ '^[A-Za-z0-9_-]{1,64}$'),
  player_name   text        not null default '' check (char_length(player_name) <= 24),
  wave          int         not null check (wave between 1 and 15),
  power         int         not null check (power between 0 and 100000),
  game_version  text        not null default '' check (char_length(game_version) <= 16),
  data          jsonb       not null check (octet_length(data::text) <= 32768),
  created_at    timestamptz not null default now()
);

create index if not exists defense_snapshots_wave_power_idx
  on public.defense_snapshots (wave, power);
create index if not exists defense_snapshots_player_wave_idx
  on public.defense_snapshots (player_id, wave);

-- ── Row Level Security + grants ─────────────────────────────────────────────
alter table public.defense_snapshots enable row level security;

revoke all on public.defense_snapshots from anon, authenticated;
grant insert on public.defense_snapshots to anon;

drop policy if exists "anon can insert snapshots" on public.defense_snapshots;
create policy "anon can insert snapshots"
  on public.defense_snapshots
  for insert
  to anon
  with check (true);

-- ── Keep one snapshot per (player, wave) ────────────────────────────────────
-- anon has no delete right, so a security definer trigger prunes the older
-- row whenever the same player uploads the same wave again.
create or replace function public.prune_old_snapshots()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.defense_snapshots
  where player_id = new.player_id
    and wave = new.wave
    and id < new.id;
  return new;
end;
$$;

revoke all on function public.prune_old_snapshots() from public, anon, authenticated;

drop trigger if exists prune_old_snapshots_trg on public.defense_snapshots;
create trigger prune_old_snapshots_trg
  after insert on public.defense_snapshots
  for each row execute function public.prune_old_snapshots();

-- ── Matchmaking RPC ─────────────────────────────────────────────────────────
-- Returns one random snapshot (the jsonb `data`) for the given wave, never
-- from p_exclude. Snapshots within +-40% of p_power sort first; if p_power is
-- 0 or nothing is in range, any snapshot for that wave is fair game.
-- Returns null when the wave has no snapshots yet (game falls back to PvE).
create or replace function public.get_opponent_snapshot(
  p_wave    int,
  p_power   int,
  p_exclude text
)
returns jsonb
language sql
security definer
set search_path = public
volatile
as $$
  select s.data
  from public.defense_snapshots s
  where s.wave = p_wave
    and s.player_id is distinct from p_exclude
  order by
    (p_power > 0 and s.power between floor(p_power * 0.6) and ceil(p_power * 1.4)) desc,
    random()
  limit 1;
$$;

revoke all on function public.get_opponent_snapshot(int, int, text) from public;
grant execute on function public.get_opponent_snapshot(int, int, text) to anon;
