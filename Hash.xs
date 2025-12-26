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
#include <ctype.h>

/* --- Helpers --- */

static void store_sv_opt(pTHX_ HV* hash, const char* prefix, STRLEN pre_len, const char* key, SV* value) {
    if (!hash || !key || !value) return;
    if (pre_len == 0) {
        hv_store(hash, key, strlen(key), value, 0);
    } else {
        char full_key[128];
        int klen = snprintf(full_key, sizeof(full_key), "%s%s", prefix, key);
        hv_store(hash, full_key, klen, value, 0);
    }
}

static SV* format_with_df(pTHX_ UDateFormat* df, UDate date) {
    UErrorCode status = U_ZERO_ERROR;
    UChar result[128];
    char final_str[256];
    if (!df) return newSVpv("", 0);
    
    udat_format(df, date, result, 128, NULL, &status);
    if (U_FAILURE(status)) return newSVpv("", 0);
    
    u_austrcpy(final_str, result);
    return newSVpv(final_str, 0);
}

/* --- XS Core --- */

MODULE = Datetime::Hash     PACKAGE = Datetime::Hash

SV*
format_datetime(input_sv, target_tz = "UTC", locale = "de_DE", prefix = "")
    SV* input_sv
    const char* target_tz
    const char* locale
    const char* prefix
    PREINIT:
        UErrorCode status = U_ZERO_ERROR;
        UDate millis = 0;
        UChar u_tz[64], u_pattern[128], u_input[256], u_utc[8];
        UCalendar *cal = NULL;
        UDateFormat *df_date_name = NULL, *df_wd_long = NULL, *df_wd_short = NULL;
        UDateFormat *df_mo_long = NULL, *df_mo_short = NULL, *df_rfc822 = NULL, *df_rfc3339 = NULL;
        UDateFormat *parser = NULL;
        HV* rh;
        const char* input_str;
        STRLEN len, pre_len;
        char buf[128];
        bool is_numeric;
        STRLEN i;
        int32_t y, m, d, h, min, s;

    CODE:
        /* 1. INPUT VALIDATION (C-level check for Perl undef) */
        if (!input_sv || !SvOK(input_sv)) {
            XSRETURN_UNDEF;
        }

        input_str = SvPV(input_sv, len);
        if (len == 0) {
            XSRETURN_UNDEF;
        }

        pre_len = (prefix) ? strlen(prefix) : 0;
        u_uastrcpy(u_tz, (target_tz) ? target_tz : "UTC");

        /* 2. HEURISTIC NUMERIC CHECK */
        is_numeric = true;
        for (i = 0; i < len; i++) {
            if (!isdigit(input_str[i]) && input_str[i] != '.') {
                is_numeric = false;
                break;
            }
        }

        /* 3. PARSING LOGIC */
        if (is_numeric && len >= 10) {
            millis = (UDate)(atof(input_str) * 1000.0);
        } else {
            u_uastrcpy(u_input, input_str);
            
            /* Attempt 1: ISO 8601 Auto-detect */
            status = U_ZERO_ERROR;
            parser = udat_open(UDAT_IGNORE, UDAT_IGNORE, (locale) ? locale : "en_US", u_tz, -1, NULL, 0, &status);
            if (U_SUCCESS(status)) {
                millis = udat_parse(parser, u_input, -1, NULL, &status);
                udat_close(parser);
            }
            
            /* Attempt 2: Explicit ISO8601 with Zulu/Offset (X pattern) */
            if (U_FAILURE(status) || millis <= 0) {
                status = U_ZERO_ERROR;
                u_uastrcpy(u_pattern, "yyyy-MM-dd'T'HH:mm:ssX");
                parser = udat_open(UDAT_PATTERN, UDAT_PATTERN, (locale) ? locale : "en_US", u_tz, -1, u_pattern, -1, &status);
                if (U_SUCCESS(status)) {
                    millis = udat_parse(parser, u_input, -1, NULL, &status);
                    udat_close(parser);
                }
            }

            /* Attempt 3: SQL Fallback (Space separated) */
            if (U_FAILURE(status) || millis <= 0) {
                status = U_ZERO_ERROR;
                u_uastrcpy(u_pattern, "yyyy-MM-dd HH:mm:ss");
                parser = udat_open(UDAT_PATTERN, UDAT_PATTERN, (locale) ? locale : "en_US", u_tz, -1, u_pattern, -1, &status);
                if (U_SUCCESS(status)) {
                    millis = udat_parse(parser, u_input, -1, NULL, &status);
                    udat_close(parser);
                }
            }
            
            /* If all parsing fails, return undef to Perl */
            if (U_FAILURE(status) || millis <= 0) {
                XSRETURN_UNDEF;
            }
        }

        /* 4. PREPARE FORMATTERS */
        status = U_ZERO_ERROR;
        df_date_name = udat_open(UDAT_NONE, UDAT_MEDIUM, locale, u_tz, -1, NULL, 0, &status);
        
        u_uastrcpy(u_pattern, "EEEE");
        df_wd_long  = udat_open(UDAT_PATTERN, UDAT_PATTERN, locale, u_tz, -1, u_pattern, -1, &status);
        u_uastrcpy(u_pattern, "EE");
        df_wd_short = udat_open(UDAT_PATTERN, UDAT_PATTERN, locale, u_tz, -1, u_pattern, -1, &status);
        u_uastrcpy(u_pattern, "MMMM");
        df_mo_long  = udat_open(UDAT_PATTERN, UDAT_PATTERN, locale, u_tz, -1, u_pattern, -1, &status);
        u_uastrcpy(u_pattern, "MMM");
        df_mo_short = udat_open(UDAT_PATTERN, UDAT_PATTERN, locale, u_tz, -1, u_pattern, -1, &status);
        
        u_uastrcpy(u_pattern, "EEE, dd MMM yyyy HH:mm:ss Z");
        df_rfc822   = udat_open(UDAT_PATTERN, UDAT_PATTERN, "en_US", u_tz, -1, u_pattern, -1, &status);
        
        u_uastrcpy(u_pattern, "yyyy-MM-dd'T'HH:mm:ss'Z'");
        u_uastrcpy(u_utc, "UTC");
        df_rfc3339  = udat_open(UDAT_PATTERN, UDAT_PATTERN, "en_US", u_utc, -1, u_pattern, -1, &status);

        /* 5. POPULATE */
        rh = newHV();
        cal = ucal_open(u_tz, -1, locale, UCAL_GREGORIAN, &status);
        if (U_SUCCESS(status)) {
            ucal_setMillis(cal, millis, &status);

            y   = ucal_get(cal, UCAL_YEAR, &status);
            m   = ucal_get(cal, UCAL_MONTH, &status) + 1;
            d   = ucal_get(cal, UCAL_DAY_OF_MONTH, &status);
            h   = ucal_get(cal, UCAL_HOUR_OF_DAY, &status);
            min = ucal_get(cal, UCAL_MINUTE, &status);
            s   = ucal_get(cal, UCAL_SECOND, &status);

            store_sv_opt(aTHX_ rh, prefix, pre_len, "year",      newSViv(y));
            store_sv_opt(aTHX_ rh, prefix, pre_len, "month",     newSViv(m));
            store_sv_opt(aTHX_ rh, prefix, pre_len, "day",       newSViv(d));
            store_sv_opt(aTHX_ rh, prefix, pre_len, "hour",      newSViv(h));
            store_sv_opt(aTHX_ rh, prefix, pre_len, "minute",    newSViv(min));
            store_sv_opt(aTHX_ rh, prefix, pre_len, "second",    newSViv(s));
            store_sv_opt(aTHX_ rh, prefix, pre_len, "dow_iso",   newSViv(((ucal_get(cal, UCAL_DAY_OF_WEEK, &status) + 5) % 7) + 1));
            store_sv_opt(aTHX_ rh, prefix, pre_len, "doy",       newSViv(ucal_get(cal, UCAL_DAY_OF_YEAR, &status)));
            store_sv_opt(aTHX_ rh, prefix, pre_len, "epoch",     newSViv((long)(millis / 1000.0)));

            sprintf(buf, "%04d-%02d-%02d", y, m, d);
            store_sv_opt(aTHX_ rh, prefix, pre_len, "date",      newSVpv(buf, 10));
            sprintf(buf, "%02d:%02d:%02d", h, min, s);
            store_sv_opt(aTHX_ rh, prefix, pre_len, "time",      newSVpv(buf, 8));
            sprintf(buf, "%02d:%02d", h, min);
            store_sv_opt(aTHX_ rh, prefix, pre_len, "time_hm",   newSVpv(buf, 5));
            sprintf(buf, "%04d-%02d-%02d %02d:%02d:%02d", y, m, d, h, min, s);
            store_sv_opt(aTHX_ rh, prefix, pre_len, "datetime",  newSVpv(buf, 19));
            
            sprintf(buf, "%04d%02d%02dT%02d%02d%02d", y, m, d, h, min, s);
            store_sv_opt(aTHX_ rh, prefix, pre_len, "iso8601_basic", newSVpv(buf, 15));
            store_sv_opt(aTHX_ rh, prefix, pre_len, "rfc5545",       newSVpv(buf, 15));

            store_sv_opt(aTHX_ rh, prefix, pre_len, "date_name",     format_with_df(aTHX_ df_date_name, millis));
            store_sv_opt(aTHX_ rh, prefix, pre_len, "weekday_long",  format_with_df(aTHX_ df_wd_long, millis));
            store_sv_opt(aTHX_ rh, prefix, pre_len, "weekday_short", format_with_df(aTHX_ df_wd_short, millis));
            store_sv_opt(aTHX_ rh, prefix, pre_len, "month_long",    format_with_df(aTHX_ df_mo_long, millis));
            store_sv_opt(aTHX_ rh, prefix, pre_len, "month_short",   format_with_df(aTHX_ df_mo_short, millis));
            store_sv_opt(aTHX_ rh, prefix, pre_len, "rfc822",        format_with_df(aTHX_ df_rfc822, millis));
            store_sv_opt(aTHX_ rh, prefix, pre_len, "rfc3339",       format_with_df(aTHX_ df_rfc3339, millis));
        }

        /* 6. CLEANUP */
        if (cal) ucal_close(cal);
        if (df_date_name) udat_close(df_date_name);
        if (df_wd_long) udat_close(df_wd_long);
        if (df_wd_short) udat_close(df_wd_short);
        if (df_mo_long) udat_close(df_mo_long);
        if (df_mo_short) udat_close(df_mo_short);
        if (df_rfc822) udat_close(df_rfc822);
        if (df_rfc3339) udat_close(df_rfc3339);

        RETVAL = newRV_noinc((SV*)rh);
    OUTPUT:
        RETVAL