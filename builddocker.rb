require 'docker'
require 'logger'
require 'logger/colors'
require 'erb'

class CI     
    class Build        
        def initialize()
            @image = ''
            @c = ''
           
        end
    end
    def init_logging
        @log = Logger.new(STDERR)

        raise 'Could not initialize logger' if @log.nil?

        Thread.new do
            # :nocov:
            Docker::Event.stream { |event| @log.debug event }        
            # :nocov:
        end
    end    
    attr_accessor :run
    attr_accessor :cmd 
    
    Docker.options[:read_timeout] = 1 * 60 * 60 # 1 hour
    Docker.options[:write_timeout] = 1 * 60 * 60 # 1 hour   
        
    def create_image
        @image = Docker::Image.build_from_dir('.')
    end
        
    def create_container
        init_logging
        @c = Docker::Container.create(
            Image: @image.id, 
            Cmd: @cmd
        ) 
        @log.info 'creating debug thread'
        Thread.new do
            @c.attach do |_stream, chunk|
                puts chunk
                STDOUT.flush
            end
        end
        @c.start
        ret = @c.wait
        status_code = ret.fetch('StatusCode', 1)
        raise "Bad return #{ret}" if status_code != 0
        c.stop!
        c
            #puts @c.streaming_logs(stdout: true)               
    end   
end
class Recipe
    class App
        def initialize(name)
            @name = name                
        end
    end
    
    attr_accessor :name
    attr_accessor :depends
    attr_accessor :dependencies
    attr_accessor :version
    attr_accessor :summary
    attr_accessor :description
    attr_accessor :frameworks
    attr_accessor :apps
        
    def render
        ERB.new(File.read('Recipe.erb')).result(binding)
    end
end

builder = CI.new
builder.run = [CI::Build.new()]
builder.cmd = %w[bash -ex Recipe]
appimage = Recipe.new
appimage.name = "ark"
appimage.version = '16.04.1'
#TO_DO do some LD magic here? kdev-tools cmake parser?
appimage.depends = 'bzip2-devel liblzma-devel'
appimage.frameworks = 'extra-cmake-modules karchive kconfig kwidgetsaddons kcompletion kcoreaddons kauth kcodecs kdoctools kguiaddons ki18n kconfigwidgets kwindowsystem kcrash kdbusaddons kitemviews kiconthemes kjobwidgets kservice solid sonnet ktextwidgets attica kglobalaccel kxmlgui kbookmarks kio knotifications kparts kpty kwayland'
appimage.apps = [Recipe::App.new("#{appimage.name}")]
File.write('Recipe', appimage.render)

#attempt to get deps
# require 'fileutils'
# system("pwd")
# system("ls -l")
# if not File.exists?("#{appimage.name}")
#     system("git clone --depth 1 http://anongit.kde.org/#{appimage.name} #{appimage.name}")
# end
# FileUtils.cp('cmake-dependencies.py', "#{appimage.name}")
# Dir.chdir("#{appimage.name}") do
#     system("cmake \
#     -DCMAKE_INSTALL_PREFIX:PATH=/app/usr/ \
#     -DCMAKE_BUILD_TYPE=RelWithDebInfo \
#     -DPACKAGERS_BUILD=1 \
#     -DBUILD_TESTING=FALSE"
#     )
#     system("make -j8")
#     appimage.dependencies {} = system("python3 cmake-dependencies.py")
# end
# p appimage.dependencies

builder.create_image
builder.create_container