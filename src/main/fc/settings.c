#include <string.h>
#include <stdint.h>

#include "common/string_light.h"
#include "common/utils.h"

#include "fc/settings_generated.h"
#include "fc/settings.h"

#include "fc/settings_generated.c"

void setting_get_name(const setting_t *val, char *buf)
{
	uint8_t bpos = 0;
	uint16_t n = 0;
#ifndef SETTING_ENCODED_NAME_USES_BYTE_INDEXING
	uint8_t shift = 0;
#endif
	for (uint8_t ii = 0; ii < SETTING_ENCODED_NAME_MAX_BYTES; ii++) {
#ifdef SETTING_ENCODED_NAME_USES_BYTE_INDEXING
		n = val->encoded_name[ii];
#else
		// Decode a variable size uint
		uint16_t b = val->encoded_name[ii];
		if (b >= 0x80) {
			// More bytes follow
			n |= (b&0x7f) << shift;
			shift += 7;
			continue;
		}
		// Final byte
		n |= b << shift;
#endif
		const char *word = settingNamesWords[n];
		if (!word) {
			// No more words
			break;
		}
		if (bpos > 0) {
			// Word separator
			buf[bpos++] = '_';
		}
		strcpy(&buf[bpos], word);
		bpos += strlen(word);
#ifndef SETTING_ENCODED_NAME_USES_BYTE_INDEXING
		// Reset shift and n
		shift = 0;
		n = 0;
#endif
	}
	buf[bpos] = '\0';
}

bool setting_name_contains(const setting_t *val, char *buf, const char *cmdline)
{
	setting_get_name(val, buf);
	return strstr(buf, cmdline) != NULL;
}

bool setting_name_exact_match(const setting_t *val, char *buf, const char *cmdline, uint8_t var_name_length)
{
	setting_get_name(val, buf);
	return sl_strncasecmp(cmdline, buf, strlen(buf)) == 0 && var_name_length == strlen(buf);
}

const setting_t *setting_find(const char *name)
{
	char buf[SETTING_MAX_NAME_LENGTH];
	for (int ii = 0; ii < SETTINGS_TABLE_COUNT; ii++) {
		const setting_t *setting = &settingsTable[ii];
		setting_get_name(setting, buf);
		if (strcmp(buf, name) == 0) {
			return setting;
		}
	}
	return NULL;
}

size_t setting_get_value_size(const setting_t *val)
{
	switch (SETTING_TYPE(val)) {
		case VAR_UINT8:
			FALLTHROUGH;
		case VAR_INT8:
			return 1;
		case VAR_UINT16:
			FALLTHROUGH;
		case VAR_INT16:
			return 2;
		case VAR_UINT32:
			FALLTHROUGH;
		case VAR_FLOAT:
			return 4;
	}
	return 0; // Unreachable
}

pgn_t setting_get_pgn(const setting_t *val)
{
	uint16_t pos = val - (const setting_t *)settingsTable;
	uint16_t acc = 0;
	for (uint8_t ii = 0; ii < SETTINGS_PGN_COUNT; ii++) {
		acc += settingsPgnCounts[ii];
		if (acc > pos) {
			return settingsPgn[ii];
		}
	}
	return -1;
}

static uint16_t getValueOffset(const setting_t *value)
{
    switch (SETTING_SECTION(value)) {
    case MASTER_VALUE:
        return value->offset;
    case PROFILE_VALUE:
        return value->offset + sizeof(pidProfile_t) * getConfigProfile();
    case CONTROL_RATE_VALUE:
        return value->offset + sizeof(controlRateConfig_t) * getConfigProfile();
    }
    return 0;
}

void *setting_get_value_pointer(const setting_t *val)
{
    const pgRegistry_t *pg = pgFind(setting_get_pgn(val));
    return pg->address + getValueOffset(val);
}

const void * setting_get_copy_value_pointer(const setting_t *val)
{
    const pgRegistry_t *pg = pgFind(setting_get_pgn(val));
    return pg->copy + getValueOffset(val);
}

setting_min_t setting_get_min(const setting_t *val)
{
	if (SETTING_MODE(val) == MODE_LOOKUP) {
		return 0;
	}
	return settingMinMaxTable[SETTING_INDEXES_GET_MIN(val)];
}

setting_max_t setting_get_max(const setting_t *val)
{
	if (SETTING_MODE(val) == MODE_LOOKUP) {
		return settingLookupTables[val->config.lookup.tableIndex].valueCount - 1;
	}
	return settingMinMaxTable[SETTING_INDEXES_GET_MAX(val)];
}
