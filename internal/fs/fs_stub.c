#include <moonbit.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

/* Read a whole file. Sets *ok to 1 on success. */
MOONBIT_FFI_EXPORT moonbit_bytes_t rich_fs_read_file(moonbit_bytes_t path, int32_t *ok) {
  *ok = 0;
  FILE *f = fopen((const char *)path, "rb");
  if (!f) return moonbit_make_bytes(0, 0);
  size_t cap = 4096, len = 0;
  char *buf = (char *)malloc(cap);
  if (!buf) {
    fclose(f);
    return moonbit_make_bytes(0, 0);
  }
  size_t n;
  while ((n = fread(buf + len, 1, cap - len, f)) > 0) {
    len += n;
    if (len == cap) {
      cap *= 2;
      char *nb = (char *)realloc(buf, cap);
      if (!nb) {
        free(buf);
        fclose(f);
        return moonbit_make_bytes(0, 0);
      }
      buf = nb;
    }
  }
  int err = ferror(f);
  fclose(f);
  if (err) {
    free(buf);
    return moonbit_make_bytes(0, 0);
  }
  moonbit_bytes_t out = moonbit_make_bytes((int32_t)len, 0);
  memcpy(out, buf, len);
  free(buf);
  *ok = 1;
  return out;
}

/* 1 if the path exists (file or directory). */
MOONBIT_FFI_EXPORT int32_t rich_fs_exists(moonbit_bytes_t path) {
  struct stat st;
  return stat((const char *)path, &st) == 0 ? 1 : 0;
}

/* Write a whole file. Returns 0 on success. */
MOONBIT_FFI_EXPORT int32_t rich_fs_write_file(moonbit_bytes_t path, moonbit_bytes_t data) {
  FILE *f = fopen((const char *)path, "wb");
  if (!f) return -1;
  size_t len = Moonbit_array_length(data);
  size_t n = fwrite(data, 1, len, f);
  int rc = fclose(f);
  return (n == len && rc == 0) ? 0 : -1;
}

/* Remove a file. Returns 0 on success. */
MOONBIT_FFI_EXPORT int32_t rich_fs_remove(moonbit_bytes_t path) {
  return remove((const char *)path) == 0 ? 0 : -1;
}
