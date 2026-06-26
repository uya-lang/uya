// bench_malloc_phase4.c - C libc 对照版，多线程小对象 malloc/free 吞吐基准

#define _POSIX_C_SOURCE 200809L

#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

enum {
    BENCH_CASE_COUNT = 4,
    BENCH_MAX_THREADS = 8,
    BENCH_ROUNDS = 4000,
    BENCH_CLASS_COUNT = 7,
    BENCH_OBJECTS_PER_CLASS = 8,
    BENCH_OBJECTS_PER_ROUND = BENCH_CLASS_COUNT * BENCH_OBJECTS_PER_CLASS,
};

static const int BENCH_THREAD_COUNTS[BENCH_CASE_COUNT] = {1, 2, 4, 8};
static const size_t BENCH_SIZE_CLASSES[BENCH_CLASS_COUNT] = {
    32u, 64u, 128u, 256u, 512u, 1024u, 2048u,
};

static volatile int g_bench_start_flag = 0;

struct BenchWorkerState {
    size_t thread_index;
    int status;
    uint64_t alloc_count;
    uint64_t free_count;
    uint64_t checksum;
};

struct BenchRunResult {
    int thread_count;
    uint64_t total_ops;
    uint64_t elapsed_ns;
    uint64_t throughput_ops_per_sec;
    uint64_t checksum;
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

static uint64_t bench_total_ops(int thread_count) {
    return (uint64_t)thread_count * (uint64_t)BENCH_ROUNDS *
           (uint64_t)BENCH_OBJECTS_PER_ROUND * 2u;
}

static uint64_t bench_ops_per_sec(uint64_t total_ops, uint64_t elapsed_ns) {
    if (elapsed_ns == 0u) {
        return 0u;
    }
    return total_ops * 1000000000ull / elapsed_ns;
}

static void *bench_worker(void *arg) {
    struct BenchWorkerState *state = (struct BenchWorkerState *)arg;
    void *ptrs[BENCH_OBJECTS_PER_ROUND] = {0};
    size_t sizes[BENCH_OBJECTS_PER_ROUND] = {0};
    uint64_t alloc_count = 0u;
    uint64_t free_count = 0u;
    uint64_t checksum = 0u;

    while (g_bench_start_flag == 0) {
    }

    for (int round = 0; round < BENCH_ROUNDS; ++round) {
        size_t slot = 0u;
        for (size_t class_index = 0u; class_index < BENCH_CLASS_COUNT; ++class_index) {
            for (size_t repeat = 0u; repeat < BENCH_OBJECTS_PER_CLASS; ++repeat) {
                size_t size = BENCH_SIZE_CLASSES[class_index];
                void *ptr = malloc(size);
                if (ptr == NULL) {
                    state->status = 1;
                    state->alloc_count = alloc_count;
                    state->free_count = free_count;
                    state->checksum = checksum;
                    return NULL;
                }

                unsigned char *bytes = (unsigned char *)ptr;
                bytes[0] = (unsigned char)(round + (int)class_index + (int)repeat + (int)state->thread_index);
                ptrs[slot] = ptr;
                sizes[slot] = size;
                alloc_count += 1u;
                slot += 1u;
            }
        }

        for (slot = 0u; slot < BENCH_OBJECTS_PER_ROUND; ++slot) {
            unsigned char *bytes = (unsigned char *)ptrs[slot];
            checksum += (uint64_t)bytes[0] + (uint64_t)sizes[slot];
            free(ptrs[slot]);
            ptrs[slot] = NULL;
            sizes[slot] = 0u;
            free_count += 1u;
        }
    }

    state->status = 0;
    state->alloc_count = alloc_count;
    state->free_count = free_count;
    state->checksum = checksum;
    return NULL;
}

static int run_thread_case(int thread_count, struct BenchRunResult *result) {
    pthread_t threads[BENCH_MAX_THREADS];
    struct BenchWorkerState states[BENCH_MAX_THREADS];
    size_t created = 0u;
    uint64_t checksum = 0u;

    if (thread_count <= 0 || thread_count > BENCH_MAX_THREADS) {
        return 10;
    }

    g_bench_start_flag = 0;
    for (created = 0u; created < (size_t)thread_count; ++created) {
        states[created].thread_index = created;
        states[created].status = 99;
        states[created].alloc_count = 0u;
        states[created].free_count = 0u;
        states[created].checksum = 0u;
        if (pthread_create(&threads[created], NULL, bench_worker, &states[created]) != 0) {
            g_bench_start_flag = 1;
            for (size_t join_created = 0u; join_created < created; ++join_created) {
                (void)pthread_join(threads[join_created], NULL);
            }
            return 11;
        }
    }

    uint64_t start_ns = bench_now_ns();
    g_bench_start_flag = 1;

    for (size_t joined = 0u; joined < created; ++joined) {
        if (pthread_join(threads[joined], NULL) != 0) {
            return 12;
        }
        if (states[joined].status != 0) {
            return 100 + states[joined].status;
        }
        checksum += states[joined].checksum +
                    states[joined].alloc_count +
                    states[joined].free_count;
    }

    result->thread_count = thread_count;
    result->total_ops = bench_total_ops(thread_count);
    result->elapsed_ns = bench_elapsed_ns(start_ns, bench_now_ns());
    result->throughput_ops_per_sec = bench_ops_per_sec(result->total_ops, result->elapsed_ns);
    result->checksum = checksum;
    return 0;
}

static void print_result(const struct BenchRunResult *result) {
    printf(
        "malloc_phase4 threads=%d total_ops=%lu elapsed_ns=%lu throughput_ops_per_sec=%lu "
        "lock_acquires=%d lock_contentions=%d tcache_hits=%d tcache_misses=%d "
        "tcache_hit_rate_bp=%d checksum=%lu\n",
        result->thread_count,
        (unsigned long)result->total_ops,
        (unsigned long)result->elapsed_ns,
        (unsigned long)result->throughput_ops_per_sec,
        0,
        0,
        0,
        0,
        0,
        (unsigned long)result->checksum
    );
}

int main(void) {
    for (size_t i = 0u; i < BENCH_CASE_COUNT; ++i) {
        struct BenchRunResult result;
        int rc = run_thread_case(BENCH_THREAD_COUNTS[i], &result);
        if (rc != 0) {
            printf("bench_malloc_phase4_c: rc=%d threads=%d\n", rc, BENCH_THREAD_COUNTS[i]);
            return 1;
        }
        print_result(&result);
    }
    return 0;
}
