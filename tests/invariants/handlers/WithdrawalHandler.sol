// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import {
    IInvariantTest,
    IPool,
    IPoolManager,
    IWithdrawalManagerCyclical as IWithdrawalManager
} from "../../../contracts/interfaces/Interfaces.sol";

import { console2 as console, MockERC20 } from "../../../contracts/Contracts.sol";

import { HandlerBase } from "./HandlerBase.sol";

contract WithdrawalHandler is HandlerBase {

    /**************************************************************************************************************************************/
    /*** State Variables                                                                                                                ***/
    /**************************************************************************************************************************************/

    address[] public lps;

    MockERC20          asset;
    IPool              pool;
    IWithdrawalManager wm;

    /**************************************************************************************************************************************/
    /*** Constructor                                                                                                                    ***/
    /**************************************************************************************************************************************/

    constructor(address pool_, address[] memory lps_) {
        testContract = IInvariantTest(msg.sender);

        pool  = IPool(pool_);
        asset = MockERC20(pool.asset());
        wm    = IWithdrawalManager(IPoolManager(pool.manager()).withdrawalManager());
        lps   = lps_;
    }

    /**************************************************************************************************************************************/
    /*** Actions                                                                                                                        ***/
    /**************************************************************************************************************************************/

    function redeem(uint256 seed_) external useTimestamps {
        console.log("withdrawalHandler.redeem(%s)", seed_);
        numberOfCalls["withdrawalHandler.redeem"]++;

        address lp_ = lps[_bound(_randomize(seed_, "lp"), 0, lps.length - 1)];
        uint256 exitCycleId_ = wm.exitCycleId(lp_);

        if (exitCycleId_ == 0) return;

        ( uint256 windowStart_, uint256 windowEnd_ ) = wm.getWindowAtId(wm.exitCycleId(lp_));

        if (block.timestamp > windowStart_) return;

        vm.warp(_bound(_randomize(seed_, "warp"), windowStart_, windowEnd_ - 1 seconds));

        vm.startPrank(lp_);
        pool.redeem(wm.lockedShares(lp_), lp_, lp_);
        vm.stopPrank();
    }

    function removeShares(uint256 seed_) external useTimestamps {
        console.log("withdrawalHandler.removeShares(%s)", seed_);
        numberOfCalls["withdrawalHandler.removeShares"]++;

        address lp_ = lps[_bound(_randomize(seed_, "lp"), 0, lps.length - 1)];
        uint256 exitCycleId_ = wm.exitCycleId(lp_);

        if (exitCycleId_ == 0) return;

        ( uint256 windowStart_, ) = wm.getWindowAtId(wm.exitCycleId(lp_));

        if (block.timestamp > windowStart_) return;

        vm.warp(_bound(_randomize(seed_, "warp"), windowStart_, windowStart_ + 1 days));

        vm.startPrank(lp_);
        pool.removeShares(wm.lockedShares(lp_), lp_);
        vm.stopPrank();
    }

    function requestRedeem(uint256 seed_) external useTimestamps {
        console.log("withdrawalHandler.requestRedeem(%s)", seed_);
        numberOfCalls["withdrawalHandler.requestRedeem"]++;

        address lp_ = lps[_bound(_randomize(seed_, "lp"), 0, lps.length - 1)];

        if (pool.balanceOf(lp_) == 0 || wm.lockedShares(lp_) != 0) return;

        uint256 shares_ = _bound(_randomize(seed_, "shares"), 1, pool.balanceOf(lp_));

        vm.prank(lp_);
        pool.requestRedeem(shares_, lp_);
    }

}
