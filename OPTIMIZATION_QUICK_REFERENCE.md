# iOS Optimization Quick Reference

## Files Modified

### New Files
- ✅ `reelay2/OptimizedDataModels.swift` - Response models and caches

### Modified Files
- ✅ `reelay2/SupabaseListService.swift` - Added optimized list queries
- ✅ `reelay2/SupabaseMovieService.swift` - Added batch queries for rewatches
- ✅ `reelay2/DataManager.swift` - Added optimized refresh methods
- ✅ `reelay2/MoviesView.swift` - Uses cached rewatch colors and must watches
- ✅ `reelay2/ListsView.swift` - Uses optimized list sync
- ✅ `reelay2/HomeView.swift` - Uses optimized list sync
- ✅ `reelay2/ListDetailsView.swift` - Uses optimized items with watched status

## Key Optimizations

### 1. Lists Screen
**Method**: `SupabaseListService.syncListsFromSupabaseOptimized()`
- Calls `get_lists_with_summary` database function
- Returns all lists with pre-computed item counts and watched counts
- **Fallback**: Automatically falls back to legacy `syncListsFromSupabase()` if function fails

### 2. Movies Screen - Rewatch Colors
**Method**: `SupabaseMovieService.getFirstWatchDatesBatch(tmdbIds:)`
- Calls `get_first_watch_dates` database function
- Returns first watch dates for all rewatch movies in one query
- Results cached in `FirstWatchDateCache` (5-minute TTL)
- **Fallback**: Uses legacy computation if cache miss

### 3. Movies Screen - Must Watches Highlighting
**Method**: `SupabaseMovieService.getMustWatchesMapping(userId:)`
- Calls `get_must_watches_mapping` database function
- Returns mapping of TMDB IDs to years they appear in Must Watches lists
- Results cached in `MustWatchesCache` (5-minute TTL)
- **Fallback**: Uses legacy list lookup if cache is stale

### 4. List Details Screen
**Method**: `SupabaseListService.getItemsForListOptimized(listId:)`
- Calls `get_list_items_with_watched` database function
- Returns list items with watched status in one query
- **Fallback**: Falls back to legacy two-query approach if function fails

### 5. Home Screen (Ready for Future)
**Method**: `SupabaseMovieService.getGoalsData(userId:targetYear:currentMonth:)`
- Calls `get_goals_data` database function
- Returns all goals data (Must Watches, Looking Forward, Themed Month) in one query
- Currently integrated but can be further optimized in goals section

## Cache Management

### FirstWatchDateCache
```swift
// Automatically updated when movies are loaded
FirstWatchDateCache.shared.update(with: firstWatchDates)

// Check if needs refresh (5-minute TTL)
if FirstWatchDateCache.shared.needsRefresh { ... }

// Get cached data
if let firstWatch = FirstWatchDateCache.shared.getFirstWatch(for: tmdbId) { ... }

// Clear cache (if needed)
FirstWatchDateCache.shared.clear()
```

### MustWatchesCache
```swift
// Automatically updated when movies are loaded
MustWatchesCache.shared.update(with: mappings)

// Check if needs refresh (5-minute TTL)
if MustWatchesCache.shared.needsRefresh { ... }

// Check if movie is on must watches
if MustWatchesCache.shared.isOnMustWatches(tmdbId: tmdbId, year: year) { ... }

// Clear cache (if needed)
MustWatchesCache.shared.clear()
```

## Database Functions Required

All functions are already deployed from `optimization_functions.sql`:

1. ✅ `get_lists_with_summary(user_id_param UUID)`
2. ✅ `get_first_watch_dates(tmdb_ids INTEGER[])`
3. ✅ `get_goals_data(user_id_param UUID, target_year INTEGER, current_month INTEGER)`
4. ✅ `get_must_watches_mapping(user_id_param UUID)`
5. ✅ `get_list_items_with_watched(list_id_param UUID)`

## Testing Checklist

### Lists Screen
- [ ] Lists load quickly
- [ ] Item counts are correct
- [ ] Watched counts are correct
- [ ] First item artwork displays correctly
- [ ] Pinned lists appear first

### Movies Screen
- [ ] Rewatch colors display correctly:
  - Grey: First entry but marked as rewatch
  - Yellow: First watch and rewatch in same year
  - Orange: Rewatched in different year
- [ ] Purple title highlighting for Must Watches works
- [ ] Movies load within 2-3 seconds (vs 5-6 seconds before)

### List Details Screen
- [ ] List items load quickly
- [ ] Watched status indicators (checkmarks) display correctly
- [ ] Progress bar shows correct percentage
- [ ] Watched count is accurate

### Home Screen
- [ ] Goals section loads quickly
- [ ] Must Watches progress is correct
- [ ] Looking Forward progress is correct
- [ ] Themed Month lists appear correctly

### Fallback Testing
- [ ] App works if database functions are disabled
- [ ] No crashes when functions fail
- [ ] Legacy methods work as expected

## Performance Metrics

### Expected Improvements
- **Lists Screen**: 50-70% faster loading
- **Movies Screen**: 40-60% faster loading (especially with many rewatches)
- **List Details**: 30-50% faster loading
- **Home Screen**: 40-60% faster loading

### Monitoring
- Check Supabase dashboard for query counts
- Monitor query execution times
- Watch for any fallback usage (indicates issues)
- Track cache hit rates in logs

## Troubleshooting

### Issue: Rewatch colors not showing correctly
- Check if `FirstWatchDateCache` is being updated
- Verify `get_first_watch_dates` function exists in database
- Check logs for fallback usage

### Issue: Must Watches highlighting not working
- Check if `MustWatchesCache` is being updated
- Verify `get_must_watches_mapping` function exists in database
- Check logs for fallback usage

### Issue: Lists not loading
- Check if `get_lists_with_summary` function exists in database
- Verify fallback to legacy method is working
- Check Supabase logs for errors

### Issue: Slow loading despite optimizations
- Check if database functions are being called (not falling back)
- Verify indexes are created (from `optimization_functions.sql`)
- Check network latency
- Monitor Supabase dashboard for slow queries

## Rollback Plan

If issues occur:
1. All optimized methods have automatic fallback to legacy implementations
2. No database changes needed to rollback
3. Caches can be cleared by restarting the app
4. Database functions can be disabled without breaking the app

## Next Steps

1. Deploy and test in staging environment
2. Monitor performance metrics
3. Gather user feedback on loading times
4. Consider additional optimizations:
   - Pagination for movies list
   - More aggressive image caching
   - Background refresh for caches
   - Incremental loading for large lists
