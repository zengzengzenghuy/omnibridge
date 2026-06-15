pragma solidity 0.7.5;

import "../upgradeability/EternalStorage.sol";

contract InitializableHome is EternalStorage {
    bytes32 internal constant INITIALIZED_VERSION_9 =
        0xa6c9b91adbbccbff85643d98cbc28d4f4927a7c44ee6462f937bfe811ef520a1; //keccak256(abi.encodePacked("isInitializedVersion9")

    function setInitializeForVersion9() internal {
        boolStorage[INITIALIZED_VERSION_9] = true;
    }

    function isInitializedForVersion9() public view returns (bool) {
        return boolStorage[INITIALIZED_VERSION_9];
    }
}
