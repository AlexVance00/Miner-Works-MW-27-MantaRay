% Library of performance analysis methods

classdef PerformanceUtils
    properties (Constant)
    end

    methods (Static)
        function plotv_nDiagram(vData, nData)
            figv_nDiagram = figure();
            axv_nDiagram = axes(figv_nDiagram);
            plot(axv_nDiagram)
        end
    end
end