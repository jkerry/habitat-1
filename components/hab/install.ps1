param
(
  # Use stable Bintray channel by default
  $channel = 'stable',
  # Set an empty version variable, signaling we want the latest release
  $Filter = '',
  # version to install. defaults to latest
  $version = ''
)

$BT_ROOT="https://api.bintray.com/content/habitat"
$BT_SEARCH="https://api.bintray.com/packages/habitat"
$os = $null
$arch = $null

function MAIN() {
    Write-Host -ForegroundColor Green "Installing Habitat 'hab' program"
    $platform_information = Get-Platform
    $workdir = Create-WorkDir
    $platform = Get-Platform
    $btv = Get-Version -version $version -platform $platform
    Download-Archive -btv $btv -platform $platform -workdir $workdir
    #   verify_archive
    #   extract_archive
    #   install_hab
    #   print_hab_version
    #   info "Installation of Habitat 'hab' program complete."
}

function Create-WorkDir(){
   $workdir = New-TemporaryDirectory
   cd $workdir.FullName
   #TODO:  install.sh has a trap here for cleaning things up
   return $workdir.FullName
}

function New-TemporaryDirectory {
    $parent = [System.IO.Path]::GetTempPath()
    $name = [System.IO.Path]::GetRandomFileName()
    New-Item -ItemType Directory -Path (Join-Path $parent "hab-$name")
}

# print_help() {
#   need_cmd cat
#   need_cmd basename

#   local _cmd
#   _cmd="$(basename "${0}")"
#   cat <<USAGE
# ${_cmd}

# Authors: The Habitat Maintainers <humans@habitat.sh>

# Installs the Habitat 'hab' program.

# USAGE:
#     ${_cmd} [FLAGS]

# FLAGS:
#     -c    Specifies a channel [values: stable, unstable] [default: stable]
#     -h    Prints help information
#     -v    Specifies a version (ex: 0.15.0, 0.15.0/20161222215311)

# ENVIRONMENT VARIABLES:
#      SSL_CERT_FILE   allows you to verify against a custom cert such as one
#                      generated from a corporate firewall

# USAGE
# }

function Get-Platform() {
    $os = $null
    $arch = $null
    if($env:os -ne "Windows_NT"){
        Write-Error "Unsupported OS type.  Expected Windows_NT, got $env:os."
        throw "Unsupported OS"
    }
    else {
        $os = 'windows'
    }
    if($env:PROCESSOR_ARCHITECTURE -eq $null){
        Write-Error "Processor architecture not found."
        throw "Processor architecture not found"
    }
    else {
        $arch_map = @{
            amd64 = "x86_64"
        }
        $arch = $arch_map[$env:PROCESSOR_ARCHITECTURE.ToLower()]
    }
    Write-Host -ForegroundColor Green "The following platform information will be used"
    $platform_information = @{
        sys = $os
        arch = $arch
        ext = "zip"
    }
    Write-Host (ConvertTo-Json $platform_information)
    return $platform_information
}

function Get-Version($version, $platform) {
    $arch = $platform['arch']
    $sys = $platform['sys']
    $_btv = $null
    $_j = $null
    $btv = $null
    if($version){
        Write-Host -ForegroundColor Green "Determining fully qualified version of package for $version"
        Write-Debug "${BT_SEARCH}/${channel}/hab-${arch}-${sys}"
        # TLS 1.2 required for bintray api. Powershell defaults to something lesser
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::TLS12;
        $version_map = Invoke-RestMethod -Method Get "${BT_SEARCH}/${channel}/hab-${arch}-${sys}"
        $fqvn = ($version_map.versions | ?{ $_ -like "*$version*"})
        if($fqvn){
            Write-Host -ForegroundColor Green "Using fully qualified Bintray version string of: $fqvn"
            $btv = $fqvn
        }
        else {
            $_e="Version `"${version}`" could not used or version doesn't exist."
            $_e="$_e Please provide a simple version like: `"0.15.0`""
            $_e="$_e or a fully qualified version like: `"0.15.0/20161222203215`"."
            throw $_e
        }
    }
    else{
        $btv = "%24latest"
    }
    return $btv
}

function Download-Archive($btv, $platform, $workdir) {
    $arch = $platform['arch']
    $sys = $platform['sys']
    $ext = $platform['ext']
    $url="${BT_ROOT}/${channel}/${sys}/${arch}/hab-${btv}-${arch}-${sys}.${ext}"
    $query="?bt_package=hab-${arch}-${sys}"

    $_hab_url="${url}${query}"
    $_sha_url="${url}.sha256sum${query}"
    Write-Debug "bin url: $_hab_url"
    Write-Debug "checksum url: $_sha_url"
    Invoke-WebRequest "${_hab_url}" -OutFile "${workdir}/hab-latest.${ext}"
    Invoke-WebRequest "${_sha_url}" -OutFile "${workdir}/hab-latest.${ext}.sha256sum"
    #   archive="${workdir}/$(cut -d ' ' -f 3 hab-latest.${ext}.sha256sum)"
    #   sha_file="${archive}.sha256sum"

    #   info "Renaming downloaded archive files"
    #   mv -v "${workdir}/hab-latest.${ext}" "${archive}"
    #   mv -v "${workdir}/hab-latest.${ext}.sha256sum" "${archive}.sha256sum"
}

# verify_archive() {
#   if command -v gpg >/dev/null; then
#     info "GnuPG tooling found, verifying the shasum digest is properly signed"
#     local _sha_sig_url="${url}.sha256sum.asc${query}"
#     local _sha_sig_file="${archive}.sha256sum.asc"
#     local _key_url="https://bintray.com/user/downloadSubjectPublicKey?username=habitat"
#     local _key_file="${workdir}/habitat.asc"

#     dl_file "${_sha_sig_url}" "${_sha_sig_file}"
#     dl_file "${_key_url}" "${_key_file}"

#     gpg --no-permission-warning --dearmor "${_key_file}"
#     gpg --no-permission-warning \
#       --keyring "${_key_file}.gpg" --verify "${_sha_sig_file}"
#   fi

#   info "Verifying the shasum digest matches the downloaded archive"
#   ${shasum_cmd} -c "${sha_file}"
# }

# extract_archive() {
#   need_cmd sed

#   info "Extracting ${archive}"
#   case "${ext}" in
#     tar.gz)
#       need_cmd zcat
#       need_cmd tar

#       zcat "${archive}" | tar x -C "${workdir}"
#       archive_dir="$(echo "${archive}" | sed 's/.tar.gz$//')"
#       ;;
#     zip)
#       need_cmd unzip

#       unzip "${archive}" -d "${workdir}"
#       archive_dir="$(echo "${archive}" | sed 's/.zip$//')"
#       ;;
#     *)
#       exit_with "Unrecognized file extension when extracting: ${ext}" 4
#       ;;
#   esac
# }

# install_hab() {
#   case "${sys}" in
#     darwin)
#       need_cmd mkdir
#       need_cmd install

#       info "Installing hab into /usr/local/bin"
#       mkdir -pv /usr/local/bin
#       install -v "${archive_dir}"/hab /usr/local/bin/hab
#       ;;
#     linux)
#       local _ident="core/hab"
#       if [ ! -z "${version-}" ]; then _ident="${_ident}/$version"; fi
#       info "Installing Habitat package using temporarily downloaded hab"
#       # Install hab release using the extracted version and add/update symlink
#       "${archive_dir}/hab" install --channel "$channel" "$_ident"
#       # TODO fn: The updated binlink behavior is to skip targets that already
#       # exist so we want to use the `--force` flag. Unfortunetly, old versions
#       # of `hab` don't have this flag. For now, we'll run with the new flag and
#       # fall back to running the older behavior. This can be removed at a
#       # future date when we no lnger are worrying about Habitat versions 0.33.2
#       # and older. (2017-09-29)
#       "${archive_dir}/hab" pkg binlink "$_ident" hab --force \
#         || "${archive_dir}/hab" pkg binlink "$_ident" hab
#       ;;
#     *)
#       exit_with "Unrecognized sys when installing: ${sys}" 5
#       ;;
#   esac
# }

# print_hab_version() {
#   need_cmd hab

#   info "Checking installed hab version"
#   hab --version
# }

# need_cmd() {
#   if ! command -v "$1" > /dev/null 2>&1; then
#     exit_with "Required command '$1' not found on PATH" 127
#   fi
# }

# info() {
#   echo "--> hab-install: $1"
# }

# warn() {
#   echo "xxx hab-install: $1" >&2
# }

# exit_with() {
#   warn "$1"
#   exit "${2:-10}"
# }

# dl_file() {
#   local _url="${1}"
#   local _dst="${2}"
#   local _code
#   local _wget_extra_args=""
#   local _curl_extra_args=""

#   # Attempt to download with wget, if found. If successful, quick return
#   if command -v wget > /dev/null; then
#     info "Downloading via wget: ${_url}"
#     if [ -n "${SSL_CERT_FILE:-}" ]; then
#       wget ${_wget_extra_args:+"--ca-certificate=${SSL_CERT_FILE}"} -q -O "${_dst}" "${_url}"
#     else
#       wget -q -O "${_dst}" "${_url}"
#     fi
#     _code="$?"
#     if [ $_code -eq 0 ]; then
#       return 0
#     else
#       local _e="wget failed to download file, perhaps wget doesn't have"
#       _e="$_e SSL support and/or no CA certificates are present?"
#       warn "$_e"
#     fi
#   fi

#   # Attempt to download with curl, if found. If successful, quick return
#   if command -v curl > /dev/null; then
#     info "Downloading via curl: ${_url}"
#     if [ -n "${SSL_CERT_FILE:-}" ]; then
#       curl ${_curl_extra_args:+"--cacert ${SSL_CERT_FILE}"} -sSfL "${_url}" -o "${_dst}"
#     else
#       curl -sSfL "${_url}" -o "${_dst}"
#     fi
#     _code="$?"
#     if [ $_code -eq 0 ]; then
#       return 0
#     else
#       local _e="curl failed to download file, perhaps curl doesn't have"
#       _e="$_e SSL support and/or no CA certificates are present?"
#       warn "$_e"
#     fi
#   fi

#   # If we reach this point, wget and curl have failed and we're out of options
#   exit_with "Required: SSL-enabled 'curl' or 'wget' on PATH with" 6
# }

# main "$@" || exit 99

Main