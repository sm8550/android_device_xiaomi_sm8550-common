#!/bin/bash
#
# Copyright (C) 2016 The CyanogenMod Project
# Copyright (C) 2017-2023 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

DEVICE=socrates
VENDOR=xiaomi

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

KANG=
SECTION=

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        --only-firmware )
                ONLY_FIRMWARE=true
                ;;
        -n | --no-cleanup )
                CLEAN_VENDOR=false
                ;;
        -k | --kang )
                KANG="--kang"
                ;;
        -s | --section )
                SECTION="${2}"; shift
                CLEAN_VENDOR=false
                ;;
        * )
                SRC="${1}"
                ;;
    esac
    shift
done

if [ -z "${SRC}" ]; then
    SRC="adb"
fi

function blob_fixup() {
    case "${1}" in
        odm/etc/camera/*.xml)
            sed -i s/xml=version/xml\ version/g "${2}"
            ;;
        vendor/etc/audio/sku_kalama/audio_policy_configuration.xml)
            sed -i s/AUDIO_FORMAT_LC3//g "${2}"
            ;;
        vendor/bin/hw/android.hardware.security.keymint-service-qti)
            "${PATCHELF}" --add-needed "android.hardware.security.rkp-V3-ndk.so" "${2}"
            ;;
        odm/lib64/libmt@1.3.so)
            "${PATCHELF}" --replace-needed "libcrypto.so" "libcrypto-v33.so" "${2}"
            ;;
        vendor/lib/c2.dolby.client.so | vendor/lib64/c2.dolby.client.so)
            grep -q "dolbycodec_shim.so" "${2}" || "${PATCHELF}" --add-needed "dolbycodec_shim.so" "${2}"
            ;;
        vendor/etc/seccomp_policy/qwesd@2.0.policy)
            echo "pipe2: 1" >> "${2}"
            ;;
        vendor/bin/COSNet_spatial_8bit_quantized.serialized.bin | vendor/lib/rfsa/adsp/libvpt_action_recognition.so | odm/lib64/libxmi_high_dynamic_range_cdsp.so)
            split --bytes=49M -d "${2}" "${2}".part
            ;;
    esac
}

function prepare_firmware() {
    :
}

# Initialize the helper
setup_vendor "${DEVICE}" "${VENDOR}" "${ANDROID_ROOT}" false "${CLEAN_VENDOR}"

if [ -z "${ONLY_FIRMWARE}" ]; then
    extract "${MY_DIR}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"
    extract "${MY_DIR}/proprietary-files-vendor.txt" "${SRC}" "${KANG}" --section "${SECTION}"
fi

if [ -z "${SECTION}" ]; then
    extract_firmware "${MY_DIR}/proprietary-firmware.txt" "${SRC}"
fi

split --bytes=49MB ${ANDROID_ROOT}/vendor/xiaomi/socrates/radio/modem.img ${ANDROID_ROOT}/vendor/xiaomi/socrates/radio/modem.img.part
split --bytes=49MB ${ANDROID_ROOT}/vendor/xiaomi/socrates/radio/dsp.img ${ANDROID_ROOT}/vendor/xiaomi/socrates/radio/dsp.img.part

"${MY_DIR}/setup-makefiles.sh"
