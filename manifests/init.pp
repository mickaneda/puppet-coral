class coral(
  $python = "/usr/bin/python3",
  $packages_base = ["wget", "tar", "unzip", "libusb", "libunwind", "libstdc++-static", "gcc", "clang", "cmake3"],
  $packages_python = ["python36-pip", "python36-pillow", "python36-numpy"],
  $install_python = true,
  $wheel = "edgetpu-2.11.1-py3-none-any.whl",
  $usb_owner = "",
  $usb_group = "plugdev",
  $usb_mode = "",
  $usb_idvendor1 = "1a6e",
  $usb_idvendor2 = "18d1",
  $udev_rule_path = "/etc/udev/rules.d/99-edgetpu-accelerator.rules",
  $udevadm_cmd = "/sbin/udevadm",
  $enable_maximum_operating_frequency = false,
  $arch = "x86_64",
  $libedgetpu_path = "/usr/lib64/libedgetpu.so.1.0",
  $libcxxabi_dir_path = "/usr/lib64/",
  $ldconfig_cmd = "/sbin/ldconfig",
){
  if $install_python {
    $packages = $packages_base + $packages_python
  }else{
    $packages = $packages_base
  }

  package{$packages:
    ensure => installed,
  }

  exec {"get_edgetpu_api":
    command => "[ -f /tmp/edgetpu_api/edgetpu-2.11.1-py3-none-any.whl ] || wget https://dl.google.com/coral/edgetpu_api/edgetpu_api_latest.tar.gz -O edgetpu_api.tar.gz --trust-server-names --quiet && tar xzf edgetpu_api.tar.gz",
    cwd => "/tmp/",
    path => "/sbin:/bin:/usr/sbin:/usr/bin",
    require => Package[$packages],
  }

  if $install_python {
    exec {"check_presence":
      command => '/bin/true',
      unless => "${python} -c 'import edgetpu' 1>/dev/null 2>&1",
      notify => [Exec["get_edgetpu_api"], Exec["install_python_edgetpu"]],
    }

    exec {"install_python_edgetpu":
      command => "${python} -m pip install --no-deps ${wheel}",
      cwd => "/tmp/edgetpu_api",
      path => "/sbin:/bin:/usr/sbin:/usr/bin",
      require => Exec["get_edgetpu_api"],
      refreshonly => true,
    }
  }

  file {"edgetpu-accelerator.rules":
    ensure => file,
    path => $udev_rule_path,
    content => template("${module_name}/edgetpu-accelerator.rules.erb"),
    notify => Exec["udevadm"],
  }

  exec {"udevadm":
    command => "${udevadm_cmd} control --reload-rules && ${udevadm_cmd} trigger",
    path => "/sbin:/bin:/usr/sbin:/usr/bin",
    refreshonly => true,
  }

  exec {"llvm":
    command => "wget https://github.com/llvm/llvm-project/archive/master.zip --quiet && unzip -q -o master.zip && cd llvm-project-master &&  mkdir -p build-libcxxabi && cd build-libcxxabi && cmake3 -y -DLIBCXXABI_LIBCXX_PATH=../libcxx ../libcxxabi && make && mv lib/libc++abi* ${libcxxabi_dir_path}",
    path => "/sbin:/bin:/usr/sbin:/usr/bin",
    cwd => "/tmp/",
    creates => "${libcxxabi_dir_path}/libc++abi.so",
  }

  if enable_maximum_operating_frequency {
    $libedgetpu = "libedgetpu_${arch}.so"
  }else{
    $libedgetpu = "libedgetpu_${arch}_throttled.so"
  }

  file {"libedgetpu":
    ensure => file,
    path => $libedgetpu_path,
    source => "/tmp/edgetpu_api/libedgetpu/${libedgetpu}",
    require => Exec["get_edgetpu_api"],
    notify => Exec["ldconfig"],
  }

  exec {"ldconfig":
    command => $ldconfig_cmd,
    path => "/sbin:/bin:/usr/sbin:/usr/bin",
    refreshonly => true,
  }

}
