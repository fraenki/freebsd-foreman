#!/bin/sh

ORIG_DIR=$PWD
TMP_DIR='/tmp/image'
IMAGE_MD_NO=99
IMAGE_MOUNT_DIR='/mnt/loop'
ROOT_MD_NO=100
ROOT_MOUNT_DIR='/mnt/mfsroot'
CLEANUP=0
MFSBSD_BUILD=0
MFSBSD_DIST_DIR="${TMP_DIR}/dist"
MFSBSD_FILENAME=''
MFSBSD_REPO='https://github.com/mmatuska/mfsbsd.git'
MFSBSD_CLONE_DIR="${TMP_DIR}/mfsbsd"
FREEBSD_MIRROR='https://download.freebsd.org/ftp/releases/amd64'

cleanup() {
  cd $TMP_DIR
  rm -R ${TMP_DIR}/rw $MFSBSD_DIST_DIR $MFSBSD_CLONE_DIR $IMAGE_MOUNT_DIR $ROOT_MOUNT_DIR 2>/dev/null
}

if [ $(id -u) != "0" ]; then
  echo "ERROR: requires root privileges"
  exit 1
fi

# handle arguments
while [ ${#} -gt 0 ]; do
  case "${1}" in
  -b)
    MFSBSD_BUILD=1
    shift
    ;;
  -c)
    CLEANUP=1
    shift
    ;;
  -f)
    if ! test -e ${2}; then
      echo "Specified mfsBSD file not found: ${2}"
      exit 1
    fi
    MFSBSD_FILENAME=$2
    shift
    ;;
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

mkdir -p $TMP_DIR $MFSBSD_DIST_DIR
cd $TMP_DIR

if [ "${CLEANUP}" == 1 ]; then
  echo "Cleaning up..."
  cleanup
  echo "Exiting."
  exit 0
fi

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

# download mfsbsd image
if [ "${MFSBSD_BUILD}" == '0' ]; then
  if [ -z "${MFSBSD_FILENAME}" ]; then
    echo "Downloading mfsBSD image... (please wait)"
    if ! fetch https://mfsbsd.vx.sk/files/images/${REL_MAJOR}/amd64/${MFSBSD_IMAGE}; then
      echo "Failed to download mfsbsd image"
      exit 1
    fi
  else
    # use specified file instead
    MFSBSD_IMAGE=$MFSBSD_FILENAME
  fi
else
  echo "Building mfsBSD image... (please wait)"

  # get distribution files
  for dist in base kernel; do
    if ! fetch -o ${MFSBSD_DIST_DIR}/${dist}.txz ${FREEBSD_MIRROR}/${REL_MAJOR}.${REL_MINOR}-RELEASE/${dist}.txz; then
      echo "Failed to download distribution files"
      exit 1
    fi
  done

  # prepare mfsbsd build
  if [ ! -d "${MFSBSD_CLONE_DIR}" ]; then
    if ! git clone $MFSBSD_REPO $MFSBSD_CLONE_DIR; then
      echo "Failed to clone mfsbsd git repo"
      exit 1
    fi
  fi
  cd $MFSBSD_CLONE_DIR
  for file in conf/*.sample; do
    if ! mv "$file" "${file%.sample}"; then
      echo "Failed to prepare mfsbsd conf files"
      exit 1
    fi
  done

  # build
  make BASE=$MFSBSD_DIST_DIR

  # output file
  for image in ${MFSBSD_CLONE_DIR}/mfsbsd-${REL_MAJOR}.${REL_MINOR}-*.img; do
    echo "Successfully built mfsbsd image: ${image}"
    MFSBSD_IMAGE=$image
    break
  done
  cd $TMP_DIR
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
