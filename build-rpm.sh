#!/bin/bash
#
# Script to create an RPM package for hda-jack-retask.fw and configuration.
# Intended for use on systems like Fedora CoreOS or other rpm-ostree based distributions.
# Prerequisites: rpm-build tools (rpmbuild)

# --- Configuration ---
PACKAGE_NAME="hda-jack-retask-config"
VERSION="1.0.0"
RELEASE="1"
ARCH="noarch"
VENDOR="scarf005"
LICENSE="AGPLv3"
SUMMARY="hdajackretask boot override packaged"
DESCRIPTION="""
hdajackretask boot override because /lib/firmware is read-only in immutable distro
"""

# --- Script Directory and Absolute Paths ---
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
SOURCE_DIR="$SCRIPT_DIR/package_files"
BUILD_DIR="$SCRIPT_DIR/rpmbuild"

# --- cleanup ---
rm -rf "$BUILD_DIR"

# --- Create Build Directories ---
mkdir -p "$BUILD_DIR/BUILD" "$BUILD_DIR/RPMS" "$BUILD_DIR/SOURCES" "$BUILD_DIR/SPECS"
SPECS_DIR="$BUILD_DIR/SPECS"
SOURCES_DIR="$BUILD_DIR/SOURCES"
RPMS_DIR="$BUILD_DIR/RPMS"

# --- Verify Source Files Exist ---
# Essential files
if [ ! -f "$SOURCE_DIR/etc/modprobe.d/hda-jack-retask.conf" ] || \
   [ ! -f "$SOURCE_DIR/lib/firmware/hda-jack-retask.fw" ]
    then
    echo "Error: Essential source files not found in $SOURCE_DIR"
    exit 1
fi

# --- Create Source Tarball ---
echo "Creating source tarball..."
TARBALL_NAME="$PACKAGE_NAME-$VERSION.tar.gz"
BUILD_ROOT_FOR_TAR="$BUILD_DIR/TAR_SRC"
SOURCE_IN_TAR_DIR="$BUILD_ROOT_FOR_TAR/$PACKAGE_NAME-$VERSION"

rm -rf "$BUILD_ROOT_FOR_TAR"
mkdir -p "$SOURCE_IN_TAR_DIR"

if ! cp -a "$SOURCE_DIR/." "$SOURCE_IN_TAR_DIR/"; then
    echo "Error: Failed to copy source files to temporary directory $SOURCE_IN_TAR_DIR"
    rm -rf "$BUILD_ROOT_FOR_TAR"
    exit 1
fi

echo "Running tar command: tar -czvf \"$SOURCES_DIR/$TARBALL_NAME\" -C \"$BUILD_ROOT_FOR_TAR\" \"$PACKAGE_NAME-$VERSION\""
if ! tar -czvf "$SOURCES_DIR/$TARBALL_NAME" -C "$BUILD_ROOT_FOR_TAR" "$PACKAGE_NAME-$VERSION"; then
    echo "Error: Failed to create tarball in $SOURCES_DIR"
    rm -rf "$BUILD_ROOT_FOR_TAR"
    exit 1
fi
rm -rf "$BUILD_ROOT_FOR_TAR"
echo "Tarball created at $SOURCES_DIR/$TARBALL_NAME"

# --- Create RPM Spec File ---
SPEC_FILE="$SPECS_DIR/$PACKAGE_NAME.spec"
echo "Creating spec file at $SPEC_FILE..."
cat > "$SPEC_FILE" <<EOF
Name:    $PACKAGE_NAME
Version: $VERSION
Release: $RELEASE%{?dist}
Summary: $SUMMARY
License: $LICENSE
Vendor:  $VENDOR
URL:     https://github.com/scarf005
Source0: %{name}-%{version}.tar.gz
BuildArch: $ARCH

%description
$DESCRIPTION

%define _sysconfdir /etc
%define _libdir /lib

%prep
tar -xzf %{SOURCE0}
cd %{name}-%{version}

%install
install -D -m 0644 %{name}-%{version}/etc/modprobe.d/hda-jack-retask.conf  %{buildroot}%{_sysconfdir}/modprobe.d/hda-jack-retask.conf
install -D -m 0644 %{name}-%{version}/lib/firmware/hda-jack-retask.fw      %{buildroot}%{_libdir}/firmware/hda-jack-retask.fw

%files
%{_sysconfdir}/modprobe.d/hda-jack-retask.conf
%{_libdir}/firmware/hda-jack-retask.fw

%post
echo "hda-jack-retask configuration installed."
echo "A system reboot is required for changes to take full effect on rpm-ostree systems."

%postun
echo "hda-jack-retask configuration removed."
echo "A system reboot may be required to fully revert changes."

%changelog
* $(LANG=C date +"%a %b %d %Y") $VENDOR <greenscarf005@gmail.com> - $VERSION-$RELEASE
- Initial package creation.
EOF

# --- Build the RPM Package ---
echo "Building RPM package..."
if rpmbuild -ba --define "_topdir $BUILD_DIR" "$SPEC_FILE"; then
    RPM_PATH=$(find "$RPMS_DIR/$ARCH/" -name "$PACKAGE_NAME-$VERSION-$RELEASE*.rpm" -print -quit)
    if [ -n "$RPM_PATH" ] && [ -f "$RPM_PATH" ]; then
      echo "--------------------------------------------------"
      echo "RPM package created successfully at:"
      echo "$RPM_PATH"
      echo "--------------------------------------------------"
      echo "You can now install it using:"
      echo "rpm-ostree install \"$RPM_PATH\""
      echo "Remember to reboot after installation."
    else
      echo "RPM build command succeeded, but RPM file not found where expected."
      echo "Searching in $RPMS_DIR/$ARCH/ for $PACKAGE_NAME-$VERSION-$RELEASE*.rpm"
      find "$RPMS_DIR" -name "*.rpm"
      exit 1
    fi
else
  echo "--------------------------------------------------"
  echo "RPM package creation failed."
  echo "Check the output above for errors."
  echo "--------------------------------------------------"
  exit 1
fi

exit 0
