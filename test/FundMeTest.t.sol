// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
 import {FundMe} from "../src/FundMe.sol";
import {DeployFundMe} from "../script/DeployFundMe.s.sol";

contract FundMeTest is Test {


    FundMe fundMe;

    address USER = makeAddr("user");
    uint256 constant SEND_VALUE = 0.1 ether; // 0.1 ETH

    uint256 constant STARTING_BALANCE = 10 ether; // 10 ETH
    //uint256 constant GAS_PRICE = 1; // 1 Gwei

   function setUp() public {
       // This function is run before each test
       // You can use it to set up the state of the contract or variables
        // fundMe = new FundMe();
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();
        vm.deal(USER, STARTING_BALANCE); // Give USER 10 ETH
   }

   function testMinimumUsd() public {

         // This function tests the minimum USD requirement
         assertEq(fundMe.MINIMUM_USD(), 5 * 10 ** 18, "Minimum USD should be 5 ETH");
   }

   function testOwner() public {
         // This function tests the owner of the contract
        assertEq(fundMe.getOwner(), msg.sender, "Owner should be the deployer");
   }

   // @dev Unit Tests: Test individual functions or small, isolated pieces of logic within a single contract.
// They focus on verifying that each component behaves as expected in isolation.
// Purpose: Catch bugs early, ensure core logic is sound, and provide quick feedback during development.
// Example: Testing if a `deposit` function correctly updates a user's balance and emits an event.


// @dev Integration Tests: Verify interactions between multiple functions within a contract,
// or between different contracts. They test how components work together as a system.
// Purpose: Uncover issues arising from the interplay of different parts,
// especially with inheritance or external contract calls (e.g., ERC-20 token interactions).
// Example: Testing a DeFi protocol where a user deposits collateral into one contract
// and then borrows from another contract, verifying both contract states are updated correctly.


// @dev Staging Tests: Run against a deployed version of the smart contracts on a "staging" blockchain network.
// This network typically mimics the production environment (e.g., a testnet like Sepolia or a private testnet).
// Purpose: Verify the end-to-end functionality, deployments, and external integrations in a realistic,
// persistent environment before going live. Catches issues related to gas costs, network latency, or
// specific chain characteristics that might not appear in local tests.
// Example: Deploying an entire DApp suite to Sepolia and running automated tests that interact
// with the deployed contracts, checking for proper front-end integration and external service calls.

// @dev Forked Tests: Run your tests against a local "fork" of a live blockchain network (e.g., Ethereum Mainnet).
// This allows you to interact with real contract states, deployed protocols, and actual tokens from the live chain,
// but in a safe, local, and manipulable environment without spending real gas or affecting live users.
// Purpose: Simulate real-world interactions, test upgrades, or verify compatibility with existing protocols
// using actual on-chain data and conditions. Ideal for testing complex DeFi interactions or upgrades.
// Example: Forking Mainnet to test how your new DEX aggregator interacts with Uniswap V3 and SushiSwap
// using their actual deployed contracts and liquidity, without deploying your own.

     function testPriceFeedVersionIsAccurate() public {
        if (block.chainid == 11155111) {
            uint256 version = fundMe.getVersion();
            assertEq(version, 4);
        } else if (block.chainid == 1) {
            uint256 version = fundMe.getVersion();
            assertEq(version, 6);
        }
  }  

  function testFundWithoutEnoughEth() public {
        // This function tests funding with less than the minimum USD amount
        vm.expectRevert("You need to spend more ETH!");
        fundMe.fund{value: 1 * 18 * 10}(); // Sending 1 ETH, which is less than 5 ETH
    }

    function testFundUpdatesFundedDataStructure() public {
        vm.prank (USER); // the next tx // will be sent by USER
        // This function tests funding with enough ETH
        fundMe.fund{value: SEND_VALUE}(); // Sending 5 ETH, which is equal to the minimum USD amount
        uint256 amountFunded = fundMe.getAddressToAmountFunded(USER); // Replace ??? with the address you want to check, e.g., msg.sender
        assertEq(amountFunded, SEND_VALUE, "Amount funded should be 5 ETH");
    }    

    function testAddsFunderToArrayOfFunders() public {
        vm.prank(USER); // the next tx will be sent by USER
        fundMe.fund{value: SEND_VALUE}(); // Sending 5 ETH, which is equal to the minimum USD amount
        address funder = fundMe.getFunder(0); // Get the first funder in the array
        assertEq(funder, USER, "Funder should be USER");
    } 

    modifier funded() {
        // This modifier checks if the contract has been funded
        vm.prank(USER); // the next tx will be sent by USER
        fundMe.fund{value: SEND_VALUE}(); // USER funds the contract with 5 ETH
        _;
    }

    function testOnlyOwnerCanWithdraw() public funded {
        vm.prank(USER); // the next tx will be sent by USER
        vm.expectRevert("NotOwner()"); // Expect revert with NotOwner error
        fundMe.withdraw(); // USER tries to withdraw, should fail
    }

    function testWithdrawWithASingleFunder() public funded{
        // This function tests withdrawing with a single funder
        //Arrange
        uint256 startingOwnerBalance = fundMe.getOwner().balance; // Get the owner's starting balance
        uint256 startingFundMeBalance = address(fundMe).balance; // Get the Fund

        // Act
        /*uint256 gasStart = gasleft(); // Get the gas left before the transaction
        vm.txGasPrice(GAS_PRICE); // Set gas price to 0 for testing*/
            
        vm.prank(fundMe.getOwner()); // the next tx will be sent by the owner
        fundMe.withdraw(); // Owner withdraws funds

       /* uint256 gasEnd = gasleft(); // Get the gas left after the transaction
        uint256 gasUsed = (gasStart - gasEnd) * tx.gasprice; // Calculate the gas used*/


            // Assert
        uint256 endingOwnerBalance = fundMe.getOwner().balance; // Get the owner's ending balance
        uint256 endingFundMeBalance = address(fundMe).balance; // Get the Fund
        assertEq(endingFundMeBalance, 0, "FundMe balance should be 0 after withdrawal");
        assertEq(startingFundMeBalance + startingOwnerBalance, endingOwnerBalance, "Owner's balance should be equal to starting balance plus FundMe balance after withdrawal");


    }

    function testWithdrawFromMultipleFunders() public funded {
        // This function tests withdrawing from multiple funders
// Arrange
        uint160 numberOfFunders = 10; // Number of funders
        uint160 startingFunderIndex = 2; // Start funding from index 2

        for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
           //vm.prank new address
           //vm.deal new address
           
           hoax(address(i), SEND_VALUE); //
              fundMe.fund{value: SEND_VALUE}(); // Each funder funds the contract with 5 ETh
           // fund the fundme

        }

        uint256 startingOwnerBalance = fundMe.getOwner().balance; // Get the owner's starting balance
        uint256 startingFundMeBalance = address(fundMe).balance; // Get the Fund
   
        vm.startPrank(fundMe.getOwner()); // the next tx will be sent by the owner
        fundMe.withdraw(); // Owner withdraws funds
        vm.stopPrank(); // Stop the prank
   
 }

}
   