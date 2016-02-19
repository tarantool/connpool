Name: tarantool-connpool
Version: 1.1.0
Release: 1%{?dist}
Summary: net.box connection pool for Tarantool
Group: Applications/Databases
License: BSD
URL: https://github.com/tarantool/connpool
Source0: https://github.com/tarantool/connpool/archive/%{version}/connpool-%{version}.tar.gz
BuildArch: noarch
BuildRequires: tarantool >= 1.6.8.0
Requires: tarantool >= 1.6.8.0

# For tests
%if (0%{?fedora} >= 22)
BuildRequires: python >= 2.7
BuildRequires: python-six >= 1.9.0
BuildRequires: python-gevent >= 1.0
BuildRequires: python-yaml >= 3.0.9
# Temporary for old test-run
# https://github.com/tarantool/connpool/issues/1
BuildRequires: python-daemon
%endif

%description
Lua connection pool for tarantool net.box with network zones support.

%prep
%setup -q -n connpool-%{version}

%check
%if (0%{?fedora} >= 22)
make test
%endif

%install
install -d %{buildroot}%{_datarootdir}/tarantool/
install -m 0644 connpool.lua %{buildroot}%{_datarootdir}/tarantool/

%files
%{_datarootdir}/tarantool/connpool.lua
%doc README.md
%{!?_licensedir:%global license %doc}
%license LICENSE

%changelog
* Fri Feb 19 2016 Roman Tsisyk <roman@tarantool.org> 1.1.0-1
- Initial version of the RPM spec
