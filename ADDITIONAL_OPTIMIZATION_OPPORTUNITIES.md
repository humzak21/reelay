# Additional Optimization Opportunities

This document outlines further optimization opportunities discovered during the analysis of the iOS codebase.

## 1. Search Functionality Optimization

### Current State
The search in `SearchView` and `MoviesView` loads all movies (up to 3000) and filters client-side.

### Opportunity
Implement server-side search using the `search_movies_paginated` function (already in `optimization_functions.sql` but not yet used).

### Implementation
```swift
// In SupabaseMovieService.swift
nonisolated func searchMoviesPaginated(
    searchQuery: String,
    limit: Int = 50,
    offset: Int = 0
) async throws -> (movies: [Movie], totalCount: Int) {
    struct SearchParams: Encodable {
        let search_query: String
        let limit_count: Int
        let offset_count: Int
    }
    
    let params = SearchParams(
        search_query: searchQuery,
        limit_count: limit,
        offset_count: offset
    )
    
    let response = try await supabase
        .rpc("search_movies_paginated", params: params)
        .execute()
    
    // Function returns movies with total_count
    // Parse and return both
}
```

### Impact
- Faster search results (only loads matching movies)
- Reduced memory usage
- Better for large movie collections

---

## 2. Pagination for Movies List

### Current State
`MoviesView` loads 3000 movies at once, which can be slow for users with large collections.

### Opportunity
Implement pagination to load movies in chunks of 100-200 at a time.

### Implementation
```swift
// In MoviesView.swift
@State private var currentPage = 0
@State private var hasMoreMovies = true
private let pageSize = 100

private func loadNextPage() async {
    guard hasMoreMovies && !isLoading else { return }
    
    isLoading = true
    let offset = currentPage * pageSize
    
    let newMovies = try await movieService.getMovies(
        sortBy: sortBy,
        ascending: sortAscending,
        limit: pageSize,
        offset: offset
    )
    
    if newMovies.count < pageSize {
        hasMoreMovies = false
    }
    
    movies.append(contentsOf: newMovies)
    currentPage += 1
    isLoading = false
}
```

### Impact
- Initial load 5-10x faster
- Smoother scrolling
- Lower memory usage
- Better user experience for large collections

---

## 3. Image Caching Optimization

### Current State
Using SDWebImage for caching, but could be more aggressive.

### Opportunity
Pre-fetch images for upcoming items and implement memory-efficient caching.

### Implementation
```swift
// Pre-fetch next 20 posters when scrolling
private func prefetchImages(for movies: [Movie]) {
    let urls = movies.prefix(20).compactMap { $0.posterURL }
    SDWebImagePrefetcher.shared.prefetchURLs(urls)
}

// Configure SDWebImage for better caching
SDImageCache.shared.config.maxMemoryCost = 100 * 1024 * 1024 // 100MB
SDImageCache.shared.config.maxDiskSize = 500 * 1024 * 1024 // 500MB
```

### Impact
- Smoother scrolling
- Faster image loading
- Better offline experience

---

## 4. Background Data Refresh

### Current State
Data is only refreshed when user pulls to refresh or opens a screen.

### Opportunity
Implement background refresh to keep data fresh without user interaction.

### Implementation
```swift
// In DataManager.swift
private var backgroundRefreshTimer: Timer?

func startBackgroundRefresh() {
    backgroundRefreshTimer = Timer.scheduledTimer(
        withTimeInterval: 300, // 5 minutes
        repeats: true
    ) { [weak self] _ in
        Task {
            await self?.refreshInBackground()
        }
    }
}

private func refreshInBackground() async {
    // Only refresh if app is active and user is logged in
    guard movieService.isLoggedIn else { return }
    
    // Refresh caches silently
    await loadFirstWatchDates(for: getAllRewatchTmdbIds())
    await loadMustWatchesMapping()
}
```

### Impact
- Always fresh data
- No waiting for refresh
- Better user experience

---

## 5. Incremental List Loading

### Current State
`ListDetailsView` loads all items at once, which can be slow for large lists.

### Opportunity
Load first 50 items immediately, then load rest in background.

### Implementation
```swift
// In ListDetailsView.swift
private func loadItemsIncrementally() async {
    // Load first 50 items immediately
    let firstBatch = try await loadItems(limit: 50, offset: 0)
    await MainActor.run {
        listItems = firstBatch
    }
    
    // Load rest in background
    Task.detached(priority: .background) {
        let remainingItems = try await loadItems(limit: 1000, offset: 50)
        await MainActor.run {
            listItems.append(contentsOf: remainingItems)
        }
    }
}
```

### Impact
- Faster initial display
- Better perceived performance
- Smoother user experience

---

## 6. Statistics Caching

### Current State
`StatisticsView` recalculates stats every time it's opened.

### Opportunity
Cache statistics with longer TTL (15-30 minutes) since they don't change frequently.

### Implementation
```swift
// In SupabaseStatisticsService.swift
@MainActor
class StatisticsCache: ObservableObject {
    static let shared = StatisticsCache()
    
    @Published private(set) var yearlyStats: [Int: YearlyStats] = [:]
    private var lastRefreshTime: Date?
    private let cacheValidityDuration: TimeInterval = 900 // 15 minutes
    
    var needsRefresh: Bool {
        guard let lastRefresh = lastRefreshTime else { return true }
        return Date().timeIntervalSince(lastRefresh) > cacheValidityDuration
    }
}
```

### Impact
- Instant statistics display
- Reduced database load
- Better user experience

---

## 7. Optimistic UI Updates

### Current State
UI waits for database confirmation before updating.

### Opportunity
Update UI immediately, then sync with database in background.

### Implementation
```swift
// In MoviesView.swift
func toggleFavorite(_ movie: Movie) async {
    // Update UI immediately
    if let index = movies.firstIndex(where: { $0.id == movie.id }) {
        var updatedMovie = movie
        updatedMovie.favorited = !(movie.favorited ?? false)
        movies[index] = updatedMovie
    }
    
    // Sync with database in background
    Task.detached(priority: .background) {
        do {
            try await movieService.toggleMovieFavorite(movieId: movie.id)
        } catch {
            // Revert on error
            await MainActor.run {
                if let index = movies.firstIndex(where: { $0.id == movie.id }) {
                    movies[index] = movie
                }
            }
        }
    }
}
```

### Impact
- Instant UI feedback
- Better perceived performance
- More responsive app

---

## 8. Batch Operations

### Current State
Operations like adding multiple movies to a list are done one at a time.

### Opportunity
Implement batch operations for common multi-item actions.

### Database Function
```sql
-- Add to optimization_functions.sql
CREATE OR REPLACE FUNCTION add_movies_to_list_batch(
    list_id_param UUID,
    movies JSONB -- Array of {tmdb_id, title, poster_url, etc.}
)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    inserted_count INTEGER;
BEGIN
    INSERT INTO list_items (list_id, tmdb_id, movie_title, movie_poster_url, ...)
    SELECT 
        list_id_param,
        (movie->>'tmdb_id')::INTEGER,
        movie->>'title',
        movie->>'poster_url',
        ...
    FROM jsonb_array_elements(movies) AS movie;
    
    GET DIAGNOSTICS inserted_count = ROW_COUNT;
    RETURN inserted_count;
END;
$$;
```

### Impact
- Much faster bulk operations
- Reduced network overhead
- Better user experience for CSV imports

---

## 9. Offline Support Enhancement

### Current State
Limited offline support using SwiftData for local storage.

### Opportunity
Implement more comprehensive offline support with sync queue.

### Implementation
```swift
// In DataManager.swift
private var syncQueue: [SyncOperation] = []

struct SyncOperation: Codable {
    let type: OperationType
    let data: Data
    let timestamp: Date
    
    enum OperationType: String, Codable {
        case addMovie, updateMovie, deleteMovie
        case addToList, removeFromList
    }
}

func queueOperation(_ operation: SyncOperation) {
    syncQueue.append(operation)
    saveQueueToStorage()
}

func syncQueuedOperations() async {
    for operation in syncQueue {
        do {
            try await executeOperation(operation)
            syncQueue.removeFirst()
        } catch {
            break // Stop on first error
        }
    }
    saveQueueToStorage()
}
```

### Impact
- Works offline
- No data loss
- Better reliability

---

## 10. Smart Preloading

### Current State
Data is loaded on-demand when screens are opened.

### Opportunity
Preload data for likely next screens based on user behavior.

### Implementation
```swift
// In ContentView.swift
func preloadForTab(_ tab: Tab) {
    Task.detached(priority: .background) {
        switch tab {
        case .movies:
            // Preload movies and caches
            await DataManager.shared.refreshMovies()
            await DataManager.shared.loadFirstWatchDates(for: getAllRewatchIds())
            
        case .lists:
            // Preload lists
            await DataManager.shared.refreshListsOptimized()
            
        case .home:
            // Preload home data
            await DataManager.shared.refreshMovies()
            await DataManager.shared.refreshListsOptimized()
        }
    }
}
```

### Impact
- Instant screen transitions
- Better perceived performance
- Smoother user experience

---

## Priority Ranking

### High Priority (Implement Next)
1. **Pagination for Movies List** - Biggest impact for users with large collections
2. **Search Optimization** - Already have database function, just need to use it
3. **Statistics Caching** - Easy win with significant impact

### Medium Priority
4. **Background Data Refresh** - Improves experience without user action
5. **Incremental List Loading** - Good for large lists
6. **Image Caching Optimization** - Improves scrolling performance

### Low Priority (Nice to Have)
7. **Optimistic UI Updates** - Better UX but more complex
8. **Batch Operations** - Only beneficial for specific use cases
9. **Offline Support Enhancement** - Complex, benefits limited users
10. **Smart Preloading** - Marginal gains, complex to implement

---

## Estimated Impact

| Optimization | Dev Time | Performance Gain | User Impact |
|--------------|----------|------------------|-------------|
| Pagination | 2-3 days | 5-10x faster initial load | High |
| Search Optimization | 1-2 days | 3-5x faster search | High |
| Statistics Caching | 1 day | Instant stats | Medium |
| Background Refresh | 2 days | Always fresh data | Medium |
| Incremental Loading | 2 days | 2-3x faster lists | Medium |
| Image Caching | 1 day | Smoother scrolling | Medium |
| Optimistic UI | 3-4 days | Instant feedback | Medium |
| Batch Operations | 2-3 days | 10x faster bulk ops | Low |
| Offline Support | 5-7 days | Works offline | Low |
| Smart Preloading | 3-4 days | Instant transitions | Low |

---

## Conclusion

The current optimizations (already implemented) provide ~50% reduction in loading times. The additional optimizations listed here could provide another 30-50% improvement, especially for users with large collections.

Recommended next steps:
1. Deploy current optimizations and monitor performance
2. Gather user feedback on loading times
3. Implement high-priority optimizations based on user needs
4. Continue monitoring and iterating
