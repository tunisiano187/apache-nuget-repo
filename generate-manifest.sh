#!/bin/bash

LOCKFILE="/var/lock/`basename $0`"
LOCKFD=99
_lock() { flock -$1 $LOCKFD; }
_no_more_locking() { _lock u; _lock xn && rm -f $LOCKFILE; }
_prepare_locking() { eval "exec $LOCKFD>\"$LOCKFILE\""; trap _no_more_locking EXIT; }
_prepare_locking
exlock() { _lock x; }
unlock() { _lock u; }

exlock
in_array () {
  local e
  for e in "${@:2}"; do [[ "$e" == "$1" ]] && return 0; done
  return 1
}
cd $( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
package_ids=()
mkdir -p nuspec latest html
rm -f nuspec/*.nuspec latest/*.nuspec html/*.html
for path in nupkg/*.nupkg; do
  file=${path##*/}
  package=${file%.nupkg}
  package_id=$(echo "$package" | sed 's/\.[0-9].*//')
  package_version=$(echo "$package" | sed "s/^$package_id\.//")
  unzip $path "*.nuspec"
  mv "$package_id.nuspec" "nuspec/$package_id.$package_version.nuspec"
  xsltproc xsl/package-html.xslt "nuspec/$package_id.$package_version.nuspec" > html/$package.html
  if ! in_array $package_id "${package_ids[@]}"; then
    package_ids+=($package_id)
  fi
done
xsltproc xsl/packages-manifest.xslt nuspec/*.nuspec | sed ':a;N;$!ba;s/<\/feed>\n<feed[^>]*>\n//g' > Packages
echo > .htaccess
for package_id in "${package_ids[@]}"; do
  latest=$(ls nupkg/$package_id.*.nupkg | sort --version-sort -r | head -1)
  file=${latest##*/}
  package=${file%.nupkg}
  echo "RedirectMatch 302 ^(.*)/api/v2/package/$package_id/?$ $1/$latest" >> .htaccess
  echo "RedirectMatch 302 ^(.*)/packages/$package_id/?$ $1/html/$package.html" >> .htaccess
  package_version=$(echo "$package" | sed "s/^$package_id\.//")
  cp nuspec/$package_id.$package_version.nuspec latest/
done
xsltproc xsl/packages-manifest.xslt latest/*.nuspec | sed ':a;N;$!ba;s/<\/feed>\n<feed[^>]*>\n//g' | xsltproc xsl/packages-html.xslt - > html/index.html
rm -f nuspec/*.nuspec latest/*.nuspec
unlock
