#ifndef SL_ZIP_ENTRY_H
#define SL_ZIP_ENTRY_H
#include <stddef.h>
// Build 71: read one file out of an IPA/ZIP (stored or deflate). Used only to
// import the website certificate from the user's own earlier ScreenLink IPA.
// match(name) selects the entry. On success returns 1 and a malloc'd buffer.
typedef int (*sl_zip_match)(const char *name);
int sl_zip_extract(const char *path, sl_zip_match match, unsigned char **data, size_t *size, char *error, size_t errorSize);
#endif
