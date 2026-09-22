alter table public.set_entries add column if not exists completed_at timestamptz not null default now();
alter table public.completed_set_entries add column if not exists completed_at timestamptz;
