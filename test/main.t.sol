// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {WETH9} from "../src/WETH.sol";
import {IUniswapV2Router01} from "../src/IUniswapV2Router01.sol";
import {IUniswapV2Pair} from "../src/IUniswapV2Pair.sol";
import {IERC20} from "../src/IERC20.sol";

contract MainTest is Test {
    using stdStorage for StdStorage;

    address constant WISE_TOKEN =     0x66a0f676479Cee1d7373f3DC2e2952778BfF5bd6;
    address constant WETH_TOKEN =           0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant WISE_WETH_PAIR = 0x21b8065d10f73EE2e260e5B47D3344d3Ced7596E;
    address constant UNI_ROUTER_V2 =  0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    //WiseToken constant WISE = WiseToken(WISE_TOKEN);
    IERC20 constant WISE = IERC20(WISE_TOKEN);
    WETH9 constant WETH = WETH9(payable(WETH_TOKEN));
    // it's actually v2 but the interface is the same
    IUniswapV2Router01 constant UNI_ROUTER = IUniswapV2Router01(UNI_ROUTER_V2);
    IUniswapV2Pair constant UNI_PAIR = IUniswapV2Pair(WISE_WETH_PAIR);

    address me = address(0x1337BEEF);

    function setUp() public {
        // give myself money
        stdstore
            .target(WISE_TOKEN)
            .sig("balanceOf(address)")
            .with_key(me)
            .checked_write(15 ether);
        vm.deal(me, 100 ether);
        vm.startPrank(me);
        WETH.deposit{value: 15 ether}();
        WETH.approve(UNI_ROUTER_V2, 15 ether);
        WISE.approve(UNI_ROUTER_V2, 15 ether);
        vm.stopPrank();
    }

    function testSell() public {
        // at time t_0 record the amount of money yielded for selling WISE for WETH
        address[] memory path = new address[](2);
        path[0] = WISE_TOKEN;
        path[1] = WETH_TOKEN;
        uint256[] memory bq01 = UNI_ROUTER.getAmountsOut(1 ether, path);
        uint256[] memory bq02 = UNI_ROUTER.getAmountsOut(2 ether, path);
        uint sellQuote0For1Wise = bq01[1];
        uint sellQuote0For2Wise = bq02[1];
        uint slippage0 = sellQuote0For2Wise - sellQuote0For1Wise;
        console.log("sellQuote0For1Wise: %s", sellQuote0For1Wise);
        console.log("sellQuote0For2Wise: %s", sellQuote0For2Wise);
        console.log("slippage0: %s", slippage0);

        // at time t_0.5 someone deposits an even amount of liquidity on both sides of the pool
        (uint256 reserveWISE, uint256 reserveWETH, ) = UNI_PAIR.getReserves();
        console.log("reserveWISE: %s", reserveWISE);
        console.log("reserveWETH: %s", reserveWETH);
        console.log("WISE Token balanceOf Pair before deposit %s", WISE.balanceOf(WISE_WETH_PAIR));
        console.log("WETH Token balanceOf Pair before deposit %s", WETH.balanceOf(WISE_WETH_PAIR));
        console.log("WISE Token balanceOf Liquidity Provider after deposit %s", WISE.balanceOf(me));
        console.log("WETH Token balanceOf Liquidity Provider Pair after deposit %s", WETH.balanceOf(me));
        uint256 correctRatioWETHforWISE = UNI_ROUTER.quote(
            2 ether, 
            reserveWISE,
            reserveWETH
        );
        vm.prank(me);
        (uint amountWISE, uint amountWETH, uint liquidityPosition) = UNI_ROUTER.addLiquidity(
            WISE_TOKEN,
            WETH_TOKEN,
            2 ether,
            correctRatioWETHforWISE,
            2 ether,
            correctRatioWETHforWISE,
            me,
            block.timestamp + 1000
        );
        console.log("amountWISE Deposited: %s", amountWISE);
        console.log("amountWETH Deposited: %s", amountWETH);
        console.log("liquidityPosition: %s", liquidityPosition);
        assertEq(amountWISE, 2 ether);
        assertEq(amountWETH, correctRatioWETHforWISE);

        (reserveWISE, reserveWETH, ) = UNI_PAIR.getReserves();
        console.log("reserveWISE: %s", reserveWISE);
        console.log("reserveWETH: %s", reserveWETH);
        console.log("WISE Token balanceOf Pair after deposit %s", WISE.balanceOf(WISE_WETH_PAIR));
        console.log("WETH Token balanceOf Pair after deposit %s", WETH.balanceOf(WISE_WETH_PAIR));
        console.log("WISE Token balanceOf Liquidity Provider after deposit %s", WISE.balanceOf(me));
        console.log("WETH Token balanceOf Liquidity Provider Pair after deposit %s", WETH.balanceOf(me));

        // at time t_1 record the amount of money yielded for selling WISE for WETH
        bq01 = UNI_ROUTER.getAmountsOut(1 ether, path);
        bq02 = UNI_ROUTER.getAmountsOut(2 ether, path);
        uint sellQuote1For1Wise = bq01[1];
        uint sellQuote1For2Wise = bq02[1];
        uint slippage1 = sellQuote1For2Wise - sellQuote1For1Wise;
        console.log("sellQuote1For1Wise: %s", sellQuote1For1Wise);
        console.log("sellQuote1For2Wise: %s", sellQuote1For2Wise);
        console.log("slippage1: %s", slippage1);

    }


    function _actuallySell(uint amount) internal returns (uint) {
        // at time t_0 record the amount of money yielded for selling WISE for WETH
        address[] memory path = new address[](2);
        path[0] = WISE_TOKEN;
        path[1] = WETH_TOKEN;
        vm.prank(me);
        uint256[] memory bq01 = UNI_ROUTER.swapExactTokensForTokens(
            amount,
            0,
            path,
            me,
            block.timestamp + 1000
        );
        assertEq(bq01[0], amount);
        uint sellQuote = bq01[1];
        return sellQuote;
    }

    function testActuallySellT01() public {
        uint sellQuote0For1Wise = _actuallySell(1 ether);
        console.log("sellQuote0For1Wise: %s", sellQuote0For1Wise);
    }

    function testActuallySellT02() public {
        uint sellQuote0For2Wise = _actuallySell(2 ether);
        console.log("sellQuote0For2Wise: %s", sellQuote0For2Wise);
    }

    function _addLiquidity() internal {
        // at time t_0.5 someone deposits an even amount of liquidity on both sides of the pool
        (uint256 reserveWISE, uint256 reserveWETH, ) = UNI_PAIR.getReserves();
        uint256 correctRatioWETHforWISE = UNI_ROUTER.quote(
            2 ether, 
            reserveWISE,
            reserveWETH
        );
        vm.prank(me);
        UNI_ROUTER.addLiquidity(
            WISE_TOKEN,
            WETH_TOKEN,
            2 ether,
            correctRatioWETHforWISE,
            2 ether,
            correctRatioWETHforWISE,
            me,
            block.timestamp + 1000
        );
    }

    function testActuallySellT11() public {
        _addLiquidity();
        uint sellQuote1For1Wise = _actuallySell(1 ether);
        console.log("sellQuote1For1Wise: %s", sellQuote1For1Wise);
    }

    function testActuallySellT12() public {
        _addLiquidity();
        uint sellQuote1For2Wise = _actuallySell(2 ether);
        console.log("sellQuote1For2Wise: %s", sellQuote1For2Wise);
    }

}
