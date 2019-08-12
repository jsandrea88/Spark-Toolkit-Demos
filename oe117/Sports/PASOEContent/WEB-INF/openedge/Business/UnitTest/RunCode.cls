/*------------------------------------------------------------------------
    File        : RunCode
    Purpose     : Test harness for runtime code examples
    Author(s)   : Dustin Grau (dugrau@progress.com)
    Created     : Mon Aug 6 10:48:07 EDT 2019
    Notes       :
  ----------------------------------------------------------------------*/

@program FILE(name="RunCode.cls", module="AppServer").
@openapi.openedge.export FILE(type="REST", executionMode="singleton", useReturnValue="false", writeDataSetBeforeImage="false").
@progress.service.resource FILE(name="runcode", URI="/runcode", schemaName="", schemaFile="").

using Progress.Lang.* from propath.
using Progress.Json.ObjectModel.* from propath.

block-level on error undo, throw.

class Business.UnitTest.RunCode use-widget-pool:

    @openapi.openedge.export(type="REST", useReturnValue="false", writeDataSetBeforeImage="false").
    @progress.service.resourceMapping(type="REST", operation="invoke", URI="/busy", alias="busy", mediaType="application/json").
    method public void lookBusy ( input  busyTime as integer,
                                  output elapsed  as integer ):
        /* If no time specified (or is negative) default to 10 seconds. */
        if busyTime eq ? or busyTime le 0 then assign busyTime = 10.

        /* Run a wait loop for some period to imitate long-running code. */
        define variable iStart as datetime no-undo.
        assign iStart = now.
        pause busyTime no-message.

        finally:
            /* Confirm that execution paused for the time stated. */
            assign elapsed = interval(now, iStart, "seconds").
        end finally.
    end method. /* lookBusy */

    @openapi.openedge.export(type="REST", useReturnValue="false", writeDataSetBeforeImage="false").
    @progress.service.resourceMapping(type="REST", operation="invoke", URI="/stop", alias="stop", mediaType="application/json").
    method public void stopCode ( output completed as logical ):
        stop. /* Trigger a stop condition for this code. */

        finally:
            assign completed = true. /* This really should't return with a STOP. */
        end finally.
    end method. /* lookBusy */

end class.