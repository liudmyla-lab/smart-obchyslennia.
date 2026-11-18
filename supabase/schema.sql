-- SMART-Обчислення: базова схема Supabase
-- Виконуйте в SQL Editor нового проєкту Supabase.
create type public.user_role as enum ('teacher','student');

create table public.classes (
 id uuid primary key default gen_random_uuid(),
 name text not null,
 teacher_id uuid not null references auth.users(id) on delete cascade,
 join_code text unique not null default upper(substr(encode(gen_random_bytes(8),'hex'),1,8)),
 created_at timestamptz not null default now()
);

create table public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 full_name text not null,
 role public.user_role not null default 'student',
 class_id uuid references public.classes(id) on delete set null,
 avatar text default '🧑‍🚀',
 created_at timestamptz not null default now()
);

create table public.tasks (
 id text primary key,
 module text not null,
 title text not null,
 prompt text not null,
 visual text,
 answer text not null,
 options jsonb not null,
 hint text,
 level int not null default 1,
 active boolean not null default true
);

create table public.attempts (
 id uuid primary key default gen_random_uuid(),
 student_id uuid not null references public.profiles(id) on delete cascade,
 task_id text not null,
 module_name text not null,
 is_correct boolean not null,
 answer_given text,
 stars_awarded int not null default 0,
 created_at timestamptz not null default now()
);

create table public.diagnostics (
 id uuid primary key default gen_random_uuid(),
 student_id uuid not null references public.profiles(id) on delete cascade,
 phase text not null check (phase in ('initial','final')),
 score numeric not null check (score between 0 and 100),
 assessed_at timestamptz not null default now(),
 notes text
);

alter table public.classes enable row level security;
alter table public.profiles enable row level security;
alter table public.tasks enable row level security;
alter table public.attempts enable row level security;
alter table public.diagnostics enable row level security;

create policy "Users read own profile" on public.profiles for select to authenticated using (id=auth.uid());
create policy "Teachers read students in own classes" on public.profiles for select to authenticated
 using (exists(select 1 from public.classes c where c.id=profiles.class_id and c.teacher_id=auth.uid()));
create policy "User update own profile" on public.profiles for update to authenticated using (id=auth.uid()) with check (id=auth.uid());
create policy "Authenticated read active tasks" on public.tasks for select to authenticated using (active=true);
create policy "Students read own attempts" on public.attempts for select to authenticated using (student_id=auth.uid());
create policy "Students insert own attempts" on public.attempts for insert to authenticated with check (student_id=auth.uid());
create policy "Teachers read class attempts" on public.attempts for select to authenticated using (
 exists(select 1 from public.profiles p join public.classes c on c.id=p.class_id where p.id=attempts.student_id and c.teacher_id=auth.uid())
);
create policy "Students read own diagnostics" on public.diagnostics for select to authenticated using (student_id=auth.uid());
create policy "Teachers manage class diagnostics" on public.diagnostics for all to authenticated using (
 exists(select 1 from public.profiles p join public.classes c on c.id=p.class_id where p.id=diagnostics.student_id and c.teacher_id=auth.uid())
) with check (
 exists(select 1 from public.profiles p join public.classes c on c.id=p.class_id where p.id=diagnostics.student_id and c.teacher_id=auth.uid())
);
create policy "Teachers manage own classes" on public.classes for all to authenticated using (teacher_id=auth.uid()) with check (teacher_id=auth.uid());

-- NOTE: Для реєстрації ролей і створення учнівських облікових записів
-- потрібен серверний endpoint з Supabase service-role key.
-- НІКОЛИ не розміщуйте service-role key у NEXT_PUBLIC_* або браузерному коді.
