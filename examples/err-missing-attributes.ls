/** Please Don't Modify These Lines Below   */
/** --------------------------------------- */
class SchemaBaseClass
  sensors: {}

SchemaBaseClass = SCHEMA_BASE_CLASS if SCHEMA_BASE_CLASS?
/** --------------------------------------- */
/** Please Don't Modify These Lines Above   */


class AAA extends SchemaBaseClass
  user_settings:
    # * field: \operation_power_saving, writeable: yes, value: null
    # * field: \operation_power_saving, writeable: yes, value: []
    # * field: \operation_power_saving, writeable: yes, value: {}
    # * field: \operation_power_saving, writeable: yes, value: [\aa]
    # * fieldx: \operation_power_saving, writeable: yes, value: [\boolean, <[off on]>]
    # * field: \operation_power_saving, writeable: yes, value: [\boolean]
    # * field: \operation_power_saving, writeable: yes, value: [\boolean, {}]
    # * field: \operation_power_saving, writeable: yes, value: [\boolean, <[off on aa]>]
    # * field: \operation_power_saving, writeable: yes, value: [\boolean, [1, 2]]
    # * field: \operation_power_saving, writeable: yes, value: [\boolean, [1, 'aa']]
    # * field: \operation_power_saving, writeable: yes, value: [\boolean, ['aa', yes]]
    * field: \operation_power_saving, writeable: yes, value: [\boolean, <[off on]>]
    # * field: \operation_mode        , writeable: yes, value: [\enum   , []]
    * field: \operation_mode        , writeable: yes, value: [\enum   , <[normal fullpower standby hibernate]>]
    * field: \target_temperature    , writeable: yes, value: [\float  , [22.0, 26.0], 0.5], unit: \degree_c
    * field: \air_flow_rate         , writeable: yes, value: [\int    , [1, 5]]
    # * field: \air_flow_rate         , writeable: yes, value: [\int    , ['aa', 5]]
    # * field: \air_flow_rate         , writeable: yes, value: [\int    , [5, 'aa']]
    # * field: \air_flow_rate         , writeable: yes, value: [\int    , [5, 1]]
    * field: \air_flow_rate_ex       , writeable: yes, value: [\int    , [1, 5]],
      $echonetlite: [41 42 43 45 49], abc: \great, def: 12

  ->
    super!
    @sensors[\user_settings] = <[00 01]>
    # @sensors[\user_settings] = [1]
    # @sensors[\user_settings] = []
    # @sensors[\user_settings] = null

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
  AAA
}

/** Please Don't Modify These Lines Below   */
/** --------------------------------------- */
module.exports = roots