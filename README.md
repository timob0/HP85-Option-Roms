HP85 Option ROMs

A project to recreate the graphics commands from the C64 SIMONS Basic as an extension for the HP85 Basic.

The project has been developed for use with the EBTKS board, copying the ROM241 and ROM102 to the roms folder
on the SD card and activating them in CONFIG.TXT enables some new commands. The plotter rom is needed for these
to work as the underlying primitives are used where possible to produce transparent plotter output as well.

The second option rom, printer85, is totally optional. It was split out from simon85 due to its different 
focus as it adds the printing features of the internal thermal printer to external HPIB attached devices,
in particular the ThinkJet is supported.
Activating this option rom re-routes the COPY and PAPER keys to an external printer to fully replace a
broken internal thermal printer.
