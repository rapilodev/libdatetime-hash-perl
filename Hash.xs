#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <unicode/ucal.h>
#include <unicode/udat.h>
#include <unicode/ustring.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>

/* Helper: Stores a slice of the input string directly into the hash (No sprintf overhead) */
static void store_part(pTHX_ HV* hash, const char* prefix, const char* key, const char* val, STRLEN len) {
    char full_key[128];
    int klen = sprintf(full_key, "%s%s", prefix, key);
    hv_store(hash, full_key, klen, newSVpvn(val, len), 0);
}

/* Helper: Stores an existing SV* into the hash */
static void store_sv(pTHX_ HV* hash, const char* prefix, const char* key, SV* value) {
    char full_key[128];
    int klen = sprintf(full_key, "%s%s", prefix, key);
    hv_store(hash, full_key, klen, value, 0);
}

/* ICU Formatting Helper */
static SV* get_formatted(pTHX_ UDate date, const char* locale, const char* tz_id, UDateFormatStyle dStyle, UDateFormatStyle tStyle, const char* pattern) {
    UErrorCode status = U_ZERO_ERROR;
    UChar u_tz[64], result[128], u_pattern[64];
    u_uastrcpy(u_tz, tz_id);
    UDateFormat* df;

    if (pattern) {
        u_uastrcpy(u_pattern, pattern);
        df = udat_open(UDAT_PATTERN, UDAT_PATTERN, locale, u_tz, -1, u_pattern, -1, &status);
    } else {
        df = udat_open(tStyle, dStyle, locale, u_tz, -1, NULL, 0, &status);
    }

    if (U_FAILURE(status)) return newSVpv("", 0);

    udat_format(df, date, result, 128, NULL, &status);
    udat_close(df);

    char final_str[256];
    u_austrcpy(final_str, result);
    return newSVpv(final_str, 0);
}

MODULE = Datetime::Hash     PACKAGE = Datetime::Hash

SV*
format_datetime(datetime_str, tz_id, locale = "de_DE", prefix = "")
    const char* datetime_str
    const char* tz_id
    const char* locale
    const char* prefix
    PREINIT:
        UErrorCode status = U_ZERO_ERROR;
        UChar u_tz_id[64];
        UCalendar *cal;
        HV* rh;
        STRLEN in_len;
        char buf[128];
    CODE:
        in_len = strlen(datetime_str);
        if (in_len < 19) XSRETURN_UNDEF;

        rh = newHV();

        /* 1. FAST PATH: Substring extraction for ISO-like fields */
        /* Input expected: "YYYY-MM-DD HH:MM:SS" (or similar 19+ char ISO) */
        store_part(aTHX_ rh, prefix, "year",          datetime_str + 0,  4);
        store_part(aTHX_ rh, prefix, "month",         datetime_str + 5,  2);
        store_part(aTHX_ rh, prefix, "day",           datetime_str + 8,  2);
        store_part(aTHX_ rh, prefix, "hour",          datetime_str + 11, 2);
        store_part(aTHX_ rh, prefix, "minute",        datetime_str + 14, 2);
        store_part(aTHX_ rh, prefix, "second",        datetime_str + 17, 2);
        store_part(aTHX_ rh, prefix, "date",          datetime_str + 0,  10);
        store_part(aTHX_ rh, prefix, "time",          datetime_str + 11, 8);
        store_part(aTHX_ rh, prefix, "time_hm",       datetime_str + 11, 5);
        store_part(aTHX_ rh, prefix, "datetime",      datetime_str + 0,  19);

        /* ISO8601 Basic / RFC5545: YYYYMMDDTHHMMSS */
        sprintf(buf, "%.4s%.2s%.2sT%.2s%.2s%.2s",
                datetime_str, datetime_str+5, datetime_str+8,
                datetime_str+11, datetime_str+14, datetime_str+17);
        store_sv(aTHX_ rh, prefix, "iso8601_basic",   newSVpv(buf, 15));
        store_sv(aTHX_ rh, prefix, "rfc5545",         newSVpv(buf, 15));

        /* 2. ICU PATH: Open calendar for calculations */
        u_uastrcpy(u_tz_id, tz_id);
        cal = ucal_open(u_tz_id, -1, locale, UCAL_GREGORIAN, &status);
        if (U_FAILURE(status)) {
            SvREFCNT_dec((SV*)rh);
            XSRETURN_UNDEF;
        }

        /* Convert string parts to integers for ICU */
        ucal_setDateTime(cal,
            atoi(datetime_str),
            atoi(datetime_str+5)-1,
            atoi(datetime_str+8),
            atoi(datetime_str+11),
            atoi(datetime_str+14),
            atoi(datetime_str+17),
            &status);

        UDate millis = ucal_getMillis(cal, &status);

        /* Calendar calculations */
        int32_t icu_dow = ucal_get(cal, UCAL_DAY_OF_WEEK, &status);
        store_sv(aTHX_ rh, prefix, "dow_iso",         newSViv(((icu_dow + 5) % 7) + 1));
        store_sv(aTHX_ rh, prefix, "doy",             newSViv(ucal_get(cal, UCAL_DAY_OF_YEAR, &status)));
        store_sv(aTHX_ rh, prefix, "epoch",           newSViv((long)(millis / 1000.0)));

        /* 3. FORMATTING PATH: Locale-aware strings */
        store_sv(aTHX_ rh, prefix, "date_name",       get_formatted(aTHX_ millis, locale, tz_id, UDAT_MEDIUM, UDAT_NONE, NULL));
        store_sv(aTHX_ rh, prefix, "weekday_long",    get_formatted(aTHX_ millis, locale, tz_id, UDAT_NONE, UDAT_NONE, "EEEE"));
        store_sv(aTHX_ rh, prefix, "weekday_short",   get_formatted(aTHX_ millis, locale, tz_id, UDAT_NONE, UDAT_NONE, "EE"));
        store_sv(aTHX_ rh, prefix, "month_long",      get_formatted(aTHX_ millis, locale, tz_id, UDAT_NONE, UDAT_NONE, "MMMM"));
        store_sv(aTHX_ rh, prefix, "month_short",     get_formatted(aTHX_ millis, locale, tz_id, UDAT_NONE, UDAT_NONE, "MMM"));

        /* RFC 822 (Email format) */
        store_sv(aTHX_ rh, prefix, "rfc822",          get_formatted(aTHX_ millis, "en_US", tz_id, UDAT_NONE, UDAT_NONE, "EEE, dd MMM yyyy HH:mm:ss Z"));

        /* RFC 3339 Zulu: Use UTC specifically for this format */
        store_sv(aTHX_ rh, prefix, "rfc3339",         get_formatted(aTHX_ millis, "en_US", "UTC", UDAT_NONE, UDAT_NONE, "yyyy-MM-dd'T'HH:mm:ss'Z'"));

        ucal_close(cal);
        RETVAL = newRV_noinc((SV*)rh);
    OUTPUT:
        RETVAL