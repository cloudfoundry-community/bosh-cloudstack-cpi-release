JAVA_VERSION=jdk1.8.0_102
JAVA_TAR_BALL=openjdk.tar.gz

cd ${BUILD_DIR}

tar zxfv ${BUILD_DIR}/openjdk/${JAVA_TAR_BALL}

if [ -z "$java_home" ]; then
	export cleanup_java="1"
	export java_home=${BUILD_DIR}/${JAVA_VERSION}
fi
echo $java_home


cleanup_java() {
  if [ -n "$cleanup_java" ]; then
  	rm -rf ${java_home}
  fi
  rm -rf ${BUILD_DIR}/openjdk
  rm -rf ${BUILD_DIR}/target
  rm -rf ${BUILD_DIR}/common
}
