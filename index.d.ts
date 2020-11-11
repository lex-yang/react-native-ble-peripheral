declare module "react-native-ble-peripheral" {
  function createService(UUID: string, primary: boolean): void;
  function addCharacteristicToService(
    ServiceUUID: string,
    UUID: string,
    permissions: number,
    properties: number
  ): void;
  function publishService(UUID: string): void;
  function updateValue(UUID: string, data: Uint8)
  function sendNotificationToDevices(
    ServiceUUID: string,
    CharacteristicUUID: string,
    data: number[]
  ): void;
  function start(): Promise<boolean>;
  function stop(): void;
  function setName(name: string): void;
  function isAdvertising(): Promise<boolean>;
  function setEventHandler(handler: object): void;
}
