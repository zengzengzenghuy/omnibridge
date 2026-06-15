// Dev: run in fork test: forge test --rpc-url https://rpc.gnosischain.com

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.7.5;
pragma abicoder v2;

import "forge-std/Test.sol";
import {EternalStorageProxy} from "../contracts/upgradeability/EternalStorageProxy.sol";
import {HomeOmnibridge} from "../contracts/upgradeable_contracts/HomeOmnibridge.sol";

contract UpgradeHomeOmnibridgeTest is Test {
    HomeOmnibridge homeOmnibridge;
    EternalStorageProxy bridgeProxy;
    address bridgeOwner = 0x7a48Dac683DA91e4faa5aB13D91AB5fd170875bd;
    uint256[3] hourlyLimitMaxPerTxMinPerTxArray = [1e25, 1e20, 1];
    uint256[2] executionHourlyLimitExecutionMaxPerTxArray = [1e25, 1e20];
    address tokenFactory;

    function setUp() public {
        homeOmnibridge = new HomeOmnibridge("on_xDai");
        bridgeProxy = EternalStorageProxy(0xf6A78083ca3e2a662D6dd1703c939c8aCE2e268d);
        tokenFactory = address(HomeOmnibridge(address(bridgeProxy)).tokenFactory()); // TODO: rewrite tokenFactory in future implementation
        uint256 currentBridgeVersion = bridgeProxy.version();
        vm.startPrank(bridgeOwner);

        bytes memory initializeCallData = abi.encodeWithSelector(
            HomeOmnibridge.initializeForVersion9.selector,
            hourlyLimitMaxPerTxMinPerTxArray,
            executionHourlyLimitExecutionMaxPerTxArray,
            tokenFactory
        );
        bridgeProxy.upgradeToAndCall(currentBridgeVersion + 1, address(homeOmnibridge), initializeCallData);

        vm.stopPrank();
    }

    function testParameter() public {
        assertEq(bridgeProxy.implementation(), address(homeOmnibridge));
        assertEq(bridgeProxy.version(), 9);

        assertEq(HomeOmnibridge(address(bridgeProxy)).hourlyLimit(address(0)), 1e25);
        assertEq(HomeOmnibridge(address(bridgeProxy)).executionHourlyLimit(address(0)), 1e25);
        assertEq(HomeOmnibridge(address(bridgeProxy)).minPerTx(address(0)), 1);
        assertEq(HomeOmnibridge(address(bridgeProxy)).maxPerTx(address(0)), 1e20);
        assertEq(HomeOmnibridge(address(bridgeProxy)).executionMaxPerTx(address(0)), 1e20);
    }
}
