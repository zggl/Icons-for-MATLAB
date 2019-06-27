classdef IconsDev < handle
    % Helps you to build toolbox and deploy it to GitHub
    % By Pavel Roslovets, ETMC Exponenta
    % https://github.com/ETMC-Exponenta/ToolboxExtender
    
    properties
        ext % Toolbox Extender
        vp % project version
    end
    
    methods
        function obj = IconsDev(extender)
            % Init
            if nargin < 1
                obj.ext = IconsExtender;
            else
                if ischar(extender) || isStringScalar(extender)
                    obj.ext = IconsExtender(extender);
                else
                    obj.ext = extender;
                end
            end
            if ~strcmp(obj.ext.root, pwd)
                warning("Project root folder does not math with current folder." +...
                    newline + "Consider to change folder, delete installed toolbox or restart MATLAB")
            end
            obj.gvp();
        end
        
        function vp = gvp(obj)
            % Get project version
            ppath = obj.ext.getppath();
            if isfile(ppath)
                if obj.ext.type == "toolbox"
                    vp = matlab.addons.toolbox.toolboxVersion(ppath);
                else
                    txt = obj.ext.readtxt(ppath);
                    vp = char(regexp(txt, '(?<=(<param.version>))(.*?)(?=(</param.version>))', 'match'));
                end
            else
                vp = '';
            end
            obj.vp = vp;
        end
        
        function build(obj, vp)
            % Build toolbox for specified version
            ppath = obj.ext.getppath();
            obj.gendoc();
            if nargin > 1 && ~isempty(vp)
                obj.setver(vp);
            else
                vp = obj.vp;
            end
            [~, bname] = fileparts(obj.ext.pname);
            bpath = fullfile(obj.ext.root, bname);
            if obj.ext.type == "toolbox"
                obj.updateroot();
                obj.seticons();
                matlab.addons.toolbox.packageToolbox(ppath, bname);
            else
                matlab.apputil.package(ppath);
                movefile(fullfile(obj.ext.root, obj.ext.name + ".mlappinstall"), bpath + ".mlappinstall",'f');
            end
            obj.ext.echo("v" + vp + " has been built");
        end
        
        function test(obj, varargin)
            % Build and install
            obj.build(varargin{:});
            obj.ext.install();
        end
        
        function untag(obj, v)
            % Delete tag from local and remote
            untagcmd1 = sprintf('git push --delete origin v%s', v);
            untagcmd2 = sprintf('git tag -d v%s', v);
            system(untagcmd1);
            system(untagcmd2);
            system('git push --tags');
            obj.ext.echo('has been untagged');
        end
        
        function release(obj, vp)
            % Build toolbox, push and tag version
            if nargin > 1
                obj.vp = vp;
            else
                vp = '';
            end
            if ~isempty(obj.ext.pname)
                obj.build(vp);
            end
            obj.push();
            obj.tag();
            obj.ext.echo('has been deployed');
            if ~isempty(obj.ext.pname)
                clipboard('copy', ['"' char(obj.ext.getbinpath) '"'])
                disp("Binary path was copied to clipboard")
            end
            disp("* Now create release on GitHub *");
            chapters = ["Summary" "Upgrade Steps" "Breaking Changes"...
                "New Features" "Bug Fixes" "Improvements" "Other Changes"];
            chapters = join("# " + chapters, newline);
            fprintf("Release notes hint: fill\n%s\n", chapters);
            disp("! Don't forget to attach binary from clipboard !");
            pause(1)
            web(obj.ext.remote + "/releases/edit/v" + obj.vp, '-browser')
        end
        
        function gendoc(obj)
            % Generate html from mlx doc
            docdir = fullfile(obj.ext.root, 'doc');
            fs = struct2table(dir(fullfile(docdir, '*.mlx')), 'AsArray', true);
            fs = convertvars(fs, 1:3, 'string');
            for i = 1 : height(fs)
                [~, fname] = fileparts(fs.name(i));
                fpath = char(fullfile(fs.folder(i), fs.name{i}));
                htmlpath = char(fullfile(docdir, fname + ".html"));
                htmlinfo = dir(htmlpath);
                convert = isempty(htmlinfo);
                if ~convert
                    fdate = datetime(fs.datenum(i), 'ConvertFrom', 'datenum');
                    htmldate = datetime(htmlinfo.datenum, 'ConvertFrom', 'datenum');
                    convert = fdate >= htmldate;
                end
                if convert
                    fprintf('Converting %s.mlx...\n', fname);
                    matlab.internal.liveeditor.openAndConvert(fpath, htmlpath);
                end
            end
            disp('Docs have been generated');
        end
        
    end
    
    
    methods (Hidden)
        
        function updateroot(obj)
            % Update project root
            service = com.mathworks.toolbox_packaging.services.ToolboxPackagingService;
            configKey = service.openProject(obj.ext.getppath());
            service.removeToolboxRoot(configKey);
            service.setToolboxRoot(configKey, obj.ext.root);
            service.closeProject(configKey);
        end
        
        function setver(obj, vp)
            % Set version
            ppath = obj.ext.getppath();
            if obj.ext.type == "toolbox"
                matlab.addons.toolbox.toolboxVersion(ppath, vp);
            else
                txt = obj.ext.readtxt(ppath);
                txt = regexprep(txt, '(?<=(<param.version>))(.*?)(?=(</param.version>))', vp);
                txt = strrep(txt, '<param.version />', '');
                obj.ext.writetxt(txt, ppath);
            end
            obj.gvp();
        end
        
        function seticons(obj)
            % Set icons of app in toolbox
            xmlfile = 'DesktopToolset.xml';
            oldtxt = '<icon filename="matlab_app_generic_icon_' + string([16; 24]) + '"/>';
            newtxt = '<icon path="./" filename="icon_' + string([16; 24]) + '.png"/>';
            if isfile(xmlfile) && isfolder('resources')
                if all(isfile("resources/icon_" + [16 24] + ".png"))
                    txt = obj.ext.readtxt(xmlfile);
                    if contains(txt, oldtxt)
                        txt = replace(txt, oldtxt, newtxt);
                        obj.ext.writetxt(txt, xmlfile);
                    end
                end
            end
        end
        
        function push(obj)
            % Commit and push project to GitHub
            commitcmd = sprintf('git commit -m v%s', obj.vp);
            system('git add .');
            system(commitcmd);
            system('git push');
            obj.ext.echo('has been pushed');
        end
        
        function tag(obj)
            % Tag git project and push tag
            tagcmd = sprintf('git tag -a v%s -m v%s', obj.vp, obj.vp);
            system(tagcmd);
            system('git push --tags');
            obj.ext.echo('has been tagged');
        end
        
    end
    
end

