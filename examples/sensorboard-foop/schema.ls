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

MANIFEST =
  name: \cnsc-cdc
  version: \0.1.1


class Sensorboard extends SchemaBaseClass
  humidity:
    * field: \temperature , unit: \degree_c , value: [\float, [-40.0, 80.0]]
    * field: \humidity    , unit: \%rH      , value: [\int, [0, 100]]

  waterlevel:
    * field: \value       , unit: ''        , value: [\boolean, <[no yes]>]
      ...

  ndir_co2:
    * field: \co2         , unit: \ppm      , value: [\int, [400, 10000]]     , $keep_error: yes # (annotation for any instance of same sensor type)
      ...

  ambient_light:
    * field: \illuminance , unit: \lux      , value: [\int, [0, 64000]]       , $keep_error: no
      ...

  fan:
    * field: \pwm         , unit: ''        , value: [\int, [1, 2395]]        , writeable: yes, $keep_error: yes
    * field: \percentage  , unit: '%'       , value: [\int, [0, 100]]         , writeable: yes

  led:
    * field: \pwm         , unit: ''        , value: [\int, [1, 2395]]        , writeable: yes, $keep_error: yes
    * field: \percentage  , unit: '%'       , value: [\int, [0, 100]]         , writeable: yes

  pump:
    * field: \vibration   , unit: ''        , value: [\boolean, <[no yes]>]  , writeable: yes
      ...

  emoji:
    * field: \value                         , value: [\int, [0, 600], 1]      , writeable: yes
    * field: \mode                          , value: [\enum, <[ascii pre_installed_image post_installed_image number pre_installed_animation post_installed_animation]>]
    * field: \index                         , value: [\int, [0, 128]]

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
      waterlevel          : <[top1 top2]>
      ndir_co2            : <[0]>
      ambient_light       : <[0]>
      fan                 : <[left right]>
      led                 : <[0]>
      pump                : <[0]>
      emoji               : <[0]>

    ##
    # (Optional)
    # Specify extra information as annotations of each sensor instance, with
    # the specific `s_id`.
    #
    @sensors[\humidity].inside        = prefix: {temperature: \TI, humidity: \HI} , model: \st221
    @sensors[\humidity].outside       = prefix: {temperature: \TE, humidity: \HE} , model: \st221
    @sensors[\waterlevel].top1        = prefix: {value: \W                      }
    @sensors[\waterlevel].top2        = prefix: {value: \W1                     }
    @sensors[\ndir_co2].0             = prefix: {co2: \C                        }, model: \ds-t-110
    @sensors[\ambient_light].0        = prefix: {illuminance: \L                }, model: \ltr-303als-01
    @sensors[\fan].left               = prefix: {pwm: \FSA                      }, model: \abc-001
    @sensors[\fan].right              = prefix: {pwm: \FSB                      }, model: \abc-001
    @sensors[\led].0                  = prefix: {pwm: \LD                       }, model: \def-002
    @sensors[\pump].0                 = prefix: {vibration: \PO                 }, model: \xyz-999
    @sensors[\emoji].0                = prefix: {value: \LM                     }, model: \www-123

    ##
    # (Optional)
    # Specify extra actuator actions (in addition to set_xxx) of those writeable sensor-types.
    #
    # Please note, these extra actuator actions are supplemental information to the defined sensor types.
    # So, all sensor instances of same sensor-type shall share these extra actuator actions if specified.
    #
    @actuators[\emoji] =
      * action: \show_number    , argument: [\int, [0, 99], 1]  , $action_prefix: \LMN
      * action: \show_ascii     , argument: [\int, [0, 127], 1] , $action_prefix: \LMA
      * action: \show_animation , argument: [\int, [0, 38], 1]  , $action_prefix: \LMF



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