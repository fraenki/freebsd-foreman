#!/bin/sh

ORIG_DIR=$PWD
TMP_DIR='/tmp/image'
IMAGE_MD_NO=99
IMAGE_MOUNT_DIR='/mnt/loop'
ROOT_MD_NO=100
ROOT_MOUNT_DIR='/mnt/mfsroot'

cleanup() {
  cd $TMP_DIR
  rm -R ${TMP_DIR}/rw $IMAGE_MOUNT_DIR $ROOT_MOUNT_DIR
}

# handle arguments
while [ ${#} -gt 0 ]; do
  case "${1}" in
  -r)
    if ! echo ${2} | grep -qE '^[0-9]+\.[0-9]+$'; then
      echo "Invalid FreeBSD release specified"
      exit 1
    fi
    RELEASE="$2"
    _tmp=`echo $2 | sed 's/\([0-9]*.[0-9]*\).*/\1/'`
    REL_MAJOR=${_tmp%.[0-9]*}
    REL_MINOR=${_tmp#[0-9]*.}
    shift
    ;;
  esac
  shift 1
done

if [ ! -e "${ORIG_DIR}/rc.local" ]; then
  echo "Custom rc.local not found."
  exit 1
fi

if [ -z "${REL_MAJOR}" -o -z "${REL_MINOR}" ]; then
  echo "Please specify a FreeBSD release."
  exit 1
fi

if [ -e "/dev/md${IMAGE_MD_NO}" -o -e "/dev/md${ROOT_MD_NO}" ]; then
  echo "Configured memory disk is already in use."
  exit 1
fi

# generate source and target filenames
MFSBSD_IMAGE="mfsbsd-${REL_MAJOR}.${REL_MINOR}-RELEASE-amd64.img"
FOREMAN_IMAGE="FreeBSD-x86_64-${REL_MAJOR}.${REL_MINOR}-mfs.img"

# handle changes to image structure in mfsbsd 13.1
if [ 1 -eq "$(echo "${REL_MAJOR}.${REL_MINOR} > 13.0" | bc)" ]; then
  MFSBSD_PART_NUM="p3"
else
  MFSBSD_PART_NUM="p2"
fi

mkdir -p $TMP_DIR
cd $TMP_DIR

# download mfsbsd image
if ! fetch https://mfsbsd.vx.sk/files/images/${REL_MAJOR}/amd64/${MFSBSD_IMAGE}; then
  echo "Failed to download mfsbsd image"
  exit 1
fi

# mount mfsbsd disk image
mkdir -p $IMAGE_MOUNT_DIR $ROOT_MOUNT_DIR
mdconfig -a -t vnode -u $IMAGE_MD_NO -f $MFSBSD_IMAGE
mount /dev/md${IMAGE_MD_NO}${MFSBSD_PART_NUM} $IMAGE_MOUNT_DIR

# mount root filesystem
cd $IMAGE_MOUNT_DIR
cp -p mfsroot.gz $TMP_DIR
cd $TMP_DIR
gzip -d mfsroot.gz
mdconfig -a -t vnode -u $ROOT_MD_NO -f mfsroot
mount /dev/md${ROOT_MD_NO} $ROOT_MOUNT_DIR

# insert rc.local into root filesystem
echo "Customizing image... (please wait)"
cd $ROOT_MOUNT_DIR
cp -p root.txz $TMP_DIR
cd $TMP_DIR
tar Jxf root.txz
cp ${ORIG_DIR}/rc.local rw/etc/rc.local
rm root.txz
tar cfJ root.txz rw
mv root.txz $ROOT_MOUNT_DIR
umount $ROOT_MOUNT_DIR
mdconfig -d -u $ROOT_MD_NO
gzip mfsroot
mv mfsroot.gz $IMAGE_MOUNT_DIR
umount $IMAGE_MOUNT_DIR
mdconfig -d -u $IMAGE_MD_NO

# finally rename to comply with what Foreman expects
mv $MFSBSD_IMAGE $FOREMAN_IMAGE

cleanup
echo "Image stored in ${TMP_DIR}/${FOREMAN_IMAGE}"
exit 0
