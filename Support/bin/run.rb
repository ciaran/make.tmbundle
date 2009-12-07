#!/usr/bin/env ruby -wKU

require ENV["TM_SUPPORT_PATH"] + "/lib/tm/executor"
require ENV["TM_SUPPORT_PATH"] + "/lib/tm/save_current_document"
require ENV["TM_SUPPORT_PATH"] + "/lib/escape"

TextMate::Executor.make_project_master_current_document

Dir.chdir(ENV["TM_PROJECT_DIRECTORY"])
ENV["TM_MAKE_FILE"] = ENV["TM_PROJECT_DIRECTORY"] + "/Makefile" if ENV["TM_MAKE_FILE"].nil? or not File.file?(ENV["TM_MAKE_FILE"])

flags = ["-w"]
flags << "-f" + File.basename(ENV["TM_MAKE_FILE"])
flags << ENV["TM_MAKE_FLAGS"] unless ENV["TM_MAKE_FLAGS"].nil?
flags << ENV["TM_MAKE_TARGET"] unless ENV["TM_MAKE_TARGET"].nil?

ENV["TM_DISPLAYNAME"] = ENV["TM_MAKE_TARGET"].nil? ? "default" : ENV["TM_MAKE_TARGET"]

Dir.chdir(File.dirname(ENV["TM_MAKE_FILE"]))

dirs = [ENV['TM_PROJECT_DIRECTORY']]

@grouped_path = nil

module TextMate
  module Executor
    class <<self
      alias_method :old_script_style_header, :script_style_header
      def script_style_header
        old_script_style_header + <<-HTML
<style type="text/css">
/* ========= */
/* = Table = */
/* ========= */

table.file-results {
  width: 100%;
  border: 4px solid rgb(220, 220, 220);
  -webkit-border-radius: 10px;
}
table.file-results.selected, table.file-results.selected:hover {
  border-color: rgb(69, 69, 69);
}
table.file-results:hover {
  border-color: rgb(180, 180, 180);
}

/* ========= */
/* = Links = */
/* ========= */

table.file-results a {
  color: black;
  text-decoration: none;
  font-style: normal;
  font-size: 12px;
  display: block;
}

/* ========== */
/* = Header = */
/* ========== */

table.file-results thead th {
  padding: 5px;
  padding-left: 10px;
  font: bold 15px "Lucida Grande";
}

/* ======== */
/* = Rows = */
/* ======== */

table.file-results tbody tr {
  background-color: rgb(242, 242, 242);
}
table.file-results tbody tr td {
  padding-left: 10px;
}
table.file-results tbody tr.selected, table.file-results tbody tr:hover.selected {
  background-color: rgb(69, 69, 69);
}
table.file-results tbody tr.selected a, table.file-results tbody tr:hover.selected a {
  color: white;
}
table.file-results tbody tr:hover {
  background-color: rgb(100, 100, 100);
}
table.file-results tbody tr:hover a {
  color: white;
}
</style>
<script type="text/javascript" charset="utf-8">
  function makeKeyPressHandler (event)
  {
    switch(event.keyCode)
    {
    case 40: // down
    case 74: // J
      if(event.shiftKey)
        selectNextTable();
      else
        selectNextTableRow();
      break; // J
    case 38: // up
    case 75: // K
      if(event.shiftKey)
        selectPreviousTable();
      else
        selectPreviousTableRow();
      break;
    case 39: // Right
    case 13: // Enter
      openSelection();
      break;
    }
  }

  function setSelected (element, flag)
  {
    if(!element)
      return;
    if(flag)
        element.className += " selected";
    else	element.className = element.className.replace(" selected", "");
  }

  var resultTables = new Array;
  var selectedResultsTable = null;
  var selectedResultsTableRows = new Array;
  var selectedResultsTableRow = null;

  function openSelection ()
  {
    window.location = selectedResultsTableRow.getElementsByTagName('a')[0].href;
  }

  function selectTableRow (index)
  {
    setSelected(selectedResultsTableRow, false);
    selectedResultsTableRow = selectedResultsTableRows[index];
    setSelected(selectedResultsTableRow, true);
    selectedResultsTableRow.scrollIntoView(false);
  }

  function selectNextTable ()
  {
    index = resultTables.indexOf(selectedResultsTable);
    if(++index < resultTables.length)
        selectResultsTable(resultTables[index]);
    else	selectResultsTable(resultTables[0]);
  }

  function selectPreviousTable ()
  {
    index = resultTables.indexOf(selectedResultsTable);
    if(--index >= 0)
        selectResultsTable(resultTables[index]);
    else	selectResultsTable(resultTables[resultTables.length-1]);
    selectTableRow(selectedResultsTableRows.length-1);
  }

  function selectNextTableRow ()
  {
    index = selectedResultsTableRows.indexOf(selectedResultsTableRow);
    if(++index < selectedResultsTableRows.length)
        selectTableRow(index);
    else	selectNextTable();
  }

  function selectPreviousTableRow ()
  {
    index = selectedResultsTableRows.indexOf(selectedResultsTableRow);
    if(--index >= 0)
        selectTableRow(index);
    else	selectPreviousTable();
  }

  function selectResultsTable (table)
  {
    if(table == selectedResultsTable)
      return;
    if(selectedResultsTable)
    {
      setSelected(selectedResultsTable, false);
      setSelected(selectedResultsTableRow, false);
    }

    selectedResultsTable = table;
    selectedResultsTableRows = Array.prototype.slice.call(selectedResultsTable.getElementsByTagName('tbody')[0].getElementsByTagName('tr'));

    setSelected(selectedResultsTable, true);
    selectTableRow(0);
  }

  function initSelection ()
  {
    resultTables = Array.prototype.slice.call(document.getElementsByClassName('file-results'));
    selectResultsTable(resultTables[0]);
    document.body.addEventListener("keydown", makeKeyPressHandler, false);
  }
  document.addEventListener("DOMContentLoaded", initSelection, false);
</script>

        HTML
      end
    end
  end
end

def end_group
  in_group = !@grouped_path.nil?
  @grouped_path = nil
  in_group ? "</tbody></table><br>" : ""
end

TextMate::Executor.run("make", flags, :verb => "Making") do |line, type|
  result = ""
  original_path = nil

  if line =~ /^make.*?: Entering directory `(.*?)'$/ and not $1.nil? and File.directory?($1)
    dirs.unshift($1)
  elsif line =~ /^make.*?: Leaving directory `(.*?)'$/ and not $1.nil? and File.directory?($1)
    dirs.delete($1)
  else
    expanded_path = nil
    if line =~ /^(.*?):(?:(\d+):)?\s*(.*?)$/ and not $1.nil?
      expanded_path = dirs.map{ |dir| File.expand_path($1, dir) }.find{ |path| File.file?path }
      original_path = $1 if expanded_path
    end

    if !expanded_path.nil?
      if expanded_path != @grouped_path
        result << end_group
        result << '<table class="file-results">'
        result << <<-HTML
          <thead>
            <tr>
              <th align="left"><a href="txmt://open?url=file://#{expanded_path}">#{htmlize original_path}</a></th>
            </tr>
          </thead>
          <tbody>
        HTML
        @grouped_path = expanded_path
      end
      result << "<tr><td><a href=\"txmt://open?url=file://#{expanded_path}#{$2.nil? ? '' : "&amp;line=" + $2}\">#{htmlize $3}</a></td></tr>\n"
    else
      result << end_group
    end
  end
  result
end
