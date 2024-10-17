#!/bin/bash
#================================================================================================
#================================ Set make environment variables ================================
#
# Set default parameters
make_path="${PWD}"
openwrt_dir="imagebuilder"
imagebuilder_path="${make_path}/${openwrt_dir}"
custom_files_path="${make_path}/config/imagebuilder/files"
custom_config_file="${make_path}/config/imagebuilder/config"

# Set default parameters
STEPS="[\033[95m STEPS \033[0m]"
INFO="[\033[94m INFO \033[0m]"
SUCCESS="[\033[92m SUCCESS \033[0m]"
WARNING="[\033[93m WARNING \033[0m]"
ERROR="[\033[91m ERROR \033[0m]"
#
#================================================================================================

# Encountered a serious error, abort the script execution
error_msg() {
    echo -e "${ERROR} ${1}"
    exit 1
}

# Downloading OpenWrt ImageBuilder
download_imagebuilder() {
    cd ${make_path}
    echo -e "${STEPS} Start downloading OpenWrt files..."

    # Determine the target system (Imagebuilder files naming has changed since 23.05.0)
    if [[ "${op_branch:0:2}" -ge "23" && "${op_branch:3:2}" -ge "05" ]]; then
        target_system="armsr/armv8"
        target_name="armsr-armv8"
        target_profile=""
    else
        target_system="armvirt/64"
        target_name="armvirt-64"
        target_profile="Default"
    fi

    # Downloading imagebuilder files
    download_file="https://downloads.${op_sourse}.org/releases/${op_branch}/targets/${target_system}/${op_sourse}-imagebuilder-${op_branch}-${target_name}.Linux-x86_64.tar.xz"
    curl -fsSOL ${download_file}
    [[ "${?}" -eq "0" ]] || error_msg "Download failed: [ ${download_file} ]"

    # Unzip and change the directory name
    tar -xJf *-imagebuilder-* && sync && rm -f *-imagebuilder-*.tar.xz
    mv -f *-imagebuilder-* ${openwrt_dir}

    sync && sleep 3
    echo -e "${INFO} [ ${make_path} ] directory status: $(ls -al 2>/dev/null)"
}

# Adjust related files in the ImageBuilder directory
adjust_settings() {
    cd ${imagebuilder_path}
    echo -e "${STEPS} Start adjusting .config file settings..."

    # For .config file
    if [[ -s ".config" ]]; then
        # Root filesystem archives
        sed -i "s|CONFIG_TARGET_ROOTFS_CPIOGZ=.*|# CONFIG_TARGET_ROOTFS_CPIOGZ is not set|g" .config
        # Root filesystem images
        sed -i "s|CONFIG_TARGET_ROOTFS_EXT4FS=.*|# CONFIG_TARGET_ROOTFS_EXT4FS is not set|g" .config
        sed -i "s|CONFIG_TARGET_ROOTFS_SQUASHFS=.*|# CONFIG_TARGET_ROOTFS_SQUASHFS is not set|g" .config
        sed -i "s|CONFIG_TARGET_IMAGES_GZIP=.*|# CONFIG_TARGET_IMAGES_GZIP is not set|g" .config
    else
        echo -e "${INFO} [ ${imagebuilder_path} ] directory status: $(ls -al 2>/dev/null)"
        error_msg "There is no .config file in the [ ${download_file} ]"
    fi

    # For other files
    # ......

    sync && sleep 3
    echo -e "${INFO} [ ${imagebuilder_path} ] directory status: $(ls -al 2>/dev/null)"
}

# Add custom packages
# If there is a custom package or ipk you would prefer to use create a [ packages ] directory,
# If one does not exist and place your custom ipk within this directory.
custom_packages() {
    cd ${imagebuilder_path}
    echo -e "${STEPS} Start adding custom packages..."

    # Create a [ packages ] directory
    [[ -d "packages" ]] || mkdir packages
    cd packages

    # Download luci-app-amlogic
    amlogic_api="https://api.github.com/repos/ophub/luci-app-amlogic/releases"
    #
    amlogic_file="luci-app-amlogic"
    amlogic_file_down="$(curl -s ${amlogic_api} | grep "browser_download_url" | grep -oE "https.*${amlogic_name}.*.ipk" | head -n 1)"
    curl -fsSOJL ${amlogic_file_down}
    [[ "${?}" -eq "0" ]] || error_msg "[ ${amlogic_file} ] download failed!"
    echo -e "${INFO} The [ ${amlogic_file} ] is downloaded successfully."
    #
    # Download luci-app-openclash
    openclash_api="https://api.github.com/repos/vernesong/OpenClash/releases"
    openclash_file="luci-app-openclash"
    openclash_file_down="$(curl -s ${openclash_api} | grep "browser_download_url" | grep -oE "https.*${openclash_file}.*.ipk" | head -n 1)"
    curl -fsSOJL ${openclash_file_down}
    [[ "${?}" -eq "0" ]] || error_msg "[ ${openclash_file} ] download failed!"
    echo -e "${INFO} The [ ${openclash_file} ] is downloaded successfully."
    #

    sync && sleep 3
    echo -e "${INFO} [ packages ] directory status: $(ls -al 2>/dev/null)"
}

# Add custom packages, lib, theme, app and i18n, etc.
custom_config() {
    cd ${imagebuilder_path}
    echo -e "${STEPS} Start adding custom config..."

    config_list=""
    if [[ -s "${custom_config_file}" ]]; then
        config_list="$(cat ${custom_config_file} 2>/dev/null | grep -E "^CONFIG_PACKAGE_.*=y" | sed -e 's/CONFIG_PACKAGE_//g' -e 's/=y//g' -e 's/[ ][ ]*//g' | tr '\n' ' ')"
        echo -e "${INFO} Custom config list: \n$(echo "${config_list}" | tr ' ' '\n')"
    else
        echo -e "${INFO} No custom config was added."
    fi
}

# Add custom files
# The FILES variable allows custom configuration files to be included in images built with Image Builder.
# The [ files ] directory should be placed in the Image Builder root directory where you issue the make command.
custom_files() {
    cd ${imagebuilder_path}
    echo -e "${STEPS} Start adding custom files..."

    if [[ -d "${custom_files_path}" ]]; then
        # Copy custom files
        [[ -d "files" ]] || mkdir -p files
        cp -rf ${custom_files_path}/* files

        sync && sleep 3
        echo -e "${INFO} [ files ] directory status: $(ls files -al 2>/dev/null)"
    else
        echo -e "${INFO} No customized files were added."
    fi
}

# Rebuild OpenWrt firmware
rebuild_firmware() {
    cd ${imagebuilder_path}
    echo -e "${STEPS} Start building OpenWrt with Image Builder..."

    # Selecting default packages, lib, theme, app and i18n, etc.
    my_packages="\
        acpid attr base-files bash bc blkid block-mount blockd bsdtar btrfs-progs busybox bzip2 \
        cgi-io chattr comgt comgt-ncm containerd coremark coreutils coreutils-base64 coreutils-nohup \
        coreutils-truncate curl dosfstools dumpe2fs e2freefrag e2fsprogs \
        exfat-mkfs f2fs-tools f2fsck fdisk gawk getopt git gzip hostapd-common iconv iw iwinfo jq \
        jshn kmod-brcmfmac kmod-brcmutil kmod-cfg80211 kmod-mac80211 libjson-script liblucihttp \
        liblucihttp-lua losetup lsattr lsblk lscpu mkf2fs mount-utils openssl-util parted \
        perl-http-date perlbase-file perlbase-getopt perlbase-time perlbase-unicode perlbase-utf8 \
        pigz ppp ppp-mod-pppoe proto-bonding pv rename resize2fs runc tar tini ttyd tune2fs \
        uclient-fetch uhttpd uhttpd-mod-ubus unzip uqmi usb-modeswitch uuidgen wget-ssl whereis \
        which wpad-basic wwan xfs-fsck xfs-mkfs xz xz-utils ziptool zoneinfo-asia zoneinfo-core zstd \
        \
        luci luci-base luci-compat luci-lib-base \
        luci-lib-ip luci-lib-ipkg luci-lib-jsonc luci-lib-nixio luci-mod-admin-full luci-mod-network \
        luci-mod-status luci-mod-system luci-proto-3g luci-proto-bonding luci-proto-ipip luci-proto-ipv6 \
        luci-proto-ncm luci-proto-ppp luci-proto-qmi \
        \
        luci-app-amlogic \
        \
        luci-app-openclash \
        \
        libc php8 php8-fastcgi php8-fpm coreutils-stat zoneinfo-asia php8-cgi \
        php8-cli php8-mod-bcmath php8-mod-calendar php8-mod-ctype php8-mod-curl php8-mod-dom php8-mod-exif \
        php8-mod-fileinfo php8-mod-filter php8-mod-gd php8-mod-iconv php8-mod-intl php8-mod-mbstring php8-mod-mysqli \
        php8-mod-mysqlnd php8-mod-opcache php8-mod-pdo php8-mod-pdo-mysql php8-mod-phar php8-mod-session \
        php8-mod-xml php8-mod-xmlreader php8-mod-xmlwriter php8-mod-zip libopenssl-legacy \
        \
        mariadb-server mariadb-server-extra mariadb-client mariadb-client-extra libmariadb nano \
        \
        freeradius3 freeradius3-common freeradius3-default freeradius3-mod-always freeradius3-mod-attr-filter \
        freeradius3-mod-chap freeradius3-mod-detail freeradius3-mod-digest freeradius3-mod-eap \
        freeradius3-mod-eap-gtc freeradius3-mod-eap-md5 freeradius3-mod-eap-mschapv2 freeradius3-mod-eap-peap \
        freeradius3-mod-eap-pwd freeradius3-mod-eap-tls freeradius3-mod-eap-ttls freeradius3-mod-exec \
        freeradius3-mod-expiration freeradius3-mod-expr freeradius3-mod-files freeradius3-mod-logintime \
        freeradius3-mod-mschap freeradius3-mod-pap freeradius3-mod-preprocess freeradius3-mod-radutmp \
        freeradius3-mod-realm freeradius3-mod-sql freeradius3-mod-sql-mysql freeradius3-mod-sqlcounter \
        freeradius3-mod-unix freeradius3-utils libfreetype wget-ssl curl unzip tar zoneinfo-asia coova-chilli \
        \
        node node-npm \
        \
        ${config_list} \
        "

    # Rebuild firmware
    make image PROFILE="${target_profile}" PACKAGES="${my_packages}" FILES="files"

    sync && sleep 3
    echo -e "${INFO} [ ${openwrt_dir}/bin/targets/*/* ] directory status: $(ls bin/targets/*/* -al 2>/dev/null)"
    echo -e "${SUCCESS} The rebuild is successful, the current path: [ ${PWD} ]"
}

# Show welcome message
echo -e "${STEPS} Welcome to Rebuild OpenWrt Using the Image Builder."
[[ -x "${0}" ]] || error_msg "Please give the script permission to run: [ chmod +x ${0} ]"
[[ -z "${1}" ]] && error_msg "Please specify the OpenWrt Branch, such as [ ${0} openwrt:22.03.3 ]"
[[ "${1}" =~ ^[a-z]{3,}:[0-9]+ ]] || error_msg "Incoming parameter format <source:branch>: openwrt:22.03.3"
op_sourse="${1%:*}"
op_branch="${1#*:}"
echo -e "${INFO} Rebuild path: [ ${PWD} ]"
echo -e "${INFO} Rebuild Source: [ ${op_sourse} ], Branch: [ ${op_branch} ]"
echo -e "${INFO} Server space usage before starting to compile: \n$(df -hT ${make_path}) \n"
#
# Perform related operations
download_imagebuilder
adjust_settings
custom_packages
custom_config
custom_files
rebuild_firmware
#
# Show server end information
echo -e "Server space usage after compilation: \n$(df -hT ${make_path}) \n"
# All process completed
wait