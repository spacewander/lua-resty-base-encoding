#include "modp_stdint.h"
#include "b32_data.h"


#define likely(x) __builtin_expect(!!(x), 1)
#define unlikely(x) __builtin_expect(!!(x), 0)
#define IN_BLOCK_LEN 5
#define OUT_BLOCK_LEN 8


size_t b32_encode(char *dest, const char *src, size_t len, uint32_t no_padding,
    uint32_t hex)
{
    unsigned char   n1, n2, n3, n4, n5, n6, n7, n8;
    const uint8_t   *s = (const uint8_t*)src;
    uint8_t         *p = (uint8_t*)dest;

    const char *encode_table = (hex == 0) ? std_encode_table : hex_encode_table;

    while (likely(len >= IN_BLOCK_LEN)) {
        n8 = (s[4] & 0x1f);
        n7 = ((s[4] & 0xe0) >> 5) | ((s[3] & 0x03) << 3);
        n6 = ((s[3] & 0x7c) >> 2);
        n5 = ((s[3] & 0x80) >> 7) | ((s[2] & 0x0f) << 1);
        n4 = ((s[2] & 0xf0) >> 4) | ((s[1] & 0x01) << 4);
        n3 = ((s[1] & 0x3e) >> 1);
        n2 = ((s[1] & 0xc0) >> 6) | ((s[0] & 0x07) << 2);
        n1 = ((s[0] & 0xf8) >> 3);

        *p++ = encode_table[n1];
        *p++ = encode_table[n2];
        *p++ = encode_table[n3];
        *p++ = encode_table[n4];
        *p++ = encode_table[n5];
        *p++ = encode_table[n6];
        *p++ = encode_table[n7];
        *p++ = encode_table[n8];

        s += IN_BLOCK_LEN;
        len -= IN_BLOCK_LEN;
    }

    n1 = n2 = n3 = n4 = n5 = n6 = n7 = n8 = 0;
    int step = 0;
    uint8_t *padding_start = p;

    switch (len) {
    case 4:
        n7 = ((s[3] & 0x03) << 3);
        n6 = ((s[3] & 0x7c) >> 2);
        n5 = ((s[3] & 0x80) >> 7);
        p[6] = encode_table[n7];
        p[5] = encode_table[n6];
        step += 2;
        /* fall through */
    case 3:
        n5 |= ((s[2] & 0x0f) << 1);
        n4 = ((s[2] & 0xf0) >> 4);
        p[4] = encode_table[n5];
        step += 1;
        /* fall through */
    case 2:
        n4 |= ((s[1] & 0x01) << 4);
        n3 = ((s[1] & 0x3e) >> 1);
        n2 = ((s[1] & 0xc0) >> 6);
        p[3] = encode_table[n4];
        p[2] = encode_table[n3];
        step += 2;
        /* fall through */
    case 1:
        n2 |= ((s[0] & 0x07) << 2);
        n1 = ((s[0] & 0xf8) >> 3);
        p[1] = encode_table[n2];
        p[0] = encode_table[n1];
        step += 2;
        break;
    case 0:
        return (size_t)(p - (uint8_t*)dest);
    }

    p += step;

    if (!no_padding) {
        memset(p, CHARPAD, padding_start + 8 - p);
        p = padding_start + 8;
    }

    return (size_t)(p - (uint8_t*)dest);
}


size_t b32_decode(char *dest, const char *src, size_t len, uint32_t hex)
{
    unsigned char        in1, in2, in3, in4, in5, in6, in7, in8;
    const unsigned char *s = (const unsigned char*)src;
    unsigned char       *p = (unsigned char*)dest;

    const char *decode_table = (hex == 0) ? std_decode_table : hex_decode_table;

    if (src[len - 1] == CHARPAD) {
        /*
        * if padding is used, then the message must be at least
        * 8 chars and be a multiple of 8
        */
        if (len < 8 || (len % 8 != 0)) {
            return -1;
        }

        len--;
        /* there can be at most 7 pad chars at the end */
        int i = 0;
        for (i = 0; src[len - 1] == CHARPAD; i++) {
            if (i >= 6) {
                return -1;
            }
            len--;
        }
    }

    while (likely(len >= OUT_BLOCK_LEN)) {
        in1 = decode_table[*s++];
        in2 = decode_table[*s++];
        in3 = decode_table[*s++];
        in4 = decode_table[*s++];
        in5 = decode_table[*s++];
        in6 = decode_table[*s++];
        in7 = decode_table[*s++];
        in8 = decode_table[*s++];

        /* faster than memchr */
        if (unlikely(in1 == BADCHAR || in2 == BADCHAR || in3 == BADCHAR
            || in4 == BADCHAR || in5 == BADCHAR || in6 == BADCHAR
            || in7 == BADCHAR || in8 == BADCHAR))
        {
            return -1;
        }

        *p++ = ((in1 & 0x1f) << 3) | ((in2 & 0x1c) >> 2);
        *p++ = ((in2 & 0x03) << 6) | ((in3 & 0x1f) << 1) | ((in4 & 0x10) >> 4);
        *p++ = ((in4 & 0x0f) << 4) | ((in5 & 0x1e) >> 1);
        *p++ = ((in5 & 0x01) << 7) | ((in6 & 0x1f) << 2) | ((in7 & 0x18) >> 3);
        *p++ = ((in7 & 0x07) << 5) | (in8 & 0x1f);

        len -= OUT_BLOCK_LEN;
    }

    int step = 0;
    unsigned int i;
    for (i = 0; i < len; i++) {
        if ((unsigned char)decode_table[s[i]] == BADCHAR) {
            return -1;
        }
    }

    switch(len) {
    case 7:
        in5 = decode_table[s[4]];
        in6 = decode_table[s[5]];
        in7 = decode_table[s[6]];
        p[3] = ((in5 & 0x01) << 7) | ((in6 & 0x1f) << 2) | ((in7 & 0x18) >> 3);
        step++;
        /* fall through */
    case 5:
        in5 = decode_table[s[4]];
        in4 = decode_table[s[3]];
        p[2] = ((in4 & 0x0f) << 4) | ((in5 & 0x1e) >> 1);
        step++;
        /* fall through */
    case 4:
        in4 = decode_table[s[3]];
        in3 = decode_table[s[2]];
        in2 = decode_table[s[1]];
        p[1] = ((in2 & 0x03) << 6) | ((in3 & 0x1f) << 1) | ((in4 & 0x10) >> 4);
        step++;
        /* fall through */
    case 2:
        in2 = decode_table[s[1]];
        in1 = decode_table[s[0]];
        p[0] = ((in1 & 0x1f) << 3) | ((in2 & 0x1c) >> 2);
        step++;
    case 0:
        break;
    default:
        return -1;
    }

    return (size_t)(p - (uint8_t*)dest) + step;
}
