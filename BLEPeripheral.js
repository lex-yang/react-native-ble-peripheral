/**
 * @providesModule BLEPeripheral
 */

'use strict';

var { NativeModules, NativeEventEmitter } = require('react-native');
const { BLEPeripheral } = NativeModules

var _stateUpdated = null;
var _writeEventHandler = null;
var _serviceAdded = null;

BLEPeripheral.setEventHandler = ({ state, write, service }) => {
  _stateUpdated = state;
  _writeEventHandler = write;
  _serviceAdded = service;
}

module.exports = BLEPeripheral;

const eventEmitter = new NativeEventEmitter(BLEPeripheral);

const stateSubscription = eventEmitter.addListener(
  'stateUpdated',
  (body) => {
    ( _stateUpdated && _stateUpdated(body.state) )
  }
)

const serviceSubscription = eventEmitter.addListener(
  'serviceAdded',
  (body) => {
    ( _serviceAdded && _serviceAdded(body.result, body.uuid) )
  }
)

const writeSubscription = eventEmitter.addListener(
  'writeEvent',
  (params) => {
    ( _writeEventHandler && _writeEventHandler(params.uuid, params.value) );
  }
);