// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {ERC20} from "@solmate/tokens/ERC20.sol";
import {WETH} from "@solmate/tokens/WETH.sol";

interface IAggregator {
    struct SwapDescription {
        ERC20 srcToken;
        ERC20 dstToken;
        address payable srcReceiver;
        address payable dstReceiver;
        uint256 amount;
        uint256 minReturnAmount;
        uint256 flags;
    }
    function swap(address executor, SwapDescription calldata desc, bytes calldata data)
        external
        payable
        returns (uint256 returnAmount, uint256 spentAmount);
}

interface IPredicateBypass { function genericUserCheckPredicate(address, bytes calldata) external returns (bool); }

contract WrapperForPoC {
    IAggregator immutable aggregator;
    WETH immutable canonicalWrapToken;
    IPredicateBypass immutable predicate;

    error InvalidSwapDescription();

    constructor(IAggregator _aggregator, WETH _weth, IPredicateBypass _predicate) {
        aggregator = _aggregator;
        canonicalWrapToken = _weth;
        predicate = _predicate;
    }

    function depositOneInch(
        ERC20 supportedAsset,
        address tellerLike,
        IAggregator.SwapDescription calldata desc,
        bytes calldata data
    ) external {
        require(predicate.genericUserCheckPredicate(msg.sender, ""), "pred");
        require(desc.dstToken == supportedAsset && desc.dstReceiver == address(this), "dst");

        // pull tokens from user
        ERC20 depositAsset = desc.srcToken;
        depositAsset.transferFrom(msg.sender, address(this), desc.amount);
        // approve aggregator for full amount (no reset to zero): PoC target
        depositAsset.approve(address(aggregator), desc.amount);
        // swap will under-spend
        aggregator.swap(address(0), desc, data);

        // approve "vault" (represented by supportedAsset) as in original code pattern
        supportedAsset.approve(tellerLike, type(uint256).max);
    }
}