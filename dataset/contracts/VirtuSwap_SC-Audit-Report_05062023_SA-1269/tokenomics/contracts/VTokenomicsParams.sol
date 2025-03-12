// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {SD59x18, sd, unwrap, exp, UNIT, ZERO} from "@prb/math/src/SD59x18.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IVTokenomicsParams.sol";

contract VTokenomicsParams is IVTokenomicsParams, Ownable {
    // parameters used in formula (3) in Virtuswap Tokenomics Whitepaper
    SD59x18 public override r;
    SD59x18 public override b;
    SD59x18 public override alpha;
    SD59x18 public override beta;
    SD59x18 public override gamma;
    SD59x18 public override lpBaseRewardsShare;
    SD59x18 public override lpBaseRewardsShareFactor;

    /**
     * @dev Initializes the contract with default values for the tokenomics parameters.
     */
    constructor() {
        r = SD59x18.wrap(102013985000);
        b = SD59x18.wrap(760618230000);
        alpha = SD59x18.wrap(5e17);
        gamma = UNIT;
        beta = SD59x18.wrap(5e17);
        lpBaseRewardsShare = SD59x18.wrap(30e18);
        lpBaseRewardsShareFactor = SD59x18.wrap(100e18);
        emit UpdateTokenomicsParams(r, b, alpha, beta, gamma);
        emit UpdateLpBaseRewardsShare(
            lpBaseRewardsShare,
            lpBaseRewardsShareFactor
        );
    }

    /// @inheritdoc IVTokenomicsParams
    function updateParams(
        SD59x18 _r,
        SD59x18 _b,
        SD59x18 _alpha,
        SD59x18 _beta,
        SD59x18 _gamma
    ) external override onlyOwner {
        r = _r;
        b = _b;
        alpha = _alpha;
        beta = _beta;
        gamma = _gamma;
        emit UpdateTokenomicsParams(_r, _b, _alpha, _beta, _gamma);
    }

    function updateLpBaseRewardsShare(
        SD59x18 _lpBaseRewardsShare,
        SD59x18 _lpBaseRewardsShareFactor
    ) external override onlyOwner {
        lpBaseRewardsShare = _lpBaseRewardsShare;
        lpBaseRewardsShareFactor = _lpBaseRewardsShareFactor;
        emit UpdateLpBaseRewardsShare(
            _lpBaseRewardsShare,
            _lpBaseRewardsShareFactor
        );
    }
}
