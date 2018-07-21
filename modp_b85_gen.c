#include "arraytoc.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
/**
 * raw data to base85 char map
 */
static char gsIntToChar[85];

/**
 * base 85 char to int
 */
static uint32_t gsCharToInt[256];

/*
 * Set up the above arrays
 */
static void initTables(void)
{
    int i = 0;
    int j = 0;
    for (i = 0; i < 256; i++) {
        gsCharToInt[i] = 99;
    }

    /* i < 33 or '!' is unprintable
     * 127 is an unprintable character
     */
    for (i = '!', j = 0; j < 85 && i < 127; ++i) {
        gsIntToChar[j] = (char)i;
        gsCharToInt[i] = (uint32_t)j;
        ++j;
    }

    if (j != 85) {
        fprintf(stderr, "Error in base85 table.  You probably had too many restrictions\n");
        exit(1);
    }
}

/**
 * beginning headers
 */
static void printStart(void)
{
    printf("/* do not edit -- autogenerated from b85gen */\n");
}

int main(void)
{
    initTables();
    printStart();
    uint32_array_to_c(gsCharToInt, sizeof(gsCharToInt) / sizeof(uint32_t), "gsCharToInt");
    char_array_to_c(gsIntToChar, sizeof(gsIntToChar), "gsIntToChar");
    return 0;
}