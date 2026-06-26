// bench_malloc_throughput.c - single-thread fixed-size malloc/free throughput benchmark
// Output:
//   1. Total elapsed time for 10000 pairs of 64B malloc+free (ns)
//   2. Average time per malloc+free pair (ns)
//   3. Total throughput (ops/sec, alloc and free each count as 1 op)

#define _POSIX_C_SOURCE 200809L

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

enum {
    BENCH_ITERATIONS = 10000,
    BENCH_WARMUP_ITERATIONS = 512,
    BENCH_ALLOC_SIZE = 64,
    BENCH_LAST_OFFSET = BENCH_ALLOC_SIZE - 1,
};

static uint64_t bench_now_ns(void) {
    struct timespec ts;
    if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0) {
        return 0u;
    }
    if (ts.tv_sec < 0 || ts.tv_nsec < 0) {
        return 0u;
    }
    return (uint64_t)ts.tv_sec * 1000000000ull + (uint64_t)ts.tv_nsec;
}

static uint64_t bench_elapsed_ns(uint64_t start_ns, uint64_t end_ns) {
    if (end_ns <= start_ns) {
        return 0u;
    }
    return end_ns - start_ns;
}

static uint64_t bench_ops_per_sec(uint64_t total_ops, uint64_t elapsed_ns) {
    if (elapsed_ns == 0u) {
        return 0u;
    }
    return total_ops * 1000000000ull / elapsed_ns;
}

static int run_malloc_free_pairs(int iterations, uint64_t *checksum) {
    for (int i = 0; i < iterations; ++i) {
        void *ptr = malloc(BENCH_ALLOC_SIZE);
        if (ptr == NULL) {
            return 1;
        }

        unsigned char *bytes = (unsigned char *)ptr;
        bytes[0] = (unsigned char)(i % 251);
        bytes[BENCH_LAST_OFFSET] = (unsigned char)((i + 17) % 251);
        *checksum += (uint64_t)bytes[0] + (uint64_t)bytes[BENCH_LAST_OFFSET];
        free(ptr);
    }
    return 0;
}

int main(void) {
    uint64_t checksum = 0u;
    int warmup_rc = run_malloc_free_pairs(BENCH_WARMUP_ITERATIONS, &checksum);
    if (warmup_rc != 0) {
        printf("bench_malloc_throughput: warmup_rc=%d\n", warmup_rc);
        return 1;
    }

    uint64_t start_ns = bench_now_ns();
    int rc = run_malloc_free_pairs(BENCH_ITERATIONS, &checksum);
    uint64_t end_ns = bench_now_ns();
    if (rc != 0) {
        printf("bench_malloc_throughput: rc=%d\n", rc);
        return 2;
    }

    uint64_t elapsed_ns = bench_elapsed_ns(start_ns, end_ns);
    uint64_t total_ops = (uint64_t)BENCH_ITERATIONS * 2u;
    printf(
        "malloc_throughput_single_thread size=%zu iterations=%d total_ops=%lu elapsed_ns=%lu avg_pair_ns=%lu throughput_ops_per_sec=%lu checksum=%lu\n",
        (size_t)BENCH_ALLOC_SIZE,
        BENCH_ITERATIONS,
        (unsigned long)total_ops,
        (unsigned long)elapsed_ns,
        (unsigned long)(elapsed_ns / (uint64_t)BENCH_ITERATIONS),
        (unsigned long)bench_ops_per_sec(total_ops, elapsed_ns),
        (unsigned long)checksum
    );
    return 0;
}
