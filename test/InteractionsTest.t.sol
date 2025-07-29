
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
 import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";
import {FundFundMe, WithdrawFundMe} from "../../script/Interactions.s.sol";

contract FundMeTestIntegration is Test {
    FundMe fundMe;

    address USER = makeAddr("user");
    uint256 constant SEND_VALUE = 0.1 ether; // 0.1 ETH
    uint256 constant STARTING_BALANCE = 10 ether; // 10 ETH
     uint256 constant GAS_PRICE = 1; // 1 Gwei
    function setUp() external {
        // This function is run before each test
        // You can use it to set up the state of the contract or variables
        DeployFundMe deploy = new DeployFundMe();
        fundMe = deploy.run();
        vm.deal(USER, STARTING_BALANCE); // Give USER 10 ETH

    }

    function testUserCanFundInteractions() public {
          FundFundMe fundFundMe = new FundFundMe();
          fundFundMe.fundFundMe(address(fundMe));
          
          WithdrawFundMe  withdrawFundMe = new WithdrawFundMe();
            withdrawFundMe.withdrawFundMe(address(fundMe));

            assert(address(fundMe).balance == 0);


    }

}