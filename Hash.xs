#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <unicode/ucal.h>
#include <unicode/udat.h>
#include <unicode/ustring.h>
#include <time.h>
#include <stdint.h>

static SV* get_formatted(pTHX_ UDate date, const char* locale, const char* tz_id, UDateFormatStyle dateStyle, UDateFormatStyle timeStyle, const char* pattern) {
    UErrorCode status = U_ZERO_ERROR;
    UChar u_tz[64], result[128];
    u_uastrcpy(u_tz, tz_id);
    
    UDateFormat* df;
    if (pattern) {
        UChar u_pattern[64];
        u_uastrcpy(u_pattern, pattern);
        df = udat_open(UDAT_PATTERN, UDAT_PATTERN, locale, u_tz, -1, u_pattern, -1, &status);
    } else {
        df = udat_open(timeStyle, dateStyle, locale, u_tz, -1, NULL, 0, &status);
    }

    if (U_FAILURE(status)) return newSVpv("", 0);
    udat_format(df, date, result, 128, NULL, &status);
    udat_close(df);
    
    char final_str[256];
    u_austrcpy(final_str, result);
    return newSVpv(final_str, 0);
}

static void store_in_hash(pTHX_ HV* hash, const char* prefix, const char* key, SV* value) {
    char full_key[128];
    sprintf(full_key, "%s%s", prefix, key);
    hv_store(hash, full_key, strlen(full_key), value, 0);
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
        char buf[128];
        char sep[2]; 
        int32_t year, month, day, hour, minute, second;
        double millis;
    CODE:
        u_uastrcpy(u_tz_id, tz_id);
        cal = ucal_open(u_tz_id, -1, locale, UCAL_GREGORIAN, &status);
        if (U_FAILURE(status)) XSRETURN_UNDEF;

        if (sscanf(datetime_str, "%d-%d-%d%1[ T]%d:%d:%d", 
                   &year, &month, &day, sep, &hour, &minute, &second) < 6) {
            ucal_close(cal);
            XSRETURN_UNDEF;
        }

        ucal_setDateTime(cal, year, month - 1, day, hour, minute, second, &status);
        millis = ucal_getMillis(cal, &status);
        rh = newHV();
        
        year        = ucal_get(cal, UCAL_YEAR, &status);
        month       = ucal_get(cal, UCAL_MONTH, &status) + 1;
        day         = ucal_get(cal, UCAL_DATE, &status);
        hour        = ucal_get(cal, UCAL_HOUR_OF_DAY, &status);
        minute      = ucal_get(cal, UCAL_MINUTE, &status);
        second      = ucal_get(cal, UCAL_SECOND, &status);
        
        int32_t icu_dow = ucal_get(cal, UCAL_DAY_OF_WEEK, &status);
        int32_t iso_dow = ((icu_dow + 5) % 7) + 1;
        int32_t doy     = ucal_get(cal, UCAL_DAY_OF_YEAR, &status);

        store_in_hash(aTHX_ rh, prefix, "dow_iso",           newSViv(iso_dow));
        store_in_hash(aTHX_ rh, prefix, "doy",               newSViv(doy));
        sprintf(buf, "%02d", day);    store_in_hash(aTHX_ rh, prefix, "day",    newSVpv(buf, 0));
        sprintf(buf, "%02d", month);  store_in_hash(aTHX_ rh, prefix, "month",  newSVpv(buf, 0));
        sprintf(buf, "%04d", year);   store_in_hash(aTHX_ rh, prefix, "year",   newSVpv(buf, 0));
        sprintf(buf, "%02d", hour);   store_in_hash(aTHX_ rh, prefix, "hour",   newSVpv(buf, 0));
        sprintf(buf, "%02d", minute); store_in_hash(aTHX_ rh, prefix, "minute", newSVpv(buf, 0));
        sprintf(buf, "%02d", second); store_in_hash(aTHX_ rh, prefix, "second", newSVpv(buf, 0));

        store_in_hash(aTHX_ rh, prefix, "date_name",         get_formatted(aTHX_ millis, locale, tz_id, UDAT_MEDIUM, UDAT_NONE, NULL));
        store_in_hash(aTHX_ rh, prefix, "weekday_long",      get_formatted(aTHX_ millis, locale, tz_id, UDAT_NONE, UDAT_NONE, "EEEE"));
        store_in_hash(aTHX_ rh, prefix, "weekday_short",     get_formatted(aTHX_ millis, locale, tz_id, UDAT_NONE, UDAT_NONE, "EE"));
        store_in_hash(aTHX_ rh, prefix, "month_long",        get_formatted(aTHX_ millis, locale, tz_id, UDAT_NONE, UDAT_NONE, "MMMM"));
        store_in_hash(aTHX_ rh, prefix, "month_short",       get_formatted(aTHX_ millis, locale, tz_id, UDAT_NONE, UDAT_NONE, "MMM"));

        sprintf(buf, "%04d-%02d-%02d", year, month, day);
        store_in_hash(aTHX_ rh, prefix, "date",          newSVpv(buf, 0));
        sprintf(buf, "%04d-%02d-%02dT%02d:%02d:%02d", year, month, day, hour, minute, second);
        store_in_hash(aTHX_ rh, prefix, "datetime",      newSVpv(buf, 0));
        sprintf(buf, "%04d%02d%02dT%02d%02d%02d", year, month, day, hour, minute, second);
        store_in_hash(aTHX_ rh, prefix, "iso8601_basic",     newSVpv(buf, 0));
        store_in_hash(aTHX_ rh, prefix, "rfc5545",           newSVpv(buf, 0));
        store_in_hash(aTHX_ rh, prefix, "rfc822",            get_formatted(aTHX_ millis, "en_US", tz_id, UDAT_NONE, UDAT_NONE, "EEE, dd MMM yyyy HH:mm:ss Z"));

        sprintf(buf, "%02d:%02d", hour, minute);
        store_in_hash(aTHX_ rh, prefix, "time_hm",           newSVpv(buf, 0));
        sprintf(buf, "%02d:%02d:%02d", hour, minute, second);
        store_in_hash(aTHX_ rh, prefix, "time",              newSVpv(buf, 0));

        long unix_ts = (long)(millis / 1000.0);
        store_in_hash(aTHX_ rh, prefix, "epoch",             newSViv(unix_ts));
        time_t ts = (time_t)unix_ts;
        struct tm utc_tm;
        gmtime_r(&ts, &utc_tm);
        sprintf(buf, "%04d-%02d-%02dT%02d:%02d:%02dZ", 
                utc_tm.tm_year + 1900, utc_tm.tm_mon + 1, utc_tm.tm_mday, 
                utc_tm.tm_hour, utc_tm.tm_min, utc_tm.tm_sec);
        store_in_hash(aTHX_ rh, prefix, "rfc3339",           newSVpv(buf, 0));

        ucal_close(cal);
        RETVAL = newRV_noinc((SV*)rh);
    OUTPUT:
        RETVAL