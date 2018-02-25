class ElectricalEquipment
  power_consumption:
    * field: \w               # walt?
    * field: \wh_cumulative   # ...
    * field: \wh_diff
  power_switch:
    * field: \on              # true / false

class AirCondition extends ElectricalEquipment
  user_settings:
    * field: \operation_power_saving
    * field: \operation_mode
    * field: \target_temperature
    * field: \air_flow_rate_setting

class Humidier extends ElectricalEquipment
  user_preferences:
    * field: \operation_mode
    * field: \target_humidity

module.exports = exports = {
  ElectricalEquipment,
  AirCondition,
  Humidier
}
