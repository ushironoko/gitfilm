#ifdef __cplusplus
extern "C" {
#endif

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>
#include <spawn.h>

#include "moonbit.h"

extern char **environ;

static int last_exit_code = 0;

MOONBIT_FFI_EXPORT moonbit_bytes_t gitfilm_exec(
  moonbit_bytes_t program,
  moonbit_bytes_t cwd,
  moonbit_bytes_t args_joined,
  moonbit_bytes_t separator
) {
  const char *prog = (const char *)program;
  const char *working_dir = (const char *)cwd;
  const char *joined = (const char *)args_joined;
  const char *sep = (const char *)separator;
  size_t sep_len = strlen(sep);

  int argc = 1;
  const char *p = joined;
  while (*p) {
    if (strncmp(p, sep, sep_len) == 0) {
      argc++;
      p += sep_len;
    } else {
      p++;
    }
  }

  char **argv = (char **)malloc(sizeof(char *) * (argc + 2));
  argv[0] = (char *)prog;

  if (strlen(joined) == 0) {
    argc = 0;
  } else {
    char *joined_copy = strdup(joined);
    int idx = 0;
    char *token = joined_copy;
    char *found;
    while ((found = strstr(token, sep)) != NULL) {
      *found = '\0';
      argv[idx + 1] = token;
      idx++;
      token = found + sep_len;
    }
    argv[idx + 1] = token;
  }
  argv[argc + 1] = NULL;

  int pipefd[2];
  if (pipe(pipefd) != 0) {
    free(argv);
    const char *err = "pipe() failed";
    size_t len = strlen(err);
    moonbit_bytes_t result = moonbit_make_bytes(len, 0);
    memcpy(result, err, len);
    last_exit_code = -1;
    return result;
  }

  posix_spawn_file_actions_t actions;
  posix_spawn_file_actions_init(&actions);
  posix_spawn_file_actions_adddup2(&actions, pipefd[1], STDOUT_FILENO);
  posix_spawn_file_actions_adddup2(&actions, pipefd[1], STDERR_FILENO);
  posix_spawn_file_actions_addclose(&actions, pipefd[0]);
  posix_spawn_file_actions_addclose(&actions, pipefd[1]);

  /* posix_spawn has no built-in cwd support; addchdir is a non-portable extension */
#ifdef __APPLE__
  if (strlen(working_dir) > 0) {
    posix_spawn_file_actions_addchdir(&actions, working_dir);
  }
#else
  if (strlen(working_dir) > 0) {
    posix_spawn_file_actions_addchdir(&actions, working_dir);
  }
#endif

  pid_t pid;
  int status = posix_spawnp(&pid, prog, &actions, NULL, argv, environ);

  posix_spawn_file_actions_destroy(&actions);
  close(pipefd[1]);

  if (status != 0) {
    close(pipefd[0]);
    free(argv);
    const char *err = "posix_spawn failed";
    size_t len = strlen(err);
    moonbit_bytes_t result = moonbit_make_bytes(len, 0);
    memcpy(result, err, len);
    last_exit_code = -1;
    return result;
  }

  size_t buf_size = 4096;
  size_t total = 0;
  char *buf = (char *)malloc(buf_size);
  ssize_t n;
  while ((n = read(pipefd[0], buf + total, buf_size - total)) > 0) {
    total += n;
    if (total >= buf_size) {
      buf_size *= 2;
      buf = (char *)realloc(buf, buf_size);
    }
  }
  close(pipefd[0]);

  int wstatus;
  waitpid(pid, &wstatus, 0);
  if (WIFEXITED(wstatus)) {
    last_exit_code = WEXITSTATUS(wstatus);
  } else {
    last_exit_code = -1;
  }

  moonbit_bytes_t result = moonbit_make_bytes(total, 0);
  memcpy(result, buf, total);
  free(buf);
  free(argv);

  return result;
}

MOONBIT_FFI_EXPORT int gitfilm_last_exit_code(void) {
  return last_exit_code;
}

#ifdef __cplusplus
}
#endif
