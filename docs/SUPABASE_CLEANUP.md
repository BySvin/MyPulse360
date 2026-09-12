# Supabase Cleanup Guide — Removing Obsolete Tables

> **Developer Guide Only**
> This document is a reference for planning and reviewing the removal of obsolete Supabase tables. It does **not** automatically execute any destructive SQL. All changes must be implemented through Supabase migrations and reviewed before execution.

---

## Current Database Architecture

### Patient

- `profiles` — user profiles tied to auth
- `clinic_id` — association with a clinic
- `wellness goals` — patient wellness goals
- `appointments` — patient appointments
- `prescriptions` — prescriptions issued to patients
- `chat_conversations` — patient chat threads
- `chat_messages` — messages within conversations

### Doctor

- `doctor profile` — doctor-specific profile data
- `consultations` — consultation records
- `appointments` — appointments assigned to doctors
- `leave management` — doctor leave records

### Staff

- `staff profile` — staff-specific profile data
- `temporary email` — temporary email during onboarding
- `invitation/confirmation` — invitation and confirmation flow
- `original email update` — original email update mechanism

### Clinic

- `clinic information` — clinic details
- `doctors` — doctors associated with a clinic
- `staff` — staff associated with a clinic
- `appointment management` — clinic-level appointment handling

---

## Tables to Remove

The following obsolete tables/features **must be removed**:

| Table | Notes |
|---|---|
| `inventory_items` | **Removed.** No replacement table. |
| `supplier` | **Removed.** |
| `shifts` | **Removed.** |

These tables are not part of the active MyPulse360 schema and should be dropped.

---

## Before Deleting

Follow every step before running the migration:

### 1. Open Supabase Project

Go to your Supabase dashboard and open the target project.

### 2. Confirm Tables Exist

Navigate to **Database → Tables** and confirm that `inventory_items`, `supplier`, and `shifts` still exist.

### 3. Check Foreign-Key Relationships and Dependencies

For each table, review:

- **Incoming foreign keys** — other tables referencing this table
- **Outgoing foreign keys** — this table referencing other tables
- **Unique constraints** or **indexes** attached to the table

Use the SQL editor or query `information_schema.table_constraints` and `information_schema.key_column_usage`.

### 4. Check RLS Policies

Review Row Level Security policies in **Authentication → Policies** (or via SQL) that target these tables:

```sql
SELECT schemaname, tablename, policyname
FROM pg_policies
WHERE tablename IN ('inventory_items', 'supplier', 'shifts');
```

### 5. Check Database Functions/Triggers

Search for any functions or triggers referencing these tables:

```sql
SELECT routine_name, routine_definition
FROM information_schema.routines
WHERE routine_definition ILIKE '%inventory_items%'
   OR routine_definition ILIKE '%supplier%'
   OR routine_definition ILIKE '%shifts%';
```

```sql
SELECT trigger_name, event_object_table, action_statement
FROM information_schema.triggers
WHERE event_object_table IN ('inventory_items', 'supplier', 'shifts')
   OR action_statement ILIKE '%inventory_items%'
   OR action_statement ILIKE '%supplier%'
   OR action_statement ILIKE '%shifts%';
```

### 6. Search the Project Codebase for References

Before proceeding, search your entire codebase for references to the obsolete tables. See [Codebase Search](#codebase-search) below.

### 7. Confirm No Breaking Changes

**Do not apply the migration until you have confirmed** that removing these tables will not break any required functionality. Remove or refactor any code that references these tables first.

---

## SQL Cleanup

### Safe Deletion Syntax

```sql
DROP TABLE IF EXISTS public.inventory_items CASCADE;
DROP TABLE IF EXISTS public.supplier CASCADE;
DROP TABLE IF EXISTS public.shifts CASCADE;
```

### ⚠️ Warning About `CASCADE`

Using `CASCADE` will automatically remove:

- Foreign key constraints referencing these tables
- Views dependent on these tables
- RLS policies targeting these tables
- Database functions or triggers that depend on these tables
- Any other dependent database objects

**Do not blindly run `CASCADE` without first confirming all dependencies.** Check foreign keys, policies, views, and functions before executing.

If you prefer a safer, incremental approach, drop dependent objects first, then drop the tables without `CASCADE`:

```sql
-- Drop dependent policies, functions, triggers first
-- Then:
DROP TABLE IF EXISTS public.inventory_items;
DROP TABLE IF EXISTS public.supplier;
DROP TABLE IF EXISTS public.shifts;
```

---

## Recommended Migration

Create a Supabase migration instead of manually deleting tables from the dashboard.

### Migration Location

```
supabase/migrations/<timestamp>_remove_obsolete_tables.sql
```

Generate a timestamp with:

```bash
date +%Y%m%d%H%M%S
```

Or use the Supabase CLI:

```bash
supabase migration new remove_obsolete_tables
```

### Migration SQL

```sql
-- Migration: Remove obsolete tables
-- Tables: inventory_items, supplier, shifts
-- Date: <insert date>
--
-- Review all dependencies before applying.

BEGIN;

-- Drop RLS policies targeting these tables
DROP POLICY IF EXISTS "..." ON public.inventory_items;
DROP POLICY IF EXISTS "..." ON public.supplier;
DROP POLICY IF EXISTS "..." ON public.shifts;

-- Drop triggers if any exist
-- DROP TRIGGER IF EXISTS <trigger_name> ON public.inventory_items;

-- Drop functions if any exist
-- DROP FUNCTION IF EXISTS <function_name>();

-- Drop the tables
DROP TABLE IF EXISTS public.inventory_items CASCADE;
DROP TABLE IF EXISTS public.supplier CASCADE;
DROP TABLE IF EXISTS public.shifts CASCADE;

COMMIT;
```

Update the placeholder policy names, trigger names, and function names after running the dependency checks from [Before Deleting](#before-deleting).

### Do NOT Auto-Execute

This migration must **not** be applied automatically. The developer must review the migration and explicitly approve it before running it against any environment.

Apply via Supabase CLI:

```bash
supabase db push
```

Or apply manually through the Supabase SQL editor after review.

---

## Verification After Deletion

Run through every item after the migration has been applied:

### Database Verification

- [ ] `inventory_items` no longer exists
- [ ] `supplier` no longer exists
- [ ] `shifts` no longer exists
- [ ] No required foreign keys reference the deleted tables
- [ ] No RLS policies reference the deleted tables
- [ ] No database functions reference the deleted tables
- [ ] No triggers reference the deleted tables
- [ ] No views reference the deleted tables

### Codebase Verification

- [ ] No frontend code references the deleted tables
- [ ] No backend code references the deleted tables
- [ ] Application builds successfully

### Functional Verification

- [ ] Patient functionality still works
- [ ] Doctor functionality still works
- [ ] Staff functionality still works
- [ ] Appointment booking still works

### Migration Verification

- [ ] Supabase migrations complete successfully

---

## Codebase Search

Search your project for references to the obsolete tables before and after the migration.

### PowerShell (Windows)

```powershell
rg -i "inventory_items" --type-add 'code:*.{ts,tsx,js,jsx,sql,json,md}' -t code
rg -i "\bsupplier\b" --type-add 'code:*.{ts,tsx,js,jsx,sql,json,md}' -t code
rg -i "\bshifts\b" --type-add 'code:*.{ts,tsx,js,jsx,sql,json,md}' -t code
```

### Bash (macOS / Linux)

```bash
grep -rn "inventory_items" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" --include="*.sql" --include="*.json" .
grep -rn "supplier" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" --include="*.sql" --include="*.json" .
grep -rn "shifts" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" --include="*.sql" --include="*.json" .
```

### What to Do With Found References

If you find references to these tables in your codebase:

1. **Remove the code** — do not simply hide the UI or comment it out
2. **Remove associated imports** — clean up any unused imports
3. **Remove associated components or utilities** — if they exist solely for these features
4. **Verify no other code depends on the removed code**

---

## Important Warning

> **These database changes are destructive.**
>
> Review the Supabase schema, all dependencies, and the migration SQL before applying them. Do not delete production data without a verified backup or migration plan.
>
> Always run the migration against a development or staging environment first. Verify the application still works correctly before applying the migration to production.
>
> The README above is a developer guide. The actual database changes must be implemented through Supabase migrations, reviewed, and approved before execution.
