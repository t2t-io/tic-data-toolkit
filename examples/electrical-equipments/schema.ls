#!/usr/bin/env lsc
#
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


MANIFEST =
  name: \electrical-equipments
  version: \0.1.2


class ElectricalMeter extends SchemaBaseClass
  electric_energy:
    * field: \energy                , value: [\int, [0, 1000]]            , unit: \w    , description: "the currently-consumed energy"
    * field: \energy_cumulative     , value: [\float, [0, 999999990000]]  , unit: \kWh
  installation_location:
    * field: \type                  , writeable: yes
      value: [\enum, <[living_room dining_room kitchen bathroom lavatory washroom_changing_room passageway room stairway front_door storeroom garden_perimeter garage veranda_balcony others free_definition not_specified indifinite position_information]>]
      ...
  fault_status:
    * field: \value                 , value: [\enum, <[no_fault fault]>]
      ...
  ->
    super!
    ##
    # Declare the number of sensors and their count and types.
    #
    @.declare-sensors do
      electric_energy       : <[0]>
      installation_location : <[0]>
      fault_status          : <[0]>


class TwoWayMeter extends ElectricalMeter
  ->
    super!
    ##
    # Declare the number of sensors and their count and types.
    # Please note, because of inheritance, the following statements are true:
    #   - sensors[installation_location]  = ['0']
    #   - sensors[fault_status]           = ['0']
    #
    @.declare-sensors do
      electric_energy       : <[0 1]>



class ElectricalEquipment extends SchemaBaseClass
  electric_energy:
    * field: \energy                , value: [\int, [0, 1000]]          , unit: \w        , description: "the currently-consumed energy"
    * field: \energy_cumulative     , value: [\int, [0, 1000]]          , unit: \Wh
  power_switch:
    * field: \value                 , value: [\boolean, <[off on]>]     , writeable: yes
      ...
  ->
    super!
    ##
    # Declare the number of sensors and their count and types.
    #
    @.declare-sensors do
      electric_energy   : <[0]>
      power_switch      : <[0]>


class AirConditionEnl extends ElectricalEquipment
  user_settings:
    * field: \operation_mode        , value: [\enum, <[auto cooling heating dehumidification circulator other]>], writeable: yes
    * field: \target_temperature    , value: [\float, [22.0, 26.0], 0.5]        , writeable: yes, unit: \degree_c
    * field: \power_saving_mode     , value: [\enum, <[power_saving normal]>]   , writeable: yes
  air_flow_rate:
    * field: \value                 , value: [\enum, <[auto 1 2 3 4 5 6 7 8]>]  , writeable: yes
  room_temperature:
    * field: \temperature           , value: [\float, [20.0, 40.0]]             , unit: \degree_c

  ->
    super!
    ##
    # Declare the number of sensors and their count and types.
    #
    @.declare-sensors do
      user_settings     : <[0]>
      air_flow_rate     : <[0]>
      room_temperature  : <[0]>

    ##
    # (Optional)
    # Specify extra information as annotations of each sensor instance, with
    # the specific `s_id`.
    #
    @sensors[\air_flow_rate].0        = echonet: {value: ['a0', [0x41, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38]]}
    @sensors[\user_settings].0        = echonet:
      operation_mode    : ['b0', [0x41,0x42,0x43,0x44,0x45,0x40]]
      power_saving_mode : ['8f', [0x41,0x42]]

    ##
    # (Optional) specify extra actuator actions (in addition to set_xxx) of those writeable sensors.
    #
    # Please note, these extra actuator actions are supplemental information to the defined sensor types.
    # So, all sensor instances of same sensor-type shall share these extra actuator actions if specified.
    #
    @actuators[\user_settings] =
      * action: \cleanup_self           , value: [\boolean, [off, on]]
      * action: \set_special_mode       , value: [\enum, <[human_sleeping offical_working home_standby]>]
        $parameters:
          human_sleeping: {target_temperature: 26.0, operation_mode: \auto}
          offical_working: {target_temperature: 24.0, operation_mode: \cooling}
          home_standby: {target_temperature: 27.0, operation_mode: \circulator}


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
  ElectricalMeter
}

/** Please Don't Modify These Lines Below   */
/** --------------------------------------- */
module.exports = roots