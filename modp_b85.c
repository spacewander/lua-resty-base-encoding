/**
 * \file
 * <PRE>
 * MODP_B85 - High performance base85 encoder/decoder
 * https://github.com/client9/stringencoders/
 *
 * Copyright &copy; 2006-2016  Nick Galbreath -- nickg [at] client9 [dot] com
 * Modified by spacewander to make it compatible with Go's encoding/ascii85
 * All rights reserved.
 * Released under MIT license. See LICENSE for details.
 * </pre>
 */

#include "modp_stdint.h"
/* private header */
#include "modp_b85_data.h"

#define unlikely(x) __builtin_expect(!!(x), 0)

/*
 * Might need changing depending on platform
 * we need htonl, and ntohl
 */
#include <arpa/inet.h>

/**
 * you can decode IN PLACE!
 * no memory allocated
 */
size_t modp_b85_decode(char* out, const char* data, size_t len)
{
    size_t i;
    int j;
    uint32_t tmp = 0;
    uint32_t digit;
    uint32_t* out_block = (uint32_t*)out;
    uint32_t* origin_out = out_block;
    const uint8_t* src = (const uint8_t*)data;
    uint8_t ch;

    for (i = 0, j = 0; i < len; ++i) {
        ch = *src;
        src++;

        /* skip space and control characters */
        if (unlikely(ch <= ' ')) {
            continue;
        }

        if (unlikely(ch == 'z')) {
            *out_block++ = 0;
            continue;
        }

        digit = gsCharToInt[(uint32_t)ch];
        if (unlikely(digit >= 85)) {
            return (size_t)-1;
        }

        tmp = tmp * 85 + digit;
        ++j;

        if (j == 5) {
            *out_block++ = ntohl(tmp);
            tmp = 0;
            j = 0;
        }
    }

    if (j != 0) {
        if (j == 1) {
            return (size_t)-1;
        }

        for (i = j; i < 5; i++) {
            /* padding with 'u' */
            tmp = tmp * 85 + 84;
        }

        *out_block = ntohl(tmp);
        return 4*(out_block - origin_out) + j - 1;
    }

    return 4*(out_block - origin_out);
}

/**
 * src != out
 */
size_t modp_b85_encode(char* out, const char* src, size_t len)
{
    size_t i;
    uint32_t tmp;
    char* dst;
    const uint32_t* sary = (const uint32_t*)src;
    const size_t buckets = len / 4;
    uint32_t remain = len % 4;
    char* origin_out = out;

    for (i = 0; i < buckets; ++i) {
        tmp = *sary++;
        tmp = htonl(tmp);

        if (unlikely(tmp == 0)) {
            *out++ = 'z';

        } else {
/* this crazy function */
#if 1
        *out++ = (char)gsIntToChar[(tmp / 52200625)]; /* don't need % 85 here, always < 85 */
        *out++ = (char)gsIntToChar[(tmp / 614125) % 85];
        *out++ = (char)gsIntToChar[(tmp / 7225) % 85];
        *out++ = (char)gsIntToChar[(tmp / 85) % 85];
        *out++ = (char)gsIntToChar[tmp % 85];
#else
        /* is really this */
        *(out + 4) = gsIntToChar[tmp % 85];
        tmp /= 85;
        *(out + 3) = gsIntToChar[tmp % 85];
        tmp /= 85;
        *(out + 2) = gsIntToChar[tmp % 85];
        tmp /= 85;
        *(out + 1) = gsIntToChar[tmp % 85];
        tmp /= 85;
        *out = gsIntToChar[tmp];
        out += 5;
#endif
        }

        /* NOTES
         * Version 1 under -O3 is about 10-20 PERCENT faster than version 2
         * BUT Version 1 is 10 TIMES SLOWER when used with -Os !!!
         * Reason: gcc does a lot of tricks to remove the divisions
         *  op with multiplies and shift.
         * In V1 with -O3 this works.  Under -Os it reverts to very
         *   slow division.
         * In V2 -O3 it does the same thing, but under Os, it's smart
         * enough to know we want the quotient and remainder and only
         * one div call per line.
         */
    }

    if (remain > 0) {
        src = (const char *)sary;
        tmp = 0;
        dst = (char *)&tmp;
        for (i = 1; i <= remain; ++i) {
            *dst++ = *src++;
        }
        tmp = htonl(tmp);

        *out++ = (char)gsIntToChar[(tmp / 52200625)];
        *out++ = (char)gsIntToChar[(tmp / 614125) % 85];
        *out++ = (char)gsIntToChar[(tmp / 7225) % 85];
        *out++ = (char)gsIntToChar[(tmp / 85) % 85];
        *out++ = (char)gsIntToChar[tmp % 85];
        return out - origin_out - (4 - remain);
    }

    return out - origin_out;
}
