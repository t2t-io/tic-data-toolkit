/** Please Don't Modify These Lines Below   */
/** --------------------------------------- */
class SchemaBaseClass
  ->
    @sensors = {}

SchemaBaseClass = SCHEMA_BASE_CLASS if SCHEMA_BASE_CLASS?
/** --------------------------------------- */
/** Please Don't Modify These Lines Above   */


class ElectricalMeter extends SchemaBaseClass
  user_settings:
    * field: \operation_power_saving, writeable: yes, value: [\boolean, <[off on]>]
    * field: \operation_mode        , writeable: yes, value: [\enum   , <[normal fullpower standby hibernate]>]
    * field: \target_temperature    , writeable: yes, value: [\float  , [22.0, 26.0], 0.5], unit: \degree_c
    * field: \air_flow_rate         , writeable: yes, value: [\int    , [1, 5]]
  ->
    super!
    @sensors[\user_settings] = <[00]>


class SmartMeter extends ElectricalMeter
  ->
    super!

class SmartMeterEL extends SmartMeter
  ->
    super!

class SmartMeterEL2 extends SmartMeter
  ->
    super!


class ElectricalEquipment extends SchemaBaseClass
  power_consumption:
    * field: \value             , value: [\int, [0, 1000]], unit: \w    , description: "the currently-consumed energy"
    * field: \value_cumulative  , value: [\int, [0, 1000]], unit: \Wh
    * field: \value_diff        , value: [\int, [0, 1000]], unit: \Wh
  power_switch: [
    * field: \value             , writeable: yes, value: [\boolean, <[off on]>]
  ]

  ->
    super!
    @sensors[\power_consumption]  = <[00 01]>
    @sensors[\power_switch]       = <[00]>


class AirCondition extends ElectricalEquipment
  user_settings:
    * field: \operation_power_saving, writeable: yes, value: [\boolean, <[off on]>]
    * field: \operation_mode        , writeable: yes, value: [\enum   , <[normal fullpower standby hibernate]>]
    * field: \target_temperature    , writeable: yes, value: [\float  , [22.0, 26.0], 0.5], unit: \degree_c
    * field: \air_flow_rate         , writeable: yes, value: [\int    , [1, 5]]
  ->
    super!
    @sensors[\user_settings] = <[00]>



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
  ElectricalEquipment,
  ElectricalMeter,
}

/** Please Don't Modify These Lines Below   */
/** --------------------------------------- */
module.exports = roots