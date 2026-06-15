pragma solidity 0.7.5;

import "../upgradeability/EternalStorage.sol";

contract InitializableForeign is EternalStorage {
    bytes32 internal constant INITIALIZED_VERSION_7 =
        0x80ba73b93b0b472f28f5bff77f7a953d80ecec8bc866178ea8c7e00ec4bab82d; //keccak256(abi.encodePacked("isInitializedVersion7")

    function setInitializeForVersion7() internal {
        boolStorage[INITIALIZED_VERSION_7] = true;
    }

    function isInitializedForVersion7() public view returns (bool) {
        return boolStorage[INITIALIZED_VERSION_7];
    }
}
