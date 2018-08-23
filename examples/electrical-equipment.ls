class Base
  ->
    @attributes = {}


class ElectricalEquipment extends Base
  power_consumption:
    * field: \value             , unit: \w    , description: "the currently-consumed energy"
    * field: \value_cumulative  , unit: \Wh
    * field: \value_diff        , unit: \Wh
  power_switch:
    * field: \value             , writeable: yes, value: [\boolean, <[off on]>]
  ->
    super!
    @attributes[\power_consumption]  = <[00 01]>
    @attributes[\power_switch]       = <[00]>


class AirCondition extends ElectricalEquipment
  user_settings:
    * field: \operation_power_saving, writeable: yes, value: [\boolean, <[off on]>]
    * field: \operation_mode        , writeable: yes, value: [\enum   , <[normal fullpower standby hibernate]>]
    * field: \target_temperature    , writeable: yes, value: [\float  , [22.0, 26.0], 0.5], unit: \degree_c
    * field: \air_flow_rate         , writeable: yes, value: [\int    , [1, 5]]
  ->
    super!
    @attributes[\user_settings] = <[00]>


module.exports = exports = {
  ElectricalEquipment,
  AirCondition
}


# what's the differences between power_switch and power_state in Echonet Lite?
#
#