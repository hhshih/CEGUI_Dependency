if (not _ACTION) then return end
    
-- load preset for extending premake functionalities
dofile("preset.lua")

-- load modules
local extension = require "extension"

-- get build path
local homedir = path.getabsolute("../") .. "/"
local env = extension.safeload(homedir .. "buildconfig.lua")
local paths = env.paths
local additional_paths = env.additional_paths

-- process path names
local function prefix_string(prefix, t)
    for k, v in pairs(t) do
        if (type(v) == "string") then
            t[k] = homedir .. v .. '/'
        else
            prefix_string(prefix, v)
        end
    end
end

prefix_string(homedir, paths)

-- set up variables for the future configuration

local main_name = "DaEngineDemo"

local alllinks = {"dbghelp.lib","DXGUID","FW1FontWrapper","AntTweakBar", "Xinput9_1_0","fmod", "fmodstudio", "lua51", "zlib", "lua_tinker", "DirectXTK", "dxgi.lib", "d3d11.lib", "d3dcompiler"}
local specificReleaseLinks = { "CEGUIBase-0.lib", "CEGUIDirect3D11Renderer-0.lib" }
local specificDebugLinks   = { "CEGUIBase-0_d.lib", "CEGUIDirect3D11Renderer-0_d.lib" }

local unittest_files = 
    { 
        paths.src .. "precompiled.cpp",
        paths.include .. "precompiled.h",
    }

local project_files = 
    { 
        paths.src .. "precompiled.cpp",
        paths.include .. "precompiled.h",
        paths.include .. "**.h", 
        paths.include .. "**.hpp", 
        paths.src     .. "**.cpp",
        paths.asset .. "**.hlsl"
    }

function common_project_setup(app_kind, project_type)
    -- default app_kind windowedapp
    if not app_kind then
        app_kind = "WindowedApp"
    end

    -- default project_type Project
    if not project_type then
        project_type = "Project"
    end

    -- if windowed app, use winmain as entry point
    if app_kind ~= "StaticLib" and app_kind == "WindowedApp" then
        flags "WinMain"
    end

    -- if static lib, do not compile main.cpp
    if app_kind == "StaticLib" then
        excludes "**/main.cpp"
    end

    -- use files based on project type
    local allfiles
    if project_type ~= "Unittest" or not project_type then
        allfiles = project_files
    else
        allfiles = unittest_files
    end

    -- start project settings
    links (alllinks)

    pchheader "precompiled.h"
    pchsource (paths.src .. "precompiled.cpp")

    files (allfiles)

    includedirs 
    {
        paths.include, 
        paths.dependency,
    }
    includedirs(additional_paths.include)

    libdirs 
    {
        paths.dependency .. "*",
    }
    libdirs(additional_paths.lib)

    flags 
    {
        "Unicode", 
        "EnableSSE",
        "EnableSSE2",
        "NoMinimalRebuild",
        "FloatFast"
    }

    defines "_CRT_SECURE_NO_WARNINGS"
    warnings "Extra"

    buildoptions
    {
        "/wd4100",
        "/wd4505",
        "/wd4290",
        "/MP",
    }

    linkoptions
    {
        "/ignore:4221"
    }
end


-- setup configuration specific settings
-- this function will leave with certain configuration filters on!
-- Do not do project-wise thing after this, or it will only be applied to configurations
function common_configuration_setup(app_kind)
    -- configuration sepcific settings
    configuration "*Lib"
       kind "StaticLib"

    configuration "*Dll"
       kind "SharedLib"

    configuration "Release*"
       kind (app_kind)
       defines { "NDEBUG" }
       optimize "Full"
       flags 
       { 
           'LinkTimeOptimization', 
           'Symbols'
       }

       -- favor speed
       buildoptions "/Os"
       
       libdirs
       {
           paths.dependency .. "**/lib/Release"
       }

    configuration "Debug*"
       defines 
       { 
           "_DEBUG", 
           "DEBUG" 
       }
       flags { "Symbols" }
       optimize "Off"
       
       libdirs
       {
           paths.dependency .. "**/lib/Debug"
       }

    configuration "Debug"
       kind (app_kind)

       links (specificDebugLinks)
       
       if (app_kind == "WindowedApp") then
           linkoptions { "/ENTRY:WinMainCRTStartup" }
       end

    configuration "Release"
       kind (app_kind)
       
       links (specificReleaseLinks)
       
       if (app_kind == "WindowedApp") then
           linkoptions { "/ENTRY:WinMainCRTStartup" }
       end


    for _, config in ipairs(configurations()) do
       configuration(config)
       targetdir (paths.bin .. _ACTION .. "/" .. config)
       objdir (paths.obj .. _ACTION )
    end

    configuration ""
	
end



-- A solution contains projects, and defines the available configurations
-- Besides DaEngineDemo, a project will be created for each unittest main
solution "DaEngine"
    configurations { "Debug", "Release"}
    location ("../build/" .. _ACTION)
    defines {"_WINDOWS", "WIN32"}
    language "C++"

    -- A project defines one build target
    project (main_name)
       common_project_setup("WindowedApp")

       postbuildcommands
       {
                'copy "$(VC_ExecutablePath_x86_ARM)\\D3DCompiler_47.dll" "../../bin/vs2013/$(configuration)" && powershell /command "Get-ChildItem -Path ../../dependency -Filter $(configuration) -Recurse | gci -Filter *.dll -Recurse | copy-item -Destination \\\"$(targetdir)\\\""'
       }

       common_configuration_setup("WindowedApp")
       targetname (main_name)

       
    -- A project defines one build target
    project (main_name .. "Lib")
       common_project_setup("StaticLib")
       common_configuration_setup("StaticLib")
       targetname (main_name)

    -- set up project for unit test
    local unittest_dir = extension.scandir(paths.unittest);
    for i, dir_name in ipairs(unittest_dir) do
        local prefixed_name = "UT_" .. dir_name
        local ut_dir = paths.unittest .. dir_name .. "/"
        project (prefixed_name)
           targetname (prefixed_name)

           common_project_setup("ConsoleApp", "Unittest")
           links {main_name .. "Lib"}

           postbuildcommands
           {
                    'powershell /command "Get-ChildItem -Path ../../dependency -Filter $(configuration) -Recurse | gci -Filter *.dll -Recurse | copy-item -Destination \\\"$(targetdir)\\\""'
           }

           files
           {
               ut_dir .. "**.h",
               ut_dir .. "**.hpp",
               ut_dir .. "**.cpp"
           }

           common_configuration_setup("ConsoleApp")

           -- for each configuration, link to corresponding main library
           for _, config in ipairs(configurations()) do
              configuration(config)
              linkoptions ("/LIBPATH:" .. paths.bin .. _ACTION .. "/" .. config)
           end
    end

