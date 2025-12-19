-- Drops Journal Schema

-- Journal entries table (individual entries from iOS/Mac)
CREATE TABLE journal_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content TEXT NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    source TEXT NOT NULL CHECK (source IN ('mac', 'ios', 'manual')),
    device_id TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE,
    version INTEGER DEFAULT 1
);

-- Journal metadata (full document sync)
CREATE TABLE journal_metadata (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    full_content TEXT NOT NULL,
    content_hash TEXT NOT NULL,
    last_sync_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version INTEGER DEFAULT 1
);

-- Row Level Security (anonymous access for now)
ALTER TABLE journal_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE journal_metadata ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all on journal_entries"
    ON journal_entries FOR ALL
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Allow all on journal_metadata"
    ON journal_metadata FOR ALL
    USING (true)
    WITH CHECK (true);

-- Enable Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE journal_entries;
ALTER PUBLICATION supabase_realtime ADD TABLE journal_metadata;

-- Indexes
CREATE INDEX idx_journal_entries_timestamp ON journal_entries(timestamp DESC);
CREATE INDEX idx_journal_entries_source ON journal_entries(source);

-- Updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    NEW.version = OLD.version + 1;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER journal_entries_updated_at
    BEFORE UPDATE ON journal_entries
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();

-- Insert initial metadata row
INSERT INTO journal_metadata (full_content, content_hash)
VALUES ('# Journal\n\n---\n', 'initial');
