#include <assert.h>
#include <pthread.h>
#include <stdio.h>
#include <time.h>

#include "job_queue.h"

struct job {
  int id;
};

void test_init(void) {
  // Arrange
  struct job_queue queue;
  // Act
  job_queue_init(&queue, 3);
  // Assert
  assert(queue.total_capacity == 3);
  assert(queue.current_capacity == 0);
  assert(queue.terminated == 0);
}

void test_add(void) {
  // Arrange
  struct job_queue queue;
  job_queue_init(&queue, 3);
  struct job j = {.id = 1};
  // Act
  job_queue_push(&queue, &j);
  // Assert
  assert(queue.total_capacity == 3);
  assert(queue.current_capacity == 1);
  assert(queue.terminated == 0);
}

void test_remove(void) {
  // Arrange
  struct job_queue queue;
  job_queue_init(&queue, 3);
  struct job j = {
      .id = 1,
  };
  void *jpointer;
  job_queue_push(&queue, &j);
  // Act
  job_queue_pop(&queue, &jpointer);
  // Assert
  assert(queue.total_capacity == 3);
  assert(queue.current_capacity == 0);
  assert(queue.terminated == 0);

  assert(jpointer == &j);
  assert(((struct job *)jpointer)->id == 1);
}

void test_destroy(void) {
  // Arrange
  struct job_queue queue;
  job_queue_init(&queue, 3);
  // Act
  job_queue_destroy(&queue);
  // Assert
  assert(queue.total_capacity == 3);
  assert(queue.current_capacity == 0);
  assert(queue.terminated == 1);
}

void test_addn(int size) {
  // Arrange
  struct job_queue queue;
  job_queue_init(&queue, size);
  struct job jarr[size];
  // Act
  for (int i = 0; i < size; i++) {
    jarr[i] = (struct job){.id = i};
    job_queue_push(&queue, &jarr[i]);
  }
  // Assert
  assert(queue.total_capacity == size);
  assert(queue.current_capacity == size);
  assert(queue.terminated == 0);
}

void test_addremoven(int size) {
  // Arrange
  struct job_queue queue;
  job_queue_init(&queue, size);
  struct job jarr[size];
  for (int i = 0; i < size; i++) {
    jarr[i] = (struct job){.id = i};
    job_queue_push(&queue, &jarr[i]);
  }
  void *jpointer;
  // Act
  for (int i = 0; i < size; i++) {
    job_queue_pop(&queue, &jpointer);
    assert(jpointer == &jarr[i]);
    assert(((struct job *)jpointer)->id == i);
  }
  // Assert
  assert(queue.total_capacity == size);
  assert(queue.current_capacity == 0);
  assert(queue.terminated == 0);
}
struct child_arg {
  struct job job;
  struct job_queue *jq;
};
void *producer(void *arg) {
  struct child_arg *pa = (struct child_arg *)arg;
  job_queue_push(pa->jq, &pa->job);
  return NULL;
}
void *worker(void *arg) {
  struct child_arg *wa = (struct child_arg *)arg;
  void *jpointer;
  // Act
  job_queue_pop(wa->jq, &jpointer);
  struct job result = *(struct job *)jpointer;
  wa->job.id = result.id;
  return NULL;
}

void test_add_n_remove_m(int n, int m, int size) {
  // Arange
  struct job_queue jq;
  job_queue_init(&jq, size);
  pthread_t tid[n + m];
  // Create input jobs
  struct child_arg paarr[n];
  for (int i = 0; i < n; i++) {
    paarr[i].job = (struct job){.id = i};
    paarr[i].jq = &jq;
    pthread_create(&tid[i], NULL, producer, &paarr[i]);
  }
  // Create output jobs
  struct child_arg waarr[m];
  for (int i = 0; i < m; i++) {
    waarr[i].job = (struct job){.id = i};
    waarr[i].jq = &jq;
    pthread_create(&tid[n + i], NULL, worker, &waarr[i]);
  }
  // Act
  for (int i = 0; i < m + n; i++) {
    pthread_join(tid[i], NULL);
  }
  // Assert
  assert(jq.total_capacity == size);
  assert(jq.current_capacity == (n - m));
  assert(jq.terminated == 0);
}

void test_add_n_remove_m_destroy(int n, int m, int size) {
  // Arange
  struct job_queue jq;
  job_queue_init(&jq, size);
  pthread_t tid[n + m];
  // Create input jobs
  struct child_arg paarr[n];
  for (int i = 0; i < n; i++) {
    paarr[i].job = (struct job){.id = i};
    paarr[i].jq = &jq;
    pthread_create(&tid[i], NULL, producer, &paarr[i]);
  }
  // Create output jobs
  struct child_arg waarr[m];
  for (int i = 0; i < m; i++) {
    waarr[i].job = (struct job){.id = i};
    waarr[i].jq = &jq;
    pthread_create(&tid[n + i], NULL, worker, &waarr[i]);
  }
  // Act
  job_queue_destroy(&jq);
  for (int i = 0; i < m + n; i++) {
    pthread_join(tid[i], NULL);
  }
  // Assert
  assert(jq.total_capacity == size);
  assert(jq.current_capacity == 0);
  assert(jq.terminated == 1);
}

int main(void) {
  test_init();
  test_add();
  test_remove();
  test_destroy();
  printf("[PASS] Basic SingleThreaded tests\n");
  test_addn(10);
  test_addn(100);
  test_addremoven(10);
  test_addremoven(100);
  printf("[PASS] Commplex SingleThreaded tests\n");
  test_add_n_remove_m(2, 1, 3);
  test_add_n_remove_m(5, 3, 3);
  test_add_n_remove_m(100, 10, 95);
  printf("[PASS] MultiThreaded push pop tests\n");
  test_add_n_remove_m_destroy(1, 1, 3);
  test_add_n_remove_m_destroy(1, 2, 3);
  test_add_n_remove_m_destroy(1, 100, 3);
  test_add_n_remove_m_destroy(100, 100, 3);
  printf("[PASS] MultiThreaded destroy tests\n");

  printf("All tests passed!\n");
  return 0;
}
