create table if not exists users (
  id uuid primary key,
  email text unique not null,
  plan text not null default 'free',
  created_at timestamptz not null default now()
);

create table if not exists subscriptions (
  id uuid primary key,
  user_id uuid not null references users(id),
  stripe_customer_id text,
  stripe_subscription_id text,
  status text not null,
  current_period_end timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists usage_logs (
  id bigserial primary key,
  user_id uuid not null references users(id),
  session_id text not null,
  command_text text,
  status text not null,
  latency_ms integer,
  created_at timestamptz not null default now()
);
