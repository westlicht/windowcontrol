' ---------------------------------------------------------------------------
' Simple application for automatic window opening/closing
' written 2009 by Simon Kallweit
' ---------------------------------------------------------------------------


' ---------------------------------------------------------------------------
' Port definitions
' ---------------------------------------------------------------------------

' Digital inputs
define P1 PORT[1]
define P2 PORT[2]
define P3 PORT[3]
define P4 PORT[4]
define P5 PORT[5]
define P6 PORT[6]

' Relais ports
define K1 PORT[7]
define K2 PORT[8]

' Function keys
define F1 PORT[9]
define F2 PORT[10]
define F3 PORT[11]
define F4 PORT[12]

' LEDs
define LED1 PORT[13]
define LED2 PORT[14]
define LED3 PORT[15]
define LED4 PORT[16]

' Temperature inputs
define T1 AD[5]
define T2 AD[6]


' ---------------------------------------------------------------------------
' Port assignments
' ---------------------------------------------------------------------------

' Sensor assignments
define sensor_rain P1
define sensor_wind P2

' Key assignments
define key_mode F1
define key_sample F2
define key_config F3
define key_info F4

' LED assignments
define led_mode LED1
define led_rain LED2
define led_wind LED3
define led_wind_hz LED4

' Relais assignments
define relais_window K1

' Frequency assignments
define wind_freq FREQ2


' ---------------------------------------------------------------------------
' Variables
' ---------------------------------------------------------------------------

' Application modes
define NUM_MODES        3      ' Number of modes
define MODE_CLOSED      0      ' Window is always closed
define MODE_OPEN        1      ' Window is always open
define MODE_AUTO        2      ' Window is automatically opened and closed

' Window states
define WINDOW_CLOSED    0      ' Window is closed
define WINDOW_OPEN      1      ' Window is open

define window_auto BIT[1]      ' Automatic window state
define window_temp BIT[2]      ' Temporary window state
define blink BIT[3]            ' Blink LED state

define mode BYTE[2]            ' Application mode

define temp_out BYTE[3]        ' Outside temperature in degrees
define temp_in BYTE[4]         ' Inside temperature in degrees

define last_second BYTE[5]     ' Last second value (used to detect second ticks)
define window_stable BYTE[6]   ' Number of seconds, the automatic window state was stable

' Default configuration
define CONF_DEF_MAGIC       31276
define CONF_DEF_TEMP_MIN    19
define CONF_DEF_WIND_MAX    4000
define CONF_DEF_TIME_MIN    60
define CONF_DEF_WIND_SAMPLE 0

' Configuration variables
define conf_temp_min BYTE[12]  ' Below that inside temperature the window is closed
define conf_time_min BYTE[13]  ' Number of seconds the window state needs to be stable before switching it
define conf_magic WORD[10]     ' Configuration magic number (use defaults when not set)
define conf_wind_max WORD[11]  ' Above that wind frequency the window is closed
define conf_wind_sample WORD[12] ' Keeps a sample of the wind frequency


' Jump to main
goto main


' Loads the configuration from the eeprom.
#load_config
    open# for read
    input# conf_magic
    input# conf_temp_min
    input# conf_time_min
    input# conf_wind_max
    input# conf_wind_sample
    close#
    if conf_magic = CONF_DEF_MAGIC then return
    ' Load defaults
    conf_temp_min = CONF_DEF_TEMP_MIN
    conf_wind_max = CONF_DEF_WIND_MAX
    conf_time_min = CONF_DEF_TIME_MIN
    conf_wind_sample = CONF_DEF_WIND_SAMPLE
    return

' Stores the configuration to the eeprom.
#save_config
    open# for write
    conf_magic = CONF_MAGIC
    print# conf_magic
    print# conf_temp_min
    print# conf_time_min
    print# conf_wind_max
    print# conf_wind_sample
    close#
    return

' Prints an application banner.
#print_banner
    print
    print "Fensterautomation (0.2)"
    print "-----------------------"
    print
    print "F1 - Modus"
    print "F2 - Wind Frequenz messen und abspeichern"
    print "F4 - Ausgabe Konfiguration und aktuelle Messung"
    print "F3 + F4 - Konfiguration anpassen"
    print
    print "LED1 - aus = Fenster geschlossen (manuell)"
    print "       ein = Fenster offen (manuell)"
    print "       blinkend = Automatisch"
    print "LED2 - aus = Kein Regen"
    print "       ein = Regen"
    print "LED3 - aus = Kein Wind (digital)"
    print "       ein = Wind (digital)"
    print "LED4 - aus = Kein Wind (frequenz)"
    print "       ein = Wind (frequenz)"
    print
    return

' Prints the current configuraiton.
#print_config
    print "Konfiguration"
    print "-------------"
    print
    print "Min. Innentemperatur:", conf_temp_min, "Grad"
    print "Max. Wind:           ", conf_wind_max, "Hz"
    print "Zeit vor Wechsel:    ", conf_time_min, "s"
    print "Wind Messung:        ", conf_wind_sample, "Hz"
    print
    return

' Prints the current measurement.
#print_data
    print "Aktuelle Messung"
    print "----------------"
    print
    print "Aussentemperatur:", temp_out, "Grad"
    print "Innentemperatur: ", temp_in, "Grad"
    if not sensor_rain then print "Regen:           ", "Nein" else print "Regen:           ", "Ja"
    if not sensor_wind then print "Wind:             ", "Nein" else print "Wind:            ", "Ja"
    print "Wind:            ", wind_freq, "Hz"
    print
    return

' Prints the current configuration and measurement and waits for the
' function key to be released.
#print_info
    gosub print_config
    gosub print_data
    #print_info_wait
    if not key_info then goto print_info_wait
    return

' Waits for the function keys to be released and then lets the user
' enter a new configuration.
#configure
    #configure_wait
    if not key_info and not key_config then goto configure_wait
    print "Min. Innentemperatur:", conf_temp_min, "neu: "
    input conf_temp_min
    print "Max. Wind:           ", conf_wind_max, "neu: "
    input conf_wind_max
    print "Zeit vor Wechsel:    ", conf_time_min, "neu: "
    input conf_time_min
    print
    gosub print_config
    gosub save_config
    return

' Updates the inputs.
' Fetches the current temperatures and scales them to degrees.
#update_inputs
    temp_out = T1 SHR 1 - 25
    temp_in = T2 SHR 1 - 25
    return

' Updates the outputs.
#update_outputs
    ' Update mode led
    if mode = MODE_CLOSED then led_mode = 0
    if mode = MODE_OPEN then led_mode = 1
    if mode = MODE_AUTO then led_mode = blink

    ' Update rain led
    led_rain = sensor_rain

    ' Update wind led
    led_wind = sensor_wind

    ' Update wind hz led
    if wind_freq > conf_wind_max then led_wind_hz = 1 else led_wind_hz = 0

    ' Update window relais
    if mode = MODE_CLOSED then relais_window = 0
    if mode = MODE_OPEN then relais_window = 1
    if mode = MODE_AUTO then relais_window = window_auto

    return

' Samples the current wind frequency and waits for the function key to be released.
#sample_wind
    conf_wind_sample = wind_freq
    gosub save_config
    #sample_wind_wait
    if not key_sample then goto sample_wind_wait
    return

' Switches the operation mode and waits for the function key to be released.
#switch_mode
    mode = (mode + 1) MOD NUM_MODES
    gosub update_outputs
    #switch_mode_wait
    if not key_mode then goto switch_mode_wait
    return

' This method is called once every second. It is responsible to update
' the internal states and switch the window.
#update
    ' If it's raining, close the window immediately
    if sensor_rain then goto close_window
    ' If wind is too string, close the window immediately
    if sensor_wind then goto close_window
    
    ' If wind is too strong, close the window immediately
    ' Currently disabled if wind_freq > conf_wind_max then goto close_window

    ' By default, we open the window
    window_temp = WINDOW_OPEN

    ' Close the window if inside temperature is too low
    if temp_in < conf_temp_min then window_temp = WINDOW_CLOSED
    ' Close the window if outside temperature is higher than inside temperature
    if temp_out > temp_in then window_temp = WINDOW_CLOSED

    ' Count seconds for which the temp window state is continuously the opposite of the current state
    if window_temp <> window_auto then window_stable = window_stable + 1 else window_stable = 0
    ' Update window state if temp state was stable for some time
    if window_stable >= conf_time_min then window_auto = window_temp

    goto update_finish

    #close_window
    window_auto = WINDOW_CLOSED
    window_stable = 0
    goto update_finish

    #update_finish
    return

' Main program
#main
    ' Load the configuration
    gosub load_config

    ' Print a banner and the current configuration
    gosub print_banner
    gosub print_config

    ' Initial settings
    mode = MODE_AUTO
    window_auto = WINDOW_CLOSED

    #main_loop
        gosub update_inputs
        if ABS(timer) MOD 20 < 10 then blink = 0 else blink = 1
        if second <> last_second then gosub update
        last_second = second
        if not key_info and not key_config then gosub configure
        if not key_info then gosub print_info
        if not key_sample then gosub sample_wind
        if not key_mode then gosub switch_mode
        gosub update_outputs
        goto main_loop
