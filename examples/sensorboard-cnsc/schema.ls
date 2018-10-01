/** Please Don't Modify These Lines Below   */
/** --------------------------------------- */
class SchemaBaseClass
  ->
    @sensors = {}
    @actuators = {}

  declare-sensors: (types-and-identities) ->
    {sensors} = self = @
    for st, identities of types-and-identities
      self.sensors[st] = {}
      for id in identities
        self.sensors[st][id] = {}


SchemaBaseClass = SCHEMA_BASE_CLASS if SCHEMA_BASE_CLASS?
/** --------------------------------------- */
/** Please Don't Modify These Lines Above   */


class Sensorboard extends SchemaBaseClass
  humidity:
    * field: \temperature , unit: \degree , value: [\float, [-40.0, 120.0]] , $prefix: <[T]>
    * field: \humidity    , unit: \%rH    , value: [\int, [0, 100]]         , $prefix: <[H]>

  iaq_co2:
    * field: \co2         , unit: \ppm    , value: [\int, [400, 4000]]      , $prefix: \VC  , $keep_error: yes
    * field: \tvoc        , unit: \ppb    , value: [\int, [125, 600]]       , $prefix: \V   , $keep_error: yes

  ndir_co2:
    * field: \co2         , unit: \ppm    , value: [\int, [400, 10000]]     , $prefix: \C   , $keep_error: yes
      ...

  barometric_pressure:
    * field: \pressure    , unit: \hPa    , value: [\int, [260, 1260]]      , $prefix: \P   , $keep_error: yes
      ...

  iaq_dust:
    * field: \dust        , unit: \µg/m^3 , value: [\int, [0, 800]]         , $prefix: \D   , $keep_error: yes
      ...

  iaq_dust_adv:
    # The density of particles in standard particle(CF=1) environment
    * field: \pm1p0sp     , unit: \µg/m^3 , value: [\int, [0, 1000]]        , $prefix: \PM1P0S
    * field: \pm2p5sp     , unit: \µg/m^3 , value: [\int, [0, 1000]]        , $prefix: \PM2P5S
    * field: \pm10sp      , unit: \µg/m^3 , value: [\int, [0, 1000]]        , $prefix: \PM10S
    # The density of particles in atmsphere environment. indoor air quality reference.
    * field: \pm1p0atm    , unit: \µg/m^3 , value: [\int, [0, 1000]]        , $prefix: \PM1P0A
    * field: \pm2p5atm    , unit: \µg/m^3 , value: [\int, [0, 1000]]        , $prefix: \PM2P5A
    * field: \pm10atm     , unit: \µg/m^3 , value: [\int, [0, 1000]]        , $prefix: \PM10A
    # The amounts of the particles in 0.1 L volume.
    * field: \pm0p3l                      , value: [\int, [0, 50000]]       , $prefix: \PM0P3L
    * field: \pm0p5l                      , value: [\int, [0, 50000]]       , $prefix: \PM0P5L
    * field: \pm1p0l                      , value: [\int, [0, 50000]]       , $prefix: \PM1P0L
    * field: \pm2p5l                      , value: [\int, [0, 50000]]       , $prefix: \PM2P5L
    * field: \pm5l                        , value: [\int, [0, 50000]]       , $prefix: \PM5L
    * field: \pm10l                       , value: [\int, [0, 50000]]       , $prefix: \PM10L

  sound:
    * field: \value       , unit: \db     , value: [\int, [0, 100]]         , $prefix: \S
      ...

  rom:
    * field: \value       , value: [\int, [1601010000, 4212312359]]         , $prefix: \Z
      ...

  emoji:
    * field: \value           , $prefix: \LM1, value: [\int, [0, 600]]
    * field: \mode            , $prefix: \LM2, value: [\enum, <[ascii pre_installed_image post_installed_image number pre_installed_animation post_installed_animation]>]
    * field: \index           , $prefix: \LM3, value: [\int, [0, 128]]
    * field: \intensity       , $prefix: \LMI, value: [\int, [0, 15]], writeable: yes
    * field: \operation_mode  , $prefix: \LMM, value: [\enum, <[normal reset]>]  # reset mode is for LST. In this mode, emoji IC reset itself in each cycle.

  # Legacy emoji display (old firmware)
  led_matrix:
    * field: \value           , $prefix: \LM , value: [\int, [0, 600]]
      ...

  ->
    super!
    ##
    # Declare the number of sensors and their count and types.
    #
    @.declare-sensors do
      barometric_pressure : <[0]>
      humidity            : <[0]>
      ndir_co2            : <[0]>
      iaq_co2             : <[0]>
      iaq_dust            : <[0]>
      iaq_dust_adv        : <[0]>
      sound               : <[0]>
      led_matrix          : <[0]>
      emoji               : <[0]>
    ##
    # (Optional) Specify extra information of each sensor.
    #
    @sensors[\barometric_pressure].0  = model: \st-lps25h
    @sensors[\humidity].0             = model: \st-hts221
    @sensors[\ndir_co2].0             = model: \ds-t-110
    @sensors[\iaq_co2].0              = model: \iaq-core-p
    @sensors[\iaq_dust].0             = model: \gp2y1010au
    @sensors[\iaq_dust_adv].0         = model: \pmsa003
    # @sensors[\sound].0                = model: \unknown
    # @sensors[\led_matrix].0           = model: \unknown
    # @sensors[\emoji].0                = model: \unknown

    ##
    # (Optional) specify extra actuator actions (in addition to set_xxx) of those writeable sensors.
    #
    # Please note, these extra actuator actions are supplemental information to the defined sensor types.
    # So, all sensor instances of same sensor-type shall share these extra actuator actions if specified.
    #
    @actuators[\emoji] =
      * action: \show_number    , value: [\int, [0, 99]]  , $prefix: \LMN
      * action: \show_ascii     , value: [\int, [0, 127]] , $prefix: \LMA
      * action: \show_animation , value: [\int, [0, 38]]  , $prefix: \LMF



##
# The root classes to be exported. Schema parser or SensorWeb shall read the list
# of root classes, and traverse all of their child classes recursively, and export
# root classes and all of their children.
#
# The root class must be derived from SchemaBaseClass class, so schema-compiler
# can recognize them.
#
# Please note, the variable name must be `roots` for schema-compiler to process.
#
roots = {
  Sensorboard
}

/** Please Don't Modify These Lines Below   */
/** --------------------------------------- */
module.exports = roots