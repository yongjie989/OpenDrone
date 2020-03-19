/*
 * This file is part of Cleanflight.
 *
 * Cleanflight is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Cleanflight is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Cleanflight.  If not, see <http://www.gnu.org/licenses/>.
 */


// Get target build configuration
#include "platform.h"

#include "common/maths.h"

#include "config/config_eeprom.h"
#include "config/parameter_group.h"
#include "config/parameter_group_ids.h"

#include "drivers/vtx_common.h"
#include "drivers/light_led.h"
#include "drivers/system.h"

#include "fc/config.h"
#include "fc/runtime_config.h"

#include "io/beeper.h"
#include "io/osd.h"
#include "io/vtx_control.h"


#if defined(VTX_CONTROL) && defined(VTX_COMMON)

PG_REGISTER(vtxConfig_t, vtxConfig, PG_VTX_CONFIG, 1);

static uint8_t locked = 0;

void vtxControlInit(void)
{
    // NOTHING TO DO
}

static void vtxUpdateBandAndChannel(uint8_t bandStep, uint8_t channelStep)
{
    if (ARMING_FLAG(ARMED)) {
        locked = 1;
    }

    if (!locked) {
        uint8_t band = 0, channel = 0;
        vtxCommonGetBandAndChannel(&band, &channel);
        vtxCommonSetBandAndChannel(band + bandStep, channel + channelStep);
    }
}

void vtxIncrementBand(void)
{
    vtxUpdateBandAndChannel(+1, 0);
}

void vtxDecrementBand(void)
{
    vtxUpdateBandAndChannel(-1, 0);
}

void vtxIncrementChannel(void)
{
    vtxUpdateBandAndChannel(0, +1);
}

void vtxDecrementChannel(void)
{
    vtxUpdateBandAndChannel(0, -1);
}

void vtxUpdateActivatedChannel(void)
{
    if (ARMING_FLAG(ARMED)) {
        locked = 1;
    }

    if (!locked) {
        static uint8_t lastIndex = -1;

        for (uint8_t index = 0; index < MAX_CHANNEL_ACTIVATION_CONDITION_COUNT; index++) {
            const vtxChannelActivationCondition_t *vtxChannelActivationCondition = &vtxConfig()->vtxChannelActivationConditions[index];

            if (isRangeActive(vtxChannelActivationCondition->auxChannelIndex, &vtxChannelActivationCondition->range)
                && index != lastIndex) {
                lastIndex = index;

                vtxCommonSetBandAndChannel(vtxChannelActivationCondition->band, vtxChannelActivationCondition->channel);
                break;
            }
        }
    }
}

void vtxCycleBandOrChannel(const uint8_t bandStep, const uint8_t channelStep)
{
    uint8_t band = 0, channel = 0;
    vtxDeviceCapability_t capability;

    bool haveAllNeededInfo = vtxCommonGetBandAndChannel(&band, &channel) && vtxCommonGetDeviceCapability(&capability);
    if (!haveAllNeededInfo) {
        return;
    }

    int newChannel = channel + channelStep;
    if (newChannel > capability.channelCount) {
        newChannel = 1;
    } else if (newChannel < 1) {
        newChannel = capability.channelCount;
    }

    int newBand = band + bandStep;
    if (newBand > capability.bandCount) {
        newBand = 1;
    } else if (newBand < 1) {
        newBand = capability.bandCount;
    }

    vtxCommonSetBandAndChannel(newBand, newChannel);
}

void vtxCyclePower(const uint8_t powerStep)
{
    uint8_t power = 0;
    vtxDeviceCapability_t capability;

    bool haveAllNeededInfo = vtxCommonGetPowerIndex(&power) && vtxCommonGetDeviceCapability(&capability);
    if (!haveAllNeededInfo) {
        return;
    }

    int newPower = power + powerStep;
    if (newPower >= capability.powerCount) {
        newPower = 0;
    } else if (newPower < 0) {
        newPower = capability.powerCount;
    }

    vtxCommonSetPowerByIndex(newPower);
}

#endif

