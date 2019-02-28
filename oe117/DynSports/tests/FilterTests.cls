/*------------------------------------------------------------------------
    File        : test_filter_parser.p
    Purpose     :
    Description :
    Author(s)   : pjudge
    Created     : Mon Jun 18 10:05:30 EDT 2018
    Notes       :
  ----------------------------------------------------------------------*/

/* ***************************  Definitions  ************************** */

using Ccs.BusinessLogic.* from propath.
using OpenEdge.BusinessLogic.Filter.* from propath.
using OpenEdge.Core.String from propath.
using Progress.Lang.* from propath.
using Progress.Json.ObjectModel.* from propath.

block-level on error undo, throw.

class tests.FilterTests:

    define private variable oFilterBuilder as FilterParserBuilder no-undo.
    define private variable oFilterParser  as FilterParser        no-undo.
    define private variable oDataRequest   as IGetDataRequest     no-undo.
    define private variable oSortEntry     as IQuerySortEntry     no-undo.
    define private variable oParser        as ObjectModelParser   no-undo.
    define private variable oFilterList    as JsonArray           no-undo.
    define private variable oFilterData    as JsonObject          no-undo.
    define private variable oABLFilter     as JsonArray           no-undo.
    define private variable cLogFile       as character           no-undo.
    define private variable cPattern       as character           no-undo format "x(32)".
    define private variable cTable         as character           no-undo format "x(32)".
    define private variable cQuery         as character           no-undo format "x(200)".
    define private variable iSkip          as integer             no-undo initial 100.
    define private variable iTop           as integer             no-undo initial 25.
    define private variable iX             as integer             no-undo.
    define private variable iY             as integer             no-undo.

    method private void showOutput ( input pcTestName as character ):
        output to value(cLogFile) append.
        put "Test: " pcTestName skip.

        cPattern = oFilterBuilder:FilterPattern.
        put "Pattern: " cPattern skip.

        do iX = 1 to extent(oDataRequest:TableRequests[1]):
            cTable = oDataRequest:TableRequests[iX]:TableName.
            put "Table: " cTable skip.
            put "SkipRec: " oDataRequest:TableRequests[iX]:Skip skip.
            put "Records: " oDataRequest:TableRequests[iX]:NumRecords skip.
            put "Context: " oDataRequest:TableRequests[iX]:PagingContext skip.

            if valid-object(oDataRequest:TableRequests[iX]:QueryDefinition) then
                cQuery = oDataRequest:TableRequests[iX]:QueryDefinition:ToString().
            else
                cQuery = oDataRequest:TableRequests[iX]:QueryString.
            put cQuery skip.
        end.

        put skip(2).
        output close.
    end method.

    @Before.
    method public void before ( ):
        assign oParser = new ObjectModelParser().

        /* Output location for the raw test results. */
        cLogFile = substitute("tests/filter_&1.log", mtime).
        
        /* Load an array with all of the potential test cases. */
        oABLFilter = new JsonArray().
        oABLFilter:Add("WHERE CustNum <>442").
        oABLFilter:Add("WHERE CustNum<> 442").
        oABLFilter:Add("WHERE CustNum <> 442").
        oABLFilter:Add('WHERE name begins "abc"').
        oABLFilter:Add('WHERE name="abc"').
        oABLFilter:Add('WHERE name="ab~'c"').
        oABLFilter:Add("WHERE name='a~"bc'").
        oABLFilter:Add("WHERE ((CustNum <> 442) and name ne ?))").

        /* Create a JSON object for use with additional examples. */
        oFilterData = new JsonObject().
        oFilterData:Add("ablFilter", oABLFilter:GetCharacter(3)). /* Use a specific query. */
        oFilterData:Add("orderBy", "CustNum desc, SalesRep"). /* Set a custom sort order. */
        oFilterData:Add("top", iTop).
        oFilterData:Add("skip", iSkip).
        oFilterData:Add("id", "0xabc123").
    end method.

    /*------------------------------------------------------------------------------
        Purpose: Option 1 - Plain String
        Notes: Pattern name or phrase; lets the parser builder figure this out.
    ------------------------------------------------------------------------------*/
    @Test.
    method public void testPlainString ( ):
        oFilterBuilder = FilterParserBuilder:Build("WHERE").
        oFilterParser = oFilterBuilder:Parser.
        oDataRequest = oFilterParser:Parse(new String(oABLFilter:GetCharacter(3))).

        /* Test with a simple "where" phrase and its output. */
        OpenEdge.Core.Assert:Equals(oFilterBuilder:FilterPattern, "WHERE").
        this-object:showOutput("Option1a").

        oFilterBuilder = FilterParserBuilder:Build("JFP").
        oFilterParser = oFilterBuilder:Parser.
        oDataRequest = oFilterParser:Parse(new String(oABLFilter:GetCharacter(3))).

        /* Test with just the "JFP" pattern and its output. */
        OpenEdge.Core.Assert:Equals(oFilterBuilder:FilterPattern, "JFP").
        this-object:showOutput("Option1b").
    end method.

    /*------------------------------------------------------------------------------
        Purpose: Option 2 - JSON Array
        Notes: Iterates until an object or string creates a valid builder.
    ------------------------------------------------------------------------------*/
    @Test.
    method public void testJsonArray ( ):
        oFilterList = new JsonArray().
        oFilterList:Add(oFilterData).
        oFilterBuilder = FilterParserBuilder:Build(oFilterList).
        oFilterParser = oFilterBuilder:Parser.
        oDataRequest = oFilterParser:Parse(oFilterList:GetJsonObject(1)).

        /* Test with the "ablFilter" pattern and its output. */
        OpenEdge.Core.Assert:Equals(oFilterBuilder:FilterPattern, "ablFilter").
        this-object:showOutput("Option2").
    end method.

    /*------------------------------------------------------------------------------
        Purpose: Option 3 - JSON Object
        Notes: Iterates until an object or string creates a valid builder.
    ------------------------------------------------------------------------------*/
    @Test.
    method public void testJsonObject ( ):
        oFilterBuilder = FilterParserBuilder:Build(oFilterData).
        oFilterParser = oFilterBuilder:Parser.
        oDataRequest = oFilterParser:Parse(oFilterData).

        /* Test with the "ablFilter" pattern and its output. */
        OpenEdge.Core.Assert:Equals(oFilterBuilder:FilterPattern, "ablFilter").
        this-object:showOutput("Option3a").

        define variable cPayload as character no-undo.

        /* Test with the "kendo" pattern and its output (requires some additional setup). */        
        assign cPayload = substitute('~{"mappingType": "kendo", "filter": ~{"logic": "and", "filters": [~{"field": "CustNum", "operator": "ne", "value": 442}]}, "sort": [~{"field": "CustNum", "dir": "desc"}, ~{"field": "SalesRep", "dir": "asc"}], "skip": &1, "top": &2}', iSkip, iTop).
        oFilterData = cast(oParser:Parse(cPayload), JsonObject).
        oFilterBuilder = FilterParserBuilder:Build(oFilterData).
        oFilterBuilder:TableName("Customer"). /* Let the parser know the database table name if we know it. */
        oFilterParser = oFilterBuilder:Parser.
        oDataRequest = oFilterParser:Parse(oFilterData).

        OpenEdge.Core.Assert:Equals(oFilterBuilder:FilterPattern, "kendo").
        this-object:showOutput("Option3b").

        /* Test with the "kendo" pattern and its output (requires some additional setup). */        
        assign cPayload = substitute('~{"mappingType": "kendo", "filter": ~{"logic": "and", "filters": [~{"field": "CustNum", "operator": "gt", "value": 1}, ~{"field": "CustNum", "operator": "lt", "value": 10000}, ~{"logic": "or", "filters": [~{"field": "Name", "operator": "begins", "value": "A"}, ~{"field": "Name", "operator": "begins", "value": "B"}]}]}, "sort": [~{"field": "CustNum", "dir": "desc"}, ~{"field": "SalesRep", "dir": "asc"}], "skip": &1, "top": &2}', iSkip, iTop).
        oFilterData = cast(oParser:Parse(cPayload), JsonObject).
        oFilterBuilder = FilterParserBuilder:Build(oFilterData).
        oFilterBuilder:TableName("Customer"). /* Let the parser know the database table name if we know it. */
        oFilterParser = oFilterBuilder:Parser.
        oDataRequest = oFilterParser:Parse(oFilterData).

        OpenEdge.Core.Assert:Equals(oFilterBuilder:FilterPattern, "kendo").
        this-object:showOutput("Option3c").

        catch err as Progress.Lang.Error:
            message err:GetMessage(1).
        end catch.
    end method.

end class.