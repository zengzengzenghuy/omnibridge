// Dev: run in fork test in ETH environment

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.7.5;
pragma abicoder v2;

import "forge-std/Test.sol";
import {EternalStorageProxy} from "../contracts/upgradeability/EternalStorageProxy.sol";
import {ForeignOmnibridge} from "../contracts/upgradeable_contracts/ForeignOmnibridge.sol";

contract UpgradeForeignOmnibridgeTest is Test {
    ForeignOmnibridge foreignOmnibridge;
    EternalStorageProxy bridgeProxy;
    address bridgeOwner = 0x42F38ec5A75acCEc50054671233dfAC9C0E7A3F6;
    uint256[3] hourlyLimitMaxPerTxMinPerTxArray = [1e25, 1e20, 1];
    uint256[2] executionHourlyLimitExecutionMaxPerTxArray = [1e25, 1e20];
    address tokenFactory;

    function setUp() public {
        foreignOmnibridge = new ForeignOmnibridge("on_ETH");
        bridgeProxy = EternalStorageProxy(0x88ad09518695c6c3712AC10a214bE5109a655671);
        tokenFactory = address(ForeignOmnibridge(address(bridgeProxy)).tokenFactory()); // TODO: rewrite tokenFactory in future implementation
        uint256 currentBridgeVersion = bridgeProxy.version();
        vm.startPrank(bridgeOwner);

        bytes memory initializeCallData = abi.encodeWithSelector(
            ForeignOmnibridge.initializeForVersion7.selector,
            hourlyLimitMaxPerTxMinPerTxArray,
            executionHourlyLimitExecutionMaxPerTxArray,
            tokenFactory
        );
        bridgeProxy.upgradeToAndCall(currentBridgeVersion + 1, address(foreignOmnibridge), initializeCallData);

        vm.stopPrank();
    }

    function testParameter() public {
        assertEq(bridgeProxy.implementation(), address(foreignOmnibridge));
        assertEq(bridgeProxy.version(), 7);
        assertEq(ForeignOmnibridge(address(bridgeProxy)).hourlyLimit(address(0)), 1e25);
        assertEq(ForeignOmnibridge(address(bridgeProxy)).executionHourlyLimit(address(0)), 1e25);
        assertEq(ForeignOmnibridge(address(bridgeProxy)).minPerTx(address(0)), 1);
        assertEq(ForeignOmnibridge(address(bridgeProxy)).maxPerTx(address(0)), 1e20);
        assertEq(ForeignOmnibridge(address(bridgeProxy)).executionMaxPerTx(address(0)), 1e20);
    }
}
