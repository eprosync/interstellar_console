workspace "Interstellar"
    configurations { "Debug", "Release" }
    platforms { "x86", "x64", "arm", "aarch64" }
    location "build"

local handle = io.popen("vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath")
local vsc = handle:read("*a")
handle:close()

if vsc then
    vsc32 = (vsc:sub(0, -2) .. "\\VC\\Auxiliary\\Build\\vcvars32.bat"):gsub('%W\\:','')
    vsc64 = (vsc:sub(0, -2) .. "\\VC\\Auxiliary\\Build\\vcvars64.bat"):gsub('%W\\:','')
else vsc = "" end

project "Interstellar"
    kind "ConsoleApp"
    language "C++"
    cppdialect "C++20"
    staticruntime "on"

    targetdir ("bin/%{cfg.platform}/%{cfg.buildcfg}")
    objdir ("bin-int/%{cfg.platform}/%{cfg.buildcfg}")

    files { "entry_point.cpp", "**.cpp", "**.hpp", "**.h", "**.lib" }
    includedirs { ".", "luajit/src" }

    filter { "system:linux", "platforms:arm" }
        links { "luajit/src/luajit" }
        prebuildcommands {
            "cd ../luajit/src && make clean && make CC=\"gcc\" BUILDMODE=static LUAJIT_ENABLE_LUA52=0 BUILD_SHARED_LIBS=OFF"
        }

    filter { "system:linux", "platforms:aarch64" }
        links { "luajit/src/luajit" }
        prebuildcommands {
            "cd ../luajit/src && make clean && make CC=\"gcc\" XCFLAGS=\"-DLUAJIT_ENABLE_GC64\" BUILDMODE=static LUAJIT_ENABLE_LUA52=0 BUILD_SHARED_LIBS=OFF"
        }

    filter { "system:linux", "platforms:x86" }
        links { "luajit/src/luajit" }
        prebuildcommands {
            "cd ../luajit/src && make clean && make CC=\"gcc -m32\" BUILDMODE=static LUAJIT_ENABLE_LUA52=0 BUILD_SHARED_LIBS=OFF"
        }

    filter { "system:linux", "platforms:x64" }
        links { "luajit/src/luajit" }
        prebuildcommands {
            "cd ../luajit/src && make clean && make CC=\"gcc -m64\" XCFLAGS=\"-DLUAJIT_ENABLE_GC64\" BUILDMODE=static LUAJIT_ENABLE_LUA52=0 BUILD_SHARED_LIBS=OFF"
        }

    filter { "system:windows", "platforms:arm" }
        links { "luajit/src/lua51" }
        prebuildcommands {
            [[cmd /C "call "]] .. vsc64 .. [[" && cd ..\luajit\src && msvcbuild.bat static x86 )"]]
        }

    filter { "system:windows", "platforms:aarch64" }
        links { "luajit/src/lua51" }
        prebuildcommands {
            [[cmd /C "call "]] .. vsc32 .. [[" && cd ..\luajit\src && msvcbuild.bat gc64 static x64 )"]]
        }

    filter { "system:windows", "platforms:x86" }
        links { "luajit/src/lua51" }
        prebuildcommands {
            [[cmd /C "call "]] .. vsc32 .. [[" && cd ..\luajit\src && msvcbuild.bat static x86 )"]]
        }

    filter { "system:windows", "platforms:x64" }
        links { "luajit/src/lua51" }
        prebuildcommands {
            [[cmd /C "call "]] .. vsc64 .. [[" && cd ..\luajit\src && msvcbuild.bat gc64 static x64 )"]]
        }

    filter "system:windows"
        systemversion "latest"
        flags { "MultiProcessorCompile" }
        runtime "Release"
        buildoptions { "/MT" }

        filter { "system:windows", "platforms:arm" }
            targetname ("interstellar")

        filter { "system:windows", "platforms:aarch64" }
            targetname ("interstellar")

        filter { "system:windows", "platforms:x86" }
            targetname ("interstellar")

        filter { "system:windows", "platforms:x64" }
            targetname ("interstellar")

    filter "system:linux"
        staticruntime "On"
        links {
            "ixwebsocket", "sodium", "cpprest", "llhttp", "cpr", "curl",
            "ssl", "crypto", "zstd", "lzma", "bz2", "z", "fmt", "pthread"
        }

        filter { "system:linux", "platforms:arm" }
            includedirs { (os.getenv("HOME") or "") .. "/vcpkg/installed/arm-linux/include" }
            libdirs { (os.getenv("HOME") or "") .. "/vcpkg/installed/arm-linux/lib" }
            targetname ("interstellar")
            targetprefix ""
    
        filter { "system:linux", "platforms:aarch64" }
            pic "On"
            includedirs { (os.getenv("HOME") or "") .. "/vcpkg/installed/arm64-linux/include" }
            libdirs { (os.getenv("HOME") or "") .. "/vcpkg/installed/arm64-linux/lib" }
            targetname ("interstellar")
            targetprefix ""

        filter { "system:linux", "platforms:x86" }
            includedirs { (os.getenv("HOME") or "") .. "/vcpkg/installed/x86-linux/include" }
            libdirs { (os.getenv("HOME") or "") .. "/vcpkg/installed/x86-linux/lib" }
            targetname ("interstellar")
            targetprefix ""

        filter { "system:linux", "platforms:x64" }
            pic "On"
            includedirs { (os.getenv("HOME") or "") .. "/vcpkg/installed/x64-linux/include" }
            libdirs { (os.getenv("HOME") or "") .. "/vcpkg/installed/x64-linux/lib" }
            targetname ("interstellar")
            targetprefix ""

    filter "platforms:x86"
        architecture "x86"

    filter "platforms:x64"
        architecture "x86_64"

    filter "platforms:arm"
        architecture "arm"

    filter "platforms:aarch64"
        architecture "aarch64"

    filter "configurations:Debug"
        defines { "DEBUG" }
        symbols "On"

    filter "configurations:Release"
        defines { "NDEBUG" }
        optimize "On"

require('vstudio')

premake.override(premake.vstudio.vc2010.elements, "project", function(base, prj)
	local calls = base(prj)
	table.insertafter(calls, premake.vstudio.vc2010.project, function(prj)
        premake.w([[<PropertyGroup Label="Vcpkg" Condition="'$(Configuration)|$(Platform)'=='Debug|Win32'">
    <VcpkgUseStatic>true</VcpkgUseStatic>
  </PropertyGroup>
  <PropertyGroup Label="Vcpkg" Condition="'$(Configuration)|$(Platform)'=='Release|Win32'">
    <VcpkgUseStatic>true</VcpkgUseStatic>
  </PropertyGroup>
  <PropertyGroup Label="Vcpkg" Condition="'$(Configuration)|$(Platform)'=='Debug|x64'">
    <VcpkgUseStatic>true</VcpkgUseStatic>
  </PropertyGroup>
  <PropertyGroup Label="Vcpkg" Condition="'$(Configuration)|$(Platform)'=='Release|x64'">
    <VcpkgUseStatic>true</VcpkgUseStatic>
  </PropertyGroup>]])
    end)
	return calls
end)