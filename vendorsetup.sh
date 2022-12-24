#!/usr/bin/env bash

DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

# **
echo 'Clearing build info'
# Remove the following intermediate buildinfo.prop file to trigger
# gen_from_buildinfo_sh rule in build/core/sysprop.mk. This will populate
# system/build.prop file with fresh infos when making "dirty" build.
rm -vf out/target/product/munch/obj/PACKAGING/system_build_prop_intermediates/buildinfo.prop

# **

patches_dir=$(pwd)/device/xiaomi/sm8250-common/patches

# **
echo 'Patching frameworks/base'
patch_dir=frameworks/base
patch_name='Patch for MIUICamera in framework base'
cur_commit="$(git -C $patch_dir show -s --format=%s)" || exit $?

# Remove old commit
if [ "$cur_commit" = "$patch_name" ]; then
    git -C $patch_dir reset --hard HEAD^ || exit $?
fi

# Apply and commit patch
git -C $patch_dir apply --verbose $patches_dir/framework_base/*.patch
git -C $patch_dir commit --no-gpg-sign -am "$patch_name"
# **

# **
echo 'Patching frameworks/av'
patch_dir=frameworks/av
patch_name='Patch for MIUICamera in framework av'
cur_commit="$(git -C $patch_dir show -s --format=%s)" || exit $?

# Remove old commit
if [ "$cur_commit" = "$patch_name" ]; then
    git -C $patch_dir reset --hard HEAD^ || exit $?
fi

# Apply and commit patch
git -C $patch_dir apply --verbose $patches_dir/framework_av/*.patch
git -C $patch_dir commit --no-gpg-sign -am "$patch_name"
# **
