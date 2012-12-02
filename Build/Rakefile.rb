#--------------------------------------
# Dependencies
#--------------------------------------
require 'albacore'
require 'version_bumper'
#--------------------------------------
# My environment vars
#--------------------------------------
@env_solutionfolderpath = "../Solution/MvcGitTest/"
@env_projectname = "MvcGitTest"
@env_buildconfigname = "Release"

def env_buildversion
  bumper_version.to_s
end

def env_projectfullname
  "#{@env_projectname}-v#{env_buildversion}-#{@env_buildconfigname}"
end

def env_buildfolderpath
  "Builds/#{env_projectfullname}/"
end
#--------------------------------------
# Albacore flow controlling tasks
#--------------------------------------
desc "Fixes version, compiles the solution, executes tests and deploys."
task :default => [:buildIt]

#desc "Fixes version, compiles the solution, executes tests and deploys."
#task :default => [:buildIt, :testIt, :deployIt]

desc "Fixes version and compiles."
task :buildIt => [:compileIt, :copyBinaries]
#task :buildIt => [:versionIt, :compileIt, :copyBinaries]

#desc "Executes all tests."
#task :testIt => [:runUnitTests]

desc "Creates ZIP and NuGet packages."
task :deployIt => [:createZipPackage, :createNuGetPackage]
#--------------------------------------
# Albacore tasks
#--------------------------------------
desc "Bumpes new version."
task :bumpVersion do
  bumper_version.bump_build
  bumper_version.write('VERSION')
end

desc "Updates version info."
assemblyinfo :versionIt => :bumpVersion do |asm|
  sharedAssemblyInfoPath = "#{@env_solutionfolderpath}SharedAssemblyInfo.cs"
  
  asm.input_file = sharedAssemblyInfoPath
  asm.output_file = sharedAssemblyInfoPath
  asm.version = env_buildversion
  asm.file_version = env_buildversion  
end

desc "Creates clean build folder structure."
task :createCleanBuildFolder do
  FileUtils.rm_rf(env_buildfolderpath)
  FileUtils.mkdir_p("#{env_buildfolderpath}Binaries")
end

desc "Clean and build the solution."
msbuild :compileIt => :createCleanBuildFolder do |msb|
  msb.properties :configuration => @env_buildconfigname
  msb.targets :Clean, :Build
  msb.solution = "#{@env_solutionfolderpath}#{@env_projectname}.sln"
end

desc "Copy binaries to output."
task :copyBinaries do
  FileUtils.cp_r(FileList["#{@env_solutionfolderpath}/#{@env_projectname}/bin/*.*"], "#{env_buildfolderpath}Binaries/")
end

desc "Run unit tests."
nunit :runUnitTests do |nunit|
  nunit.command = "#{@env_solutionfolderpath}packages/NUnit.2.5.10.11092/tools/nunit-console.exe"
  nunit.options "/framework=v4.0.30319","/xml=#{env_buildfolderpath}/NUnit-results-#{@env_projectname}-UnitTests.xml"
  nunit.assemblies = FileList["#{@env_solutionfolderpath}Tests/**/#{@env_buildconfigname}/*.UnitTests.dll"].exclude(/obj\//)
end

desc "Creates ZIPs package of binaries folder."
zip :createZipPackage do |zip|
     zip.directories_to_zip "#{env_buildfolderpath}Binaries/"
     zip.output_file = "../#{env_projectfullname}.zip"
end

desc "Creates NuGet package"
exec :createNuGetPackage do |cmd|
  cmd.command = "NuGet.exe"
  cmd.parameters = "pack #{@env_projectname}.nuspec -version #{env_buildversion} -nodefaultexcludes -outputdirectory #{env_buildfolderpath} -basepath #{env_buildfolderpath}\Binaries"
end