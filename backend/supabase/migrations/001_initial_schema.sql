-- ═══════════════════════════════════════════════════════════════════
-- Chippy — Initial Schema
-- Run this in: Supabase Dashboard → SQL Editor → New Query → Run
-- ═══════════════════════════════════════════════════════════════════

-- UUID generation
create extension if not exists "uuid-ossp";


-- ───────────────────────────────────────────────────────────────────
-- TABLES
-- ───────────────────────────────────────────────────────────────────

create table public.documents (
    id              uuid primary key default uuid_generate_v4(),
    user_id         uuid not null references auth.users(id) on delete cascade,
    filename        text not null,
    file_path       text not null,      -- Supabase Storage path: {user_id}/{document_id}/{filename}
    file_size       integer,            -- bytes
    mime_type       text,               -- application/pdf | image/jpeg | image/png | image/heic
    document_type   text not null default 'other',
                                        -- lab_result | radiology | discharge_summary |
                                        -- clinical_note | prescription | insurance | other
    status          text not null default 'processing',
                                        -- processing | complete | failed
    ocr_text        text,               -- on-device Vision OCR text sent from iOS
    error_message   text,               -- populated on status=failed
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now()
);

create table public.analysis_results (
    id              uuid primary key default uuid_generate_v4(),
    document_id     uuid not null references public.documents(id) on delete cascade,
    user_id         uuid not null references auth.users(id) on delete cascade,
    summary         text,               -- plain-language document summary
    explainer_text  text,               -- cached explainer response (avoids re-calling LLM)
    document_date   date,               -- date of the medical event, not the upload date
    provider_name   text,
    diagnoses       jsonb not null default '[]'::jsonb,
                                        -- [{code, name, description}]
    medications     jsonb not null default '[]'::jsonb,
                                        -- [{name, dose, frequency, route}]
    lab_values      jsonb not null default '[]'::jsonb,
                                        -- [{name, value, unit, reference_range, is_abnormal}]
    key_findings    jsonb not null default '[]'::jsonb,
                                        -- [string]
    created_at      timestamptz not null default now()
);

create table public.health_events (
    id              uuid primary key default uuid_generate_v4(),
    user_id         uuid not null references auth.users(id) on delete cascade,
    document_id     uuid references public.documents(id) on delete set null,
    title           text not null,
    category        text not null,      -- diagnosis | medication | lab | procedure | visit | imaging | insurance
    event_date      date,
    summary         text,
    created_at      timestamptz not null default now()
);

create table public.chat_messages (
    id                  uuid primary key default uuid_generate_v4(),
    user_id             uuid not null references auth.users(id) on delete cascade,
    role                text not null check (role in ('user', 'assistant')),
    content             text not null,
    source_document_ids jsonb not null default '[]'::jsonb,
                                        -- document IDs the assistant cited
    created_at          timestamptz not null default now()
);


-- ───────────────────────────────────────────────────────────────────
-- INDEXES
-- ───────────────────────────────────────────────────────────────────

create index documents_user_id_idx          on public.documents(user_id);
create index documents_status_idx           on public.documents(status);
create index documents_user_status_idx      on public.documents(user_id, status);

create index analysis_results_document_idx  on public.analysis_results(document_id);
create index analysis_results_user_idx      on public.analysis_results(user_id);

create index health_events_user_id_idx      on public.health_events(user_id);
create index health_events_event_date_idx   on public.health_events(event_date);
create index health_events_category_idx     on public.health_events(user_id, category);

create index chat_messages_user_id_idx      on public.chat_messages(user_id);
create index chat_messages_created_at_idx   on public.chat_messages(user_id, created_at desc);


-- ───────────────────────────────────────────────────────────────────
-- AUTO-UPDATE updated_at ON documents
-- ───────────────────────────────────────────────────────────────────

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

create trigger documents_set_updated_at
    before update on public.documents
    for each row
    execute function public.set_updated_at();


-- ───────────────────────────────────────────────────────────────────
-- ROW LEVEL SECURITY
-- ───────────────────────────────────────────────────────────────────

alter table public.documents          enable row level security;
alter table public.analysis_results   enable row level security;
alter table public.health_events      enable row level security;
alter table public.chat_messages      enable row level security;


-- documents policies
create policy "documents: users read own"
    on public.documents for select
    using (auth.uid() = user_id);

create policy "documents: users insert own"
    on public.documents for insert
    with check (auth.uid() = user_id);

create policy "documents: users update own"
    on public.documents for update
    using (auth.uid() = user_id);

create policy "documents: users delete own"
    on public.documents for delete
    using (auth.uid() = user_id);


-- analysis_results policies
create policy "analysis_results: users read own"
    on public.analysis_results for select
    using (auth.uid() = user_id);

create policy "analysis_results: users insert own"
    on public.analysis_results for insert
    with check (auth.uid() = user_id);

create policy "analysis_results: users update own"
    on public.analysis_results for update
    using (auth.uid() = user_id);

create policy "analysis_results: users delete own"
    on public.analysis_results for delete
    using (auth.uid() = user_id);


-- health_events policies
create policy "health_events: users read own"
    on public.health_events for select
    using (auth.uid() = user_id);

create policy "health_events: users insert own"
    on public.health_events for insert
    with check (auth.uid() = user_id);

create policy "health_events: users update own"
    on public.health_events for update
    using (auth.uid() = user_id);

create policy "health_events: users delete own"
    on public.health_events for delete
    using (auth.uid() = user_id);


-- chat_messages policies
create policy "chat_messages: users read own"
    on public.chat_messages for select
    using (auth.uid() = user_id);

create policy "chat_messages: users insert own"
    on public.chat_messages for insert
    with check (auth.uid() = user_id);

create policy "chat_messages: users delete own"
    on public.chat_messages for delete
    using (auth.uid() = user_id);


-- ───────────────────────────────────────────────────────────────────
-- STORAGE BUCKET
-- Create the bucket manually in Supabase Dashboard:
--   Storage → New bucket → Name: "medical-documents" → Private (not public)
--
-- Then run the storage RLS policies below.
-- ───────────────────────────────────────────────────────────────────

-- Storage policies (run AFTER creating the bucket in the dashboard)
create policy "storage: users read own files"
    on storage.objects for select
    using (
        bucket_id = 'medical-documents'
        and auth.uid()::text = (storage.foldername(name))[1]
    );

create policy "storage: users upload own files"
    on storage.objects for insert
    with check (
        bucket_id = 'medical-documents'
        and auth.uid()::text = (storage.foldername(name))[1]
    );

create policy "storage: users delete own files"
    on storage.objects for delete
    using (
        bucket_id = 'medical-documents'
        and auth.uid()::text = (storage.foldername(name))[1]
    );
