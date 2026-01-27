#! /bin/sh

# Source optional build metadata if present
if [ -f ./build ]; then
  . ./build
fi

bench=public/bench.txt
bench_incremental=public/bench-incremental.txt
marker_file=app/benchmark-marker.tsx

# Ensure public dir exists for bench file
mkdir -p "$(dirname "$bench")"

echo "starting build $build_id"
echo "build_id=$build_id" > $bench
echo "push_ts=$push_ts" >> $bench

# Reset marker file to baseline before cold build
cat > $marker_file << 'MARKER_EOF'
// This file is modified during incremental builds to trigger a rebuild
// The marker value changes with each build to ensure the file is different
export const BENCHMARK_MARKER = 'baseline'

export function BenchmarkMarker() {
  return null
}
MARKER_EOF

echo "start_ts=$(date +%s)" >> $bench

npm run build-only

echo "end_ts=$(date +%s)" >> $bench
echo "next_version=$(node -p "require('next/package.json').version")" >> $bench
echo "bundler=webpack" >> $bench

cat $bench

# --- Incremental build ---
echo ""
echo "=== Starting incremental build ==="

# Capture the moment incremental build phase begins (this becomes push_ts for incremental)
incremental_push_ts=$(date +%s.%N)

# Check if .next/cache exists (indicates caching is working)
if [ -d ".next/cache" ]; then
  cache_exists="true"
  cache_size=$(du -sh .next/cache 2>/dev/null | cut -f1)
  echo "Cache exists: $cache_exists (size: $cache_size)"
else
  cache_exists="false"
  cache_size="0"
  echo "Cache does not exist"
fi

# Modify the marker file to trigger incremental rebuild
unique_marker="incremental-$(date +%s)-$build_id"
cat > $marker_file << MARKER_EOF
// This file is modified during incremental builds to trigger a rebuild
// The marker value changes with each build to ensure the file is different
export const BENCHMARK_MARKER = '$unique_marker'

export function BenchmarkMarker() {
  return null
}
MARKER_EOF

echo "Modified marker file with: $unique_marker"

# Run incremental build
echo "build_id=$build_id" > $bench_incremental
echo "push_ts=$incremental_push_ts" >> $bench_incremental
echo "start_ts=$(date +%s)" >> $bench_incremental

npm run build-only

echo "end_ts=$(date +%s)" >> $bench_incremental
echo "next_version=$(node -p "require('next/package.json').version")" >> $bench_incremental
echo "bundler=webpack" >> $bench_incremental
echo "cache_exists=$cache_exists" >> $bench_incremental
echo "cache_size=$cache_size" >> $bench_incremental

echo ""
echo "=== Incremental build results ==="
cat $bench_incremental
