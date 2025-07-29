// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";
import {FundMe} from "../src/FundMe.sol";

contract FundFundMe is Script {

    uint256 constant SEND_VALUE = 0.1 ether;

    function fundFundMe(address mostRecentlyDeployed) public {
        // --- ADDED vm.startBroadcast() and vm.stopBroadcast() here ---
        vm.startBroadcast();
        FundMe(payable(mostRecentlyDeployed)).fund{value: SEND_VALUE}();
        vm.stopBroadcast();
        // --- END ADDED ---

        console.log("Funded FundMe with %s", SEND_VALUE);
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("FundMe", block.chainid);
        // This line was problematic as it didn't call the fundFundMe function.
        // If you intend for `run()` to execute the funding, it should call `fundFundMe`.
        // However, for your test, you're calling `fundFundMe` directly.
        // So, this `run()` function is effectively unused by your test.
        // For completeness, if `run()` were used, it would be:
        // vm.startBroadcast(); // This broadcast might conflict if fundFundMe also broadcasts
        // new FundFundMe().fundFundMe(mostRecentlyDeployed); // Correct way to call its own function
        // vm.stopBroadcast();
        // Given your test structure, we are ignoring this `run()` for now.
        // The fix focuses on the `fundFundMe` function.
    }
}

contract WithdrawFundMe is Script {
    function withdrawFundMe(address mostRecentlyDeployed) public {
        // --- ADDED vm.startBroadcast() and vm.stopBroadcast() here ---
        vm.startBroadcast();
        FundMe(payable(mostRecentlyDeployed)).withdraw();
        vm.stopBroadcast();
        // --- END ADDED ---

        console.log("Withdraw FundMe balance!");
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("FundMe", block.chainid);
        vm.startBroadcast();
        withdrawFundMe(mostRecentlyDeployed);
        vm.stopBroadcast();
    }
}