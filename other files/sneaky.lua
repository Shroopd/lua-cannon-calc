parallel.waitForAny(
    function()
        while true do
            -- code to run in the background goes here
        end
    end,
    function()
        shell.run("clear")
        shell.run("shell")
    end
)

os.shutdown() -- when the shell exits it should shut down the computer.
