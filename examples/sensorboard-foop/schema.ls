/** Please Don't Modify These Lines Below   */
/** --------------------------------------- */
class SchemaBaseClass
  ->
    @sensors = {}
    @actuators = {}

  declare-sensors: (types-and-identities) ->
    self = @
    for st, identities of types-and-identities
      self.sensors[st] = {}
      for id in identities
        self.sensors[st][id] = {}


SchemaBaseClass = SCHEMA_BASE_CLASS if SCHEMA_BASE_CLASS?
/** --------------------------------------- */
/** Please Don't Modify These Lines Above   */


class Sensorboard extends SchemaBaseClass
  humidity:
    * field: \temperature , unit: \degree , value: [\float, [-40.0, 80.0]]  , $prefix: <[TE TI]>
    * field: \humidity    , unit: \%rH    , value: [\int, [0, 100]]         , $prefix: <[HE HI]>

  waterlevel:
    * field: \value       , unit: ''      , value: [\boolean, <[no, yes]>]  , $prefix: <[W W1]>
      ...

  ndir_co2:
    * field: \co2         , unit: \ppm    , value: [\int, [400, 10000]]     , $prefix: \C   , $keep_error: yes
      ...

  ambient_light:
    * field: \illuminance , unit: \lux    , value: [\int, [0, 64000]]       , $prefix: \L

  fan:
    * field: \pwm         , unit: ''      , value: [\int, [1, 2395]]        , writeable: yes, $prefix: <[FSA FSB]>
    * field: \percentage  , unit: '%'     , value: [\int, [0, 100]]         , writeable: yes, $prefix: null

  led:
    * field: \pwm         , unit: ''      , value: [\int, [1, 2395]]        , writeable: yes, $prefix: \LD
    * field: \percentage  , unit: '%'     , value: [\int, [0, 100]]         , writeable: yes, $prefix: null

  pump:
    * field: \vibration   , unit: ''      , value: [\boolean, <[no, yes]>]  , writeable: yes, $prefix: \PO

  emoji:
    * field: \value       , $prefix: \LM , value: [\int, [0, 600]]
    * field: \mode        , $prefix: null
      value: [\enum, <[ascii pre_installed_image post_installed_image number pre_installed_animation post_installed_animation]>]
    * field: \index       , $prefix: null, value: [\int, [0, 128]]

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
      humidity            : <[inside outside]>
      waterlevel          : <[1st 2nd]>
      ndir_co2            : <[0]>
      ambient_light       : <[0]>
      fan                 : <[left right]>
      led                 : <[0]>
      pump                : <[0]>
      emoji               : <[0]>

    ##
    # (Optional) Specify extra information of each sensor.
    #
    @sensors[\humidity].0             = model: \sht-31
    @sensors[\humidity].1             = model: \sht-31
    @sensors[\ndir_co2].0             = model: \ds-t-110
    @sensors[\ambient_light].0        = model: \ltr-303als-01

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