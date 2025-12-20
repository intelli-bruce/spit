-- Throw Initial Schema
-- Block-based notes with tags and history

-- ============================================
-- 1. Tables
-- ============================================

-- Notes (metadata)
CREATE TABLE notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    source TEXT NOT NULL CHECK (source IN ('ios', 'mac')),
    device_id TEXT,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

-- Note blocks (content: text, image, audio, video)
CREATE TABLE note_blocks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    note_id UUID NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
    parent_id UUID REFERENCES note_blocks(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('text', 'image', 'audio', 'video')),
    content TEXT,
    storage_path TEXT,
    position INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version INTEGER NOT NULL DEFAULT 1
);

-- Block history (unlimited retention)
CREATE TABLE note_block_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    block_id UUID NOT NULL REFERENCES note_blocks(id) ON DELETE CASCADE,
    content TEXT,
    storage_path TEXT,
    version INTEGER NOT NULL,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    change_type TEXT NOT NULL CHECK (change_type IN ('create', 'update', 'delete'))
);

-- Tags
CREATE TABLE tags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Note-Tag junction
CREATE TABLE note_tags (
    note_id UUID NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
    tag_id UUID NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (note_id, tag_id)
);

-- ============================================
-- 2. Indexes
-- ============================================

CREATE INDEX idx_notes_created_at ON notes(created_at DESC);
CREATE INDEX idx_notes_updated_at ON notes(updated_at DESC);
CREATE INDEX idx_notes_is_deleted ON notes(is_deleted);
CREATE INDEX idx_notes_source ON notes(source);

CREATE INDEX idx_note_blocks_note_id ON note_blocks(note_id);
CREATE INDEX idx_note_blocks_parent_id ON note_blocks(parent_id);
CREATE INDEX idx_note_blocks_type ON note_blocks(type);
CREATE INDEX idx_note_blocks_position ON note_blocks(note_id, position);

CREATE INDEX idx_note_block_history_block_id ON note_block_history(block_id);
CREATE INDEX idx_note_block_history_version ON note_block_history(block_id, version DESC);

CREATE INDEX idx_note_tags_note_id ON note_tags(note_id);
CREATE INDEX idx_note_tags_tag_id ON note_tags(tag_id);

-- ============================================
-- 3. Row Level Security
-- ============================================

ALTER TABLE notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE note_blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE note_block_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE note_tags ENABLE ROW LEVEL SECURITY;

-- Anonymous access policies (v1)
CREATE POLICY "Allow all on notes"
    ON notes FOR ALL
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Allow all on note_blocks"
    ON note_blocks FOR ALL
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Allow all on note_block_history"
    ON note_block_history FOR ALL
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Allow all on tags"
    ON tags FOR ALL
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Allow all on note_tags"
    ON note_tags FOR ALL
    USING (true)
    WITH CHECK (true);

-- ============================================
-- 4. Realtime
-- ============================================

ALTER PUBLICATION supabase_realtime ADD TABLE notes;
ALTER PUBLICATION supabase_realtime ADD TABLE note_blocks;
ALTER PUBLICATION supabase_realtime ADD TABLE tags;
ALTER PUBLICATION supabase_realtime ADD TABLE note_tags;

-- ============================================
-- 5. Triggers
-- ============================================

-- Update updated_at on notes
CREATE OR REPLACE FUNCTION update_notes_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER notes_updated_at
    BEFORE UPDATE ON notes
    FOR EACH ROW
    EXECUTE FUNCTION update_notes_updated_at();

-- Update updated_at and version on note_blocks
CREATE OR REPLACE FUNCTION update_note_blocks_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    NEW.version = OLD.version + 1;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER note_blocks_updated_at
    BEFORE UPDATE ON note_blocks
    FOR EACH ROW
    EXECUTE FUNCTION update_note_blocks_updated_at();

-- Auto-save to history on block changes
CREATE OR REPLACE FUNCTION save_block_history()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO note_block_history (block_id, content, storage_path, version, change_type)
        VALUES (NEW.id, NEW.content, NEW.storage_path, NEW.version, 'create');
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO note_block_history (block_id, content, storage_path, version, change_type)
        VALUES (OLD.id, OLD.content, OLD.storage_path, OLD.version, 'update');
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO note_block_history (block_id, content, storage_path, version, change_type)
        VALUES (OLD.id, OLD.content, OLD.storage_path, OLD.version, 'delete');
    END IF;
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER note_blocks_history
    AFTER INSERT OR UPDATE OR DELETE ON note_blocks
    FOR EACH ROW
    EXECUTE FUNCTION save_block_history();

-- Update parent note's updated_at when block changes
CREATE OR REPLACE FUNCTION update_note_on_block_change()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        UPDATE notes SET updated_at = NOW() WHERE id = OLD.note_id;
    ELSE
        UPDATE notes SET updated_at = NOW() WHERE id = NEW.note_id;
    END IF;
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER note_blocks_update_note
    AFTER INSERT OR UPDATE OR DELETE ON note_blocks
    FOR EACH ROW
    EXECUTE FUNCTION update_note_on_block_change();

-- ============================================
-- 6. Storage (run in Supabase Dashboard)
-- ============================================

-- Create bucket:
-- INSERT INTO storage.buckets (id, name, public)
-- VALUES ('throw-media', 'throw-media', true);

-- Storage policies:
-- CREATE POLICY "Public read" ON storage.objects FOR SELECT USING (bucket_id = 'throw-media');
-- CREATE POLICY "Public upload" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'throw-media');
-- CREATE POLICY "Public update" ON storage.objects FOR UPDATE USING (bucket_id = 'throw-media');
-- CREATE POLICY "Public delete" ON storage.objects FOR DELETE USING (bucket_id = 'throw-media');
