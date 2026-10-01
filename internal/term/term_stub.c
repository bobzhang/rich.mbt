#include <moonbit.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#ifdef _WIN32
#include <io.h>
#include <windows.h>
#else
#include <sys/ioctl.h>
#include <termios.h>
#include <unistd.h>
#endif

MOONBIT_FFI_EXPORT int32_t rich_term_write(int32_t fd, moonbit_bytes_t data) {
  size_t len = Moonbit_array_length(data);
  size_t off = 0;
  while (off < len) {
#ifdef _WIN32
    int n = _write(fd, data + off, (unsigned int)(len - off));
#else
    ssize_t n = write(fd, data + off, len - off);
#endif
    if (n < 0) {
      if (errno == EINTR) continue;
      return -1;
    }
    off += (size_t)n;
  }
  return 0;
}

MOONBIT_FFI_EXPORT int32_t rich_term_isatty(int32_t fd) {
#ifdef _WIN32
  return _isatty(fd) ? 1 : 0;
#else
  return isatty(fd) ? 1 : 0;
#endif
}

/* Returns (columns << 16) | rows, or -1. */
MOONBIT_FFI_EXPORT int32_t rich_term_size(int32_t fd) {
#ifdef _WIN32
  CONSOLE_SCREEN_BUFFER_INFO info;
  HANDLE h = GetStdHandle(fd == 2 ? STD_ERROR_HANDLE : STD_OUTPUT_HANDLE);
  if (GetConsoleScreenBufferInfo(h, &info)) {
    int cols = info.srWindow.Right - info.srWindow.Left + 1;
    int rows = info.srWindow.Bottom - info.srWindow.Top + 1;
    return (cols << 16) | (rows & 0xffff);
  }
  return -1;
#else
  struct winsize ws;
  if (ioctl(fd, TIOCGWINSZ, &ws) == 0) {
    return ((int32_t)ws.ws_col << 16) | (int32_t)ws.ws_row;
  }
  return -1;
#endif
}

MOONBIT_FFI_EXPORT double rich_term_monotonic(void) {
#ifdef _WIN32
  LARGE_INTEGER freq, counter;
  QueryPerformanceFrequency(&freq);
  QueryPerformanceCounter(&counter);
  return (double)counter.QuadPart / (double)freq.QuadPart;
#else
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (double)ts.tv_sec + (double)ts.tv_nsec / 1e9;
#endif
}

MOONBIT_FFI_EXPORT double rich_term_time(void) {
#ifdef _WIN32
  return (double)time(NULL);
#else
  struct timespec ts;
  clock_gettime(CLOCK_REALTIME, &ts);
  return (double)ts.tv_sec + (double)ts.tv_nsec / 1e9;
#endif
}

MOONBIT_FFI_EXPORT void rich_term_sleep(double seconds) {
  if (seconds <= 0) return;
#ifdef _WIN32
  Sleep((DWORD)(seconds * 1000));
#else
  struct timespec ts;
  ts.tv_sec = (time_t)seconds;
  ts.tv_nsec = (long)((seconds - (double)ts.tv_sec) * 1e9);
  while (nanosleep(&ts, &ts) != 0 && errno == EINTR) {
  }
#endif
}

/* fmt must be NUL terminated. */
MOONBIT_FFI_EXPORT moonbit_bytes_t rich_term_strftime(moonbit_bytes_t fmt, double epoch) {
  time_t t = (time_t)epoch;
  struct tm tm;
#ifdef _WIN32
  localtime_s(&tm, &t);
#else
  localtime_r(&t, &tm);
#endif
  char buf[512];
  size_t n = strftime(buf, sizeof buf, (const char *)fmt, &tm);
  moonbit_bytes_t r = moonbit_make_bytes((int32_t)n, 0);
  memcpy(r, buf, n);
  return r;
}

/* Read a line from stdin (including the newline). Sets *eof on end of input. */
MOONBIT_FFI_EXPORT moonbit_bytes_t rich_term_read_line(int32_t echo, int32_t *eof) {
#ifndef _WIN32
  struct termios old_t, new_t;
  int restore = 0;
  if (!echo && isatty(0) && tcgetattr(0, &old_t) == 0) {
    new_t = old_t;
    new_t.c_lflag &= ~(tcflag_t)ECHO;
    tcsetattr(0, TCSAFLUSH, &new_t);
    restore = 1;
  }
#endif
  size_t cap = 256, len = 0;
  char *buf = (char *)malloc(cap);
  int c;
  *eof = 0;
  while ((c = fgetc(stdin)) != EOF) {
    if (len + 1 >= cap) {
      cap *= 2;
      buf = (char *)realloc(buf, cap);
    }
    buf[len++] = (char)c;
    if (c == '\n') break;
  }
  if (c == EOF && len == 0) *eof = 1;
#ifndef _WIN32
  if (restore) {
    tcsetattr(0, TCSAFLUSH, &old_t);
  }
#endif
  moonbit_bytes_t r = moonbit_make_bytes((int32_t)len, 0);
  memcpy(r, buf, len);
  free(buf);
  return r;
}

/* Write a file. Returns 0 on success. path must be NUL terminated. */
MOONBIT_FFI_EXPORT int32_t rich_term_write_file(moonbit_bytes_t path, moonbit_bytes_t data) {
  FILE *f = fopen((const char *)path, "wb");
  if (!f) return -1;
  size_t len = Moonbit_array_length(data);
  size_t n = fwrite(data, 1, len, f);
  int rc = fclose(f);
  return (n == len && rc == 0) ? 0 : -1;
}

/* Read a whole file. Sets *ok to 1 on success. */
MOONBIT_FFI_EXPORT moonbit_bytes_t rich_term_read_file(moonbit_bytes_t path, int32_t *ok) {
  *ok = 0;
  FILE *f = fopen((const char *)path, "rb");
  if (!f) return moonbit_make_bytes(0, 0);
  long n = -1;
  if (fseek(f, 0, SEEK_END) == 0) n = ftell(f);
  if (n < 0 || fseek(f, 0, SEEK_SET) != 0) {
    fclose(f);
    return moonbit_make_bytes(0, 0);
  }
  moonbit_bytes_t r = moonbit_make_bytes((int32_t)n, 0);
  size_t got = fread(r, 1, (size_t)n, f);
  fclose(f);
  if (got == (size_t)n) *ok = 1;
  return r;
}

/* Pipe text to a shell command (e.g. a pager). Returns the exit status or -1. */
MOONBIT_FFI_EXPORT int32_t rich_term_pipe_to(moonbit_bytes_t command, moonbit_bytes_t data) {
#ifdef _WIN32
  FILE *p = _popen((const char *)command, "w");
#else
  FILE *p = popen((const char *)command, "w");
#endif
  if (!p) return -1;
  fwrite(data, 1, Moonbit_array_length(data), p);
#ifdef _WIN32
  return _pclose(p);
#else
  return pclose(p);
#endif
}
