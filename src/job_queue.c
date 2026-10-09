#include <assert.h>
#include <bits/pthreadtypes.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>

#include "job_queue.h"

int job_queue_init(struct job_queue *job_queue, int capacity) {
  char **queue = malloc(sizeof(char *) * capacity); // Array of pointers to jobs
  pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
  pthread_cond_t new_job = PTHREAD_COND_INITIALIZER;
  pthread_cond_t removed_job = PTHREAD_COND_INITIALIZER;
  *job_queue = (struct job_queue){.total_capacity = capacity,
                                  .current_capacity = 0,
                                  .queue = queue,
                                  .mutex = mutex,
                                  .new_job = new_job,
                                  .removed_job = removed_job,
                                  .terminated = 0};
  return 0;
}

// Assume that only one thread calls this function
int job_queue_destroy(struct job_queue *job_queue) {
  int done = 0;
  while (!done) {
    pthread_mutex_lock(&job_queue->mutex);
    job_queue->terminated = 1;
    if (job_queue->current_capacity > 0) {
      pthread_cond_wait(&job_queue->removed_job, &job_queue->mutex);
      // Make sure that no new job can be added
    } else {
      done = 1;
    }
    // Wake up pop threads, and making sure no new jobs can be added
    pthread_cond_broadcast(&job_queue->new_job);
    pthread_cond_broadcast(&job_queue->removed_job);
    pthread_mutex_unlock(&job_queue->mutex);
  }
  free(job_queue->queue);
  return 0;
}

int job_queue_push(struct job_queue *job_queue, void *data) {
  if (job_queue->terminated) { // Disallow pushes after termination
    return -1;
  }
  int done = 0;
  while (!done) {
    pthread_mutex_lock(&job_queue->mutex);
    if (job_queue->current_capacity >=
        job_queue->total_capacity) { // not enough space
      pthread_cond_wait(&job_queue->removed_job, &job_queue->mutex);
    } else {
      job_queue->queue[job_queue->current_capacity] = (char *)data;
      job_queue->current_capacity++;
      done = 1;
      pthread_cond_signal(&job_queue->new_job);
    }
    pthread_mutex_unlock(&job_queue->mutex);
  }
  return 0;
}

int job_queue_pop(struct job_queue *job_queue, void **data) {
  int done = 0;
  int terminated = 0;
  while (!done) {
    pthread_mutex_lock(&job_queue->mutex);
    if (job_queue->terminated && job_queue->current_capacity == 0) {
      done = 1;
      terminated = 1;
      // both wake up remaining pushers and destroyer
      pthread_cond_broadcast(&job_queue->removed_job);
    } else if (job_queue->current_capacity == 0) {
      pthread_cond_wait(&job_queue->new_job, &job_queue->mutex);
    } else {
      *data = job_queue->queue[0]; // data points to first job-pointer
      for (int i = 1; i < job_queue->current_capacity;
           i++) { // Every element gets moved up
        job_queue->queue[i - 1] = job_queue->queue[i];
      }
      done = 1;
      job_queue->current_capacity--;
      pthread_cond_signal(&job_queue->removed_job);
    }
    pthread_mutex_unlock(&job_queue->mutex);
  }
  if (terminated) {
    return -1;
  }
  return 0;
}
