# Reelay Cross-Platform Performance Optimization Guide

This document details all database and client-side optimizations implemented to reduce loading times for the Home, Movies, and Lists screens. Use this guide to implement the same optimizations on iOS.

---

## Table of Contents

1. [Overview](#overview)
2. [Database Functions (Deploy First)](#database-functions-deploy-first)
3. [Client-Side Changes by Screen](#client-side-changes-by-screen)
4. [Data Models](#data-models)
5. [Migration Strategy](#migration-strategy)

---

## Overview

### Problem Statement

The app was making excessive database round-trips due to N+1 query patterns:

| Screen | Before | After | Reduction |
|--------|--------|-------|-----------|
| Lists (50 lists) | ~52 queries | 1 query | 98% |
| Movies (50 rewatches) | ~51 queries | 2 queries | 96% |
| Home Goals | ~8 queries | 1-2 queries | 87% |

### Solution Approach

1. **Server-side aggregation**: Move computation to PostgreSQL functions
2. **Batch queries**: Replace N individual queries with single batch queries
3. **Database indexes**: Add indexes for common query patterns

---

## Database Functions

optimization_functions.sql
Already deployed

### Function Reference

#### 1. `get_lists_with_summary(user_id_param UUID)`

**Purpose**: Returns all lists with pre-computed item counts, watched counts, and first item artwork in a single query.

**Replaces**: 
- 1 query for all lists
- N queries for items (one per list)  
- 1 query for watched status

**Returns**:
```
TABLE (
    id UUID,
    user_id UUID,
    name TEXT,
    description TEXT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    pinned BOOLEAN,
    ranked BOOLEAN,
    tags TEXT,
    themed_month_date DATE,
    item_count BIGINT,
    watched_count BIGINT,
    first_item_poster_url TEXT,
    first_item_backdrop_path TEXT
)
```

**SQL**:
```sql
CREATE OR REPLACE FUNCTION get_lists_with_summary(user_id_param UUID)
RETURNS TABLE (
    id UUID,
    user_id UUID,
    name TEXT,
    description TEXT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    pinned BOOLEAN,
    ranked BOOLEAN,
    tags TEXT,
    themed_month_date DATE,
    item_count BIGINT,
    watched_count BIGINT,
    first_item_poster_url TEXT,
    first_item_backdrop_path TEXT
) LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    WITH list_stats AS (
        SELECT 
            li.list_id,
            COUNT(*) AS item_count,
            COUNT(DISTINCT d.tmdb_id) AS watched_count
        FROM list_items li
        LEFT JOIN diary d ON li.tmdb_id = d.tmdb_id
        GROUP BY li.list_id
    ),
    first_items AS (
        SELECT DISTINCT ON (li.list_id)
            li.list_id,
            li.movie_poster_url,
            li.movie_backdrop_path
        FROM list_items li
        ORDER BY li.list_id, li.sort_order ASC
    )
    SELECT 
        l.id,
        l.user_id,
        l.name,
        l.description,
        l.created_at,
        l.updated_at,
        l.pinned,
        l.ranked,
        l.tags,
        l.themed_month_date,
        COALESCE(ls.item_count, 0)::BIGINT,
        COALESCE(ls.watched_count, 0)::BIGINT,
        fi.movie_poster_url,
        fi.movie_backdrop_path
    FROM lists l
    LEFT JOIN list_stats ls ON l.id = ls.list_id
    LEFT JOIN first_items fi ON l.id = fi.list_id
    WHERE l.user_id = user_id_param
    ORDER BY l.pinned DESC, l.updated_at DESC;
END;
$$;
```

---

#### 2. `get_first_watch_dates(tmdb_ids INTEGER[])`

**Purpose**: Returns first watch dates for multiple TMDB IDs in a single batch query. Used for computing rewatch colors (yellow = same year, orange = different year).

**Replaces**: N individual queries to get first watch date for each rewatch entry.

**Returns**:
```
TABLE (
    tmdb_id INTEGER,
    first_watch_date DATE,
    first_watch_year INTEGER
)
```

**SQL**:
```sql
CREATE OR REPLACE FUNCTION get_first_watch_dates(tmdb_ids INTEGER[])
RETURNS TABLE (
    tmdb_id INTEGER,
    first_watch_date DATE,
    first_watch_year INTEGER
) LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT ON (d.tmdb_id)
        d.tmdb_id::INTEGER,
        d.watched_date,
        EXTRACT(YEAR FROM d.watched_date)::INTEGER
    FROM diary d
    WHERE d.tmdb_id = ANY(tmdb_ids)
      AND (d.rewatch IS NULL OR d.rewatch != 'yes')
    ORDER BY d.tmdb_id, d.watched_date ASC;
END;
$$;
```

---

#### 3. `get_goals_data(user_id_param UUID, target_year INTEGER, current_month INTEGER)`

**Purpose**: Returns all goals data (Must Watches, Looking Forward, Themed Month lists) with pre-computed watched counts in a single query.

**Replaces**:
- Query for all lists
- Query for Must Watches items
- Query for Looking Forward items
- Query for Themed Month items
- Batch query for watched status

**Returns**:
```
TABLE (
    list_type TEXT,        -- 'must_watches', 'looking_forward', or 'themed_month'
    list_id UUID,
    list_name TEXT,
    total_items BIGINT,
    watched_count BIGINT,
    items JSONB            -- Array of {tmdb_id, title, poster_url, is_watched}
)
```

**SQL**:
```sql
CREATE OR REPLACE FUNCTION get_goals_data(
    user_id_param UUID,
    target_year INTEGER,
    current_month INTEGER
)
RETURNS TABLE (
    list_type TEXT,
    list_id UUID,
    list_name TEXT,
    total_items BIGINT,
    watched_count BIGINT,
    items JSONB
) LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    WITH goal_lists AS (
        -- Must Watches list
        SELECT 
            'must_watches' AS list_type,
            l.id,
            l.name
        FROM lists l
        WHERE l.user_id = user_id_param
          AND LOWER(l.name) LIKE '%must watch%'
          AND l.name LIKE '%' || target_year::TEXT || '%'
        
        UNION ALL
        
        -- Looking Forward list
        SELECT 
            'looking_forward' AS list_type,
            l.id,
            l.name
        FROM lists l
        WHERE l.user_id = user_id_param
          AND LOWER(l.name) LIKE '%looking forward%'
          AND l.name LIKE '%' || target_year::TEXT || '%'
        
        UNION ALL
        
        -- Themed Month lists
        SELECT 
            'themed_month' AS list_type,
            l.id,
            l.name
        FROM lists l
        WHERE l.user_id = user_id_param
          AND l.themed_month_date IS NOT NULL
          AND EXTRACT(MONTH FROM l.themed_month_date) = current_month
          AND EXTRACT(YEAR FROM l.themed_month_date) = target_year
    ),
    list_data AS (
        SELECT 
            gl.list_type,
            gl.id AS list_id,
            gl.name AS list_name,
            COUNT(li.id) AS total_items,
            COUNT(DISTINCT d.tmdb_id) AS watched_count,
            jsonb_agg(
                jsonb_build_object(
                    'tmdb_id', li.tmdb_id,
                    'title', li.movie_title,
                    'poster_url', li.movie_poster_url,
                    'is_watched', (d.tmdb_id IS NOT NULL)
                ) ORDER BY li.sort_order
            ) AS items
        FROM goal_lists gl
        LEFT JOIN list_items li ON gl.id = li.list_id
        LEFT JOIN diary d ON li.tmdb_id = d.tmdb_id
        GROUP BY gl.list_type, gl.id, gl.name
    )
    SELECT * FROM list_data;
END;
$$;
```

---

#### 4. `get_must_watches_mapping(user_id_param UUID)`

**Purpose**: Returns a mapping of TMDB IDs to years they appear in "Must Watches" lists. Used for purple title highlighting on Movies screen.

**Returns**:
```
TABLE (
    tmdb_id INTEGER,
    years INTEGER[]
)
```

**SQL**:
```sql
CREATE OR REPLACE FUNCTION get_must_watches_mapping(user_id_param UUID)
RETURNS TABLE (
    tmdb_id INTEGER,
    years INTEGER[]
) LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    WITH must_watch_lists AS (
        SELECT 
            l.id,
            (regexp_match(l.name, '(\d{4})'))[1]::INTEGER AS year
        FROM lists l
        WHERE l.user_id = user_id_param
          AND LOWER(l.name) LIKE '%must watch%'
          AND l.name ~ '\d{4}'
    )
    SELECT 
        li.tmdb_id,
        array_agg(DISTINCT mwl.year ORDER BY mwl.year) AS years
    FROM must_watch_lists mwl
    JOIN list_items li ON mwl.id = li.list_id
    GROUP BY li.tmdb_id;
END;
$$;
```

---

#### 5. `get_list_items_with_watched(list_id_param UUID)`

**Purpose**: Returns list items with watched status and rating in a single query.

**Returns**:
```
TABLE (
    id BIGINT,
    list_id UUID,
    tmdb_id INTEGER,
    movie_title TEXT,
    movie_poster_url TEXT,
    movie_backdrop_path TEXT,
    movie_year INTEGER,
    movie_release_date DATE,
    added_at TIMESTAMPTZ,
    sort_order INTEGER,
    is_watched BOOLEAN,
    diary_entry_id INTEGER,
    rating NUMERIC,
    ratings100 NUMERIC
)
```

**SQL**:
```sql
CREATE OR REPLACE FUNCTION get_list_items_with_watched(list_id_param UUID)
RETURNS TABLE (
    id BIGINT,
    list_id UUID,
    tmdb_id INTEGER,
    movie_title TEXT,
    movie_poster_url TEXT,
    movie_backdrop_path TEXT,
    movie_year INTEGER,
    movie_release_date DATE,
    added_at TIMESTAMPTZ,
    sort_order INTEGER,
    is_watched BOOLEAN,
    diary_entry_id INTEGER,
    rating NUMERIC,
    ratings100 NUMERIC
) LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT 
        li.id,
        li.list_id,
        li.tmdb_id,
        li.movie_title,
        li.movie_poster_url,
        li.movie_backdrop_path,
        li.movie_year,
        li.movie_release_date,
        li.added_at,
        li.sort_order,
        (d.id IS NOT NULL) AS is_watched,
        d.id AS diary_entry_id,
        d.rating,
        d.ratings100
    FROM list_items li
    LEFT JOIN LATERAL (
        SELECT id, rating, ratings100
        FROM diary
        WHERE diary.tmdb_id = li.tmdb_id
        ORDER BY watched_date DESC
        LIMIT 1
    ) d ON true
    WHERE li.list_id = list_id_param
    ORDER BY li.sort_order ASC;
END;
$$;
```

---

### Database Indexes

Add these indexes for improved query performance:

```sql
-- Faster list item lookups by list_id with sort order
CREATE INDEX IF NOT EXISTS idx_list_items_list_id_sort 
ON list_items(list_id, sort_order);

-- Faster first watch date lookups (excludes rewatches)
CREATE INDEX IF NOT EXISTS idx_diary_tmdb_rewatch 
ON diary(tmdb_id, rewatch) 
WHERE rewatch IS NULL OR rewatch != 'yes';

-- Faster recent movies queries
CREATE INDEX IF NOT EXISTS idx_diary_watched_date_desc 
ON diary(watched_date DESC NULLS LAST, created_at DESC);

-- Faster list name pattern matching
CREATE INDEX IF NOT EXISTS idx_lists_user_name_pattern 
ON lists(user_id, lower(name));

-- Faster themed month date lookups
CREATE INDEX IF NOT EXISTS idx_lists_themed_month 
ON lists(user_id, themed_month_date) 
WHERE themed_month_date IS NOT NULL;
```

---

## Client-Side Changes by Screen

### Lists Screen

#### Before (N+1 Pattern)
```swift
// Pseudocode - iOS
func loadListsWithSummary() async {
    let lists = await supabase.from("lists").select().execute()  // 1 query
    
    for list in lists {
        let items = await supabase.from("list_items")
            .select()
            .eq("list_id", list.id)
            .execute()  // N queries
    }
    
    let allTmdbIds = lists.flatMap { $0.items.map { $0.tmdbId } }
    let watched = await supabase.from("diary")
        .select("tmdb_id")
        .in("tmdb_id", allTmdbIds)
        .execute()  // 1 query
}
```

#### After (Single Query)
```swift
// Pseudocode - iOS
func loadListsWithSummaryOptimized() async {
    let userId = getCurrentUserId()
    
    let results = await supabase.rpc(
        "get_lists_with_summary",
        params: ["user_id_param": userId]
    ).execute()  // 1 query - everything included!
    
    // Results already contain:
    // - item_count
    // - watched_count  
    // - first_item_poster_url
    // - first_item_backdrop_path
}
```

---

### Movies Screen - Rewatch Colors

#### Before (N+1 Pattern)
```swift
// Pseudocode - iOS
func computeRewatchColors(movies: [Movie]) async -> [Int: RewatchColor] {
    let rewatches = movies.filter { $0.isRewatch }
    var colors: [Int: RewatchColor] = [:]
    
    for rewatch in rewatches {
        // Individual query for each rewatch!
        let firstWatch = await getFirstWatchDate(tmdbId: rewatch.tmdbId)
        
        if firstWatch == nil {
            colors[rewatch.id] = .grey
        } else if firstWatch.year == rewatch.watchedDate.year {
            colors[rewatch.id] = .yellow
        } else {
            colors[rewatch.id] = .orange
        }
    }
    return colors
}
```

#### After (Batch Query)
```swift
// Pseudocode - iOS
func computeRewatchColors(movies: [Movie]) async -> [Int: RewatchColor] {
    let rewatches = movies.filter { $0.isRewatch }
    let uniqueTmdbIds = Set(rewatches.compactMap { $0.tmdbId })
    
    // Single batch query for ALL first watch dates
    let firstWatchDates = await supabase.rpc(
        "get_first_watch_dates",
        params: ["tmdb_ids": Array(uniqueTmdbIds)]
    ).execute()
    
    // Build lookup map
    let dateMap = Dictionary(
        uniqueKeysWithValues: firstWatchDates.map { 
            ($0.tmdbId, (date: $0.firstWatchDate, year: $0.firstWatchYear)) 
        }
    )
    
    // Compute colors using the map (no more queries!)
    var colors: [Int: RewatchColor] = [:]
    for rewatch in rewatches {
        guard let tmdbId = rewatch.tmdbId else { continue }
        let firstWatch = dateMap[tmdbId]
        
        if firstWatch?.date == nil {
            colors[rewatch.id] = .grey
        } else if firstWatch?.year == rewatch.watchedDate?.year {
            colors[rewatch.id] = .yellow
        } else {
            colors[rewatch.id] = .orange
        }
    }
    return colors
}
```

---

### Home Screen - Goals Data

#### Before (Multiple Queries)
```swift
// Pseudocode - iOS
func loadGoalsData() async {
    let allLists = await getLists()  // 1 query
    
    // Find Must Watches list
    let mustWatchesList = allLists.first { 
        $0.name.lowercased().contains("must watch") && 
        $0.name.contains("\(currentYear)") 
    }
    let mustWatchesItems = await getListItems(mustWatchesList.id)  // 1 query
    
    // Find Looking Forward list
    let lookingForwardList = allLists.first { ... }
    let lookingForwardItems = await getListItems(lookingForwardList.id)  // 1 query
    
    // Find Themed Month lists
    let themedMonthLists = allLists.filter { ... }
    for list in themedMonthLists {
        let items = await getListItems(list.id)  // N queries
    }
    
    // Check watched status
    let allTmdbIds = [mustWatchesItems, lookingForwardItems, ...].flatMap { ... }
    let watched = await getWatchedTmdbIds(allTmdbIds)  // 1 query
}
```

#### After (Single Query)
```swift
// Pseudocode - iOS
func loadGoalsDataOptimized() async {
    let userId = getCurrentUserId()
    
    let results = await supabase.rpc(
        "get_goals_data",
        params: [
            "user_id_param": userId,
            "target_year": currentYear,
            "current_month": currentMonth
        ]
    ).execute()  // 1 query - everything included!
    
    // Results contain:
    // - list_type: "must_watches" | "looking_forward" | "themed_month"
    // - list_id, list_name
    // - total_items, watched_count
    // - items: [{tmdb_id, title, poster_url, is_watched}, ...]
}
```

---

## Data Models

### ListWithSummaryDb (Response from `get_lists_with_summary`)

```swift
struct ListWithSummaryDb: Codable {
    let id: String
    let userId: String
    let name: String
    let description: String?
    let createdAt: String
    let updatedAt: String
    let pinned: Bool
    let ranked: Bool
    let tags: String?
    let themedMonthDate: String?
    let itemCount: Int
    let watchedCount: Int
    let firstItemPosterUrl: String?
    let firstItemBackdropPath: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case description
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case pinned
        case ranked
        case tags
        case themedMonthDate = "themed_month_date"
        case itemCount = "item_count"
        case watchedCount = "watched_count"
        case firstItemPosterUrl = "first_item_poster_url"
        case firstItemBackdropPath = "first_item_backdrop_path"
    }
}
```

### FirstWatchDate (Response from `get_first_watch_dates`)

```swift
struct FirstWatchDate: Codable {
    let tmdbId: Int
    let firstWatchDate: String?
    let firstWatchYear: Int?
    
    enum CodingKeys: String, CodingKey {
        case tmdbId = "tmdb_id"
        case firstWatchDate = "first_watch_date"
        case firstWatchYear = "first_watch_year"
    }
}
```

### GoalListData (Response from `get_goals_data`)

```swift
struct GoalListData: Codable {
    let listType: String
    let listId: String
    let listName: String
    let totalItems: Int
    let watchedCount: Int
    let items: String  // JSON string, decode separately
    
    enum CodingKeys: String, CodingKey {
        case listType = "list_type"
        case listId = "list_id"
        case listName = "list_name"
        case totalItems = "total_items"
        case watchedCount = "watched_count"
        case items
    }
}

struct GoalItem: Codable {
    let tmdbId: Int
    let title: String
    let posterUrl: String?
    let isWatched: Bool
    
    enum CodingKeys: String, CodingKey {
        case tmdbId = "tmdb_id"
        case title
        case posterUrl = "poster_url"
        case isWatched = "is_watched"
    }
}
```

### MustWatchesMapping (Response from `get_must_watches_mapping`)

```swift
struct MustWatchesMapping: Codable {
    let tmdbId: Int
    let years: [Int]
    
    enum CodingKeys: String, CodingKey {
        case tmdbId = "tmdb_id"
        case years
    }
}
```

---

## Migration Strategy

### Phase 1: Deploy Database Functions
1. Run `sql/optimization_functions.sql` in Supabase SQL Editor
2. Verify functions exist in Database → Functions
3. Test functions manually in SQL Editor

### Phase 2: Update Apps with Fallbacks
Both Android and iOS should implement:

```swift
// Pseudocode
func loadListsWithSummary() async -> [ListWithSummary] {
    do {
        // Try optimized function first
        return try await loadListsWithSummaryOptimized()
    } catch {
        // Fallback to original implementation if function doesn't exist
        print("Optimized query failed, falling back: \(error)")
        return try await loadListsWithSummaryLegacy()
    }
}
```

This ensures:
- Apps work before database functions are deployed
- Apps work if database functions fail
- Gradual rollout is possible

### Phase 3: Monitor & Remove Fallbacks
After confirming optimizations work:
1. Monitor query performance in Supabase Dashboard
2. Remove fallback code after stable period
3. Consider additional optimizations (caching, etc.)

---

## Summary of Changes

| Component | Change | Impact |
|-----------|--------|--------|
| `get_lists_with_summary` | New DB function | Lists: N+2 → 1 query |
| `get_first_watch_dates` | New DB function | Movies: N → 1 query for rewatches |
| `get_goals_data` | New DB function | Home: ~8 → 1 query |
| `get_must_watches_mapping` | New DB function | Movies: N → 1 query for highlighting |
| `get_list_items_with_watched` | New DB function | List detail: 2 → 1 query |
| Database indexes | 5 new indexes | Faster query execution |

**Expected Result**: ~50% reduction in loading times for Home, Movies, and Lists screens.
