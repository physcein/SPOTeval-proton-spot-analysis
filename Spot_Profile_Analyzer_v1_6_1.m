% Program Name: Proton Spot Profile Evaluation (SPOTeval) Tool
% Author: Tae Kyu Lee, Ph.D.
%
% This code was written in Matlab version R2021b.
% This matlab code utilizes the measurements from Film or
% Optical Dosimeter System (ODS) developed by Wen Hsi, Ph.D., and analyzes with
% FWHM, Sigma, Penumbra, Symmetry, spot angle deviation, and gamma index.

function Spot_Profile_Analyzer_v1_6_1(varargin)
clear all;
clc;
% Subroutine that display initial folder information

% Define properties and set default values.
prop.filterspec = '*.CR2';
prop.refilter = '';
prop.prompt = 'Spot Profile Evaluator (SPOTeval) V.1.6.2 - Format: E000Z000NETS000 in MeV, cm & mm';
prop.output = 'cell';
prop.numfiles = [];

% Process inputs and set prop fields.
properties = fieldnames(prop);
arg_index = 1;
while arg_index <= nargin
    arg = varargin{arg_index};
    if ischar(arg)
        prop_index = find(strncmpi(arg,properties,length(arg)));
        if length(prop_index) == 1
            prop.(properties{prop_index}) = varargin{arg_index + 1};
        else
            error('Property ''%s'' does not exist or is ambiguous.',arg)
        end
        arg_index = arg_index + 2;
    elseif isstruct(arg)
        arg_fn = fieldnames(arg);
        for i = 1:length(arg_fn)
            prop_index = find(strncmpi(arg_fn{i},properties,...
                length(arg_fn{i})));
            if length(prop_index) == 1
                prop.(properties{prop_index}) = arg.(arg_fn{i});
            else
                error('Property ''%s'' does not exist or is ambiguous.',...
                    arg_fn{i})
            end
        end
        arg_index = arg_index + 1;
    else
        error(['Properties must be specified by property/value pairs',...
            ' or structures.'])
    end
end

% Validate FilterSpec property.
if isempty(prop.filterspec)
    prop.filterspec = '*';
end
if ~ischar(prop.filterspec)
    error('FilterSpec property must contain a string.')
end

% Validate REFilter property.
if ~ischar(prop.refilter)
    error('REFilter property must contain a string.')
end

% Validate Prompt property.
if ~ischar(prop.prompt)
    error('Prompt property must contain a string.')
end

% Validate NumFiles property.
if numel(prop.numfiles) > 2 || any(prop.numfiles < 0)
    error('NumFiles must be empty, a scalar or two-element vector.')
end
prop.numfiles = unique(prop.numfiles);
if isequal(prop.numfiles,1)
    numstr = 'Select exactly 1 file.';
elseif length(prop.numfiles) == 1
    numstr = sprintf('Select exactly %d files.',prop.numfiles);
else
    numstr = sprintf('Select %d to %d files.',prop.numfiles);
end

% Validate Output property.
legal_outputs = {'cell','struct','char'};
out_idx = find(strncmpi(prop.output,legal_outputs,length(prop.output)));
if length(out_idx) == 1
    prop.output = legal_outputs{out_idx};
else
    error(['Value of ''Output'' property, ''%s'', is illegal or '...
        'ambiguous.'],prop.output)
end

% Initialize file lists.
[current_dir,f,e] = fileparts(prop.filterspec);
filter = [f,e];

if isempty(current_dir)
    current_dir = pwd;
end
if isempty(filter)
    filter = '*';
end
re_filter = prop.refilter;
full_filter = fullfile(current_dir,filter);
path_cell = path2cell(current_dir);
full_filter=sprintf('%s*',full_filter);
fdir = filtered_dir(full_filter,re_filter);
filenames = {fdir.name}';
filenames = annotate_file_names(filenames,fdir);

% Initialize some data.
file_picks = {};
full_file_picks = {};
dir_picks = struct('name',{},'date','','bytes',[],'isdir',[]);
show_full_path = false;
nodupes = true;
history = {current_dir};

% Create figure.
gray = get(0,'DefaultUIControlBackgroundColor');

% global bkgdname Energy NET ZPOS MUd TRN0 datestrs

global Dt txt2 fn bkgdname bkgdpwd xx1 xx xxx Dtcropx Dtcrop_b...
    xx2 yy yyy Dtcropy  Dtcrop_a pos0 scsx scsy...
    FWHM_X FWHM_Y Sigma_X SigmaX_Fit Sigma_Y SigmaY_Fit fsize textg...
    TRN0 option Dtcrop a b datestrs Energy NET ZPOS MUd...
    Dtcropxx Dtcropyy Dtcrop_ Dtcmax Dtcrop_o voxx voxy...
    xl80 xr80 xl20 xr20 xxl80 xxr80 xxl20 xxr20...
    fig_dev up_new up1_new up2_new TwoD_new TwoD1_new...
    ang_new ang1_new rot sl_new ROIx1 ROIx2 ROIy1 ROIy2 W2CADD...
    DTA dosed

DTA=0.001;dosed=0.01;

M=-5;

scs = get(0,'ScreenSize');

scsx=scs(3)/1920;
scsy=scs(4)/1080;

fig = figure('Position',[0 0 1200*scsx 870*scsy],...
    'Color',gray,...
    'Resize','off',...
    'NumberTitle','off',...
    'Name',prop.prompt,...
    'IntegerHandle','off',...
    'CloseRequestFcn',@cancel,...
    'CreateFcn',{@movegui,'center'});

% th = uitoolbar(fig,'Visible','on')
set(fig,'Toolbar','figure');
% set(fig,'Menubar','figure');


% movegui(fig,'center');

% Create uicontrols.

% File menu
Fil=uimenu(gcf,'Label','File');
uimenu(Fil,'Label','Open Measurement File','Callback',@FileOpen);
%     uimenu(Fil,'Label','Save','Callback','save');
uimenu(Fil,'Label','Quit Profile_Analyzer','Callback',@QuitW,...
    'Separator','on','Accelerator','Q');
Help=uimenu(gcf,'Label','Help');
uimenu(Help,'Label','About Profile_Analyzer v.1.3',...
    'Callback',@About_Profile_Analyzer);
MM=0;

up0=uipanel('Units','pixels',...
    'BackgroundColor','w',...
    'BorderType','etchedout',...
    'Position',[10*scsx 378*scsy 200*scsx 81*scsy]);
uicontrol('Parent',up0,'Units','pixels',...
    'Position',[5*scsx 60*scsy 110*scsx 16*scsy],...
    'BackgroundColor','w',...
    'Style','text',...
    'String','File Extension:',...
    'FontName','MS Sans Serif',...
    'FontSize',9*scsx*1.02,...
    'FontWeight','bold',...
    'HorizontalAlignment','left')
filter_ed = uicontrol('Parent',up0,'Units','pixels',...
    'Position',[90*scsx 55*scsy 100*scsx 20*scsy],...
    'Style','edit',...
    'BackgroundColor',[1 1 .7],...
    'String',filter,...
    'FontName','MS Sans Serif',...
    'FontSize',8*scsx*1.02,...
    'FontWeight','bold',...
    'ForegroundColor',[0 0 0],...
    'HorizontalAlignment','center',...
    'Callback',@setfilspec);
showallfiles = uicontrol('Parent',up0,'Units','pixels',...
    'Position',[40*scsx 25*scsy 120*scsx 30*scsy],...
    'BackgroundColor','w',...
    'Style','checkbox',...
    'String','Show All Files',...
    'FontName','MS Sans Serif',...
    'FontSize',9*scsx*1.02,...
    'FontWeight','bold',...
    'Value',0,...
    'HorizontalAlignment','left',...
    'Callback',@togglefilter);
uicontrol('Parent',up0,'Units','pixels',...
    'Position',[5*scsx 2*scsy 110*scsx 20*scsy],...
    'BackgroundColor','w',...
    'Style','text',...
    'String','Change Folder',...
    'FontName','MS Sans Serif',...
    'FontSize',9*scsx*1.02,...
    'FontWeight','bold',...
    'HorizontalAlignment','left')
dir_popup = uicontrol('Parent',up0,'Units','pixels',...
    'Style','popupmenu',...
    'Position',[90*scsx -5*scsy 100*scsx 30*scsy],...
    'BackgroundColor',[1 1 .7],...
    'String',path_cell(end:-1:1),...
    'FontName','MS Sans Serif',...
    'FontSize',8*scsx*1.02,...
    'FontWeight','bold',...
    'Value',1,...
    'Callback',@dirpopup);

up=uipanel('Units','pixels',...
    'BackgroundColor','w',...
    'BorderType','etchedout',...
    'Position',[10*scsx (355+M)*scsy 200*scsx 25*scsy]);
uicontrol('parent',up,'Position',[5*scsx 2*scsy 180*scsx 16*scsy],...
    'BackgroundColor','w',...
    'Style','text',...
    'String','Current Folder',...
    'FontName','MS Sans Serif',...
    'FontWeight','bold',...
    'FontSize',10*scsx*1.02,...
    'HorizontalAlignment','center')

hist_cm = uicontextmenu;
pathbox = uicontrol('Position',[10*scsx (326+M)*scsy 200*scsx 25*scsy],...
    'Style','edit',...
    'BackgroundColor','w',...
    'String',current_dir,...
    'FontName','MS Sans Serif',...
    'FontSize',8*scsx*1.02,...
    'FontWeight','demi',...
    'HorizontalAlignment','left',...
    'Callback',@change_path,...
    'UIContextMenu',hist_cm);
hist_menus = [];
hist_cb = @history_cb;
hist_menus = make_history_cm(hist_cb,hist_cm,hist_menus,history);

navlist = uicontrol('Style','listbox',...
    'Position',[10*scsx (62+M+MM)*scsy 200*scsx 260*scsy],...
    'String',filenames,...
    'FontName','MS Sans Serif',...
    'FontSize',8*scsx*1.02,...
    'FontWeight','demi',...
    'Value',[],...
    'BackgroundColor','w',...
    'Callback',@clicknav,...
    'Max',2);

up1=uipanel('Units','pixels',...
    'BackgroundColor','w',...
    'BorderType','etchedout',...
    'Position',[10*scsx (15+M)*scsy 200*scsx 40*scsy]);
uicontrol('Parent',up1,...
    'Units','pixels',...
    'Position',[7*scsx 5*scsy 90*scsx 27*scsy],'String','Evaluate!',...
    'BackgroundColor',gray,...%[.5 .8 .5],...
    'FontName','MS Sans Serif',...
    'FontSize',10*scsx,...
    'FontWeight','bold',...
    'Callback',@done);
uicontrol('Parent',up1,...
    'Position',[102*scsx 5*scsy 90*scsx 27*scsy],'String','Close',...
    'BackgroundColor',gray,...%[.5 .8 .5],...
    'FontName','MS Sans Serif',...
    'FontWeight','bold',...
    'FontSize',10*scsx,...
    'Callback',@cancel);

% bkgd=[0 0 0]/255;

%% Up2
up2=uipanel('Units','pixels',...
    'Position',[10*scsx 660*scsy 200*scsx 160*scsy],...
    'BorderType','line',...
    'BorderType','etchedout',...
    'TitlePosition','lefttop','Title','Global Variables');
uicontrol('Parent',up2,'Units','pixels',...
    'Position',[5*scsx 120*scsy 85*scsx 20*scsy],...
    'Style','text',...
    'String','Radiation',...
    'FontName','MS Sans Serif',...
    'FontSize',10*scsx,...
    'FontWeight','bold',...
    'HorizontalAlignment','Left')
uicontrol('Parent',up2,'Units','pixels',...
    'Position',[5*scsx 100*scsy 85*scsx 20*scsy],...
    'Style','text',...
    'String','Background',...
    'FontName','MS Sans Serif',...
    'FontSize',10*scsx,...
    'FontWeight','bold',...
    'HorizontalAlignment','Left')
uicontrol('Parent',up2,...
    'Units','pixels',...
    'Position',[95*scsx 110*scsy 100*scsx 27*scsy],'String','Set Background',...
    'BackgroundColor',gray,...
    'FontName','MS Sans Serif',...
    'FontSize',9*scsx*1.02,...
    'FontWeight','bold',...
    'Callback',@bkgd);
txt2=uicontrol('Parent',up2,'Units','pixels',...
    'Position',[100*scsx 85*scsy 90*scsx 20*scsy],...
    'FontSize',9*scsx*1.02,...
    'ForegroundColor','r',...
    'Style','text',...
    'HorizontalAlignment','left',...
    'String',sprintf('%s','Not Set'),...
    'Callback',{@bkgd});
uicontrol('Parent',up2,'Units','pixels',...
    'Position',[5*scsx 70*scsy 85*scsx 20*scsy],...
    'Style','text',...
    'String','Pixel Scaling',...
    'FontName','MS Sans Serif',...
    'FontSize',10*scsx,...
    'FontWeight','bold',...
    'HorizontalAlignment','Left')
uicontrol('Parent',up2,'Units','pixels',...
    'Position',[5*scsx 50*scsy 80*scsx 20*scsy],...
    'Style','text',...
    'String',sprintf('%s','1 Pixel (x,y) = '),...
    'FontName','MS Sans Serif',...
    'FontSize',9*scsx,...
    'HorizontalAlignment','Left')
voxx=(16/1851.30+12/1390.83+8/930.21)/3;
voxy=(16/1904.12+12/1434.91+8/953.20)/3;
uicontrol('Parent',up2,'Units','pixels',...
    'Position',[80*scsx 54*scsy 100*scsx 16*scsy],...
    'Style','text',...
    'String',sprintf('%s%3.4f%s%3.4f%s','(',voxx,',',voxy,')' ),...
    'FontName','MS Sans Serif',...
    'FontSize',9*scsx,...
    'ForegroundColor','r',...
    'HorizontalAlignment','Left',...
    'Callback',{@scal2});
uicontrol('Parent',up2,'Units','pixels',...
    'Position',[167*scsx 55*scsy 30*scsx 15*scsy],...
    'Style','text',...
    'String',sprintf('%s',' cm'),...
    'FontName','MS Sans Serif',...
    'FontSize',9*scsx,...
    'HorizontalAlignment','Left',...
    'Callback',@scal2);

uicontrol('Parent',up2,'Units','pixels',...
    'Position',[5*scsx 30*scsy 80*scsx 20*scsy],...
    'Style','text',...
    'String',sprintf('%s','Pixel (x) = '),...
    'FontName','MS Sans Serif',...
    'FontSize',9*scsx,...
    'HorizontalAlignment','Left')
uicontrol('Parent',up2,'Units','pixels',...
    'Position',[62*scsx 30*scsy 60*scsx 20*scsy],...
    'BackgroundColor',[1 1 .7],...
    'FontSize',9*scsx*1.02,...
    'ForegroundColor','r',...
    'Style','edit',...
    'HorizontalAlignment','left',...
    'String',sprintf('%s',''),...
    'Callback',{@scal1x});
uicontrol('Parent',up2,...
    'Units','pixels',...
    'Position',[125*scsx 27*scsy 60*scsx 27*scsy],'String','Apply',...
    'BackgroundColor',gray,...%[.5 .8 .5],...
    'FontName','MS Sans Serif',...
    'FontSize',9*scsx*1.02,...
    'FontWeight','bold',...
    'Callback',@scal2);

uicontrol('Parent',up2,'Units','pixels',...
    'Position',[5*scsx 3*scsy 80*scsx 20*scsy],...
    'Style','text',...
    'String',sprintf('%s','Pixel (y) = '),...
    'FontName','MS Sans Serif',...
    'FontSize',9*scsx,...
    'HorizontalAlignment','Left')
uicontrol('Parent',up2,'Units','pixels',...
    'Position',[62*scsx 3*scsy 60*scsx 20*scsy],...
    'BackgroundColor',[1 1 .7],...
    'FontSize',9*scsx*1.02,...
    'ForegroundColor','r',...
    'Style','edit',...
    'HorizontalAlignment','left',...
    'String',sprintf('%s',''),...
    'Callback',{@scal1y});
uicontrol('Parent',up2,...
    'Units','pixels',...
    'Position',[125*scsx 0*scsy 60*scsx 27*scsy],'String','Apply',...
    'BackgroundColor',gray,...%[.5 .8 .5],...
    'FontName','MS Sans Serif',...
    'FontSize',9*scsx*1.02,...
    'FontWeight','bold',...
    'Callback',@scal2);

%% Up23
up23=uipanel('Units','pixels',...
    'BackgroundColor','y',...
    'BorderType','etchedout',...
    'Position',[10*scsx 633*scsy 200*scsx 24*scsy]);
txt21=uicontrol('Parent',up23,'Units','pixels',...
    'Position',[5*scsx 3*scsy 190*scsx 16*scsy],...
    'BackgroundColor','y',...
    'Style','text',...
    'String','Select Measurement Type',...
    'FontName','MS Sans Serif',...
    'FontSize',10*scsx*1.02,...
    'FontWeight','bold',...
    'HorizontalAlignment','center');
% txt22=uicontrol('Parent',up23,'Units','pixels',...
%     'Position',[5 2 190 20],...
%     'BackgroundColor','w',...
%     'Style','text',...
%     'String','',...
%     'FontName','MS Sans Serif',...
%     'FontSize',9*scsx*1.02,...
%     'FontWeight','bold',...
%     'HorizontalAlignment','center');

%% Up24
up24=uibuttongroup('Units','pixels',...
    'BackgroundColor','w',...
    'BorderType','etchedout',...
    'Position',[10*scsx 576*scsy 200*scsx 55*scsy]);
uicontrol('Parent',up24,'Units','pixels',...
    'Position',[5*scsx 30*scsy 190*scsx 20*scsy],...
    'BackgroundColor','w',...
    'Style','radiobutton',...
    'String','Film',...
    'FontName','MS Sans Serif',...
    'FontSize',9*scsx*1.02,...
    'FontWeight','bold',...
    'HorizontalAlignment','left');
uicontrol('Parent',up24,'Units','pixels',...
    'Position',[5*scsx 5*scsy 190*scsx 20*scsy],...
    'BackgroundColor','w',...
    'Style','radiobutton',...
    'String','Optical Dosimeter System',...
    'FontName','MS Sans Serif',...
    'FontSize',9*scsx*1.02,...
    'FontWeight','bold',...
    'HorizontalAlignment','left');
set(up24,'SelectionChangeFcn',@selchk);
set(up24,'SelectedObject',[]);  % No selection
set(up24,'Visible','on');

%% Up25
up25_0=uipanel('Units','pixels',...
    'BackgroundColor','y',...
    'BorderType','etchedout',...
    'Position',[10*scsx 549*scsy 200*scsx 24*scsy]);
txt21_0=uicontrol('Parent',up25_0,'Units','pixels',...
    'Position',[5*scsx 2*scsy 190*scsx 16*scsy],...
    'BackgroundColor','y',...
    'Style','text',...
    'String','Select Gaussian Fit',...
    'FontName','MS Sans Serif',...
    'FontSize',10*scsx*1.02,...
    'FontWeight','bold',...
    'HorizontalAlignment','center');
up25=uibuttongroup('Units','pixels',...
    'BackgroundColor','w',...
    'BorderType','etchedout',...
    'Position',[10*scsx 492*scsy 200*scsx 55*scsy]);
uicontrol('Parent',up25,'Units','pixels',...
    'Position',[5*scsx 30*scsy 190*scsx 20*scsy],...
    'BackgroundColor','w',...
    'Style','radiobutton',...
    'String','Single Gaussin Fit',...
    'FontName','MS Sans Serif',...
    'FontSize',9*scsx*1.02,...
    'FontWeight','bold',...
    'HorizontalAlignment','left');
uicontrol('Parent',up25,'Units','pixels',...
    'Position',[5*scsx 5*scsy 190*scsx 20*scsy],...
    'BackgroundColor','w',...
    'Style','radiobutton',...
    'String','Double Gaussin Fit',...
    'FontName','MS Sans Serif',...
    'FontSize',9*scsx*1.02,...
    'FontWeight','bold',...
    'HorizontalAlignment','left');
set(up25,'SelectionChangeFcn',@selchk1);
set(up25,'SelectedObject',[]);  % No selection
set(up25,'Visible','on');

%% Up26
up26=uibuttongroup('Units','pixels',...
    'BackgroundColor','w',...
    'BorderType','etchedout',...
    'Position',[10*scsx 462*scsy 200*scsx 27*scsy]);
% uicontrol('Parent',up26,...
%     'Units','pixels',...
%     'Position',[1*scsx 0*scsy 200*scsx 27*scsy],'String','Create W2CAD File',...
%     'BackgroundColor',gray,...%[.5 .8 .5],...
%     'FontName','MS Sans Serif',...
%     'FontSize',9*scsx*1.02,...
%     'FontWeight','bold',...
%     'Callback',@W2CAD);
uicontrol('Parent',up26,'Units','pixels',...
    'Position',[5*scsx 0*scsy 120*scsx 18*scsy],...
    'BackgroundColor','w',...
    'Style','text',...
    'String','Create W2CAD File',...
    'FontName','MS Sans Serif',...
    'FontSize',9*scsx*1.02,...
    'FontWeight','bold',...
    'Value',0,...
    'HorizontalAlignment','left');

Yes=uicontrol('Parent',up26,'Units','pixels',...
    'Position',[115*scsx 2*scsy 40*scsx 20*scsy],...
    'BackgroundColor','w',...
    'Style','radiobutton',...
    'String','Yes',...
    'FontName','MS Sans Serif',...
    'FontSize',8*scsx*1.02,...
    'FontWeight','bold',...
    'HorizontalAlignment','left');
No=uicontrol('Parent',up26,'Units','pixels',...
    'Position',[158*scsx 2*scsy 35*scsx 20*scsy],...
    'BackgroundColor','w',...
    'Style','radiobutton',...
    'String','No',...
    'FontName','MS Sans Serif',...
    'FontSize',8*scsx*1.02,...
    'FontWeight','bold',...
    'HorizontalAlignment','left');
set(up26,'SelectionChangeFcn',@W2CAD);
set(up26,'SelectedObject',No);  % No selection
set(up26,'Visible','on');



%% Up3
up3=uipanel('Units','pixels',...
    'Position',[220*scsx 491*scsy 200*scsx 329*scsy],...
    'BorderType','line',...
    'BorderType','etchedout',...
    'TitlePosition','lefttop','Title','Profile Characteristics');
MM=290;MMM=29;
En=uicontrol('Parent',up3,'Units','pixels',...
    'Position',[5*scsx MM*scsy 160*scsx 20*scsy],...
    'Style','text',...
    'String',sprintf('%s%s%s','Energy =  ','...','  MeV'),...
    'FontName','MS Sans Serif',...
    'FontSize',9*scsx*1.02,...
    'HorizontalAlignment','Left');
Zp=uicontrol('Parent',up3,'Units','pixels',...
    'Position',[5*scsx (MM-MMM*1)*scsy 160*scsx 20*scsy],...
    'Style','text',...
    'String',sprintf('%s%s%s','Z-Position =  ','...','  cm'),...
    'FontName','MS Sans Serif',...
    'FontSize',9*scsx*1.02,...
    'HorizontalAlignment','Left');
Nt=uicontrol('Parent',up3,'Units','pixels',...
    'Position',[5*scsx (MM-MMM*2)*scsy 160*scsx 20*scsy],...
    'Style','text',...
    'String',sprintf('%s%s%s','NET =  ','...','  mm'),...
    'FontName','MS Sans Serif',...
    'FontSize',9*scsx*1.02,...
    'HorizontalAlignment','Left');
Fx=uicontrol('Parent',up3,'Units','pixels',...
    'Position',[5*scsx (MM-MMM*3)*scsy 160*scsx 20*scsy],...
    'Style','text',...
    'String',sprintf('%s%s%s','FWHM_X =  ','...','  cm'),...
    'FontName','MS Sans Serif',...
    'FontSize',9*scsx*1.02,...
    'HorizontalAlignment','Left');
Sx=uicontrol('Parent',up3,'Units','pixels',...
    'Position',[5*scsx (MM-MMM*4)*scsy 160*scsx 20*scsy],...
    'Style','text',...
    'String',sprintf('%s%s%s','Sigma_X =  ','...','  cm'),...
    'FontName','MS Sans Serif',...
    'FontSize',9*scsx*1.02,...
    'HorizontalAlignment','Left');
Fy=uicontrol('Parent',up3,'Units','pixels',...
    'Position',[5*scsx (MM-MMM*5)*scsy 160*scsx 20*scsy],...
    'Style','text',...
    'String',sprintf('%s%s%s','FWHM_Y =  ','...','  cm'),...
    'FontName','MS Sans Serif',...
    'FontSize',9*scsx*1.02,...
    'HorizontalAlignment','Left');
Sy=uicontrol('Parent',up3,'Units','pixels',...
    'Position',[5*scsx (MM-MMM*6)*scsy 160*scsx 20*scsy],...
    'Style','text',...
    'String',sprintf('%s%s%s','Sigma_Y =  ','...','  cm'),...
    'FontName','MS Sans Serif',...
    'FontSize',9*scsx*1.02,...
    'HorizontalAlignment','Left');
F10x=uicontrol('Parent',up3,'Units','pixels',...
    'Position',[5*scsx (MM-MMM*7)*scsy 160*scsx 20*scsy],...
    'Style','text',...
    'String',sprintf('%s%s%s','FW10%M_X =  ','...','  cm'),...
    'FontName','MS Sans Serif',...
    'FontSize',9*scsx*1.02,...
    'HorizontalAlignment','Left');
F10y=uicontrol('Parent',up3,'Units','pixels',...
    'Position',[5*scsx (MM-MMM*8)*scsy 160*scsx 20*scsy],...
    'Style','text',...
    'String',sprintf('%s%s%s','FW10%M_Y =  ','...','  cm'),...
    'FontName','MS Sans Serif',...
    'FontSize',9*scsx*1.02,...
    'HorizontalAlignment','Left');
Px=uicontrol('Parent',up3,'Units','pixels',...
    'Position',[5*scsx (MM-MMM*9)*scsy 160*scsx 20*scsy],...
    'Style','text',...
    'String',sprintf('%s%s%s','Penumbra_X =  ','...','  cm'),...
    'FontName','MS Sans Serif',...
    'FontSize',9*scsx*1.02,...
    'HorizontalAlignment','Left');
Py=uicontrol('Parent',up3,'Units','pixels',...
    'Position',[5*scsx (MM-MMM*10)*scsy 160*scsx 20*scsy],...
    'Style','text',...
    'String',sprintf('%s%s%s','Penumbra_Y =  ','...','  cm'),...
    'FontName','MS Sans Serif',...
    'FontSize',9*scsx*1.02,...
    'HorizontalAlignment','Left');

%% Up4

up4=uipanel('Units','pixels',...
    'Position',[450*scsx 460*scsy 360*scsx 360*scsy],...
    'BorderType','line',...
    'BorderType','etchedout',...
    'BackGroundColor','w',...
    'TitlePosition','lefttop','Title','Measured Data    ');

ROI=axes('Parent',up4,'Units','pixels',...
    'Position',[0*scsx 0*scsy 360*scsx 360*scsy]);
axis(ROI,'off');
%% Up5

up5=uipanel('Units','pixels',...
    'Position',[830*scsx 460*scsy 360*scsx 360*scsy],...
    'BorderType','line',...
    'BorderType','etchedout',...
    'BackGroundColor','w',...
    'TitlePosition','lefttop','Title','2D Profile');

TwoD=axes('Parent',up5,'Units','pixels',...
    'Position',[0*scsx 0*scsy 360*scsx 360*scsy]);
axis(TwoD,'off');

%% Up5_6
up5_6=uipanel('Units','pixels',...
    'Position',[220*scsx 461*scsy 200*scsx 25*scsy],...
    'BorderType','none');

uicontrol('Parent',up5_6,...
    'Units','pixels',...
    'Position',[1*scsx 0*scsy 200*scsx 27*scsy],'String','Calculate Angle Dev.',...
    'BackgroundColor',gray,...
    'FontName','MS Sans Serif',...
    'FontSize',9*scsx*1.02,...
    'FontWeight','bold',...
    'Callback',@Profile_Dev);

%% Up6

upsx=uipanel('Units','pixels',...
    'BorderType','none',...
    'Position',[600*scsx 425*scsy 70*scsx 20*scsy]);
smx=uicontrol('Parent',upsx,'Units','pixels',...
    'Position',[0*scsx 0*scsy 70*scsx 20*scsy],...
    'Style','radiobutton',...
    'String','Filtering',...
    'FontName','MS Sans Serif',...
    'FontSize',9*scsx*1.02,...
    'FontWeight','bold',...
    'HorizontalAlignment','left');
set(smx,'Callback',@smoothx);
% set(upsx,'SelectedObject',[]);  % No selection
% set(upsx,'Visible','on');

up6=uipanel('Units','pixels',...
    'Position',[275*scsx 30*scsy 400*scsx 400*scsy],...
    'BorderType','line',...
    'BorderType','etchedout',...
    'BackGroundColor','w',...
    'TitlePosition','lefttop','Title','X-Profile');

Xaxis=axes('Parent',up6,'Units','pixels',...
    'Position',[60*scsx 50*scsy 320*scsx 320*scsy]);
% axis(Xaxis,'off');

xtxt1=uicontrol('Parent',up6,'Units','pixels',...
    'Position',[218*scsx 210*scsy 130*scsx 20*scsy],...
    'Style','text',...
    'String',sprintf('%s%s%s',''),...
    'FontName','times',...
    'FontSize',8*scsx*1.02,...
    'HorizontalAlignment','Left',...
    'BackGroundColor','w');
xtxt2=uicontrol('Parent',up6,'Units','pixels',...
    'Position',[230*scsx 190*scsy 110*scsx 20*scsy],...
    'Style','text',...
    'String',sprintf('%s%s%s',''),...
    'FontName','times',...
    'FontSize',8*scsx*1.02,...
    'HorizontalAlignment','Left',...
    'BackGroundColor','w');
xtxt3=uicontrol('Parent',up6,'Units','pixels',...
    'Position',[240*scsx 180*scsy 110*scsx 20*scsy],...
    'Style','text',...
    'String',sprintf('%s%s%s',''),...
    'FontName','times',...
    'FontSize',8*scsx*1.02,...
    'HorizontalAlignment','Left',...
    'BackGroundColor','w');
%% Up7

upsy=uipanel('Units','pixels',...
    'BorderType','none',...
    'Position',[1060*scsx 425*scsy 70*scsx 20*scsy]);
smy=uicontrol('Parent',upsy,'Units','pixels',...
    'Position',[0*scsx 0*scsy 70*scsx 20*scsy],...
    'Style','radiobutton',...
    'String','Filtering',...
    'FontName','MS Sans Serif',...
    'FontSize',9*scsx*1.02,...
    'FontWeight','bold',...
    'HorizontalAlignment','left');
set(smy,'Callback',@smoothy);
% set(upsy,'SelectedObject',[]);  % No selection
% set(upsy,'Visible','on');

up7=uipanel('Units','pixels',...
    'Position',[735*scsx 30*scsy 400*scsx 400*scsy],...
    'BorderType','line',...
    'BorderType','etchedout',...
    'BackGroundColor','w',...
    'TitlePosition','lefttop','Title','Y-Profile');

Yaxis=axes('Parent',up7,'Units','pixels',...
    'Position',[60*scsx 50*scsy 320*scsx 320*scsy]);
% axis(Yaxis,'off');

ytxt1=uicontrol('Parent',up7,'Units','pixels',...
    'Position',[218*scsx 210*scsy 130*scsx 20*scsy],...
    'Style','text',...
    'String',sprintf('%s%s%s',''),...
    'FontName','times',...
    'FontSize',8*scsx*1.02,...
    'HorizontalAlignment','Left',...
    'BackGroundColor','w');
ytxt2=uicontrol('Parent',up7,'Units','pixels',...
    'Position',[230*scsx 190*scsy 110*scsx 20*scsy],...
    'Style','text',...
    'String',sprintf('%s%s%s',''),...
    'FontName','times',...
    'FontSize',8*scsx*1.02,...
    'HorizontalAlignment','Left',...
    'BackGroundColor','w');
ytxt3=uicontrol('Parent',up7,'Units','pixels',...
    'Position',[240*scsx 180*scsy 110*scsx 20*scsy],...
    'Style','text',...
    'String',sprintf('%s%s%s',''),...
    'FontName','times',...
    'FontSize',8*scsx*1.02,...
    'HorizontalAlignment','Left',...
    'BackGroundColor','w');

dat=uicontrol('Parent',fig,'Units','pixels',...
    'Position',[920*scsx 5*scsy 250*scsx 20*scsy],...
    'Style','text',...
    'String',sprintf('%s%s%s',''),...
    'FontName','times',...
    'FontSize',8*scsx*1.02,...
    'HorizontalAlignment','Right');

%%
set(fig,'HandleVisibility','off')

% uiwait(fig);

%% -------------------- Callback functions --------------------%%
%%
scax=zeros(1,1);
    function scal1x(src2,eventdata)
        mrn2=get(src2,'String');
        %         mrnv2=get(src2,'Value');
        scx=str2num(mrn2);
        if size(scx,1)~=0
            scax=scx;
        else
            scax=zeros(1,1);
        end
        if scax==0
            uicontrol('Parent',up2,'Units','pixels',...
                'Position',[80*scsx 54*scsy 100*scsx 16*scsy],...
                'Style','text',...
                'String',sprintf('%s%3.4f%s%3.4f%s','(',voxx,',',voxy,')' ),...
                'FontName','MS Sans Serif',...
                'FontSize',9*scsx,...
                'ForegroundColor','r',...
                'HorizontalAlignment','Left',...
                'Callback',{@scal2});
            uicontrol('Parent',up2,'Units','pixels',...
                'Position',[167*scsx 54*scsy 30*scsx 16*scsy],...
                'Style','text',...
                'String',sprintf('%s',' cm'),...
                'FontName','MS Sans Serif',...
                'FontSize',10*scsx,...
                'HorizontalAlignment','Left',...
                'Callback',@scal2);
        else
            voxx=scax;
            uicontrol('Parent',up2,'Units','pixels',...
                'Position',[80*scsx 54*scsy 100*scsx 16*scsy],...
                'Style','text',...
                'String',sprintf('%s%3.4f%s%3.4f%s','(',voxx,',',voxy,')' ),...
                'FontName','MS Sans Serif',...
                'FontSize',9*scsx,...
                'ForegroundColor','r',...
                'HorizontalAlignment','Left',...
                'Callback',{@scal2});
            uicontrol('Parent',up2,'Units','pixels',...
                'Position',[167*scsx 54*scsy 30*scsx 16*scsy],...
                'Style','text',...
                'String',sprintf('%s',' cm'),...
                'FontName','MS Sans Serif',...
                'FontSize',10*scsx,...
                'HorizontalAlignment','Left',...
                'Callback',@scal2);
        end
    end
scay=zeros(1,1);
    function scal1y(src2,eventdata)
        mrn2=get(src2,'String');
        %         mrnv2=get(src2,'Value');
        scy=str2num(mrn2);
        if size(scy,1)~=0
            scay=scy;
        else
            scay=zeros(1,1);
        end
        if scay==0
            uicontrol('Parent',up2,'Units','pixels',...
                'Position',[80*scsx 54*scsy 100*scsx 16*scsy],...
                'Style','text',...
                'String',sprintf('%s%3.4f%s%3.4f%s','(',voxx,',',voxy,')' ),...
                'FontName','MS Sans Serif',...
                'FontSize',9*scsx,...
                'ForegroundColor','r',...
                'HorizontalAlignment','Left',...
                'Callback',{@scal2});
            uicontrol('Parent',up2,'Units','pixels',...
                'Position',[167*scsx 54*scsy 30*scsx 16*scsy],...
                'Style','text',...
                'String',sprintf('%s',' cm'),...
                'FontName','MS Sans Serif',...
                'FontSize',10*scsx,...
                'HorizontalAlignment','Left',...
                'Callback',@scal2);
        else
            voxy=scay;            
            uicontrol('Parent',up2,'Units','pixels',...
                'Position',[80*scsx 54*scsy 100*scsx 16*scsy],...
                'Style','text',...
                'String',sprintf('%s%3.4f%s%3.4f%s','(',voxx,',',voxy,')' ),...
                'FontName','MS Sans Serif',...
                'FontSize',9*scsx,...
                'ForegroundColor','r',...
                'HorizontalAlignment','Left',...
                'Callback',{@scal2});
            uicontrol('Parent',up2,'Units','pixels',...
                'Position',[167*scsx 54*scsy 30*scsx 16*scsy],...
                'Style','text',...
                'String',sprintf('%s',' cm'),...
                'FontName','MS Sans Serif',...
                'FontSize',10*scsx,...
                'HorizontalAlignment','Left',...
                'Callback',@scal2);
        end
    end
    function scal2(varargin)
        if scax==0
            uicontrol('Parent',up2,'Units','pixels',...
                'Position',[80*scsx 54*scsy 100*scsx 16*scsy],...
                'Style','text',...
                'String',sprintf('%s%3.4f%s%3.4f%s','(',voxx,',',voxy,')' ),...
                'FontName','MS Sans Serif',...
                'FontSize',9*scsx,...
                'ForegroundColor','r',...
                'HorizontalAlignment','Left',...
                'Callback',{@scal2});
            uicontrol('Parent',up2,'Units','pixels',...
                'Position',[167*scsx 54*scsy 30*scsx 16*scsy],...
                'Style','text',...
                'String',sprintf('%s',' cm'),...
                'FontName','MS Sans Serif',...
                'FontSize',10*scsx,...
                'HorizontalAlignment','Left',...
                'Callback',@scal2);
        elseif scay==0
            uicontrol('Parent',up2,'Units','pixels',...
                'Position',[80*scsx 54*scsy 100*scsx 16*scsy],...
                'Style','text',...
                'String',sprintf('%s%3.4f%s%3.4f%s','(',voxx,',',voxy,')' ),...
                'FontName','MS Sans Serif',...
                'FontSize',9*scsx,...
                'ForegroundColor','r',...
                'HorizontalAlignment','Left',...
                'Callback',{@scal2});
            uicontrol('Parent',up2,'Units','pixels',...
                'Position',[167*scsx 54*scsy 30*scsx 16*scsy],...
                'Style','text',...
                'String',sprintf('%s',' cm'),...
                'FontName','MS Sans Serif',...
                'FontSize',10*scsx,...
                'HorizontalAlignment','Left',...
                'Callback',@scal2);            
        else
            uicontrol('Parent',up2,'Units','pixels',...
                'Position',[80*scsx 54*scsy 100*scsx 16*scsy],...
                'Style','text',...
                'String',sprintf('%s%3.4f%s%3.4f%s','(',scax,',',scay,')' ),...
                'FontName','MS Sans Serif',...
                'FontSize',9*scsx,...
                'ForegroundColor','r',...
                'HorizontalAlignment','Left',...
                'Callback',{@scal2});
            uicontrol('Parent',up2,'Units','pixels',...
                'Position',[167*scsx 54*scsy 30*scsx 16*scsy],...
                'Style','text',...
                'String',sprintf('%s',' cm'),...
                'FontName','MS Sans Serif',...
                'FontSize',10*scsx,...
                'HorizontalAlignment','Left',...
                'Callback',@scal2);
        end
    end

%% Background
    function bkgd(varargin)
        [bkgdname, bkgdpwd] = uigetfile( ...
            {'*.tif;*.jpg;*.CR2;', 'Background File';...
            '*.*', 'All Files (*.*)'}, ...
            'Select Background File');%,'MultiSelect','on');
        if size(bkgdname,2)>2
            delete(txt2)
            txt2=uicontrol('Parent',up2,'Units','pixels',...
                'Position',[100*scsx 85*scsy 90*scsx 20*scsy],...
                'FontSize',9*scsx*1.02,...
                'ForegroundColor','r',...
                'Style','text',...
                'String',sprintf('%s','Set'),...
                'HorizontalAlignment','left',...
                'Callback',{@bkgd});
%             uicontrol('Parent',up2,'Units','pixels',...
%                 'Position',[167*scsx 50*scsy 30*scsx 20*scsy],...
%                 'Style','text',...
%                 'String',sprintf('%s',' cm'),...
%                 'FontName','MS Sans Serif',...
%                 'FontSize',10*scsx,...
%                 'HorizontalAlignment','Left',...
%                 'Callback',@scal2);
        elseif bkgdname==0
            delete(txt2)
            txt2=uicontrol('Parent',up2,'Units','pixels',...
                'Position',[100*scsx 85*scsy 90*scsx 20*scsy],...
                'FontSize',9*scsx*1.02,...
                'ForegroundColor','r',...
                'Style','text',...
                'String',sprintf('%s','Not Set'),...
                'HorizontalAlignment','left');
%             uicontrol('Parent',up2,'Units','pixels',...
%                 'Position',[167*scsx 50*scsy 30*scsx 20*scsy],...
%                 'Style','text',...
%                 'String',sprintf('%s',' cm'),...
%                 'FontName','MS Sans Serif',...
%                 'FontSize',10*scsx,...
%                 'HorizontalAlignment','Left',...
%                 'Callback',@scal2);
        end

    end

%% Profile Analysis
    function Profile_Analyzer(fndir,fn,cr)

        MUd=1;
        rate=1500/4272;
       
        
        if scax==0
            %             vox=0.0591/10/rate;%2.54/150;
         
            if Measurement_Type==1
                 voxx=2.54/150*2;
                 voxy=2.54/150*2;
            elseif Measurement_Type==2
                %                 vox= 0.008825/rate;%0.00668455;
                voxx=(16/1851.30+12/1390.83+8/930.21)/3/rate;
                voxy=(16/1904.12+12/1434.91+8/953.20)/3/rate;
            end
        else
            if Measurement_Type==1
                 voxx=2.54/150*2;
                 voxy=2.54/150*2;
            elseif Measurement_Type==2
                voxx=scax/rate;
                voxy=scay/rate;
                %                 vox=sca/rate;
            end
        end

        fst=strvcat(fn);
        
        R1=strfind(fst,'E');
        M1=strfind(fst,'Z');
        F1=strfind(fst,'NET');
        
        if strfind(fst,'.tif')
            SP=strfind(fst,'.tif');
        elseif strfind(fst,'.CR2')
            SP=strfind(fst,'.CR2')
        end
      
        if strfind(fst,'_')
            fst1=strrep(fst,'_','.');
            Energy=str2num(fst1(1,R1+1:M1-1));
            ZPOS=str2num(fst1(1,M1+1:F1-1));
            NET=str2num(fst1(1,F1+3:SP-1))/100;
        elseif strfind(fst,'I')
            fst1=strrep(fst,'I','0');
            Energy=str2num(fst1(1,R1+1:M1-1));
            ZPOS=str2num(fst1(1,M1+1:F1-1));
            NET=str2num(fst1(1,F1+3:SP-1))/100;
        elseif strfind(fst,'U')
            fst1=strrep(fst,'U','+');
            Energy=str2num(fst1(1,R1+1:M1-1));
            ZPOS=str2num(fst1(1,M1+1:F1-1));
            NET=str2num(fst1(1,F1+3:SP-1))/100;
        elseif strfind(fst,'D')
            fst1=strrep(fst,'D','-');
            Energy=str2num(fst1(1,R1+1:M1-1));
            ZPOS=str2num(fst1(1,M1+1:F1-1));
            NET=str2num(fst1(1,F1+3:SP-1))/100;            
        else
            fst1=fst;
            Energy=str2num(fst1(1,R1+1:M1-1));
            ZPOS=str2num(fst1(1,M1+1:F1-1));
            NET=str2num(fst1(1,F1+3:F1+6))/100;
        end
%         Energy
%         ZPOS
%         NET
        
        %% Outputs

        MM=290;MMM=29;
        if ~isempty(size(En))
            delete(En);
        else
        end
        En=uicontrol('Parent',up3,'Units','pixels',...
            'Position',[5*scsx MM*scsy 160*scsx 20*scsy],...
            'Style','text',...
            'String',sprintf('%s%g%s','Energy =  ',Energy,'  MeV'),...
            'FontName','MS Sans Serif',...
            'FontSize',9*scsx*1.02,...
            'HorizontalAlignment','Left');
        if ~isempty(size(Zp))
            delete(Zp);
        else
        end
        Zp=uicontrol('Parent',up3,'Units','pixels',...
            'Position',[5*scsx (MM-MMM*1)*scsy 160*scsx 20*scsy],...
            'Style','text',...
            'String',sprintf('%s%5.3f%s','Z-Position =  ',ZPOS,'  cm'),...
            'FontName','MS Sans Serif',...
            'FontSize',9*scsx*1.02,...
            'HorizontalAlignment','Left');
        if ~isempty(size(Nt))
            delete(Nt);
        else
        end
        Nt=uicontrol('Parent',up3,'Units','pixels',...
            'Position',[5*scsx (MM-MMM*2)*scsy 160*scsx 20*scsy],...
            'Style','text',...
            'String',sprintf('%s%g%s','NET =  ',NET,'  mm'),...
            'FontName','MS Sans Serif',...
            'FontSize',9*scsx*1.02,...
            'HorizontalAlignment','Left');
        if ~isempty(size(Fx))
            delete(Fx);
        else
        end
        Fx=uicontrol('Parent',up3,'Units','pixels',...
            'Position',[5*scsx (MM-MMM*3)*scsy 160*scsx 20*scsy],...
            'Style','text',...
            'String',sprintf('%s%s%s','FWHM_X =  ','...','  cm'),...
            'FontName','MS Sans Serif',...
            'FontSize',9*scsx*1.02,...
            'HorizontalAlignment','Left');
        if ~isempty(size(Sx))
            delete(Sx);
        else
        end
        Sx=uicontrol('Parent',up3,'Units','pixels',...
            'Position',[5*scsx (MM-MMM*4)*scsy 160*scsx 20*scsy],...
            'Style','text',...
            'String',sprintf('%s%s%s','Sigma_X =  ','...','  cm'),...
            'FontName','MS Sans Serif',...
            'FontSize',9*scsx*1.02,...
            'HorizontalAlignment','Left');
        if ~isempty(size(Fy))
            delete(Fy);
        else
        end
        Fy=uicontrol('Parent',up3,'Units','pixels',...
            'Position',[5*scsx (MM-MMM*5)*scsy 160*scsx 20*scsy],...
            'Style','text',...
            'String',sprintf('%s%s%s','FWHM_Y =  ','...','  cm'),...
            'FontName','MS Sans Serif',...
            'FontSize',9*scsx*1.02,...
            'HorizontalAlignment','Left');
        if ~isempty(size(Sy))
            delete(Sy);
        else
        end
        Sy=uicontrol('Parent',up3,'Units','pixels',...
            'Position',[5*scsx (MM-MMM*6)*scsy 160*scsx 20*scsy],...
            'Style','text',...
            'String',sprintf('%s%s%s','Sigma_Y =  ','...','  cm'),...
            'FontName','MS Sans Serif',...
            'FontSize',9*scsx*1.02,...
            'HorizontalAlignment','Left');
        if ~isempty(size(F10x))
            delete(F10x);
        else
        end
        F10x=uicontrol('Parent',up3,'Units','pixels',...
            'Position',[5*scsx (MM-MMM*7)*scsy 160*scsx 20*scsy],...
            'Style','text',...
            'String',sprintf('%s%s%s','FW10%M_X =  ','...','  cm'),...
            'FontName','MS Sans Serif',...
            'FontSize',9*scsx*1.02,...
            'HorizontalAlignment','Left');
        if ~isempty(size(F10y))
            delete(F10y);
        else
        end
        F10y=uicontrol('Parent',up3,'Units','pixels',...
            'Position',[5*scsx (MM-MMM*8)*scsy 160*scsx 20*scsy],...
            'Style','text',...
            'String',sprintf('%s%s%s','FW10%M_Y =  ','...','  cm'),...
            'FontName','MS Sans Serif',...
            'FontSize',9*scsx*1.02,...
            'HorizontalAlignment','Left');
        if ~isempty(size(Px))
            delete(Px);
        else
        end
        Px=uicontrol('Parent',up3,'Units','pixels',...
            'Position',[5*scsx (MM-MMM*9)*scsy 160*scsx 20*scsy],...
            'Style','text',...
            'String',sprintf('%s%s%s','Penumbra_X =  ','...','  cm'),...
            'FontName','MS Sans Serif',...
            'FontSize',9*scsx*1.02,...
            'HorizontalAlignment','Left');
        if ~isempty(size(Py))
            delete(Py);
        else
        end
        Py=uicontrol('Parent',up3,'Units','pixels',...
            'Position',[5*scsx (MM-MMM*10)*scsy 160*scsx 20*scsy],...
            'Style','text',...
            'String',sprintf('%s%s%s','Penumbra_Y =  ','...','  cm'),...
            'FontName','MS Sans Serif',...
            'FontSize',9*scsx*1.02,...
            'HorizontalAlignment','Left');

        %%
        % Concatenate file name string
        fndir=strvcat(fndir);
        [pathstr, name, ext] = fileparts(fndir);
        
        % Open Tiff  file
        Dt0=imread(fndir);
        Dt0=flipdim(Dt0,2);

        if size(Dt0,1)>size(Dt0,2)
            if Measurement_Type==2
                Dt1=imresize(Dt0,[1500 NaN]);
                Dt_=imrotate(Dt1,270,'bilinear');
            elseif Measurement_Type==1
                Dt_=Dt0;
            end
        else
            if Measurement_Type==2
                Dt1=imresize(Dt0,[NaN 1500]);
                Dt_=imrotate(Dt1,270,'bilinear');
            elseif Measurement_Type==1
                Dt_=Dt0;
            end
        end
        Dt_=im2uint16(Dt_);
        % Dt_=sum(Dt2,3);

        if Measurement_Type==1
            if ~isempty(bkgdname)
                bkgd=imread(sprintf('%s%s',bkgdpwd,bkgdname)); % For Proton
                bkgd=im2uint16(bkgd);
                Dt=imsubtract(Dt_,bkgd);
            else
                Dt=Dt_;
            end

%             if ~isempty(bkgdname)
%                 bkgd1=imread(sprintf('%s%s',bkgdpwd,bkgdname)); % For Proton
%                 if size(Dt_,1)>size(Dt_,2)
%                     bkgd2=imresize(bkgd1,[size(Dt_,1) NaN]);
% %                     bkgd=imrotate(bkgd2,270,'bilinear');
%                     bkgd=bkgd2;
%                 else                    
%                     bkgd2=imresize(bkgd1,[NaN size(Dt_,2)]);
%                     bkgd=imrotate(bkgd2,270,'bilinear');
%                     bkgd=bkgd2;
%                 end
%                 bkgd=im2uint16(bkgd);
%                 size(Dt_)
%                 size(bkgd)
%                 Dt=imsubtract(Dt_,bkgd);
%             else
%                 Dt=Dt_;
%             end
            
            
            %%%==========================================
            %% Locating CAX
            clc;
            Dtc=Dt(:,:,3);
            Dtplotx1_=sum(Dtc,2);
            Dtplotx2_=sum(Dtc,1);
            
            aa_=find(max(Dtplotx1_)==Dtplotx1_,1);
            bb_=find(max(Dtplotx2_)==Dtplotx2_,2);

            CAX_X=bb_*voxx
            CAX_Y=aa_*voxy
            
            %%%==========================================            
            %% Define ROI
                ROIx1=aa_-120;
                ROIx2=aa_+120;
                ROIy1=bb_-120;
                ROIy2=bb_+120;
            
            %%%==========================================                      
            
            if ~isempty(size(ROI))
                delete(ROI);
            else
            end
            if ~isempty(size(up4))
                delete(up4);
            else
            end
            up4=uipanel('Parent',fig,'Units','pixels',...
                'Position',[450 460 360 360],...
                'BorderType','line',...
                'BorderType','etchedout',...
                'BackGroundColor','w',...
                'TitlePosition','lefttop','Title','Select ROI');
            ROI=axes('Parent',up4,'Units','pixels',...
                'Position',[0 0 360 360]);
            axis(ROI,'off');
            imshow(Dt,'Parent',ROI);%,'InitialMagnification',10);
            h=imrect(ROI);
            setColor(h,'y');
            pos=wait(h);
%             delete(f2);
            % close(f2);
            File_Name=fn
            pos1=[pos(1,1) pos(1,1)+pos(1,3) pos(1,2) pos(1,2)+pos(1,4)];
            position=round(pos1);

            up4=uipanel('Parent',fig,'Units','pixels',...
                'Position',[450*scsx 460*scsy 360*scsx 360*scsy],...
                'BorderType','line',...
                'BorderType','etchedout',...
                'BackGroundColor','w',...
                'TitlePosition','lefttop','Title','Selected ROI     ');
            
            ROI=axes('Parent',up4,'Units','pixels',...
                'Position',[0*scsx 0*scsy 360*scsx 360*scsy]);
            axis(ROI,'off');
            
            ROIx1=position(1,3);ROIx2=position(1,4);
            ROIy1=position(1,1);ROIy2=position(1,2);
            
            imshow(Dt(ROIx1:ROIx2, ROIy1:ROIy2,:),'Parent',ROI);     
            
%             Dtsum=-log(sum(Dt(position(1,3):position(1,4), position(1,1):position(1,2),1),3)/65535);
            Dtsum=(sum(Dt(ROIx1:ROIx2, ROIy1:ROIy2,1),3));
%             Dtsum=Dtsum';

            scnsize = get(0,'ScreenSize');
            bdwidth=60;
            pos1  = [bdwidth+15,...
                1/3*scnsize(4)- 5*bdwidth ,...
                1/4*scnsize(3) ,...
                1/4*scnsize(4)];
            
%             ff=figure('Name','Selected ROI','NumberTitle','off','Position',pos1)
%             
%             imshow(Dt(ROIx1:ROIx2, ROIy1:ROIy2,:));
%             saveas(gcf,[strrep(fn,'.CR2',''),'_roi','.jpg']);
%             delete(ff)
            %% Scan Calibration (Reading ==> OD)
%             OD=(2.720889E-02)*(Dtsum).^3 - (1.025030E-01)*(Dtsum).^2 + (7.603538E-01)*(Dtsum).^1;            
% nm=find(Dtsum<=1138);
% Dtsum(nm)=1138;
% OD=(-1/1.721)*log((Dtsum-1137)/(6.75e4));
            OD=(-1)*log10((Dtsum)/(6.75e4));
            %% Film Calibration (OD ==> Dose)
%             Dtplot=-50*(OD.^(2/3))/log(OD);
%             A0=8.32;A1=49.91;A2=2.6;
            A0=9.93;A1=42.47;A2=2.4;
%             A0=9.90;A1=38.02;A2=2.6;
            Dtplot=A0*OD+A1*OD.^A2;

%             Dtplot=(a1*(exp(-OD)-1))./(b1-exp(-OD));
            %             Dtplot=OD;
%             Dtplot=(-2.318410E+02)*(OD).^6 + 1.757979E+03*(OD).^5 - 4.547998E+03*(OD).^4 + 4.875320E+03*(OD).^3 - 1.269139E+03*(OD).^2 + 1.745999E+02*(OD).^1 +(3.199514E-02);
%             Dtplot=(-2.015e+04)*(OD.^6)+(8.279e+04)*(OD.^5)+(-1.36e+05)*(OD.^4)+(1.148e+05)*(OD.^3)+(-5.101e+04)*(OD.^2)+(1.223e+04)*(OD)+(-1265);
%             Dtplot=(6197)*(OD.^6)+(-2.618e+04)*(OD.^5)+(4.459e+04)*(OD.^4)+(-3.834e+04)*(OD.^3)+(1.814e+04)*(OD.^2)+(-3885)*(OD)+(286.5);
%             Dtplot=(771.7)*(OD.^3)+(-110.6)*(OD.^2)+(171.9)*(OD)+(-17.46);
%             Dtplot(find(Dtplot<0))=1e-4;
            Dtcrop_o=Dtplot/max(max(Dtplot));

        else%if Measurement_Type==2

            if ~isempty(bkgdname)
                bkgd1=imread(sprintf('%s%s',bkgdpwd,bkgdname)); % For Proton
                if size(bkgd1,1)>size(bkgd1,2)
                    bkgd2=imresize(bkgd1,[1500 NaN]);
%                     bkgd=imrotate(bkgd2,270,'bilinear');
                    bkgd=bkgd2;
                else                    
                    bkgd2=imresize(bkgd1,[NaN 1500]);
                    bkgd=imrotate(bkgd2,270,'bilinear');
                    bkgd=bkgd2;
                end
                bkgd=im2uint16(bkgd);
                size(Dt_)
                size(bkgd)
                Dt=imsubtract(Dt_,bkgd);
            else
                Dt=Dt_;
            end

            %%%==========================================
            %% Locating CAX
            clc;
            Dtc=Dt(:,:,3);
            Dtplotx1_=sum(Dtc,2);
            Dtplotx2_=sum(Dtc,1);
            
            aa_=find(max(Dtplotx1_)==Dtplotx1_,1);
            bb_=find(max(Dtplotx2_)==Dtplotx2_,2);

            CAX_X=bb_*voxx;
            CAX_Y=aa_*voxy;
            
            %%%==========================================            
            %% Define ROI
                ROIx1=aa_-120;
                ROIx2=aa_+120;
                ROIy1=bb_-120;
                ROIy2=bb_+120;
                        
            %%%==========================================            
            
            
            if ~isempty(size(ROI))
                delete(ROI);
            else
            end
            if ~isempty(size(up4))
                delete(up4);
            else
            end

            up4=uipanel('Parent',fig,'Units','pixels',...
                'Position',[450*scsx 460*scsy 360*scsx 360*scsy],...
                'BorderType','line',...
                'BorderType','etchedout',...
                'BackGroundColor','w',...
                'TitlePosition','lefttop','Title','Selected ROI     ');
            
            ROI=axes('Parent',up4,'Units','pixels',...
                'Position',[0*scsx 0*scsy 360*scsx 360*scsy]);
            axis(ROI,'off');
%             imshow(Dt(435+40:980+40, 810-95:1355-95,:),'Parent',ROI);            
%             Dtt=sum(Dt(435+40:980+40, 810-95:1355-95,2),3);
%                        
            imshow(Dt(ROIx1:ROIx2, ROIy1:ROIy2,:),'Parent',ROI);            
%             Dtt=sum(Dt(435:980, 810:1355,2),3); % Green Channel
            Dtsum=sum(Dt(ROIx1:ROIx2, ROIy1:ROIy2,:),3); % Sum of all channels
           
            scnsize = get(0,'ScreenSize');
            bdwidth=60;
            pos1  = [bdwidth+15,...
                1/3*scnsize(4)- 5*bdwidth ,...
                1/4*scnsize(3) ,...
                1/4*scnsize(4)];
            
%             ff=figure('Name','Selected ROI','NumberTitle','off','Position',pos1)
%             size(Dt)
%             imshow(Dt(ROIx1:ROIx2, ROIy1:ROIy2,:));
%             saveas(gcf,[strrep(fn,'.CR2',''),'_roi','.jpg']);
%             delete(ff)            
            

            %% Noise Filtering
%             H = fspecial('disk');
%             Dtt_ = imfilter(Dtt,H,'replicate');
%             Dtt_=medfilt2(Dtt_);
%             %    Dtt_=Dtt;
%             Dtplot=Dtt_;
%             Dtplot(find(Dtplot<0))=1e-4;
%             Dtcrop_o=Dtt/max(max(Dtt));

%             H = fspecial('disk');
%             Dtt__ = imfilter(Dtt,H,'replicate');
%             Dtt_ = imfilter(Dtt__,H,'replicate');
            %    Dtt_=Dtt;
            
            %% Scintilator plate response vs Dose: Currently, linear relationship of sum of three RGB channel responses and dose is assumed.
            Dtt=Dtsum;
            Dtplot=Dtt;
            Dtplot(find(Dtplot<0))=1e-4;
            Dtcrop_o=Dtt/max(max(Dtt));

        end
        %% Clear Axes        
        if ~isempty(size(TwoD))
            delete(TwoD);
        else
        end
        if ~isempty(size(smx))
            delete(smx)
        else
        end

        smx=uicontrol('Parent',upsx,'Units','pixels',...
            'Position',[0*scsx 0*scsy 70*scsx 20*scsy],...
            'Style','radiobutton',...
            'String','Filtering',...
            'FontName','MS Sans Serif',...
            'FontSize',9*scsx*1.02,...
            'FontWeight','bold',...
            'HorizontalAlignment','left');
        set(smx,'Callback',@smoothx);

        if ~isempty(size(smy))
            delete(smy)
        else
        end
        smy=uicontrol('Parent',upsy,'Units','pixels',...
            'Position',[0*scsx 0*scsy 70*scsx 20*scsy],...
            'Style','radiobutton',...
            'String','Filtering',...
            'FontName','MS Sans Serif',...
            'FontSize',9*scsx*1.02,...
            'FontWeight','bold',...
            'HorizontalAlignment','left');
        set(smy,'Callback',@smoothy);

        if ~isempty(size(Xaxis))
            delete(Xaxis)
        else
        end
        if ~isempty(size(Yaxis))
            delete(Yaxis)
        else
        end
        if ~isempty(size(xtxt1))
            delete(xtxt1)
        else
        end
        if ~isempty(size(xtxt2))
            delete(xtxt2)
        else
        end
        if ~isempty(size(xtxt3))
            delete(xtxt3)
        else
        end
        if ~isempty(size(ytxt1))
            delete(ytxt1)
        else
        end
        if ~isempty(size(ytxt2))
            delete(ytxt2)
        else
        end
        if ~isempty(size(ytxt3))
            delete(ytxt3)
        else
        end
        if ~isempty(size(dat))
            delete(dat)
        else
        end
        %%                
        
        Dtplotx1=sum(Dtplot,2);
        Dtplotx2=sum(Dtplot,1);
        
        aa=find(max(Dtplotx1)==Dtplotx1,1);
        bb=find(max(Dtplotx2)==Dtplotx2,2);
        
        Dtcrop=Dtplot/max(max(Dtplot));

        %%
        scnsize = get(0,'ScreenSize');
        bdwidth=60;
        pos1  = [bdwidth+15,...
            1/3*scnsize(4)- 5*bdwidth ,...
            3/4*scnsize(3) ,...
            3/4*scnsize(4)];
        
        fsize=10*scsx;%0.01*scnsize(4)*scsx*1.05;
        fsizet=11*scsx;%0.015*scnsize(4)*scsx*1.05;        
        
        Dtcrop1=sum(Dtcrop,2);
        Dtcrop2=sum(Dtcrop,1);
        
        a=find(max(Dtcrop1)==Dtcrop1,1);
        b=find(max(Dtcrop2)==Dtcrop2,2);

        avg_width=10;
        xx=(1:size(Dtplot,1))*voxx-a*voxx;
        Dtcropx=Dtcrop(:,b)/((max(Dtcrop(a-avg_width:a+avg_width,b))+Dtcrop(a,b))/2);
        Dtcropx=Dtcropx';
        yy=(1:size(Dtplot,2))*voxy-b*voxy;
        Dtcropy=Dtcrop(a,:)/((max(Dtcrop(a,b-avg_width:b+avg_width))+Dtcrop(a,b))/2);
%         Dtcropyy=Dtcropy;
  
        %% Gaussian Fitting
        if Gaussian_Fit==1
            %% Single Gaussian Fit for X Profile
            [xData, yData] = prepareCurveData( yy, Dtcropy );
            
            %         Set up fittype and options.
            ft = fittype( 'a1*exp(-(x-x01)^2/(2*s1^2))', 'independent', 'x', 'dependent', 'y' );
            opts = fitoptions( ft );
            opts.Display = 'Off';
            opts.Lower = [0 0 0];
            opts.StartPoint = [0.5 1 0 ];
            opts.Upper = [1.0 Inf Inf];
            
            %         Fit model to data.
            [fitresult, gof] = fit( xData, yData, ft, opts )
            textg='Gaussian Fit';
            
            w=fitresult.a1
            sigmay1=fitresult.s1;
            x01=fitresult.x01;
            
            SigmaX_Fit=sigmay1
            
            Dtcrop_a=w*exp(-(yy-x01).^2/(2*sigmay1^2));
            Dtcrop_a=Dtcrop_a/max(Dtcrop_a);
        else
            %% Double Gaussian Fit for X Profile
            [xData, yData] = prepareCurveData( yy, Dtcropy );
            
            %         Set up fittype and options.
            ft = fittype( 'a1*exp(-(x-x01)^2/(2*s1^2))+a2*exp(-(x-x02)^2/(2*s2^2))', 'independent', 'x', 'dependent', 'y' );
            opts = fitoptions( ft );
            opts.Display = 'Off';
            opts.Lower = [0 0 0 0 0 0];
            opts.StartPoint = [0.5 0.5 1 1 0 0];
            opts.Upper = [1.0 1.0 Inf Inf Inf Inf];
            
            %         Fit model to data.
            [fitresult, gof] = fit( xData, yData, ft, opts )
            textg='Gaussian Fit';
            
            w1=fitresult.a1
            sigmay1=fitresult.s1;
            x01=fitresult.x01;
            
            w2=(1-w1)
            w2=fitresult.a2
            sigmay2=fitresult.s2;
            x02=fitresult.x02;
            
            SigmaX_primary=sigmay1
            SigmaX_secondary=sigmay2
            
            Dtcrop_a=w1*exp(-(yy-x01).^2/(2*sigmay1^2))+w2*exp(-(yy-x02).^2/(2*sigmay2^2));
            Dtcrop_a=Dtcrop_a/max(Dtcrop_a);

            %% To locate Gaussian Fit 50%
            
            [Dtcmax_a amx]=max(Dtcrop_a);
            
            al1g=max(find(Dtcrop_a(1,1:amx)<Dtcmax_a/2));
            al2g=min(find(Dtcrop_a(1,1:amx)>Dtcmax_a/2));
            % find(Dtcrop(1:a,1:b)<1.1*(Dtcmax/2) && Dtcrop(1:a,1:b)>0.9*(Dtcmax/2))
            ar1g=amx+min(find(Dtcrop_a(1,amx+1:size(Dtcrop_a,2))<Dtcmax_a/2));
            ar2g=amx+max(find(Dtcrop_a(1,amx+1:size(Dtcrop_a,2))>Dtcmax_a/2));
            
            %===========================
            yl1g=Dtcrop_a(al1g); % yl1
            yl2g=Dtcrop_a(al2g); % yl2
            
            xl1g=al1g*voxx;
            xl2g=al2g*voxx;
            
            mlg=(yl1g-yl2g)/(xl1g-xl2g);
            blg=yl1g-mlg*xl1g;
            xl50g=(0.5-blg)/mlg;
            
            yr1g=Dtcrop_a(ar1g); % yr1
            yr2g=Dtcrop_a(ar2g); % yr2
            
            xr1g=ar1g*voxx;
            xr2g=ar2g*voxx;
            
            mrg=(yr1g-yr2g)/(xr1g-xr2g);
            brg=yr1g-mrg*xr1g;
            xr50g=(0.5-brg)/mrg;
            
            FWHMX_Fit=abs(xl50g-xr50g);
            SigmaX_Fit=FWHMX_Fit/2/sqrt(2*log(2))
        end

        %% Gaussian Fitting
        if Gaussian_Fit==1
            %% Single Gaussian Fit for Y Profile
            [xData, yData] = prepareCurveData( xx, Dtcropx );
            
            % Set up fittype and options.
            ft = fittype( 'a1*exp(-(x-x01)^2/(2*s1^2))', 'independent', 'x', 'dependent', 'y' );
            opts = fitoptions( ft );
            opts.Display = 'Off';
            opts.Lower = [0 0 0];
            opts.StartPoint = [0.5 1 0];
            opts.Upper = [1.0 Inf Inf];
            
            % Fit model to data.
            [fitresult, gof] = fit( xData, yData, ft, opts )
            textg='Gaussian Fit';
            
            w=fitresult.a1
            sigmax1=fitresult.s1;
            x01=fitresult.x01;            
            
            SigmaY_Fit=sigmax1
            
            Dtcrop_b=w*exp(-(xx-x01).^2/(2*sigmax1^2));
            Dtcrop_b=Dtcrop_b/max(Dtcrop_b);
        else            
            %% Double Gaussian Fit for X Profile
            
            [xData, yData] = prepareCurveData( xx, Dtcropx );
            
            % Set up fittype and options.
            ft = fittype( 'a1*exp(-(x-x01)^2/(2*s1^2))+a2*exp(-(x-x02)^2/(2*s2^2))', 'independent', 'x', 'dependent', 'y' );
            opts = fitoptions( ft );
            opts.Display = 'Off';
            opts.Lower = [0 0 0 0 0 0];
            opts.StartPoint = [0.5 0.5 1 1 0 0];
            opts.Upper = [1.0 1.0 Inf Inf Inf Inf];
            
            % Fit model to data.
            [fitresult, gof] = fit( xData, yData, ft, opts )
            textg='Gaussian Fit';
            
            w1=fitresult.a1
            sigmax1=fitresult.s1;
            x01=fitresult.x01;
            
            %             w2=(1-w1)
            w2=fitresult.a2
            sigmax2=fitresult.s2;
            x02=fitresult.x02;
            
            SigmaYX_primary=sigmax1
            SigmaY_secondary=sigmax2
            
            Dtcrop_b=w1*exp(-(xx-x01).^2/(2*sigmax1^2))+w2*exp(-(xx-x02).^2/(2*sigmax2^2));
            Dtcrop_b=Dtcrop_b/max(Dtcrop_b);

            %% To locate Gaussian Fit 50%
            
            [Dtcmax_b bmx]=max(Dtcrop_b);
            
            bl1g=max(find(Dtcrop_b(1,1:bmx)<Dtcmax_b/2));
            bl2g=min(find(Dtcrop_b(1,1:bmx)>Dtcmax_b/2));
            
            % find(Dtcrop(1:a,1:b)<1.1*(Dtcmax/2) && Dtcrop(1:a,1:b)>0.9*(Dtcmax/2))
            
            br1g=bmx+min(find(Dtcrop_b(1,bmx+1:size(Dtcrop_b,2))<Dtcmax_b/2));
            br2g=bmx+max(find(Dtcrop_b(1,bmx+1:size(Dtcrop_b,2))>Dtcmax_b/2));
            
            %===========================
            yxl1g=Dtcrop_b(bl1g); % yxl1
            yxl2g=Dtcrop_b(bl2g); % yxl2
            
            xxl1g=bl1g*voxy;
            xxl2g=bl2g*voxy;
            
            mxlg=(yxl1g-yxl2g)/(xxl1g-xxl2g);
            bxlg=yxl1g-mxlg*xxl1g;
            xxl50g=(0.5-bxlg)/mxlg;
            
            yxr1g=Dtcrop_b(br1g); % yxr1
            yxr2g=Dtcrop_b(br2g); % yxr2
            
            xxr1g=br1g*voxy;
            xxr2g=br2g*voxy;
            
            mxrg=(yxr1g-yxr2g)/(xxr1g-xxr2g);
            bxrg=yxr1g-mxrg*xxr1g;
            xxr50g=(0.5-bxrg)/mxrg;
            
            FWHMY_Fit=abs(xxl50g-xxr50g);
            SigmaY_Fit=FWHMY_Fit/2/sqrt(2*log(2))
                    
        end
              
        xxx=zeros(size(Dtcrop,1),size(Dtcrop,2));
        
        for n=1:size(xxx,2)
            xxx(:,n)=xx;
        end;
        
        yyy=zeros(size(Dtcrop,1),size(Dtcrop,2));
        
        for n=1:size(yyy,1)
            yyy(n,:)=yy;
        end;
        %%===========================
       
        %% To locate 50%
        Dtcmax=max(max(Dtcrop));
        al1=max(find(Dtcrop(a,1:b)<Dtcmax/2));
        al2=min(find(Dtcrop(a,1:b)>Dtcmax/2));        
        
        % find(Dtcrop(1:a,1:b)<1.1*(Dtcmax/2) && Dtcrop(1:a,1:b)>0.9*(Dtcmax/2))
        
        ar1=(b-1)+min(find(Dtcrop(a,b:size(Dtcrop,2))<Dtcmax/2));
        ar2=(b-1)+max(find(Dtcrop(a,b:size(Dtcrop,2))>Dtcmax/2));
        
        bl1=max(find(Dtcrop(1:a,b)<Dtcmax/2));
        bl2=min(find(Dtcrop(1:a,b)>Dtcmax/2));
        
        br1=(a-1)+min(find(Dtcrop(a:size(Dtcrop,1),b)<Dtcmax/2));
        br2=(a-1)+max(find(Dtcrop(a:size(Dtcrop,1),b)>Dtcmax/2));
        
        %===========================
        
        yl1=Dtcrop(a,al1); % yl1
        yl2=Dtcrop(a,al2); % yl2
        
        xl1=al1*voxx;
        xl2=al2*voxx;
        
        ml=(yl1-yl2)/(xl1-xl2);
        bl=yl1-ml*xl1;
        xl50=(0.5-bl)/ml;
        
        yr1=Dtcrop(a,ar1); % yr1
        yr2=Dtcrop(a,ar2); % yr2
        
        xr1=ar1*voxx;
        xr2=ar2*voxx;
        
        mr=(yr1-yr2)/(xr1-xr2);
        br=yr1-mr*xr1;
        xr50=(0.5-br)/mr;
        
        FWHM_X=abs(xl50-xr50);
        Sigma_X=FWHM_X/2/sqrt(2*log(2))
      
        %===========================
        yxl1=Dtcrop(bl1,b); % yxl1
        yxl2=Dtcrop(bl2,b); % yxl2
        
        xxl1=bl1*voxy;
        xxl2=bl2*voxy;
        
        mxl=(yxl1-yxl2)/(xxl1-xxl2);
        bxl=yxl1-mxl*xxl1;
        xxl50=(0.5-bxl)/mxl;
        
        yxr1=Dtcrop(br1,b); % yxr1
        yxr2=Dtcrop(br2,b); % yxr2
        
        xxr1=br1*voxy;
        xxr2=br2*voxy;
        
        mxr=(yxr1-yxr2)/(xxr1-xxr2);
        bxr=yxr1-mxr*xxr1;
        xxr50=(0.5-bxr)/mxr;
        
        FWHM_Y=abs(xxl50-xxr50);
        Sigma_Y=FWHM_Y/2/sqrt(2*log(2))

        %% To locate 10%
        al1=max(find(Dtcrop(a,1:b)<=Dtcmax/10));
        al2=min(find(Dtcrop(a,1:b)>=Dtcmax/10));
        
        ar1=(b-1)+min(find(Dtcrop(a,b:size(Dtcrop,2))<=Dtcmax/10));
        ar2=(b-1)+max(find(Dtcrop(a,b:size(Dtcrop,2))>=Dtcmax/10));
        
        bl1=max(find(Dtcrop(1:a,b)<=Dtcmax/10));
        bl2=min(find(Dtcrop(1:a,b)>=Dtcmax/10));
        
        br1=(a-1)+min(find(Dtcrop(a:size(Dtcrop,1),b)<=Dtcmax/10));
        br2=(a-1)+max(find(Dtcrop(a:size(Dtcrop,1),b)>=Dtcmax/10));
        
        %===========================
        
        yl1=Dtcrop(a,al1); % yl1
        yl2=Dtcrop(a,al2); % yl2
        
        xl1=al1*voxx;
        xl2=al2*voxx;
        
        ml=(yl1-yl2)/(xl1-xl2);
        bl=yl1-ml*xl1;
        xl10=(0.1-bl)/ml;
        
        yr1=Dtcrop(a,ar1); % yr1
        yr2=Dtcrop(a,ar2); % yr2
        
        xr1=ar1*voxx;
        xr2=ar2*voxx;
        
        mr=(yr1-yr2)/(xr1-xr2);
        br=yr1-mr*xr1;
        xr10=(0.1-br)/mr;
        
        FW10M_X=abs(xl10-xr10)
        
        %===========================
        yxl1=Dtcrop(bl1,b); % yxl1
        yxl2=Dtcrop(bl2,b); % yxl2
        
        xxl1=bl1*voxy;
        xxl2=bl2*voxy;
        
        mxl=(yxl1-yxl2)/(xxl1-xxl2);
        bxl=yxl1-mxl*xxl1;
        xxl10=(0.1-bxl)/mxl;
        
        yxr1=Dtcrop(br1,b); % yxr1
        yxr2=Dtcrop(br2,b); % yxr2
        
        xxr1=br1*voxy;
        xxr2=br2*voxy;
        
        mxr=(yxr1-yxr2)/(xxr1-xxr2);
        bxr=yxr1-mxr*xxr1;
        xxr10=(0.1-bxr)/mxr;
        
        FW10M_Y=abs(xxl10-xxr10)
        
        %% To locate 80%
        al1=max(find(Dtcrop(a,1:b)<=Dtcmax/1.25));
        al2=min(find(Dtcrop(a,1:b)>=Dtcmax/1.25));
        
        ar1=(b-1)+min(find(Dtcrop(a,b:size(Dtcrop,2))<=Dtcmax/1.25));
        ar2=(b-1)+max(find(Dtcrop(a,b:size(Dtcrop,2))>=Dtcmax/1.25));
        
        bl1=max(find(Dtcrop(1:a,b)<=Dtcmax/1.25));
        bl2=min(find(Dtcrop(1:a,b)>=Dtcmax/1.25));
        
        br1=(a-1)+min(find(Dtcrop(a:size(Dtcrop,1),b)<=Dtcmax/1.25));
        br2=(a-1)+max(find(Dtcrop(a:size(Dtcrop,1),b)>=Dtcmax/1.25));
        
        %===========================
        
        yl1=Dtcrop(a,al1); % yl1
        yl2=Dtcrop(a,al2); % yl2
        
        xl1=al1*voxx;
        xl2=al2*voxx;
        
        ml=(yl1-yl2)/(xl1-xl2);
        bl=yl1-ml*xl1;
        xl80=(0.8-bl)/ml;
        
        yr1=Dtcrop(a,ar1); % yr1
        yr2=Dtcrop(a,ar2); % yr2
        
        xr1=ar1*voxx;
        xr2=ar2*voxx;
        
        mr=(yr1-yr2)/(xr1-xr2);
        br=yr1-mr*xr1;
        xr80=(0.8-br)/mr;
        
        FW80M_X=abs(xl80-xr80);
        
        %===========================
        yxl1=Dtcrop(bl1,b); % yxl1
        yxl2=Dtcrop(bl2,b); % yxl2
        
        xxl1=bl1*voxy;
        xxl2=bl2*voxy;
        
        mxl=(yxl1-yxl2)/(xxl1-xxl2);
        bxl=yxl1-mxl*xxl1;
        xxl80=(0.8-bxl)/mxl;
        
        yxr1=Dtcrop(br1,b); % yxr1
        yxr2=Dtcrop(br2,b); % yxr2
        
        xxr1=br1*voxy;
        xxr2=br2*voxy;
        
        mxr=(yxr1-yxr2)/(xxr1-xxr2);
        bxr=yxr1-mxr*xxr1;
        xxr80=(0.8-bxr)/mxr;
        
        FW80M_Y=abs(xxl80-xxr80);
        
        %% To locate 20%
        al1=max(find(Dtcrop(a,1:b)<=Dtcmax/5));
        al2=min(find(Dtcrop(a,1:b)>=Dtcmax/5));
        
        ar1=(b-1)+min(find(Dtcrop(a,b:size(Dtcrop,2))<=Dtcmax/5));
        ar2=(b-1)+max(find(Dtcrop(a,b:size(Dtcrop,2))>=Dtcmax/5));
        
        bl1=max(find(Dtcrop(1:a,b)<=Dtcmax/5));
        bl2=min(find(Dtcrop(1:a,b)>=Dtcmax/5));
        
        br1=(a-1)+min(find(Dtcrop(a:size(Dtcrop,1),b)<=Dtcmax/5));
        br2=(a-1)+max(find(Dtcrop(a:size(Dtcrop,1),b)>=Dtcmax/5));
        
        %===========================
        
        yl1=Dtcrop(a,al1); % yl1
        yl2=Dtcrop(a,al2); % yl2
        
        xl1=al1*voxx;
        xl2=al2*voxx;
        
        ml=(yl1-yl2)/(xl1-xl2);
        bl=yl1-ml*xl1;
        xl20=(0.2-bl)/ml;
        
        yr1=Dtcrop(a,ar1); % yr1
        yr2=Dtcrop(a,ar2); % yr2
        
        xr1=ar1*voxx;
        xr2=ar2*voxx;
        
        mr=(yr1-yr2)/(xr1-xr2);
        br=yr1-mr*xr1;
        xr20=(0.2-br)/mr;
        
        FW20M_X=abs(xl20-xr20);
        
        %===========================
        yxl1=Dtcrop(bl1,b); % yxl1
        yxl2=Dtcrop(bl2,b); % yxl2
        
        xxl1=bl1*voxy;
        xxl2=bl2*voxy;
        
        mxl=(yxl1-yxl2)/(xxl1-xxl2);
        bxl=yxl1-mxl*xxl1;
        xxl20=(0.2-bxl)/mxl;
        
        yxr1=Dtcrop(br1,b); % yxr1
        yxr2=Dtcrop(br2,b); % yxr2
        
        xxr1=br1*voxy;
        xxr2=br2*voxy;
        
        mxr=(yxr1-yxr2)/(xxr1-xxr2);
        bxr=yxr1-mxr*xxr1;
        xxr20=(0.2-bxr)/mxr;
        
        FW20M_Y=abs(xxl20-xxr20);
        
        Penumbra_X=(abs(xl20-xl80)+abs(xr20-xr80))/2
        Penumbra_Y=(abs(xxl20-xxl80)+abs(xxr20-xxr80))/2

        %% Outputs
        if ~isempty(size(Fx))
            delete(Fx)
        else
        end
        Fx=uicontrol('Parent',up3,'Units','pixels',...
            'Position',[5*scsx (MM-MMM*3)*scsy 160*scsx 20*scsy],...
            'Style','text',...
            'String',sprintf('%s%5.3f%s','FWHM_X =  ',FWHM_X,'  cm'),...
            'FontName','MS Sans Serif',...
            'FontSize',9*scsx*1.02,...
            'HorizontalAlignment','Left');
        if ~isempty(size(Sx))
            delete(Sx)
        else
        end
        Sx=uicontrol('Parent',up3,'Units','pixels',...
            'Position',[5*scsx (MM-MMM*4)*scsy 160*scsx 20*scsy],...
            'Style','text',...
            'String',sprintf('%s%5.3f%s','Sigma_X =  ',Sigma_X,'  cm'),...
            'FontName','MS Sans Serif',...
            'FontSize',9*scsx*1.02,...
            'HorizontalAlignment','Left');
        if ~isempty(size(Fy))
            delete(Fy)
        else
        end
        Fy=uicontrol('Parent',up3,'Units','pixels',...
            'Position',[5*scsx (MM-MMM*5)*scsy 160*scsx 20*scsy],...
            'Style','text',...
            'String',sprintf('%s%5.3f%s','FWHM_Y =  ',FWHM_Y,'  cm'),...
            'FontName','MS Sans Serif',...
            'FontSize',9*scsx*1.02,...
            'HorizontalAlignment','Left');
        if ~isempty(size(Sy))
            delete(Sy)
        else
        end
        Sy=uicontrol('Parent',up3,'Units','pixels',...
            'Position',[5*scsx (MM-MMM*6)*scsy 160*scsx 20*scsy],...
            'Style','text',...
            'String',sprintf('%s%5.3f%s','Sigma_Y =  ',Sigma_Y,'  cm'),...
            'FontName','MS Sans Serif',...
            'FontSize',9*scsx*1.02,...
            'HorizontalAlignment','Left');
        if ~isempty(size(F10x))
            delete(F10x)
        else
        end
        F10x=uicontrol('Parent',up3,'Units','pixels',...
            'Position',[5*scsx (MM-MMM*7)*scsy 160*scsx 20*scsy],...
            'Style','text',...
            'String',sprintf('%s%5.3f%s','FW10%M_X =  ',FW10M_X,'  cm'),...
            'FontName','MS Sans Serif',...
            'FontSize',9*scsx*1.02,...
            'HorizontalAlignment','Left');
        if ~isempty(size(F10y))
            delete(F10y)
        else
        end
        F10y=uicontrol('Parent',up3,'Units','pixels',...
            'Position',[5*scsx (MM-MMM*8)*scsy 160*scsx 20*scsy],...
            'Style','text',...
            'String',sprintf('%s%5.3f%s','FW10%M_Y =  ',FW10M_Y,'  cm'),...
            'FontName','MS Sans Serif',...
            'FontSize',9*scsx*1.02,...
            'HorizontalAlignment','Left');
        if ~isempty(size(Px))
            delete(Px)
        else
        end
        Px=uicontrol('Parent',up3,'Units','pixels',...
            'Position',[5*scsx (MM-MMM*9)*scsy 160*scsx 20*scsy],...
            'Style','text',...
            'String',sprintf('%s%5.3f%s','Penumbra_X =  ',Penumbra_X,'  cm'),...
            'FontName','MS Sans Serif',...
            'FontSize',9*scsx*1.02,...
            'HorizontalAlignment','Left');
        if ~isempty(size(Py))
            delete(Py)
        else
        end
        Py=uicontrol('Parent',up3,'Units','pixels',...
            'Position',[5*scsx (MM-MMM*10)*scsy 160*scsx 20*scsy],...
            'Style','text',...
            'String',sprintf('%s%5.3f%s','Penumbra_Y =  ',Penumbra_Y,'  cm'),...
            'FontName','MS Sans Serif',...
            'FontSize',9*scsx*1.02,...
            'HorizontalAlignment','Left');
        
        %%===========================
        
        option='1';
        
        % Read time and date
        datetime=fix(clock);
        
        month=datetime(2);
        if month==1 monthstr='Jan'; end;
        if month==2 monthstr='Feb'; end;
        if month==3 monthstr='Mar'; end;
        if month==4 monthstr='Apr'; end;
        if month==5 monthstr='May'; end;
        if month==6 monthstr='Jun'; end;
        if month==7 monthstr='Jul'; end;
        if month==8 monthstr='Aug'; end;
        if month==9 monthstr='Sep'; end;
        if month==10 monthstr='Oct'; end;
        if month==11 monthstr='Nov'; end;
        if month==12 monthstr='Dec'; end;
        %
        ampmstr='AM';
        yearstr=int2str(datetime(1));
        daystr=num2str(datetime(3)/100);
        
        % For 10, 20 and 30 cases. First two elements in string are "0."
        if length(daystr)<4
            daystr(4)='0'; end;
        daystr=daystr(3:4);
        
        % adjust AM-PM and 12AM.
        hournum=(datetime(4));
        if datetime(4) > 12
            hournum = (datetime(4)-12);
            ampmstr='PM';
            % else
            %     hournum = (datetime(4));
            %     ampmstr='AM';
        end;
        if datetime(4)==0
            hournum = 12;
        end;
        
        minnum=datetime(5);
        secnum=datetime(6);
        
        under='_';
        colon=':';
        space=' ';
        comma=',';
        datestr=sprintf('%s%s%s%s%s%s%s%2d%s%02d%s%02d%s%s',daystr,space,...
            monthstr,space,yearstr,comma,space,hournum,colon,minnum,colon,...
            secnum,space,ampmstr);
        if month<10
            datestrs=sprintf('%s-0%d-%s',daystr,month,yearstr);
        else
            datestrs=sprintf('%s-0%d-%s',daystr,month,yearstr);
        end
        
        TRN0='GTR2';
        btype='Spot Scanning';
        
        %% Mesh after Gaussian Fitting
%         clear TwoD
%         
%         up5=uipanel('Parent',fig,'Units','pixels',...
%             'Position',[830*scsx 460*scsy 360*scsx 360*scsy],...
%             'BorderType','line',...
%             'BorderType','etchedout',...
%             'BackGroundColor','w',...
%             'TitlePosition','lefttop','Title','2D Profile');
%         
%         TwoD=axes('Parent',up5,'Units','pixels',...
%             'Position',[0*scsx 0*scsy 360*scsx 360*scsy]);
%         
%         plot(fitresult, [xData, yData], zData, 'Parent',TwoD)
%         camva(TwoD,'auto' );
% %         legend(TwoD, textg, 'Raw data', 'Location', 'SouthEast' );
%         % Label axes
%         % xlabel( 'X (cm)' );
%         % ylabel( 'Y (cm)' );
%         xlabel(TwoD, 'Y (# of pixels)' );
%         ylabel(TwoD, 'X (# of pixels)' );
%         zlabel(TwoD, 'Dose (norm.)' );
%         grid(TwoD,'on');
        
        %% Spot Profiles

%         delete(TwoD);
        TwoD=axes('Parent',up5,'Units','pixels',...
            'Position',[0*scsx 0*scsy 360*scsx 360*scsy]);
        
        contourf(TwoD, xxx, yyy, Dtcrop_o);
%         alpha(0.2);
%         hold(TwoD,'on');
%         contour(TwoD, xxx,  yyy, Dtcrop_,'LineWidth',1,'LineStyle','--');
        view(TwoD,[90 90]);        
        hold(TwoD,'on');
        yy3d=yyy(a,:);xx3d=xxx(:,b);
        plot3(TwoD,zeros(1,size(yyy,2)),yy3d,1.1*ones(1,size(yyy,2)),'--y',xx3d,zeros(1,size(xxx,1)),1.1*ones(size(xxx,1),1),'--y','LineWidth',.5)
        xlabel (TwoD,'X (cm)','FontSize',fsize,'FontWeight','normal','FontName','times','FontAngle','italic');
        ylabel (TwoD,'Y (cm)','FontSize',fsize,'FontWeight','normal','FontName','times','FontAngle','italic');
%         L1=legend(TwoD, 'Raw data', textg, 'Location','SouthEast' );
        L1=legend(TwoD, 'Raw data', 'Location','SouthEast' );
        set(L1,'FontSize',10*scsx);
        axis(TwoD,[min(xx) max(xx) min(yy) max(yy)]);
        box(TwoD,'on');
        axis(TwoD,'off');
        axis(TwoD,'equal');               
        hold(TwoD,'off');

        %Save Figures
        scnsize = get(0,'ScreenSize');
        bdwidth=60;
        pos1  = [bdwidth+15,...
            1/3*scnsize(4)- 5*bdwidth ,...
            1/4*scnsize(3) ,...
            1/4*scnsize(4)];

        ff1=figure('Name','Selected ROI','NumberTitle','off','Position',pos1);
%         imshow(Dt(435+40:980+40, 810-95:1355-95,:));
        imshow(Dt(ROIx1:ROIx2, ROIy1:ROIy2,:));
        if strfind(fst,'.CR2')
            saveas(ff1,[pwd,'\',strrep(fn,'.CR2',''),'_roi','.jpg']);
        elseif strfind(fst,'.tif')
            saveas(ff1,[pwd,'\',strrep(fn,'.tif',''),'_roi','.jpg']);
        end
        delete(ff1)
      
%         
%         ff2=figure('Name','Contour for Selected ROI','NumberTitle','off','Position',pos1)       
%         contourf(xxx, yyy, Dtcrop_o);
%         %         alpha(0.2);
%         hold on;
% %         contour(xxx,  yyy, Dtcrop_o,'LineWidth',1,'LineStyle','--');
%         view([90 90]);
%         hold on;
%         yy3d=yyy(a,:);xx3d=xxx(:,b);
%         plot3(zeros(1,size(yyy,2)),yy3d,1.1*ones(1,size(yyy,2)),'--y',xx3d,zeros(1,size(xxx,1)),1.1*ones(size(xxx,1),1),'--y','LineWidth',.5)
%         xlabel ('Y (cm)','FontSize',fsize,'FontWeight','normal','FontName','times','FontAngle','italic');
%         ylabel ('X (cm)','FontSize',fsize,'FontWeight','normal','FontName','times','FontAngle','italic');
% %         L1=legend('Raw data', textg, 'Location','SouthEast' );
% %         set(L1,'FontSize',10*scsx);
% %         axis([min(xx) max(xx) min(yy) max(yy)]);
%         box on;
%         axis off;
%         axis equal;
%         saveas(ff2,[pwd,'\',strrep(fn,'.CR2',''),'_contour','.jpg']);
%         
%         delete(ff2)
%         
%                 orient(gca,'landscape');
%                 saveas(gca,['Energy',num2str(Energy),'_','ZPOS',num2str(ZPOS),'_','Spot','_Y_Profile_',datestrs,'.jpg']);
                
        %% X Spot Profiles
%         yyd=decimate(yy,15);
%         Dtcropyd=decimate(Dtcropy,15);
%         Dtcropys=interp1(yyd,Dtcropyd,yy,'spline');

%         delete(Xaxis);
        Xaxis=axes('Parent',up6,'Units','pixels',...
            'Position',[60*scsx 50*scsy 320*scsx 320*scsy]);        
                
        mxx1=[abs(min(xx)) max(xx) abs(min(yy)) max(yy)];
        mxx=mxx1(find(max(mxx1)));

        Dtcropyy=Dtcrop_a;
                
        mm=min(find(yy>=-mxx));
        mx=max(find(yy<=mxx));        
%         [Gy,DTA,dosed]=Gamma_Index_Calc(yy(mm:mx),Dtcrop_a(mm:mx),yy(mm:mx),Dtcropy(mm:mx),DTA,dosed,0);
%         Passing_ratey=round(size(find(Gy<1.0))/size(Gy)*100*100)/100

        mc=find(Dtcrop_a==max(Dtcrop_a));
        lsum=sum(Dtcropy(mm:mc));
        rsum=sum(Dtcropy(mc:mx));
        sum(Dtcropy(mm:mx))/2+Dtcropy(mc)
        Symmetryy=(lsum-rsum)/(sum(Dtcropy(mm:mx))/2+Dtcropy(mc))*100;
        
        plot(Xaxis,yy, Dtcropy,'k-',yy, Dtcrop_a,'r:',[0 0],[0 1.1],':k',[-mxx mxx],[0.5 0.5],':b',[-mxx mxx],[0.8 0.8],':b',[-mxx mxx],[0.2 0.2],':b',[-mxx mxx],[0.1 0.1],':b',...
            [xl80-b*voxx xl80-b*voxx],[0.0 0.8],':k',[xr80-b*voxx xr80-b*voxx],[0.0 0.8],':k',[xl20-b*voxx xl20-b*voxx],[0.0 0.2],':k',[xr20-b*voxx xr20-b*voxx],[0.0 0.2],':k');
                
%         delete(xtxt1);
        xtxt1=uicontrol('Parent',up6,'Units','pixels',...
            'Position',[218*scsx 220*scsy 130*scsx 20*scsy],...
            'Style','text',...
            'String',sprintf('%s%5.3f%s','FWHM (X) : ',FWHM_X,' cm'),...
            'FontName','times',...
            'FontSize',fsize,...
            'HorizontalAlignment','Left',...
            'BackGroundColor','w');
%         delete(xtxt2);
        xtxt2=uicontrol('Parent',up6,'Units','pixels',...
            'Position',[230*scsx 200*scsy 110*scsx 20*scsy],...
            'Style','text',...
            'String',sprintf('%s%5.3f%s','Sigma (X) : ',Sigma_X,' cm'),...
            'FontName','times',...
            'FontSize',fsize,...
            'HorizontalAlignment','Left',...
            'BackGroundColor','w');
        xtxt3=uicontrol('Parent',up6,'Units','pixels',...
            'Position',[240*scsx 180*scsy 110*scsx 20*scsy],...
            'Style','text',...
            'String',sprintf('%s%3.3f%s','Symmetry: ',Symmetryy,' %'),...
            'FontName','times',...
            'FontSize',fsize,...
            'HorizontalAlignment','Left',...
            'BackGroundColor','w');
        axis(Xaxis,[-mxx mxx 0 1.1], 'square')%max(Dtcropx)*1.1])
        L2=legend( Xaxis, 'Raw data', textg, 'Location', 'NorthEast' );
        set(L2,'FontSize',10*scsx);
        xlabel (Xaxis,'X (cm)','FontSize',fsize,'FontWeight','normal','FontName','times','FontAngle','italic');
        ylabel (Xaxis,'Normalized','FontSize',fsize,'FontWeight','normal','FontName','times','FontAngle','italic');
%         axis(Xaxis, 'square');
        
%                 orient(gca,'landscape');
%                 saveas(gca,['Energy',num2str(Energy),'_','ZPOS',num2str(ZPOS),'_','Spot','_X_Profile_',datestrs,'.jpg']);
%         %
        %% Y Spot Profiles
%         delete(Yaxis);        
        Yaxis=axes('Parent',up7,'Units','pixels',...
            'Position',[60*scsx 50*scsy 320*scsx 320*scsy]);
        
        Dtcropxx=Dtcrop_b;       
        
        mm=min(find(xx>=-mxx));
        mx=max(find(xx<=mxx));
        
%         [Gx,DTA,dosed]=Gamma_Index_Calc(xx(mm:mx),Dtcrop_b(mm:mx),xx(mm:mx),Dtcropx(mm:mx),DTA,dosed,0);
%         Passing_ratex=round(size(find(Gx<1.0))/size(Gx)*100*100)/100

        mc=find(Dtcrop_b==max(Dtcrop_b));
        lsum=sum(Dtcropx(mm:mc));
        rsum=sum(Dtcropx(mc:mx));
        Symmetryx=(lsum-rsum)/(sum(Dtcropx(mm:mx))/2+Dtcropx(mc))*100;
        
        plot(Yaxis,xx, Dtcropx,'k-',xx, Dtcrop_b,'r:',[0 0],[0 1.1],':k',[-mxx mxx],[0.5 0.5],':b',[-mxx mxx],[0.8 0.8],':b',[-mxx mxx],[0.2 0.2],':b',[-mxx mxx],[0.1 0.1],':b',...
            [xxl80-a*voxy xxl80-a*voxy],[0.0 0.8],':k',[xxr80-a*voxy xxr80-a*voxy],[0.0 0.8],':k',[xxl20-a*voxy xxl20-a*voxy],[0.0 0.2],':k',[xxr20-a*voxy xxr20-a*voxy],[0.0 0.2],':k');
        
        ytxt1=uicontrol('Parent',up7,'Units','pixels',...
            'Position',[218*scsx 220*scsy 130*scsx 20*scsy],...
            'Style','text',...
            'String',sprintf('%s%5.3f%s','FWHM (Y) : ',FWHM_Y,' cm'),...
            'FontName','times',...
            'FontSize',fsize,...
            'HorizontalAlignment','Left',...
            'BackGroundColor','w');
%         delete(ytxt2);
        ytxt2=uicontrol('Parent',up7,'Units','pixels',...
            'Position',[230*scsx 200*scsy 110*scsx 20*scsy],...
            'Style','text',...
            'String',sprintf('%s%5.3f%s','Sigma (Y) : ',Sigma_Y,' cm'),...
            'FontName','times',...
            'FontSize',fsize,...
            'HorizontalAlignment','Left',...
            'BackGroundColor','w');
        ytxt3=uicontrol('Parent',up7,'Units','pixels',...
            'Position',[240*scsx 180*scsy 110*scsx 20*scsy],...
            'Style','text',...
            'String',sprintf('%s%3.3f%s','Symmetry: ',Symmetryx,' %'),...
            'FontName','times',...
            'FontSize',fsize,...
            'HorizontalAlignment','Left',...
            'BackGroundColor','w');
        
%         delete(dat);
        dat=uicontrol('Parent',fig,'Units','pixels',...
            'Position',[920*scsx 5*scsy 250*scsx 20*scsy],...
            'Style','text',...
            'String',sprintf('%s%s','Date & Time : ','dd mm yyyy, hh:mm:ss PM'),...
            'FontName','times',...
            'FontSize',fsize,...
            'HorizontalAlignment','Right');
                
        axis(Yaxis,[-mxx mxx 0 1.1], 'square')%max(Dtcropy)*1.1])
        L3=legend( Yaxis, 'Raw data', textg, 'Location', 'NorthEast' );
        set(L3,'FontSize',10*scsx);
        xlabel (Yaxis,'Y (cm)','FontSize',fsize,'FontWeight','normal','FontName','times','FontAngle','italic');
        ylabel (Yaxis,'Normalized','FontSize',fsize,'FontWeight','normal','FontName','times','FontAngle','italic');
        axis(Yaxis, 'square');
        
%                 orient(gca,'landscape');
%                 saveas(gca,['Energy',num2str(Energy),'_','ZPOS',num2str(ZPOS),'_','Spot','_Y_Profile_',datestrs,'.jpg']);
%         Create a Report file (*.csv)
        if (exist(sprintf('%s_Profile_Report_%s.csv',TRN0,datestrs)))
            % Open MLIC Data file
            ffd=fopen(sprintf('%s_Profile_Report_%s.csv',TRN0,datestrs),'at');
            
            p=0;
            % Get total number of lines in file
            while feof(ffd) == 0
                x=fgetl(ffd);
                p=p+1;
                if isempty(strfind(x,''))
                    break;
                else
                end
            end
            clear x
            
            fclose(ffd);

        else
            % Make and Open Profile Report file
            fod=fopen(sprintf('%s_Profile_Report_%s.csv',TRN0,datestrs),'w');
            %     fprintf(fod,'%s, %s, %s, %s, %s, %s, %s\n','Range(cm)(Requested)','SOBP(cm)(Requested)','Range(cm)(Measured)','SOBP(cm)(Measured)','Distal(cm)','Flatness(%)','Surface_Dose(%)');
            
            fprintf(fod,'%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s\n',...
                'E(MeV)','Z(cm)','NET(mm)','FWHM_X(cm)','FWHM_Y(cm)','Sigma_X(cm)',...
                'Sigma_Y(cm)','Sigma_X_fit(cm)','Sigma_Y_fit(cm)',...
                'FW10%M_X(cm)','FW10%M_Y(cm)','Penumbra_X(cm)','Penumbra_Y(cm)',...
                'CAX_X(cm)','CAX_Y(cm)',...
                'Gaussian Fit','Weights','File Name');
            fprintf(fod,'');    fprintf(fod,'');
            fclose(fod);
        end
        
        ffd=fopen(sprintf('%s_Profile_Report_%s.csv',TRN0,datestrs),'at');
        
        % fprintf(ffd,'\n');
        fprintf(ffd,'%5.3f, ',Energy);fprintf(ffd,'%5.3f, ',ZPOS);
        fprintf(ffd,'%5.3f, ',NET);
        fprintf(ffd,'%5.3f, ',FWHM_X);fprintf(ffd,'%5.3f, ',FWHM_Y);
        fprintf(ffd,'%5.3f, ',Sigma_X);fprintf(ffd,'%5.3f, ',Sigma_Y);
        fprintf(ffd,'%5.3f, ',SigmaX_Fit);fprintf(ffd,'%5.3f, ',SigmaY_Fit);
        fprintf(ffd,'%5.3f, ',FW10M_X);fprintf(ffd,'%5.3f, ',FW10M_Y);
        fprintf(ffd,'%5.3f, ',Penumbra_X);fprintf(ffd,'%5.3f, ',Penumbra_Y);
        fprintf(ffd,'%5.3f, ',CAX_X);fprintf(ffd,'%5.3f, ',CAX_Y);
        if Gaussian_Fit==1
            fprintf(ffd,'%s, ','Single');
            fprintf(ffd,'%5.3f, ',w);
            BB='Single';
        else
            fprintf(ffd,'%s, ','Double');
            fprintf(ffd,'%5.3f/%5.3f, ',w1,w2);
            BB='Double';
        end          
        fprintf(ffd,'%s',strvcat(fn));
        fprintf(ffd,'\n');
        
        fst=strvcat(fn);
        if strfind(fst,'.CR2')
            cr=strfind(fst,'.CR2');
        elseif strfind(fst,'.tif')
            cr=strfind(fst,'.tif')
        end
        File_Name=fst(1,1:cr-1)
	    % saveas(fig,['Spot_Profile_for_',fnn,'_',datestrs,'.jpg']);

        X_prof=[yy' Dtcropyy'];
        Y_prof=[xx' Dtcropxx'];
        
        if ZPOS<1 && ZPOS>0
            x_profile=sprintf('%s%g%s%g%s','X_profile_for_E',round(Energy*10)/10,'Z00',round(ZPOS),'.txt');
            y_profile=sprintf('%s%g%s%g%s','Y_profile_for_E',round(Energy*10)/10,'Z00',round(ZPOS),'.txt');
        else
            x_profile=sprintf('%s%g%s%g%s','X_profile_for_E',round(Energy*10)/10,'Z',round(ZPOS),'.txt');
            y_profile=sprintf('%s%g%s%g%s','Y_profile_for_E',round(Energy*10)/10,'Z',round(ZPOS),'.txt');
        end
        
        save(x_profile, 'X_prof', '-ASCII');
        save(y_profile, 'Y_prof', '-ASCII');


        %% TPS Input
        if W2CADD==2
        elseif W2CADD==1
            if size(Energy,1)<1
            else
                Energy
                %% TPS Input for X Profile
                
                %                 if (exist(sprintf('X_Spot_Profile_in_%s_PBS_Option%s.asc',TRN0,option)))
                %                     % Open Profile Data file
                %
                %                     ffd=fopen(sprintf('X_Spot_Profile_in_%s_PBS_Option%s.asc',TRN0,option),'at');
                %                     fprintf(ffd,'$STOM\n');
                %                 else
                % Generate TPS Depth Dose file
                fod=fopen(sprintf('X_Spot_Profile_in_%s_PBS_E%3.1fMeV_Z%imm.asc',TRN0,Energy,ZPOS),'wt');
                fprintf(fod,'$NUM 001\n');
                fprintf(fod,'# \n');
                fprintf(fod,'# MPTC-ProTom Proton PBS Beam Ranges: \n');
                fprintf(fod,'# Option 1: ');fprintf(fod,'\n');%fprintf(fod,'%s\n',Rang);
                fprintf(fod,'# \n');
                fprintf(fod,'# Spot Profile measurements calibrated with EBT3 Film\n');
                fprintf(fod,'# Spot Profile measurements\n');
                fprintf(fod,'# \n');
                fclose(fod);
                
                ffd=fopen(sprintf('X_Spot_Profile_in_%s_PBS_E%3.1fMeV_Z%imm.asc',TRN0,Energy,ZPOS),'at');
                fprintf(ffd,'$STOM\n');
                %                 end
                
                fprintf(ffd,'# ENERGY ');fprintf(ffd,'%3.1f MeV',Energy);
                % fprintf(ffd,' : Range at Nozzle Entrance = ');fprintf(ffd,'%2.2f',RNE);fprintf(ffd,'cm');
                fprintf(ffd,'\n');
                fprintf(ffd,'# Units:');    fprintf(ffd,'\n');
                fprintf(ffd,'# Energy in [MeV]; X-axis in [mm]; Doses in [cGy/MU];');    fprintf(ffd,'\n');
                fprintf(ffd,'# Nozzle Equivalent Thickness (NET) in [mm]');    fprintf(ffd,'\n');
                fprintf(ffd,'#');    fprintf(ffd,'\n');
                % fprintf(ffd,'# Option ');fprintf(ffd,'%d',option);    fprintf(ffd,'\n');
                fprintf(ffd,'%%');fprintf(ffd,'VERSION 02');    fprintf(ffd,'\n');
                fprintf(ffd,'%%');fprintf(ffd,'Date ');fprintf(ffd,'%s',datestrs);    fprintf(ffd,'\n');
                fprintf(ffd,'%%');fprintf(ffd,'BMTY PRO');    fprintf(ffd,'\n');
                fprintf(ffd,'%%');fprintf(ffd,'TYPE MeasuredSpotFluenceX');    fprintf(ffd,'\n');
                fprintf(ffd,'%%');fprintf(ffd,'ENERGY ');fprintf(ffd,'%2.2f',Energy);    fprintf(ffd,'\n');
                fprintf(ffd,'%%');fprintf(ffd,'NET ');fprintf(ffd,'%2.2f',NET);    fprintf(ffd,'\n');
                fprintf(ffd,'%%');fprintf(ffd,'ZPOS ');fprintf(ffd,'%3.2f',ZPOS);    fprintf(ffd,'\n');
                fprintf(ffd,'%%');fprintf(ffd,'AXIS Z');    fprintf(ffd,'\n');
                
                for n=1:size(Dtcropyy,2)
                    fprintf(ffd,'%s','<+000.0 ');
                    fprintf(ffd,'%s','000.0 ');
                    if yy(1,n)*10<10
                        fprintf(ffd,' ');fprintf(ffd,'%2.4f',yy(1,n)*10);
                    elseif yy(1,n)*10>=10 && yy(1,n)*10<100
                        fprintf(ffd,' ');fprintf(ffd,'%2.4f',yy(1,n)*10);
                    else
                        fprintf(ffd,'%3.1f',yy(1,n)*10);
                    end
                    fprintf(ffd,'%s',' ');
                    if Dtcropyy(1,n)<0;
                        Dtcropyy(1,n)=0;
                    else
                    end
                    % for those with 3cm PMMA
                    %     fprintf(ffd,'%1.8f',gainsD(1,n)/MUd*0.949617939262883);
                    % Without PMMA
                    fprintf(ffd,'%1.8f',Dtcropyy(1,n)/MUd);
                    fprintf(ffd,'%s','>');
                    fprintf(ffd,'\n');
                end
                fprintf(ffd,'$ENOM\n');
                fprintf(ffd,'$ENOF\n');
                fclose(ffd);
                
                %% TPS Input for Y Profile
                
                %                 if (exist(sprintf('Y_Spot_Profile_in_%s_PBS_Option%s.asc',TRN0,option)))
                %                     % Open Depth Dose Data file
                %
                %                     ffd=fopen(sprintf('Y_Spot_Profile_in_%s_PBS_Option%s.asc',TRN0,option),'at');
                %                     fprintf(ffd,'$STOM\n');
                %                 else
                % Generate TPS Depth Dose file
                fod=fopen(sprintf('Y_Spot_Profile_in_%s_PBS_E%3.1fMeV_Z%imm.asc',TRN0,Energy,ZPOS),'wt');
                fprintf(fod,'$NUM 001\n');
                fprintf(fod,'# \n');
                fprintf(fod,'# MPTC-ProTom Proton PBS Beam Ranges: \n');
                fprintf(fod,'# Option 1: ');fprintf(fod,'\n');%fprintf(fod,'%s\n',Rang);
                fprintf(fod,'# \n');
                fprintf(fod,'# Spot Profile measurements calibrated with EBT3 Film\n');
                fprintf(fod,'# Spot Profile measurements\n');
                fprintf(fod,'# \n');
                fclose(fod);
                
                ffd=fopen(sprintf('Y_Spot_Profile_in_%s_PBS_E%3.1fMeV_Z%imm.asc',TRN0,Energy,ZPOS),'at');
                fprintf(ffd,'$STOM\n');
                %                 end
                
                fprintf(ffd,'# ENERGY ');fprintf(ffd,'%3.1f MeV',Energy);
                % fprintf(ffd,' : Range at Nozzle Entrance = ');fprintf(ffd,'%2.2f',RNE);fprintf(ffd,'cm');
                fprintf(ffd,'\n');
                fprintf(ffd,'# Units:');    fprintf(ffd,'\n');
                fprintf(ffd,'# Energy in [MeV]; Y-axis in [mm]; Doses in [cGy/MU];');    fprintf(ffd,'\n');
                fprintf(ffd,'# Nozzle Equivalent Thickness (NET) in [mm]');    fprintf(ffd,'\n');
                fprintf(ffd,'#');    fprintf(ffd,'\n');
                % fprintf(ffd,'# Option ');fprintf(ffd,'%d',option);    fprintf(ffd,'\n');
                fprintf(ffd,'%%');fprintf(ffd,'VERSION 02');    fprintf(ffd,'\n');
                fprintf(ffd,'%%');fprintf(ffd,'Date ');fprintf(ffd,'%s',datestrs);    fprintf(ffd,'\n');
                fprintf(ffd,'%%');fprintf(ffd,'BMTY PRO');    fprintf(ffd,'\n');
                fprintf(ffd,'%%');fprintf(ffd,'TYPE MeasuredSpotFluenceY');    fprintf(ffd,'\n');
                fprintf(ffd,'%%');fprintf(ffd,'ENERGY ');fprintf(ffd,'%2.2f',Energy);    fprintf(ffd,'\n');
                fprintf(ffd,'%%');fprintf(ffd,'NET ');fprintf(ffd,'%2.2f',NET);    fprintf(ffd,'\n');
                fprintf(ffd,'%%');fprintf(ffd,'ZPOS ');fprintf(ffd,'%3.2f',ZPOS);    fprintf(ffd,'\n');
                fprintf(ffd,'%%');fprintf(ffd,'AXIS Z');    fprintf(ffd,'\n');
                
                for n=1:size(Dtcropxx,2)
                    fprintf(ffd,'%s','<+000.0 ');
                    fprintf(ffd,'%s','000.0 ');
                    if xx(1,n)*10<10
                        fprintf(ffd,' ');fprintf(ffd,'%2.4f',xx(1,n)*10);
                    elseif xx(1,n)*10>=10 && xx(1,n)*10<100
                        fprintf(ffd,' ');fprintf(ffd,'%2.4f',xx(1,n)*10);
                    else
                        fprintf(ffd,'%3.1f',xx(1,n)*10);
                    end
                    fprintf(ffd,'%s',' ');
                    if Dtcropxx(1,n)<0;
                        Dtcropxx(1,n)=0;
                    else
                    end
                    % for those with 3cm PMMA
                    %     fprintf(ffd,'%1.8f',gainsD(1,n)/MUd*0.949617939262883);
                    % Without PMMA
                    fprintf(ffd,'%1.8f',Dtcropxx(1,n)/MUd);
                    fprintf(ffd,'%s','>');
                    fprintf(ffd,'\n');
                end
                
                fprintf(ffd,'$ENOM\n');
                fprintf(ffd,'$ENOF\n');
                fclose(ffd);
            end
        end
    end

% Create=zeros(1,1);
%     function W2CAD(src,eventdata)
%         'Has been added'
%         Cr=get(src,'String');
%         Creat=strfind(Cr,'W2CAD');
%         
%         if size(Creat,1)~=0
%             Create=ones(1,1);
%         else
%             Create=zeros(1,1);
%         end
%         if Create==1  && size(xx,1)~=0

W2CADD = 2*ones(1,1);
    function W2CAD(src1,eventdata)
        Select = get(get(src1,'SelectedObject'),'String')
        switch Select
            case 'Yes'
                W2CADD(1,1)=1;
            case 'No'
                W2CADD(1,1)=2;
        end
    end

%% Calculate Spot Profile Deviation in terms of angle and area of 50%
Devi=zeros(1,1);
    function Profile_Dev(src,eventdata)
        dv=get(src,'String');
        dev=strfind(dv,'Dev');
        
        if size(dev,1)~=0
            Devi=ones(1,1);
        else
            Devi=zeros(1,1);
        end
        if Devi==1 && size(xx,1)~=0
             
%             xxx;
%             yyy;
%             Dtcrop_;
%             Dtcrop_o;
            %% Creating the coordinates
            size(Dtcrop)
            [a,b]=find(max(max(Dtcrop))==Dtcrop);
            a=a(1,1);
            b=b(1,1);
            x1=1:size(Dtcrop,1);
            xx1=zeros(size(Dtcrop,1),size(Dtcrop,2));
            
            for n=1:size(xx1,2)
                xx1(:,n)=x1;
            end;
            
            x2=1:size(Dtcrop,2);
            xx2=zeros(size(Dtcrop,1),size(Dtcrop,2));
            
            for n=1:size(xx2,1)
                xx2(n,:)=x2;
            end;
            %
            Dtcrop__=exp(-(xx2-b).^2./(2*(Sigma_X./voxx).^2)-(xx1-a).^2./(2*(Sigma_Y./voxy).^2));
            [a_,b_]=find(max(max(Dtcrop__))==Dtcrop__);
            Dtcmax_=Dtcrop__(a_,b_);

            Hfl=zeros(size(Dtcrop_,1),2);
            Hfr=zeros(size(Dtcrop_,1),2);
            
            xl50g_o=zeros(size(Dtcrop_o,1),1);
            xr50g_o=zeros(size(Dtcrop_o,1),1);
            xl50g__=zeros(size(Dtcrop_o,1),1);
            xr50g__=zeros(size(Dtcrop_o,1),1);
            
            %% To calculate the angle of deviation & locate 50%
            Dtcmax=max(max(Dtcrop_o));
            for n=1:size(Dtcrop_o,1)
                al1g=max(find(Dtcrop_o(n,1:b)<Dtcmax/2));
                al2g=min(find(Dtcrop_o(n,1:b)>Dtcmax/2));
                
                ar1g=(b-1)+min(find(Dtcrop_o(n,b:size(Dtcrop_o,2))<Dtcmax/2));
                ar2g=(b-1)+max(find(Dtcrop_o(n,b:size(Dtcrop_o,2))>Dtcmax/2));
                %===========================
                Hfl(n,1)=xxx(n,al1g);
                Hfl(n,2)=yyy(n,al1g);
                
                Hfr(n,1)=xxx(n,ar1g);
                Hfr(n,2)=yyy(n,ar1g);
                
                al1g=max(find(Dtcrop_o(n,1:b)<Dtcmax/2));
                al2g=min(find(Dtcrop_o(n,1:b)>Dtcmax/2));
                
                %% Find Poits at 50%
                
                ar1g=(b-1)+min(find(Dtcrop_o(n,b:size(Dtcrop_o,2))<Dtcmax/2));
                ar2g=(b-1)+max(find(Dtcrop_o(n,b:size(Dtcrop_o,2))>Dtcmax/2));
                %===========================
                yl1g=Dtcrop_o(n,al1g); % yl1
                yl2g=Dtcrop_o(n,al2g); % yl2
                
                xl1g=al1g*voxx-b*voxx;
                xl2g=al2g*voxx-b*voxx;
                
                mlg=(yl1g-yl2g)/(xl1g-xl2g);
                blg=yl1g-mlg*xl1g;
                xl50g_o(n,1)=(0.5-blg)/mlg;
                
                if xl50g_o(n,1)==0 || isnan(xl50g_o(n,1)) ||...
                        xl50g_o(n,1)==Inf || xl50g_o(n,1)==-Inf
                    xl50g_o(n,1)=0;
                end
                
                yr1g=Dtcrop_o(n,ar1g); % yr1
                yr2g=Dtcrop_o(n,ar2g); % yr2
                
                xr1g=ar1g*voxx-b*voxx;
                xr2g=ar2g*voxx-b*voxx;
                
                mrg=(yr1g-yr2g)/(xr1g-xr2g);
                brg=yr1g-mrg*xr1g;
                xr50g_o(n,1)=(0.5-brg)/mrg;
                
                if xr50g_o(n,1)==0 || isnan(xr50g_o(n,1)) ||...
                        xr50g_o(n,1)==Inf || xr50g_o(n,1)==-Inf
                    xr50g_o(n,1)=0;
                end
                Dtcrop__=Dtcrop_o;
                ar1g=(b_)+min(find(Dtcrop__(n,b_:size(Dtcrop__,2))<Dtcmax_/2));
                ar2g=(b_)+max(find(Dtcrop__(n,b_:size(Dtcrop__,2))>Dtcmax_/2));
                %===========================
                yl1g=Dtcrop__(n,al1g); % yl1
                yl2g=Dtcrop__(n,al2g); % yl2
                
                xl1g=al1g*voxx-b_*voxx;
                xl2g=al2g*voxx-b_*voxx;
                
                mlg=(yl1g-yl2g)/(xl1g-xl2g);
                blg=yl1g-mlg*xl1g;
                xl50g__(n,1)=(0.5-blg)/mlg;
                
                if xl50g__(n,1)==0 || isnan(xl50g__(n,1)) ||...
                        xl50g__(n,1)==Inf || xl50g__(n,1)==-Inf
                    xl50g__(n,1)=0;
                end
                
                yr1g=Dtcrop__(n,ar1g); % yr1
                yr2g=Dtcrop__(n,ar2g); % yr2
                
                xr1g=ar1g*voxx-b_*voxx;
                xr2g=ar2g*voxx-b_*voxx;
                
                mrg=(yr1g-yr2g)/(xr1g-xr2g);
                brg=yr1g-mrg*xr1g;
                xr50g__(n,1)=(0.5-brg)/mrg;
                
                if xr50g__(n,1)==0 || isnan(xr50g__(n,1)) ||...
                        xr50g__(n,1)==Inf || xr50g__(n,1)==-Inf
                    xr50g__(n,1)=0;
                end                
            end

                        
            xl50g_oa=((1:size(xl50g_o,1))-a)*voxy;
            xr50g_oa=((1:size(xl50g_o,1))-a)*voxy;
            xl50g__a=((1:size(xl50g__,1))-a)*voxy;
            xr50g__a=((1:size(xl50g__,1))-a)*voxy;
            
            Area_o=sum((xr50g_o-xl50g_o)*(voxx+voxy)/2);
            Area__=sum((xr50g__-xl50g__)*(voxx+voxy)/2);
            
            First_quadrant=find(xr50g__a<0);
            Second_quadrant=find(xr50g__a>=0);
            Third_quadrant=find(xr50g__a>=0);
            Fourth_quadrant=find(xr50g__a<0);
            
%             Area_subtracted_left=(xr50g__-xr50g_o)*vox;
%             Area_subtracted_left_p=sum(Area_subtracted_left(find(Area_subtracted_left>=0)))
%             Area_subtracted_left_n=sum(Area_subtracted_left(find(Area_subtracted_left<0)))
%             
%             Area_subtracted_right=(xl50g__-xl50g_o)*vox;
%             Area_subtracted_right_p=sum(Area_subtracted_right(find(Area_subtracted_right>=0)))
%             Area_subtracted_right_n=sum(Area_subtracted_right(find(Area_subtracted_right<0)))


            Area_subtracted_1st_quadrant=abs(sum(xl50g__(First_quadrant)-xl50g_o(First_quadrant))*(voxx+voxy)/2/Area__*100);
            Points_1st_quadrant=xl50g__(First_quadrant)-xl50g_o(First_quadrant);
            Area_subtracted_1st_quadrant_p=abs(sum(Points_1st_quadrant(Points_1st_quadrant>=0))*(voxx+voxy)/2/Area__*100);
            Area_subtracted_1st_quadrant_n=abs(sum(Points_1st_quadrant(Points_1st_quadrant<0))*(voxx+voxy)/2/Area__*100);

            Area_subtracted_2nd_quadrant=abs(sum(xl50g__(Second_quadrant)-xl50g_o(Second_quadrant))*(voxx+voxy)/2/Area__*100);
            Points_2nd_quadrant=xl50g__(Second_quadrant)-xl50g_o(Second_quadrant);
            Area_subtracted_2nd_quadrant_p=abs(sum(Points_2nd_quadrant(Points_2nd_quadrant>=0))*(voxx+voxy)/2/Area__*100);
            Area_subtracted_2nd_quadrant_n=abs(sum(Points_2nd_quadrant(Points_2nd_quadrant<0))*(voxx+voxy)/2/Area__*100);

            Area_subtracted_3rd_quadrant=abs(sum(xr50g__(Third_quadrant)-xr50g_o(Third_quadrant))*(voxx+voxy)/2/Area__*100);
            Points_3rd_quadrant=xr50g__(Third_quadrant)-xr50g_o(Third_quadrant);
            Area_subtracted_3rd_quadrant_p=abs(sum(Points_3rd_quadrant(Points_3rd_quadrant<0))*(voxx+voxy)/2/Area__*100);
            Area_subtracted_3rd_quadrant_n=abs(sum(Points_3rd_quadrant(Points_3rd_quadrant>=0))*(voxx+voxy)/2/Area__*100);

            Area_subtracted_4th_quadrant=abs(sum(xr50g__(Fourth_quadrant)-xr50g_o(Fourth_quadrant))*(voxx+voxy)/2/Area__*100);
            Points_4th_quadrant=xr50g__(Fourth_quadrant)-xr50g_o(Fourth_quadrant);
            Area_subtracted_4th_quadrant_p=abs(sum(Points_4th_quadrant(Points_4th_quadrant<0))*(voxx+voxy)/2/Area__*100);
            Area_subtracted_4th_quadrant_n=abs(sum(Points_4th_quadrant(Points_4th_quadrant>=0))*(voxx+voxy)/2/Area__*100);

            Area_subtracted_p=Area_subtracted_1st_quadrant_p+Area_subtracted_2nd_quadrant_p+...
                Area_subtracted_3rd_quadrant_p+Area_subtracted_4th_quadrant_p;
            Area_subtracted_n=Area_subtracted_1st_quadrant_n+Area_subtracted_2nd_quadrant_n+...
                Area_subtracted_3rd_quadrant_n+Area_subtracted_4th_quadrant_n;
            
%             Area_subtracted_Ratio=Area_subtracted/Area__*100

%             figure(2)
%             plot(xl50g_oa,xl50g_o,'k');hold on;
%             plot(xr50g_oa,xr50g_o,'b');hold on;
%             plot(xl50g__a,xl50g__,'r');hold on;
%             plot(xr50g__a,xr50g__,'g')
% %             view([90 90]);    
%             axis equal
%             
            %% Calculated ROI Rotation
            
            Hflz1=Hfl(find(Hfl(:,2)~=0),1);
            Hflz2=Hfl(find(Hfl(:,2)~=0),2);
            
            Hfrz1=Hfr(find(Hfr(:,2)~=0),1);
            Hfrz2=Hfr(find(Hfr(:,2)~=0),2);
            
            Hfld=sqrt(Hflz1.^2+Hflz2.^2);
            Hfrd=sqrt(Hfrz1.^2+Hfrz2.^2);
            
            mxpl = find(max(Hfld)==Hfld);
            mxpr = find(max(Hfrd)==Hfrd);
            
            angle_zl=atan(Hflz2(mxpl)./Hflz1(mxpl))*360/(2*pi);
            angle_zr=atan(Hfrz2(mxpr)./Hfrz1(mxpr))*360/(2*pi);
            rot=max(angle_zl,angle_zr);

            if rot<0
                rot=90+rot;
            else
                rot=rot;
            end
            
            Dtcrop_or=Dtcrop_o;
            
            if 2*a+1<=size(Dtcrop_o,1) && 2*b+1<=size(Dtcrop_o,2)
                Dtcrop_or(1:2*a+1,1:2*b+1)=imrotate(Dtcrop_o(1:2*a+1,1:2*b+1),-rot,'bilinear','crop');
            elseif 2*a+1<=size(Dtcrop_o,1) && 2*b+1>=size(Dtcrop_o,2)
                Dtcrop_or(1:2*a+1,2*b-size(Dtcrop_o,2):size(Dtcrop_o,2))=...
                    imrotate(Dtcrop_o(1:2*a+1,2*b-size(Dtcrop_o,2):size(Dtcrop_o,2)),-rot,'bilinear','crop');
            elseif 2*a+1>=size(Dtcrop_o,1) && 2*b+1<=size(Dtcrop_o,2)
                Dtcrop_or(2*a-size(Dtcrop_o,1):size(Dtcrop_o,1),1:2*b+1)=...
                    imrotate(Dtcrop_o(2*a-size(Dtcrop_o,1):size(Dtcrop_o,1),1:2*b+1),-rot,'bilinear','crop');
            elseif 2*a+1>=size(Dtcrop_o,1) && 2*b+1>=size(Dtcrop_o,2)
                Dtcrop_or(2*a-size(Dtcrop_o,1):size(Dtcrop_o,1),2*b-size(Dtcrop_o,2):size(Dtcrop_o,2))=...
                    imrotate(Dtcrop_o(2*a-size(Dtcrop_o,1):size(Dtcrop_o,1),2*b-size(Dtcrop_o,2):size(Dtcrop_o,2)),-rot,'bilinear','crop');
            end

%             Dtcrop_r=Dtcrop_;
%             
%             if 2*a+1<=size(Dtcrop_,1) && 2*b+1<=size(Dtcrop_,2)
%                 Dtcrop_r(1:2*a+1,1:2*b+1)=imrotate(Dtcrop_(1:2*a+1,1:2*b+1),-rot,'bilinear','crop');
%             elseif 2*a+1<=size(Dtcrop_,1) && 2*b+1>=size(Dtcrop_,2)
%                 Dtcrop_r(1:2*a+1,2*b-size(Dtcrop_,2):size(Dtcrop_,2))=...
%                     imrotate(Dtcrop_(1:2*a+1,2*b-size(Dtcrop_,2):size(Dtcrop_,2)),-rot,'bilinear','crop');
%             elseif 2*a+1>=size(Dtcrop_,1) && 2*b+1<=size(Dtcrop_,2)
%                 Dtcrop_r(2*a-size(Dtcrop_,1):size(Dtcrop_,1),1:2*b+1)=...
%                     imrotate(Dtcrop_(2*a-size(Dtcrop_,1):size(Dtcrop_,1),1:2*b+1),-rot,'bilinear','crop');
%             elseif 2*a+1>=size(Dtcrop_,1) && 2*b+1>=size(Dtcrop_,2)
%                 Dtcrop_r(2*a-size(Dtcrop_,1):size(Dtcrop_,1),2*b-size(Dtcrop_,2):size(Dtcrop_,2))=...
%                     imrotate(Dtcrop_(2*a-size(Dtcrop_,1):size(Dtcrop_,1),2*b-size(Dtcrop_,2):size(Dtcrop_,2)),-rot,'bilinear','crop');
%             end
            
            
            %% Creating GUI for Deviation Calculation
            fig_dev = figure('Position',[0*scsx 0*scsy 640*scsx 400*scsy],...
                'Color',gray,...
                'Resize','off',...
                'NumberTitle','off',...
                'Name',['Needed Angle of Rotation for the Spot of the Energy of ',num2str(Energy),' MeV'],...
                'IntegerHandle','off',...
                'CreateFcn',{@movegui,'center'});
            
            % th = uitoolbar(fig,'Visible','on')
            set(fig_dev,'Toolbar','figure');
            % set(fig,'Menubar','figure');
            
            up_new=uipanel('Parent',fig_dev,'Units','pixels',...
                'Position',[55*scsx 45*scsy 340*scsx 340*scsy],...
                'BorderType','line',...
                'BorderType','etchedout',...
                'BackGroundColor','w',...
                'TitlePosition','lefttop','Title','Rotated Profile');
            
            TwoD_new=axes('Parent',up_new,'Units','pixels',...
                'Position',[0*scsx 0*scsy 340*scsx 340*scsy]);

            contourf(TwoD_new,xxx, yyy, Dtcrop_o,3,'LineWidth',1,'LineStyle','--');
            alpha(0.5);
            hold on;
            contourf(TwoD_new,xxx,  yyy, Dtcrop_or,3);
%             alpha(0.5);
            yy3d=yyy(a,:);xx3d=xxx(:,b);
            hold on;
            plot3(TwoD_new,zeros(1,size(yyy,2)),yy3d,1.1*ones(1,size(yyy,2)),'--y',xx3d,zeros(1,size(xxx,1)),1.1*ones(size(xxx,1),1),'--y','LineWidth',.5)
            hold on;            
            xlabel (TwoD_new,'X (cm)','FontSize',fsize,'FontWeight','normal','FontName','times','FontAngle','italic');
            ylabel (TwoD_new,'Y (cm)','FontSize',fsize,'FontWeight','normal','FontName','times','FontAngle','italic');
            L4=legend(TwoD_new,'Original', 'Rotated', 'Location','SouthEast' );
            set(L4,'FontSize',10*scsx);
            
            if abs(xl20)>=abs(xr20)
                if abs(xxl20)>=abs(xxr20)
                    axis(TwoD_new,[1.2*(xl20-b*voxx) 1.2*abs(xl20-b*voxx) 1.2*(xxl20-a*voxy) 1.2*abs(xxl20-a*voxy)]);
                elseif abs(xxl20)<abs(xxr20)
                     axis(TwoD_new,[1.2*(xl20-b*voxx) 1.2*abs(xl20-b*voxx) -1.2*(xxr20-a*voxy) 1.2*xxr20-a*voxy]);
                end
            elseif abs(xl20)<abs(xr20)
                if abs(xxl20)>=abs(xxr20)
                    axis(TwoD_new,[-1.2*(xr20-b*voxx) 1.2*(xr20-b*voxx) 1.2*(xxl20-a*voxy) 1.2*abs(xxl20-a*voxy)]);
                elseif abs(xxl20)<abs(xxr20)
                     axis(TwoD_new,[-1.2*(xr20-b*voxx) 1.2*(xr20-b*voxx) -1.2*(xxr20-a*voxy) 1.2*(xxr20-a*voxy)]);
                end
            end                

            view(TwoD_new,[90 90]);
            box(TwoD_new,'on');
            axis(TwoD_new,'equal');

            up2_new=uipanel('Parent',fig_dev,'Units','pixels',...
                'Position',[420*scsx 150*scsy 200*scsx 160*scsy],...
                'BorderType','line',...
                'BorderType','etchedout',...
                'TitlePosition','lefttop','Title','Angle of Rotation');
            uicontrol('Parent',up2_new,'Units','pixels',...
                'Position',[5*scsx 120*scsy 100*scsx 20*scsy],...
                'Style','text',...
                'String','Rotated Angle ',...
                'FontName','MS Sans Serif',...
                'FontSize',10*scsx,...
                'FontWeight','bold',...
                'HorizontalAlignment','Left')
            uicontrol('Parent',up2_new,'Units','pixels',...
                'Position',[45*scsx 100*scsy 60*scsx 20*scsy],...
                'Style','text',...
                'String',sprintf('%s','= '),...
                'FontName','MS Sans Serif',...
                'FontSize',10*scsx,...
                'HorizontalAlignment','Left')
            ang_new=uicontrol('Parent',up2_new,'Units','pixels',...
                'Position',[65*scsx 100*scsy 55*scsx 20*scsy],...
                'Style','text',...
                'String',sprintf('%5.4f',rot),...
                'FontName','MS Sans Serif',...
                'FontSize',10*scsx,...
                'ForegroundColor','r',...
                'HorizontalAlignment','Left',...
                'Callback',{@rot2});
            uicontrol('Parent',up2_new,'Units','pixels',...
                'Position',[120*scsx 100*scsy 50*scsx 20*scsy],...
                'Style','text',...
                'String',sprintf('%s',' degrees'),...
                'FontName','MS Sans Serif',...
                'FontSize',10*scsx,...
                'HorizontalAlignment','Left',...
                'Callback',@rot2);
            ang1_new=uicontrol('Parent',up2_new,'Units','pixels',...
                'Position',[55*scsx 76*scsy 60*scsx 20*scsy],...
                'BackgroundColor',[1 1 .7],...
                'FontSize',9*scsx*1.02,...
                'ForegroundColor','r',...
                'Style','edit',...
                'HorizontalAlignment','left',...
                'String',sprintf('%s',''),...
                'Callback',{@rot1});
            uicontrol('Parent',up2_new,...
                'Units','pixels',...
                'Position',[125*scsx 73*scsy 60*scsx 27*scsy],'String','Rotate',...
                'BackgroundColor',gray,...%[.5 .8 .5],...
                'FontName','MS Sans Serif',...
                'FontSize',9*scsx*1.02,...
                'FontWeight','bold',...
                'Callback',@rot2);            
            sl_new=uicontrol('Parent',up2_new,'Units','pixels',...
                'Style','slider',...
                'SliderStep',[0.00277777777777777778 0],...
                'Position',[20*scsx 30*scsy 160*scsx 25*scsy],...
                'BackgroundColor',[1 1 .7],...
                'Min',-180,'Max',180,'Value',rot,...
                'ForegroundColor','r',...
                'String','Angle Adjustment',...
                'Callback',{@rot3});
            uicontrol('Parent',up2_new,'Units','pixels',...
                'Position',[20*scsx 00*scsy 40*scsx 25*scsy],...
                'Style','text',...
                'String','-180',...
                'FontName','MS Sans Serif',...
                'FontSize',10*scsx,...
                'FontWeight','bold',...
                'HorizontalAlignment','Left')            
            uicontrol('Parent',up2_new,'Units','pixels',...
                'Position',[152*scsx 00*scsy 40*scsx 25*scsy],...
                'Style','text',...
                'String','180',...
                'FontName','MS Sans Serif',...
                'FontSize',10*scsx,...
                'FontWeight','bold',...
                'HorizontalAlignment','Left')            
            
        end
    end
    function rot3(hObj,event,ax) %#ok<INUSL>
        % Called to set zlim of surface in figure axes
        % when user moves the slider control
        rott = get(hObj,'Value');
        rot=rott;
        
        if ~isempty(size(ang_new))
            delete(ang_new);
        else
        end
        
        ang_new=uicontrol('Parent',up2_new,'Units','pixels',...
            'Position',[65*scsx 100*scsy 55*scsx 20*scsy],...
            'Style','text',...
            'String',sprintf('%6.4f',rot),...
            'FontName','MS Sans Serif',...
            'FontSize',10*scsx,...
            'ForegroundColor','r',...
            'HorizontalAlignment','Left',...
            'Callback',{@rot2});
        
        if ~isempty(size(ang1_new))
            delete(ang1_new);
        else
        end
        ang1_new=uicontrol('Parent',up2_new,'Units','pixels',...
            'Position',[55*scsx 76*scsy 60*scsx 20*scsy],...
            'BackgroundColor',[1 1 .7],...
            'FontSize',9*scsx*1.02,...
            'ForegroundColor','r',...
            'Style','edit',...
            'HorizontalAlignment','left',...
            'String',sprintf('%6.4f',rot),...
            'Callback',{@rot1});
        
        Dtcrop_or=Dtcrop_o;
        
        if 2*a+1<=size(Dtcrop_o,1) && 2*b+1<=size(Dtcrop_o,2)
            Dtcrop_or(1:2*a+1,1:2*b+1)=imrotate(Dtcrop_o(1:2*a+1,1:2*b+1),-rot,'bilinear','crop');
        elseif 2*a+1<=size(Dtcrop_o,1) && 2*b+1>=size(Dtcrop_o,2)
            Dtcrop_or(1:2*a+1,2*b-size(Dtcrop_o,2):size(Dtcrop_o,2))=...
                imrotate(Dtcrop_o(1:2*a+1,2*b-size(Dtcrop_o,2):size(Dtcrop_o,2)),-rot,'bilinear','crop');
        elseif 2*a+1>=size(Dtcrop_o,1) && 2*b+1<=size(Dtcrop_o,2)
            Dtcrop_or(2*a-size(Dtcrop_o,1):size(Dtcrop_o,1),1:2*b+1)=...
                imrotate(Dtcrop_o(2*a-size(Dtcrop_o,1):size(Dtcrop_o,1),1:2*b+1),-rot,'bilinear','crop');
        elseif 2*a+1>=size(Dtcrop_o,1) && 2*b+1>=size(Dtcrop_o,2)
            Dtcrop_or(2*a-size(Dtcrop_o,1):size(Dtcrop_o,1),2*b-size(Dtcrop_o,2):size(Dtcrop_o,2))=...
                imrotate(Dtcrop_o(2*a-size(Dtcrop_o,1):size(Dtcrop_o,1),2*b-size(Dtcrop_o,2):size(Dtcrop_o,2)),-rot,'bilinear','crop');
        end
        
        if ~isempty(size(TwoD_new))
            delete(TwoD_new);
        else
        end
        
        TwoD_new=axes('Parent',up_new,'Units','pixels',...
            'Position',[0*scsx 0*scsy 340*scsx 340*scsy]);
        %             axis(TwoD_new,'off');
        
        contourf(TwoD_new,xxx, yyy, Dtcrop_o,3,'LineWidth',1,'LineStyle','--');
        alpha(0.5);
        hold on;
        contourf(TwoD_new,xxx,  yyy, Dtcrop_or,3);
        %             alpha(0.5);
        yy3d=yyy(a,:);xx3d=xxx(:,b);
        hold on;
        plot3(TwoD_new,zeros(1,size(yyy,2)),yy3d,1.1*ones(1,size(yyy,2)),'--y',xx3d,zeros(1,size(xxx,1)),1.1*ones(size(xxx,1),1),'--y','LineWidth',.5)
        hold on;
        xlabel (TwoD_new,'X (cm)','FontSize',fsize,'FontWeight','normal','FontName','times','FontAngle','italic');
        ylabel (TwoD_new,'Y (cm)','FontSize',fsize,'FontWeight','normal','FontName','times','FontAngle','italic');
            L5=legend(TwoD_new,'Original', 'Rotated', 'Location','SouthEast' );
            set(L5,'FontSize',10*scsx);
            
            if abs(xl20)>=abs(xr20)
                if abs(xxl20)>=abs(xxr20)
                    axis(TwoD_new,[1.2*(xl20-b*voxx) 1.2*abs(xl20-b*voxx) 1.2*(xxl20-a*voxy) 1.2*abs(xxl20-a*voxy)]);
                elseif abs(xxl20)<abs(xxr20)
                     axis(TwoD_new,[1.2*(xl20-b*voxx) 1.2*abs(xl20-b*voxx) -1.2*(xxr20-a*voxy) 1.2*xxr20-a*voxy]);
                end
            elseif abs(xl20)<abs(xr20)
                if abs(xxl20)>=abs(xxr20)
                    axis(TwoD_new,[-1.2*(xr20-b*voxx) 1.2*(xr20-b*voxx) 1.2*(xxl20-a*voxy) 1.2*abs(xxl20-a*voxy)]);
                elseif abs(xxl20)<abs(xxr20)
                     axis(TwoD_new,[-1.2*(xr20-b*voxx) 1.2*(xr20-b*voxx) -1.2*(xxr20-a*voxy) 1.2*(xxr20-a*voxy)]);
                end
            end                

            view(TwoD_new,[90 90]);
            box(TwoD_new,'on');
            axis(TwoD_new,'equal');

    end
% rot=[];
    function rot1(src2,eventdata)
        mrn2=get(src2,'String');
        %         mrnv2=get(src2,'Value');
        rt=str2num(mrn2);
        if size(rt,1)~=0
            rot=rt;
        else
%             rot=zeros(1,1);
        end 
        if isempty(rot)
            
            if ~isempty(size(ang_new))
                delete(ang_new);
            else
            end
          
            ang_new=uicontrol('Parent',up2_new,'Units','pixels',...
                'Position',[65*scsx 100*scsy 55*scsx 20*scsy],...
                'Style','text',...
                'String',sprintf('%g',angle),...
                'FontName','MS Sans Serif',...
                'FontSize',10*scsx,...
                'ForegroundColor','r',...
                'HorizontalAlignment','Left',...
                'Callback',{@rot2});
        else
            
            if ~isempty(size(ang_new))
                delete(ang_new);
            else
            end
                       
            ang_new=uicontrol('Parent',up2_new,'Units','pixels',...
                'Position',[65*scsx 100*scsy 55*scsx 20*scsy],...
                'Style','text',...
                'String',sprintf('%6.4f',rot),...
                'FontName','MS Sans Serif',...
                'FontSize',10*scsx,...
                'ForegroundColor','r',...
                'HorizontalAlignment','Left',...
                'Callback',{@rot2});

            if ~isempty(size(sl_new))
                delete(sl_new);
            else
            end

            sl_new=uicontrol('Parent',up2_new,'Units','pixels',...
                'Style','slider',...
                'SliderStep',[0.00277777777777777778 0],...
                'Position',[20*scsx 30*scsy 160*scsx 25*scsy],...
                'BackgroundColor',[1 1 .7],...
                'Min',-180,'Max',180,'Value',rot,...
                'ForegroundColor','r',...
                'Callback',{@rot3});
            
            Dtcrop_or=Dtcrop_o;
            
            if 2*a+1<=size(Dtcrop_o,1) && 2*b+1<=size(Dtcrop_o,2)
                Dtcrop_or(1:2*a+1,1:2*b+1)=imrotate(Dtcrop_o(1:2*a+1,1:2*b+1),-rot,'bilinear','crop');
            elseif 2*a+1<=size(Dtcrop_o,1) && 2*b+1>=size(Dtcrop_o,2)
                Dtcrop_or(1:2*a+1,2*b-size(Dtcrop_o,2):size(Dtcrop_o,2))=...
                    imrotate(Dtcrop_o(1:2*a+1,2*b-size(Dtcrop_o,2):size(Dtcrop_o,2)),-rot,'bilinear','crop');
            elseif 2*a+1>=size(Dtcrop_o,1) && 2*b+1<=size(Dtcrop_o,2)
                Dtcrop_or(2*a-size(Dtcrop_o,1):size(Dtcrop_o,1),1:2*b+1)=...
                    imrotate(Dtcrop_o(2*a-size(Dtcrop_o,1):size(Dtcrop_o,1),1:2*b+1),-rot,'bilinear','crop');
            elseif 2*a+1>=size(Dtcrop_o,1) && 2*b+1>=size(Dtcrop_o,2)
                Dtcrop_or(2*a-size(Dtcrop_o,1):size(Dtcrop_o,1),2*b-size(Dtcrop_o,2):size(Dtcrop_o,2))=...
                    imrotate(Dtcrop_o(2*a-size(Dtcrop_o,1):size(Dtcrop_o,1),2*b-size(Dtcrop_o,2):size(Dtcrop_o,2)),-rot,'bilinear','crop');
            end
                        
            if ~isempty(size(TwoD_new))
                delete(TwoD_new);
            else
            end

            TwoD_new=axes('Parent',up_new,'Units','pixels',...
                'Position',[0*scsx 0*scsy 340*scsx 340*scsy]);
            %             axis(TwoD_new,'off');
            
            contourf(TwoD_new,xxx, yyy, Dtcrop_o,3,'LineWidth',1,'LineStyle','--');
            alpha(0.5);
            hold on;
            contourf(TwoD_new,xxx,  yyy, Dtcrop_or,3);
%             alpha(0.5);
            yy3d=yyy(a,:);xx3d=xxx(:,b);
            hold on;
            plot3(TwoD_new,zeros(1,size(yyy,2)),yy3d,1.1*ones(1,size(yyy,2)),'--y',xx3d,zeros(1,size(xxx,1)),1.1*ones(size(xxx,1),1),'--y','LineWidth',.5)
            hold on;
            xlabel (TwoD_new,'X (cm)','FontSize',fsize,'FontWeight','normal','FontName','times','FontAngle','italic');
            ylabel (TwoD_new,'Y (cm)','FontSize',fsize,'FontWeight','normal','FontName','times','FontAngle','italic');
            L6=legend(TwoD_new,'Original', 'Rotated', 'Location','SouthEast' );
            set(L6,'FontSize',10*scsx);
            
            if abs(xl20)>=abs(xr20)
                if abs(xxl20)>=abs(xxr20)
                    axis(TwoD_new,[1.2*(xl20-b*voxx) 1.2*abs(xl20-b*voxx) 1.2*(xxl20-a*voxy) 1.2*abs(xxl20-a*voxy)]);
                elseif abs(xxl20)<abs(xxr20)
                     axis(TwoD_new,[1.2*(xl20-b*voxx) 1.2*abs(xl20-b*voxx) -1.2*(xxr20-a*voxy) 1.2*xxr20-a*voxy]);
                end
            elseif abs(xl20)<abs(xr20)
                if abs(xxl20)>=abs(xxr20)
                    axis(TwoD_new,[-1.2*(xr20-b*voxx) 1.2*(xr20-b*voxx) 1.2*(xxl20-a*voxy) 1.2*abs(xxl20-a*voxy)]);
                elseif abs(xxl20)<abs(xxr20)
                     axis(TwoD_new,[-1.2*(xr20-b*voxx) 1.2*(xr20-b*voxx) -1.2*(xxr20-a*voxy) 1.2*(xxr20-a*voxy)]);
                end
            end                

            view(TwoD_new,[90 90]);
            box(TwoD_new,'on');
            axis(TwoD_new,'equal');
        end
    end
    function rot2(varargin)
        if isempty(rot)
            
            if ~isempty(size(ang_new))
                delete(ang_new);
            else
            end
            
            ang_new=uicontrol('Parent',up2_new,'Units','pixels',...
                'Position',[65*scsx 100*scsy 55*scsx 20*scsy],...
                'Style','text',...
                'String',sprintf('%g',angle),...
                'FontName','MS Sans Serif',...
                'FontSize',10*scsx,...
                'ForegroundColor','r',...
                'HorizontalAlignment','Left',...
                'Callback',{@rot2});
        else
            
            if ~isempty(size(ang_new))
                delete(ang_new);
            else
            end
            
            ang_new=uicontrol('Parent',up2_new,'Units','pixels',...
                'Position',[65*scsx 100*scsy 55*scsx 20*scsy],...
                'Style','text',...
                'String',sprintf('%6.4f',rot),...
                'FontName','MS Sans Serif',...
                'FontSize',10*scsx,...
                'ForegroundColor','r',...
                'HorizontalAlignment','Left',...
                'Callback',{@rot2});    

            if ~isempty(size(sl_new))
                delete(sl_new);
            else
            end

            sl_new=uicontrol('Parent',up2_new,'Units','pixels',...
                'Style','slider',...
                'SliderStep',[0.00277777777777777778 0],...
                'Position',[20*scsx 30*scsy 160*scsx 25*scsy],...
                'BackgroundColor',[1 1 .7],...
                'Min',-180,'Max',180,'Value',rot,...
                'ForegroundColor','r',...
                'Callback',{@rot3});
                        
            Dtcrop_or=Dtcrop_o;
            
            if 2*a+1<=size(Dtcrop_o,1) && 2*b+1<=size(Dtcrop_o,2)
                Dtcrop_or(1:2*a+1,1:2*b+1)=imrotate(Dtcrop_o(1:2*a+1,1:2*b+1),-rot,'bilinear','crop');
            elseif 2*a+1<=size(Dtcrop_o,1) && 2*b+1>=size(Dtcrop_o,2)
                Dtcrop_or(1:2*a+1,2*b-size(Dtcrop_o,2):size(Dtcrop_o,2))=...
                    imrotate(Dtcrop_o(1:2*a+1,2*b-size(Dtcrop_o,2):size(Dtcrop_o,2)),-rot,'bilinear','crop');
            elseif 2*a+1>=size(Dtcrop_o,1) && 2*b+1<=size(Dtcrop_o,2)
                Dtcrop_or(2*a-size(Dtcrop_o,1):size(Dtcrop_o,1),1:2*b+1)=...
                    imrotate(Dtcrop_o(2*a-size(Dtcrop_o,1):size(Dtcrop_o,1),1:2*b+1),-rot,'bilinear','crop');
            elseif 2*a+1>=size(Dtcrop_o,1) && 2*b+1>=size(Dtcrop_o,2)
                Dtcrop_or(2*a-size(Dtcrop_o,1):size(Dtcrop_o,1),2*b-size(Dtcrop_o,2):size(Dtcrop_o,2))=...
                    imrotate(Dtcrop_o(2*a-size(Dtcrop_o,1):size(Dtcrop_o,1),2*b-size(Dtcrop_o,2):size(Dtcrop_o,2)),-rot,'bilinear','crop');
            end
           
            if ~isempty(size(TwoD_new))
                delete(TwoD_new);
            else
            end

            TwoD_new=axes('Parent',up_new,'Units','pixels',...
                'Position',[0*scsx 0*scsy 340*scsx 340*scsy]);
            %             axis(TwoD_new,'off');
            
            contourf(TwoD_new,xxx, yyy, Dtcrop_o,3,'LineWidth',1,'LineStyle','--');
            alpha(0.5);
            hold on;
            contourf(TwoD_new,xxx,  yyy, Dtcrop_or,3);
%             alpha(0.5);
            yy3d=yyy(a,:);xx3d=xxx(:,b);
            hold on;
            plot3(TwoD_new,zeros(1,size(yyy,2)),yy3d,1.1*ones(1,size(yyy,2)),'--y',xx3d,zeros(1,size(xxx,1)),1.1*ones(size(xxx,1),1),'--y','LineWidth',.5)
            hold on;
            xlabel (TwoD_new,'X (cm)','FontSize',fsize,'FontWeight','normal','FontName','times','FontAngle','italic');
            ylabel (TwoD_new,'Y (cm)','FontSize',fsize,'FontWeight','normal','FontName','times','FontAngle','italic');
            L7=legend(TwoD_new,'Original', 'Rotated', 'Location','SouthEast' );
            set(L7,'FontSize',10*scsx);
            
            if abs(xl20)>=abs(xr20)
                if abs(xxl20)>=abs(xxr20)
                    axis(TwoD_new,[1.2*(xl20-b*voxx) 1.2*abs(xl20-b*voxx) 1.2*(xxl20-a*voxy) 1.2*abs(xxl20-a*voxy)]);
                elseif abs(xxl20)<abs(xxr20)
                     axis(TwoD_new,[1.2*(xl20-b*voxx) 1.2*abs(xl20-b*voxx) -1.2*(xxr20-a*voxy) 1.2*xxr20-a*voxy]);
                end
            elseif abs(xl20)<abs(xr20)
                if abs(xxl20)>=abs(xxr20)
                    axis(TwoD_new,[-1.2*(xr20-b*voxx) 1.2*(xr20-b*voxx) 1.2*(xxl20-a*voxy) 1.2*abs(xxl20-a*voxy)]);
                elseif abs(xxl20)<abs(xxr20)
                     axis(TwoD_new,[-1.2*(xr20-b*voxx) 1.2*(xr20-b*voxx) -1.2*(xxr20-a*voxy) 1.2*(xxr20-a*voxy)]);
                end
            end                

            view(TwoD_new,[90 90]);
            box(TwoD_new,'on');
            axis(TwoD_new,'equal');
        end
    end

    function FileOpen(varargin)
        % hObject    handle to FileOpen (see GCBO)
        % eventdata  reserved - to be defined in a future version of MATLAB
        % handles    structure with handles and user data (see GUIDATA)
        filter=get(filter_ed,'String');
        [filename, pathname] = uigetfile( ...
            {filter, 'Profile data File(s)';...
            '*.*','All Files (*.*)'},...
            'Select Profile data File');%,'MultiSelect','on');
        % If "Cancel" is selected then return
        if isequal([filename,pathname],[0,0])
            %     errordlg('You must select a file','Error!','modal')
            return
            % Otherwise construct the fullfilename and Check and load
            % the file
        else
            File = fullfile(pathname,filename);
%             prefix=strrep(filename,'.csv','');
%             % Open RTOG header file
%             fid=fopen(filename,'rt');
%             m=0;
%             while m<1
%                 x=fgetl(fid);
%                 m=m+1;
%                 %                 if isempty(strfind(x,'Measurement'))~=1
%                 delete(fig);
                cd (current_dir);
                Profile_Analyzer(File,filename,pwd);
                %                 else
                %                     errordlg('This is not a MLIC data file!',...
                %                         'Error!','modal');
                %                     return;
                %                 end
%             end
        end
    end

    function QuitW(varargin)
        delete(fig);
    end

    function About_Profile_Analyzer(varargin)
        msgbox('This program is pencil beam spot analyzer and creates TPS configuration files.','Profile Analyzer V.1.3','Help')
    end

    function open(varargin)
        values = get(navlist,'Value');
        if fdir(values).isdir
            if strcmp(fdir(values).name,'.')
                return
            elseif strcmp(fdir(values).name,'..')
                set(dir_popup,'Value',min(2,length(path_cell)))
                dirpopup();
                return
            end
            current_dir = fullfile(current_dir,fdir(values).name);
            history{end+1} = current_dir;
            history = unique(history);
            hist_menus = make_history_cm(hist_cb,hist_cm,hist_menus,...
                history);
            full_filter = fullfile(current_dir,filter);
            path_cell = path2cell(current_dir);
            fdir = filtered_dir(full_filter,re_filter);
            filenames = {fdir.name}';
            filenames = annotate_file_names(filenames,fdir);
            set(dir_popup,'String',path_cell(end:-1:1),'Value',1)
            set(pathbox,'String',current_dir)
            set(navlist,'ListboxTop',1,'Value',[],'String',filenames)
        end
    end

    function clicknav(varargin)
        value = get(navlist,'Value')
        fnn=get(navlist,'String');
        path = get(pathbox,'String');
        fname=fnn(value)        
        fname=strvcat(fname)
        fname_=sprintf('%s%s%s',path,'\',fname)

        % Display Image
               
        if isempty(strfind(fname,'\'))
            if ~isempty(strfind(fname,'.dcm'))
                Dt00=dicominfo(fname_);
                Dt0=dicomread(Dt00);
                Dt_=Dt0;
            else
                Dt0=imread(fname_);
                Dt0=flipdim(Dt0,2);
                if size(Dt0,1)>size(Dt0,2)
                    if Measurement_Type==2
                        Dt1=imresize(Dt0,[1500 NaN]);
                        Dt_=imrotate(Dt1,270,'bilinear');
                    elseif Measurement_Type==1
%                         Dt_=imrotate(Dt0,90,'bilinear');
                        Dt_=Dt0;
                    end
                else
                    if Measurement_Type==2
                        Dt1=imresize(Dt0,[NaN 1500]);
                        Dt_=imrotate(Dt1,270,'bilinear');
                    elseif Measurement_Type==1
%                         Dt_=imrotate(Dt0,90,'bilinear');
                        Dt_=Dt0;
                    end
                end
            end

            if ~isempty(size(ROI))
                delete(ROI);
            else
            end
            if ~isempty(size(up4))
                delete(up4);
            else
            end
            up4=uipanel('Parent',fig,'Units','pixels',...
                'Position',[450*scsx 460*scsy 360*scsx 360*scsy],...
                'BorderType','line',...
                'BorderType','etchedout',...
                'BackGroundColor','w',...
                'TitlePosition','lefttop','Title','Measured Data    ');
            
            ROI=axes('Parent',up4,'Units','pixels',...
                'Position',[0*scsx 0*scsy 360*scsx 360*scsy]);
            axis(ROI,'off');
            if ~isempty(strfind(fname,'.dcm'))
                imshow(Dt_,[0 4000],'Parent',ROI);%,'InitialMagnification','fit');                
            else
                imshow(Dt_,'Parent',ROI);%,'InitialMagnification','fit');
            end
%                     saveas(ROI,['Meas',fname,'_',datestrs,'.jpg']);

        else
            ROI=axes('Parent',up4,'Units','pixels',...
                'Position',[0*scsx 0*scsy 360*scsx 360*scsy]);
            axis(ROI,'off');
      
        end
        nval = length(value);
        dbl_click_fcn = @done;
        switch nval
            case 0
                %                 set([addbut,openbut],'Enable','off')
            case 1
                %                 set(addbut,'Enable','on');
                if fdir(value).isdir
                    %                     set(openbut,'Enable','on')
                    dbl_click_fcn = @open;
                    %                 else
                    %                     set(openbut,'Enable','off')
                end
        end
        if strcmp(get(fig,'SelectionType'),'open')
            dbl_click_fcn();
        end
    end

    function dirpopup(varargin)
        value = get(dir_popup,'Value');
        len = length(path_cell);
        path_cell = path_cell(1:end-value+1);
        if ispc && value == len
            current_dir = '';
            full_filter = filter;
            fdir = struct('name',getdrives,'date',datestr(now),...
                'bytes',0,'isdir',1);
        else
            current_dir = cell2path(path_cell);
            history{end+1} = current_dir;
            history = unique(history);
            hist_menus = make_history_cm(hist_cb,hist_cm,hist_menus,...
                history);
            full_filter = fullfile(current_dir,filter);
            fdir = filtered_dir(full_filter,re_filter);
        end
        filenames = {fdir.name}';
        filenames = annotate_file_names(filenames,fdir);
        set(dir_popup,'String',path_cell(end:-1:1),'Value',1)
        set(pathbox,'String',current_dir)
        set(navlist,'String',filenames,'Value',[])
    end

    function change_path(varargin)
        proposed_path = get(pathbox,'String');
        % Process any directories named '..'.
        proposed_path_cell = path2cell(proposed_path);
        ddots = strcmp(proposed_path_cell,'..');
        ddots(find(ddots) - 1) = true;
        proposed_path_cell(ddots) = [];
        proposed_path = cell2path(proposed_path_cell);
        % Check for existance of directory.
        if ~exist(proposed_path,'dir')
            uiwait(errordlg(['Directory "',proposed_path,...
                '" does not exist.'],'','modal'));
            return
        end
        current_dir = proposed_path;
        history{end+1} = current_dir;
        history = unique(history);
        hist_menus = make_history_cm(hist_cb,hist_cm,hist_menus,history);
        full_filter = fullfile(current_dir,filter);
        path_cell = path2cell(current_dir);
        fdir = filtered_dir(full_filter,re_filter);
        filenames = {fdir.name}';
        filenames = annotate_file_names(filenames,fdir);
        set(dir_popup,'String',path_cell(end:-1:1),'Value',1)
        set(pathbox,'String',current_dir)
        set(navlist,'String',filenames,'Value',[])
    end

    function showfullpath(varargin)
        show_full_path = get(viewfullpath,'Value');
        if show_full_path
            set(pickslist,'String',full_file_picks)
        else
            set(pickslist,'String',file_picks)
        end
    end

    function togglefilter(varargin)
        value = get(showallfiles,'Value');
        if value
            filter = '*';
            %             re_filter = '';
            set(filter_ed,'Enable','off')
        else
            %             if isempty(get(filter_ed,'String')) ||...
            %                     isempty(get(refilter_ed,'String'))
            %                 filter = '*';
            %                 re_filter = '';
            %             else
            filter = sprintf('%s*',get(filter_ed,'String'));
            %                 re_filter = get(refilter_ed,'String');
            %             end
            set(filter_ed,'Enable','on')
        end
        full_filter = fullfile(current_dir,filter);
        fdir = filtered_dir(full_filter,re_filter);
        filenames = {fdir.name}';
        filenames = annotate_file_names(filenames,fdir);
        set(navlist,'String',filenames,'Value',[])
    end

    function setfilspec(varargin)
        filter = sprintf('%s*',get(filter_ed,'String'));
        if isempty(filter)
            filter = '*';
            set(filter_ed,'String',filter)
        end
        % Process file spec if a subdirectory was included.
        [p,f,e] = fileparts(filter);
        if ~isempty(p)
            newpath = fullfile(current_dir,p,'');
            set(pathbox,'String',newpath)
            filter = [f,e];
            if isempty(filter)
                filter = '*';
            end
            set(filter_ed,'String',filter)
            change_path();
        end
        full_filter = fullfile(current_dir,filter);
        fdir = filtered_dir(full_filter,re_filter);
        filenames = {fdir.name}';
        filenames = annotate_file_names(filenames,fdir);
        set(navlist,'String',filenames,'Value',[])
    end

%     function setrefilter(varargin)
%         re_filter = get(refilter_ed,'String');
%         fdir = filtered_dir(full_filter,re_filter);
%         filenames = {fdir.name}';
%         filenames = annotate_file_names(filenames,fdir);
%         set(navlist,'String',filenames,'Value',[])
%     end

    function var1 = get_var_names(varargin)
        % Returns the names of the two variables to plot
        file_list = get(navlist,'String');
        index_selected = get(navlist,'Value');
        if index_selected < 3
            errordlg('You must select a file','Incorrect Selection',...
                'modal')
            %             var1=0;
            return;
        else
            var1 = file_list{index_selected};
        end
    end

    function done(varargin)
%         try
            file_picks = get_var_names();
%             prefix=strrep(file_picks,'.csv','');
            full_file_picks=sprintf('%s\\%s',current_dir,file_picks);
%             % Make sure if the file is a MLIC measurement file
%             fid=fopen(full_file_picks,'rt');
%             m=0;
%             while m<1
%                 x=fgetl(fid);
%                 m=m+1;
%                 %                 if isempty(strfind(x,'Measurement'))~=1
                cd (current_dir);
                %                     delete(fig);
                
                Profile_Analyzer(full_file_picks,file_picks,current_dir);
                %                 else
                %                     errordlg('This is not a MLIC data file',...
                %                         'Error!','modal');
                %                     return;
                %                 end
%             end
%         catch
%             errordlg(lasterr,'File Type Error','modal')
%             return;
%         end
    end

    function cancel(varargin)
        prop.output = 'Close';
        delete(fig)
%         if (exist(sprintf('X_Spot_Profile_in_%s_PBS_E%3.1fMeV_Z%imm.asc',TRN0,Energy,ZPOS)))&& size(yy,1)~=0
%             ffd=fopen(sprintf('X_Spot_Profile_in_%s_PBS_E%3.1fMeV_Z%imm.asc',TRN0,Energy,ZPOS),'at');
%             fprintf(ffd,'$ENOF\n');
%             fclose(ffd);
%         end
%         if (exist(sprintf('Y_Spot_Profile_in_%s_PBS_E%3.1fMeV_Z%imm.asc',TRN0,Energy,ZPOS)))&& size(xx,1)~=0
%             ffd=fopen(sprintf('Y_Spot_Profile_in_%s_PBS_E%3.1fMeV_Z%imm.asc',TRN0,Energy,ZPOS),'at');
%             fprintf(ffd,'$ENOF\n');
%             fclose(ffd);
%         end
    end

    function history_cb(varargin)
        current_dir = history{varargin{3}};
        full_filter = fullfile(current_dir,filter);
        path_cell = path2cell(current_dir);
        fdir = filtered_dir(full_filter,re_filter);
        filenames = {fdir.name}';
        filenames = annotate_file_names(filenames,fdir);
        set(dir_popup,'String',path_cell(end:-1:1),'Value',1)
        set(pathbox,'String',current_dir)
        set(navlist,'ListboxTop',1,'Value',[],'String',filenames)
    end

%% Film or Optical System?
Measurement_Type = 2*ones(1,1);
    function selchk(src1,eventdata)
        models=get(get(src1,'SelectedObject'),'String');
        switch models
            case 'Film'
                Measurement_Type(1,1)=1;
            case 'Optical Dosimeter System'
                Measurement_Type(1,1)=2;
        end
    end
%% Single or Double Gaaussian
Gaussian_Fit = 2*ones(1,1);
    function selchk1(src1,eventdata)
        fits=get(get(src1,'SelectedObject'),'String');
        switch fits
            case 'Single Gaussin Fit'
                Gaussian_Fit(1,1)=1;
            case 'Double Gaussin Fit'
                Gaussian_Fit(1,1)=2;
        end
    end
%% Smoothing
% smoothingx = zeros(1,1);
    function smoothx(src1,~)
        datax=get(src1,'Value');        
        if datax ==1  && size(yy,1)~=0
%                 smoothingx(1,1)=1;
%                 yyd=decimate(yy,25);
%                 Dtcropyd=decimate(Dtcropy,25);
%                 Dtcropys=interp1(yyd,Dtcropyd,yy,'linear');
%                 h=fdesign.lowpass('N,F3dB',3,0.05);
%                 d1 = design(h,'butter');
%                 Dtcropys = filtfilt(d1.sosMatrix,d1.ScaleValues,Dtcropy);
                
                H = fspecial('disk');
                Dtcropys_ = imfilter(Dtcropy,H,'replicate');
                Dtcropys = imfilter(Dtcropys_,H,'replicate');
                
                Dtcropyy=Dtcropys/max(Dtcropys);
                if ~isempty(size(Xaxis))
                    delete(Xaxis);
                else
                end
                
                Xaxis=axes('Parent',up6,'Units','pixels',...
                    'Position',[60*scsx 50*scsy 320*scsx 320*scsy]);
                %                 plot(Xaxis,yy, Dtcropyy,'k-',yy, Dtcrop_a,'r:');
                mxx1=[abs(min(xx)) max(xx) abs(min(yy)) max(yy)];
                mxx=mxx1(find(max(mxx1)));                
                
                mm=min(find(yy>=-mxx));
                mx=max(find(yy<=mxx));
                
%                 [Gy,DTA,dosed]=Gamma_Index_Calc(yy(mm:mx),Dtcrop_a(mm:mx),yy(mm:mx),Dtcropyy(mm:mx),DTA,dosed,0);
%                 Passing_ratey=round(size(find(Gy<1.0))/size(Gy)*100*100)/100

                mc=find(Dtcrop_a==max(Dtcrop_a));
                lsum=sum(Dtcropyy(mm:mc));
                rsum=sum(Dtcropyy(mc:mx));
                Symmetryy=(lsum-rsum)/(sum(Dtcropyy(mm:mx))/2+Dtcropyy(mc))*100;
                
                plot(Xaxis,yy, Dtcropyy,'k-',yy, Dtcrop_a,'r:',[0 0],[0 1.1],':k',[-mxx mxx],[0.5 0.5],':b',[-mxx mxx],[0.8 0.8],':b',[-mxx mxx],[0.2 0.2],':b',[-mxx mxx],[0.1 0.1],':b',...
                    [xl80-b*voxx xl80-b*voxx],[0.0 0.8],':k',[xr80-b*voxx xr80-b*voxx],[0.0 0.8],':k',[xl20-b*voxx xl20-b*voxx],[0.0 0.2],':k',[xr20-b*voxx xr20-b*voxx],[0.0 0.2],':k');
                
                if ~isempty(size(xtxt1))
                    delete(xtxt1);
                else
                end
                xtxt1=uicontrol('Parent',up6,'Units','pixels',...
                    'Position',[218*scsx 220*scsy 130*scsx 20*scsy],...
                    'Style','text',...
                    'String',sprintf('%s%5.3f%s','FWHM (X) : ',FWHM_X,' cm'),...
                    'FontName','times',...
                    'FontSize',fsize,...
                    'HorizontalAlignment','Left',...
                    'BackGroundColor','w');
                if ~isempty(size(xtxt2))
                    delete(xtxt2);
                else
                end
                xtxt2=uicontrol('Parent',up6,'Units','pixels',...
                    'Position',[230*scsx 200*scsy 110*scsx 20*scsy],...
                    'Style','text',...
                    'String',sprintf('%s%5.3f%s','Sigma (X) : ',Sigma_X,' cm'),...
                    'FontName','times',...
                    'FontSize',fsize,...
                    'HorizontalAlignment','Left',...
                    'BackGroundColor','w');
                if ~isempty(size(xtxt3))
                    delete(xtxt3);
                else
                end
                xtxt3=uicontrol('Parent',up6,'Units','pixels',...
                    'Position',[240*scsx 180*scsy 110*scsx 20*scsy],...
                    'Style','text',...
                    'String',sprintf('%s%3.3f%s','Symmetry: ',Symmetryy,' %'),...
                    'FontName','times',...
                    'FontSize',fsize,...
                    'HorizontalAlignment','Left',...
                    'BackGroundColor','w');
                
                mxx1=[abs(min(xx)) max(xx) abs(min(yy)) max(yy)];
                mxx=mxx1(find(max(mxx1)));
                
                axis(Xaxis,[-mxx mxx 0 1.1], 'square')%max(Dtcropx)*1.1])
                L8=legend( Xaxis, 'Raw data', textg, 'Location', 'NorthEast' );
                set(L8,'FontSize',10*scsx);
                
                xlabel (Xaxis,'X (cm)','FontSize',fsize,'FontWeight','normal','FontName','times','FontAngle','italic');
                ylabel (Xaxis,'Normalized','FontSize',fsize,'FontWeight','normal','FontName','times','FontAngle','italic');
        elseif  datax==0 && size(yy,1)~=0
            if ~isempty(size(Xaxis))
                delete(Xaxis);
            else
            end
            Xaxis=axes('Parent',up6,'Units','pixels',...
                'Position',[60*scsx 50*scsy 320*scsx 320*scsy]);
            Dtcropyy=Dtcropy/max(Dtcropy);
            %             plot(Xaxis,yy, Dtcropyy,'k-',yy, Dtcrop_a,'r:');
            mxx1=[abs(min(xx)) max(xx) abs(min(yy)) max(yy)];
            mxx=mxx1(find(max(mxx1)));            
            
            mm=min(find(yy>=-mxx));
            mx=max(find(yy<=mxx));
            
%             [Gy,DTA,dosed]=Gamma_Index_Calc(yy(mm:mx),Dtcrop_a(mm:mx),yy(mm:mx),Dtcropyy(mm:mx),DTA,dosed,0);
%             Passing_ratey=round(size(find(Gy<1.0))/size(Gy)*100*100)/100
            
            mc=find(Dtcrop_a==max(Dtcrop_a));
            lsum=sum(Dtcropyy(mm:mc));
            rsum=sum(Dtcropyy(mc:mx));
            Symmetryy=(lsum-rsum)/(sum(Dtcropyy(mm:mx))/2+Dtcropyy(mc))*100;
            
            plot(Xaxis,yy, Dtcropyy,'k-',yy, Dtcrop_a,'r:',[0 0],[0 1.1],':k',[-mxx mxx],[0.5 0.5],':b',[-mxx mxx],[0.8 0.8],':b',[-mxx mxx],[0.2 0.2],':b',[-mxx mxx],[0.1 0.1],':b',...
                [xl80-b*voxx xl80-b*voxx],[0.0 0.8],':k',[xr80-b*voxx xr80-b*voxx],[0.0 0.8],':k',[xl20-b*voxx xl20-b*voxx],[0.0 0.2],':k',[xr20-b*voxx xr20-b*voxx],[0.0 0.2],':k');
            
            if ~isempty(size(xtxt1))
                delete(xtxt1);
            else
            end
            xtxt1=uicontrol('Parent',up6,'Units','pixels',...
                'Position',[218*scsx 220*scsy 130*scsx 20*scsy],...
                'Style','text',...
                'String',sprintf('%s%5.3f%s','FWHM (X) : ',FWHM_X,' cm'),...
                'FontName','times',...
                'FontSize',fsize,...
                'HorizontalAlignment','Left',...
                'BackGroundColor','w');
            if ~isempty(size(xtxt2))
                delete(xtxt2);
            else
            end
            xtxt2=uicontrol('Parent',up6,'Units','pixels',...
                'Position',[230*scsx 200*scsy 110*scsx 20*scsy],...
                'Style','text',...
                'String',sprintf('%s%5.3f%s','Sigma (X) : ',Sigma_X,' cm'),...
                'FontName','times',...
                'FontSize',fsize,...
                'HorizontalAlignment','Left',...
                'BackGroundColor','w');
            if ~isempty(size(xtxt3))
                delete(xtxt3);
            else
            end
            xtxt3=uicontrol('Parent',up6,'Units','pixels',...
                'Position',[240*scsx 180*scsy 110*scsx 20*scsy],...
                'Style','text',...
                'String',sprintf('%s%3.3f%s','Symmetry: ',Symmetryy,' %'),...
                'FontName','times',...
                'FontSize',fsize,...
                'HorizontalAlignment','Left',...
                'BackGroundColor','w');
            
            mxx1=[abs(min(xx)) max(xx) abs(min(yy)) max(yy)];
            mxx=mxx1(find(max(mxx1)));
            
            axis(Xaxis,[-mxx mxx 0 1.1], 'square')%max(Dtcropx)*1.1])
            L9=legend( Xaxis, 'Raw data', textg, 'Location', 'NorthEast' );
            set(L9,'FontSize',10*scsx);
            xlabel (Xaxis,'X (cm)','FontSize',fsize,'FontWeight','normal','FontName','times','FontAngle','italic');
            ylabel (Xaxis,'Normalized','FontSize',fsize,'FontWeight','normal','FontName','times','FontAngle','italic');
        end
    end

% smoothingy = zeros(1,1);
    function smoothy(src1,~)
        datay=get(src1,'Value');
        if datay==1 && size(xx,1)~=0
            %                 smoothingy(1,1)=1;
            %             xxd=decimate(xx,25);
            %             Dtcropxd=decimate(Dtcropx,25);
            %             Dtcropxs=interp1(xxd,Dtcropxd,xx,'linear');
%             h=fdesign.lowpass('N,F3dB',3,0.05);
%             d1 = design(h,'butter');
%             Dtcropxs = filtfilt(d1.sosMatrix,d1.ScaleValues,Dtcropx);
            H = fspecial('disk');
            Dtcropxs_ = imfilter(Dtcropx,H,'replicate');
            Dtcropxs = imfilter(Dtcropxs_,H,'replicate');
            Dtcropxx=Dtcropxs/max(Dtcropxs);
            if ~isempty(size(Yaxis))
                delete(Yaxis);
            else
            end
            Yaxis=axes('Parent',up7,'Units','pixels',...
                'Position',[60*scsx 50*scsy 320*scsx 320*scsy]);
            %             plot(Yaxis,xx, Dtcropxx,'k-',xx, Dtcrop_b,'r:');
            mxx1=[abs(min(xx)) max(xx) abs(min(yy)) max(yy)];
            mxx=mxx1(find(max(mxx1)));           
            
            mm=min(find(xx>=-mxx));
            mx=max(find(xx<=mxx));
            
%             [Gx,DTA,dosed]=Gamma_Index_Calc(xx(mm:mx),Dtcrop_b(mm:mx),xx(mm:mx),Dtcropxx(mm:mx),DTA,dosed,0);
%             Passing_ratex=round(size(find(Gx<1.0))/size(Gx)*100*100)/100
            
            mc=find(Dtcrop_b==max(Dtcrop_b));
            lsum=sum(Dtcropxx(mm:mc));
            rsum=sum(Dtcropxx(mc:mx));
            Symmetryx=(lsum-rsum)/(sum(Dtcropxx(mm:mx))/2+Dtcropxx(mc))*100;
        
            plot(Yaxis,xx, Dtcropxx,'k-',xx, Dtcrop_b,'r:',[0 0],[0 1.1],':k',[-mxx mxx],[0.5 0.5],':b',[-mxx mxx],[0.8 0.8],':b',[-mxx mxx],[0.2 0.2],':b',[-mxx mxx],[0.1 0.1],':b',...
                [xxl80-a*voxy xxl80-a*voxy],[0.0 0.8],':k',[xxr80-a*voxy xxr80-a*voxy],[0.0 0.8],':k',[xxl20-a*voxy xxl20-a*voxy],[0.0 0.2],':k',[xxr20-a*voxy xxr20-a*voxy],[0.0 0.2],':k');
            
            if ~isempty(size(ytxt1))
                delete(ytxt1);
            else
            end
            ytxt1=uicontrol('Parent',up7,'Units','pixels',...
                'Position',[218*scsx 220*scsy 130*scsx 20*scsy],...
                'Style','text',...
                'String',sprintf('%s%5.3f%s','FWHM (Y) : ',FWHM_Y,' cm'),...
                'FontName','times',...
                'FontSize',fsize,...
                'HorizontalAlignment','Left',...
                'BackGroundColor','w');
            if ~isempty(size(ytxt2))
                delete(ytxt2);
            else
            end
            ytxt2=uicontrol('Parent',up7,'Units','pixels',...
                'Position',[230*scsx 200*scsy 110*scsx 20*scsy],...
                'Style','text',...
                'String',sprintf('%s%5.3f%s','Sigma (Y) : ',Sigma_Y,' cm'),...
                'FontName','times',...
                'FontSize',fsize,...
                'HorizontalAlignment','Left',...
                'BackGroundColor','w');
            if ~isempty(size(ytxt3))
                delete(ytxt3);
            else
            end            
            ytxt3=uicontrol('Parent',up7,'Units','pixels',...
                'Position',[240*scsx 180*scsy 110*scsx 20*scsy],...
                'Style','text',...
                'String',sprintf('%s%3.3f%s','Symmetry: ',Symmetryx,' %'),...
                'FontName','times',...
                'FontSize',fsize,...
                'HorizontalAlignment','Left',...
                'BackGroundColor','w');

            mxx1=[abs(min(xx)) max(xx) abs(min(yy)) max(yy)];
            mxx=mxx1(find(max(mxx1)));
            
            axis(Yaxis,[-mxx mxx 0 1.1], 'square');
            L10=legend(Yaxis, 'Raw data', textg, 'Location', 'NorthEast' );
            set(L10,'FontSize',10*scsx);
            xlabel (Yaxis,'Y (cm)','FontSize',fsize,'FontWeight','normal','FontName','times','FontAngle','italic');
            ylabel (Yaxis,'Normalized','FontSize',fsize,'FontWeight','normal','FontName','times','FontAngle','italic');
        elseif datay==0 && size(xx,1)~=0
            if ~isempty(size(Yaxis))
                delete(Yaxis);
            else
            end
            Yaxis=axes('Parent',up7,'Units','pixels',...
                'Position',[60*scsx 50*scsy 320*scsx 320*scsy]);
            Dtcropxx=Dtcropx/max(Dtcropx);           
            %             plot(Yaxis,xx, Dtcropxx,'k-',xx, Dtcrop_b,'r:');
            mxx1=[abs(min(xx)) max(xx) abs(min(yy)) max(yy)];
            mxx=mxx1(find(max(mxx1)));
            
            mm=min(find(xx>=-mxx));
            mx=max(find(xx<=mxx));
%             
%             [Gx,DTA,dosed]=Gamma_Index_Calc(xx(mm:mx),Dtcrop_b(mm:mx),xx(mm:mx),Dtcropxx(mm:mx),DTA,dosed,0);
%             Passing_ratex=round(size(find(Gx<1.0))/size(Gx)*100*100)/100
            
            mc=find(Dtcrop_b==max(Dtcrop_b));
            lsum=sum(Dtcropxx(mm:mc));
            rsum=sum(Dtcropxx(mc:mx));
            Symmetryx=(lsum-rsum)/(sum(Dtcropxx(mm:mx))/2+Dtcropxx(mc))*100;
                   
            plot(Yaxis,xx, Dtcropxx,'k-',xx, Dtcrop_b,'r:',[0 0],[0 1.1],':k',[-mxx mxx],[0.5 0.5],':b',[-mxx mxx],[0.8 0.8],':b',[-mxx mxx],[0.2 0.2],':b',[-mxx mxx],[0.1 0.1],':b',...
                [xxl80-a*voxy xxl80-a*voxy],[0.0 0.8],':k',[xxr80-a*voxy xxr80-a*voxy],[0.0 0.8],':k',[xxl20-a*voxy xxl20-a*voxy],[0.0 0.2],':k',[xxr20-a*voxy xxr20-a*voxy],[0.0 0.2],':k');
            
            if ~isempty(size(ytxt1))
                delete(ytxt1);
            else
            end
            ytxt1=uicontrol('Parent',up7,'Units','pixels',...
                'Position',[218*scsx 220*scsy 130*scsx 20*scsy],...
                'Style','text',...
                'String',sprintf('%s%5.3f%s','FWHM (Y) : ',FWHM_Y,' cm'),...
                'FontName','times',...
                'FontSize',fsize,...
                'HorizontalAlignment','Left',...
                'BackGroundColor','w');
            if ~isempty(size(ytxt2))
                delete(ytxt2);
            else
            end
            ytxt2=uicontrol('Parent',up7,'Units','pixels',...
                'Position',[230*scsx 200*scsy 110*scsx 20*scsy],...
                'Style','text',...
                'String',sprintf('%s%5.3f%s','Sigma (Y) : ',Sigma_Y,' cm'),...
                'FontName','times',...
                'FontSize',fsize,...
                'HorizontalAlignment','Left',...
                'BackGroundColor','w');
            if ~isempty(size(ytxt3))
                delete(ytxt3);
            else
            end            
            ytxt3=uicontrol('Parent',up7,'Units','pixels',...
                'Position',[240*scsx 180*scsy 110*scsx 20*scsy],...
                'Style','text',...
                'String',sprintf('%s%3.3f%s','Symmetry: ',Symmetryx,' %'),...
                'FontName','times',...
                'FontSize',fsize,...
                'HorizontalAlignment','Left',...
                'BackGroundColor','w');
            
            mxx1=[abs(min(xx)) max(xx) abs(min(yy)) max(yy)];
            mxx=mxx1(find(max(mxx1)));
        
            axis(Yaxis,[-mxx mxx 0 1.1], 'square')%max(Dtcropy)*1.1])
            L11=legend( Yaxis, 'Raw data', textg, 'Location', 'NorthEast' );
            set(L11,'FontSize',10*scsx);
            xlabel (Yaxis,'Y (cm)','FontSize',fsize,'FontWeight','normal','FontName','times','FontAngle','italic');
            ylabel (Yaxis,'Normalized','FontSize',fsize,'FontWeight','normal','FontName','times','FontAngle','italic');            
        end
    end    
end

% -------------------- Subfunctions --------------------

function c = path2cell(p)
% Turns a path string into a cell array of path elements.
c = strread(p,'%s','delimiter','\\/');
if ispc
    c = [{'My Computer'};c];
else
    c = [{filesep};c(2:end)];
end
end


function p = cell2path(c)
% Turns a cell array of path elements into a path string.
if ispc
    p = fullfile(c{2:end},'');
else
    p = fullfile(c{:},'');
end
end


function d = filtered_dir(full_filter,re_filter)
% Like dir, but applies filters and sorting.
p = fileparts(full_filter);
if isempty(p) && full_filter(1) == '/'
    p = '/';
end
if exist(full_filter,'dir')
    c = cell(0,1);
    dfiles = struct('name',c,'date',c,'bytes',c,'isdir',c);
else
    dfiles = dir(full_filter);
end
if ~isempty(dfiles)
    dfiles([dfiles.isdir]) = [];
end
ddir = dir(p);
ddir = ddir([ddir.isdir]);
% Additional regular expression filter.
if nargin > 1 && ~isempty(re_filter)
    if ispc
        no_match = cellfun('isempty',regexpi({dfiles.name},re_filter));
    else
        no_match = cellfun('isempty',regexp({dfiles.name},re_filter));
    end
    dfiles(no_match) = [];
end

% Set navigator style:
%	1 => mix file and directory names
%	2 => means list all files before all directories
%	3 => means list all directories before all files
%	4 => same as 2 except put . and .. directories first
if isunix
    style = 4;
else
    style = 4;
end
switch style
    case 1
        d = [dfiles;ddir];
        [unused,index] = sort({d.name});
        d = d(index);
    case 2
        [unused,index1] = sort({dfiles.name});
        [unused,index2] = sort({ddir.name});
        d = [dfiles(index1);ddir(index2)];
    case 3
        [unused,index1] = sort({dfiles.name});
        [unused,index2] = sort({ddir.name});
        d = [ddir(index2);dfiles(index1)];
    case 4
        [unused,index1] = sort({dfiles.name});
        dot1 = find(strcmp({ddir.name},'.'));
        dot2 = find(strcmp({ddir.name},'..'));
        ddot1 = ddir(dot1);
        ddot2 = ddir(dot2);
        ddir([dot1,dot2]) = [];
        [unused,index2] = sort({ddir.name});
        d = [ddot1;ddot2;ddir(index2);dfiles(index1)];
end
end


function drives = getdrives
% Returns a cell array of drive names on Windows.
letters = char('A':'Z');
num_letters = length(letters);
drives = cell(1,num_letters);
for i = 1:num_letters
    if exist([letters(i),':\'],'dir');
        drives{i} = [letters(i),':'];
    end
end
drives(cellfun('isempty',drives)) = [];
end


function filenames = annotate_file_names(filenames,dir_listing)
% Adds a trailing filesep character to directory names.
fs = filesep;
for i = 1:length(filenames)
    if dir_listing(i).isdir
        filenames{i} = [filenames{i},fs];
    end
end
end

function hist_menus = make_history_cm(cb,hist_cm,hist_menus,history)
% Make context menu for history.
if ~isempty(hist_menus)
    delete(hist_menus)
end
num_hist = length(history);
hist_menus = zeros(1,num_hist);
for i = 1:num_hist
    hist_menus(i) = uimenu(hist_cm,'Label',history{i},...
        'Callback',{cb,i});
end
end


