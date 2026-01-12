-- =====================================================
-- REELAY PERFORMANCE OPTIMIZATION SQL FUNCTIONS
-- =====================================================
-- These functions move heavy computation to the database
-- to reduce round-trips and improve loading times.
-- =====================================================

-- =====================================================
-- 1. GET LISTS WITH SUMMARY (Single Query)
-- Replaces N+1 queries with a single aggregated query
-- =====================================================
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

-- =====================================================
-- 2. GET FIRST WATCH DATES (Batch Query)
-- Returns first watch dates for multiple TMDB IDs at once
-- Eliminates N+1 queries for rewatch color computation
-- =====================================================
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

-- =====================================================
-- 3. GET HOME SCREEN DATA (Combined Query)
-- Returns all data needed for home screen in one call
-- =====================================================
CREATE OR REPLACE FUNCTION get_home_screen_data(
    target_year INTEGER,
    current_month INTEGER
)
RETURNS TABLE (
    -- Recent movies (JSON array)
    recent_movies JSONB,
    -- Yearly stats
    yearly_movies_count BIGINT,
    yearly_average_rating NUMERIC,
    films_released_this_year BIGINT,
    top_genre TEXT,
    top_director TEXT,
    favorite_day TEXT
) LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    WITH recent AS (
        SELECT jsonb_agg(
            jsonb_build_object(
                'id', d.id,
                'title', d.title,
                'poster_url', d.poster_url,
                'rating', d.rating,
                'watched_date', d.watched_date,
                'tmdb_id', d.tmdb_id
            ) ORDER BY d.watched_date DESC, d.created_at DESC
        ) AS movies
        FROM (
            SELECT * FROM diary 
            ORDER BY watched_date DESC, created_at DESC 
            LIMIT 10
        ) d
    ),
    yearly_stats AS (
        SELECT * FROM get_dashboard_stats_by_year(target_year)
    ),
    released_count AS (
        SELECT COUNT(*)::BIGINT AS cnt
        FROM diary
        WHERE release_year = target_year
    )
    SELECT 
        COALESCE(r.movies, '[]'::jsonb),
        COALESCE(ys.total_films, 0),
        ys.average_rating,
        COALESCE(rc.cnt, 0),
        ys.top_genre,
        ys.top_director,
        ys.favorite_day
    FROM recent r
    CROSS JOIN yearly_stats ys
    CROSS JOIN released_count rc;
END;
$$;

-- =====================================================
-- 4. GET LIST ITEMS WITH WATCHED STATUS (Single Query)
-- Returns list items with watched status in one query
-- =====================================================
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

-- =====================================================
-- 5. GET GOALS DATA (Combined Query for Home Screen)
-- Returns Must Watches, Looking Forward, and Themed Month data
-- =====================================================
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

-- =====================================================
-- 6. GET MOVIES PAGE DATA (Optimized with Rewatch Colors)
-- Returns movies with pre-computed rewatch colors
-- =====================================================
CREATE OR REPLACE FUNCTION get_movies_with_rewatch_colors(
    limit_count INTEGER DEFAULT 100,
    offset_count INTEGER DEFAULT 0,
    sort_column TEXT DEFAULT 'created_at',
    sort_ascending BOOLEAN DEFAULT false
)
RETURNS TABLE (
    movie_data JSONB,
    rewatch_color TEXT
) LANGUAGE plpgsql AS $$
DECLARE
    sort_order TEXT;
BEGIN
    sort_order := CASE WHEN sort_ascending THEN 'ASC' ELSE 'DESC' END;
    
    RETURN QUERY
    WITH first_watches AS (
        SELECT DISTINCT ON (tmdb_id)
            tmdb_id,
            watched_date AS first_watch_date,
            EXTRACT(YEAR FROM watched_date)::INTEGER AS first_watch_year
        FROM diary
        WHERE rewatch IS NULL OR rewatch != 'yes'
        ORDER BY tmdb_id, watched_date ASC
    ),
    movies_page AS (
        SELECT d.*
        FROM diary d
        ORDER BY 
            CASE WHEN sort_column = 'created_at' AND NOT sort_ascending THEN d.created_at END DESC,
            CASE WHEN sort_column = 'created_at' AND sort_ascending THEN d.created_at END ASC,
            CASE WHEN sort_column = 'watched_date' AND NOT sort_ascending THEN d.watched_date END DESC,
            CASE WHEN sort_column = 'watched_date' AND sort_ascending THEN d.watched_date END ASC,
            CASE WHEN sort_column = 'title' AND NOT sort_ascending THEN d.title END DESC,
            CASE WHEN sort_column = 'title' AND sort_ascending THEN d.title END ASC,
            CASE WHEN sort_column = 'rating' AND NOT sort_ascending THEN d.rating END DESC,
            CASE WHEN sort_column = 'rating' AND sort_ascending THEN d.rating END ASC,
            CASE WHEN sort_column = 'release_year' AND NOT sort_ascending THEN d.release_year END DESC,
            CASE WHEN sort_column = 'release_year' AND sort_ascending THEN d.release_year END ASC
        LIMIT limit_count
        OFFSET offset_count
    )
    SELECT 
        to_jsonb(m.*) AS movie_data,
        CASE 
            WHEN m.rewatch = 'yes' THEN
                CASE 
                    WHEN fw.first_watch_date IS NULL THEN 'grey'
                    WHEN EXTRACT(YEAR FROM m.watched_date) = fw.first_watch_year THEN 'yellow'
                    ELSE 'orange'
                END
            ELSE NULL
        END AS rewatch_color
    FROM movies_page m
    LEFT JOIN first_watches fw ON m.tmdb_id = fw.tmdb_id;
END;
$$;

-- =====================================================
-- 7. SEARCH MOVIES WITH PAGINATION
-- Server-side search with pagination support
-- =====================================================
CREATE OR REPLACE FUNCTION search_movies_paginated(
    search_query TEXT,
    limit_count INTEGER DEFAULT 50,
    offset_count INTEGER DEFAULT 0
)
RETURNS TABLE (
    id INTEGER,
    title TEXT,
    director TEXT,
    poster_url TEXT,
    rating NUMERIC,
    ratings100 NUMERIC,
    watched_date DATE,
    tmdb_id INTEGER,
    release_year NUMERIC,
    genres TEXT[],
    rewatch TEXT,
    favorited BOOLEAN,
    total_count BIGINT
) LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    WITH search_results AS (
        SELECT d.*
        FROM diary d
        WHERE d.title ILIKE '%' || search_query || '%'
           OR d.director ILIKE '%' || search_query || '%'
    ),
    counted AS (
        SELECT COUNT(*) AS total FROM search_results
    )
    SELECT 
        sr.id,
        sr.title,
        sr.director,
        sr.poster_url,
        sr.rating,
        sr.ratings100,
        sr.watched_date,
        sr.tmdb_id,
        sr.release_year,
        sr.genres,
        sr.rewatch,
        sr.favorited,
        c.total
    FROM search_results sr
    CROSS JOIN counted c
    ORDER BY sr.watched_date DESC
    LIMIT limit_count
    OFFSET offset_count;
END;
$$;

-- =====================================================
-- 8. GET MUST WATCHES MAPPING (For Movies Screen)
-- Returns tmdb_id -> years mapping for purple highlighting
-- =====================================================
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

-- =====================================================
-- INDEXES FOR OPTIMIZATION
-- =====================================================

-- Index for faster list item lookups by list_id
CREATE INDEX IF NOT EXISTS idx_list_items_list_id_sort 
ON list_items(list_id, sort_order);

-- Index for faster diary lookups by tmdb_id and rewatch status
CREATE INDEX IF NOT EXISTS idx_diary_tmdb_rewatch 
ON diary(tmdb_id, rewatch) 
WHERE rewatch IS NULL OR rewatch != 'yes';

-- Index for faster diary lookups by watched_date for recent movies
CREATE INDEX IF NOT EXISTS idx_diary_watched_date_desc 
ON diary(watched_date DESC NULLS LAST, created_at DESC);

-- Composite index for list name pattern matching
CREATE INDEX IF NOT EXISTS idx_lists_user_name_pattern 
ON lists(user_id, lower(name));

-- Index for themed month date lookups
CREATE INDEX IF NOT EXISTS idx_lists_themed_month 
ON lists(user_id, themed_month_date) 
WHERE themed_month_date IS NOT NULL;
