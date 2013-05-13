function o = report(varargin)
%function o = report(varargin)
% Report Class Constructor
%
% INPUTS
%   varargin        0 args  : empty report object
%                   1 arg   : must be report object (return a copy of arg)
%                   > 1 args: option/value pairs (see structure below for options)
%
% OUTPUTS
%   o     [report]  report object
%
% SPECIAL REQUIREMENTS
%   none

% Copyright (C) 2013 Dynare Team
%
% This file is part of Dynare.
%
% Dynare is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
%
% Dynare is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with Dynare.  If not, see <http://www.gnu.org/licenses/>.

% default values
o = struct;
o.title = '';
o.orientation = 'portrait';
o.paper = 'a4';
o.margin = 2.5;
o.margin_unit = 'cm';
o.pages = pages();
o.filename = 'report.tex';
o.config = '';
o.showDate = true;
o.compiler = '';

if nargin == 1
    assert(isa(varargin{1}, 'report'), ['@report.report: with one arg, ' ...
                        'you must pass a report object']);
    r = varargin{1};
    return;
elseif nargin > 1
    if round(nargin/2) ~= nargin/2
        error(['@report.report: options must be supplied in name/value ' ...
               'pairs']);
    end

    optNames = lower(fieldnames(o));

    % overwrite default values
    for pair = reshape(varargin, 2, [])
        field = lower(pair{1});
        if any(strmatch(field, optNames, 'exact'))
            o.(field) = pair{2};
        else
            error('@report.report: %s is not a recognized option.', ...
                  field);
        end
    end
end

% Check options provided by user
assert(ischar(o.title), '@report.report: title must be a string');
assert(ischar(o.filename), '@report.report: filename must be a string');
assert(ischar(o.config), '@report.report: config file must be a string');
assert(ischar(o.compiler), '@report.report: compiler file must be a string');
assert(islogical(o.showDate), '@report.report: showDate must be either true or false');
assert(isfloat(o.margin) && o.margin > 0, '@report.report: margin must be a float > 0.');

valid_margin_unit = {'cm', 'in'};
assert(any(strcmp(o.margin_unit, valid_margin_unit)), ...
       ['@report.report: margin_unit must be one of ' strjoin(valid_margin_unit, ' ')]);

valid_paper = {'a4', 'letter'};
assert(any(strcmp(o.paper, valid_paper)), ...
       ['@report.report: paper must be one of ' strjoin(valid_paper, ' ')]);

valid_orientation = {'portrait', 'landscape'};
assert(any(strcmp(o.orientation, valid_orientation)), ...
       ['@report.report: orientation must be one of ' strjoin(valid_orientation, ' ')]);

% Create report object
o = class(o, 'report');
end