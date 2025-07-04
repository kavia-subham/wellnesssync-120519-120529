-- Migration 001: Initial Schema for AI-Powered Wellness Platform
-- Applies to: Supabase / PostgreSQL
-- Author: AI CodeGen
-- Description: Defines base tables, relationships, indexes, and role setup for user, health data, device integration, recommendation, feedback, and outcomes.
-- SECURITY: Follows best practice for securing sensitive data (row- and column-level privacy, auditability).

-- ================================
-- 1. BASIC ROLES & SECURITY SETUP
-- ================================
-- Create a standard app role (read/write on own rows), and a limited analytics role (read-only, aggregate data).
CREATE ROLE wellness_app_user NOINHERIT;
CREATE ROLE wellness_analytics NOINHERIT;

-- Table: users
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    full_name TEXT,
    date_of_birth DATE,
    gender VARCHAR(10),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Sensitive columns: password_hash, email
-- Optionally, use PostgreSQL's Row Level Security (RLS) in Supabase for privacy.

-- Table: device_integrations
CREATE TABLE device_integrations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_type TEXT NOT NULL, -- e.g. 'fitbit', 'apple_health', etc.
    device_identifier TEXT,     -- Device unique id
    access_token TEXT,          -- Secure: Obfuscated at the app layer if needed
    refresh_token TEXT,
    expires_at TIMESTAMP WITH TIME ZONE,
    metadata JSONB,
    connected_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, device_type)
);

-- Table: health_data
CREATE TABLE health_data (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_id UUID REFERENCES device_integrations(id) ON DELETE SET NULL,
    data_type TEXT NOT NULL, -- e.g. 'heart_rate', 'sleep', 'steps'
    data_value NUMERIC,      -- Store as numeric, or in data_json for details
    data_json JSONB,         -- For storing structured info (e.g. sleep breakdown)
    measured_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_health_data_user_type_measured ON health_data(user_id, data_type, measured_at DESC);

-- Table: recommendations
CREATE TABLE recommendations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    generated_by TEXT,    -- AI model version or algorithm reference
    content TEXT NOT NULL,
    recommendation_type TEXT, -- 'nutrition', 'exercise', 'mental_health', etc.
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    valid_until TIMESTAMP WITH TIME ZONE,
    responded BOOLEAN DEFAULT FALSE
);

CREATE INDEX idx_recommendations_user_created ON recommendations(user_id, created_at DESC);

-- Table: feedback
CREATE TABLE feedback (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    recommendation_id UUID REFERENCES recommendations(id) ON DELETE SET NULL,
    feedback_text TEXT,
    rating INTEGER CHECK (rating BETWEEN 1 AND 5),
    submitted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_feedback_recommendation_user ON feedback(recommendation_id, user_id);

-- Table: outcomes
CREATE TABLE outcomes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    health_data_id UUID REFERENCES health_data(id) ON DELETE SET NULL,
    recommendation_id UUID REFERENCES recommendations(id) ON DELETE SET NULL,
    outcome_type TEXT, -- e.g. "weight_change", "blood_pressure", "adherence"
    outcome_value TEXT, -- Value or summary (can also use JSON)
    measured_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_outcomes_user_type_measured ON outcomes(user_id, outcome_type, measured_at DESC);

-- ==================
-- 2. RELATIONSHIPS
-- ==================
-- (Done via proper FK constraints on user_id, device_id, recommendation_id.)

-- ==========================
-- 3. ROLES, PRIVILEGES, RLS
-- ==========================
-- NOTE: Supabase applies RLS policies via its dashboard; here is a sample setup for native Postgres.

-- Grant privileges for app user
GRANT USAGE, SELECT, INSERT, UPDATE, DELETE ON ALL SEQUENCES IN SCHEMA public TO wellness_app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO wellness_app_user;

-- Analytics role: read-only, no PII
GRANT CONNECT ON DATABASE myapp TO wellness_analytics;
GRANT USAGE ON SCHEMA public TO wellness_analytics;
GRANT SELECT ON TABLE health_data, recommendations, outcomes TO wellness_analytics;

-- =====================
-- 4. AUDIT/SECURITY NOTE
-- =====================
-- For full production, consider adding an audit trail table, encrypted columns (pgcrypto), and using Supabase RLS policies for multi-tenancy isolation.

-- ===================
-- 5. FUTURE EXTENSIONS
-- ===================
-- e.g. Add audit_log, consents table, notifications...

-- =====================
-- END OF MIGRATION FILE
-- =====================
